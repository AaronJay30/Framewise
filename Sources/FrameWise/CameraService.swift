#if canImport(AVFoundation)
import AVFoundation
import Foundation
import FrameWiseCore

/// Main-actor callbacks emitted by the camera service.
@MainActor
protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ cameraService: CameraService, didEmit event: CameraEvent)
    func cameraService(
        _ cameraService: CameraService,
        didCapturePhoto data: Data,
        settings: CameraSettings
    )
    func cameraService(
        _ cameraService: CameraService,
        didUpdateExposureRange range: CameraExposureRange
    )
    func cameraService(
        _ cameraService: CameraService,
        didUpdateZoomRange range: ClosedRange<Float>
    )
    func cameraService(
        _ cameraService: CameraService,
        didUpdateFlashAvailability isAvailable: Bool
    )
    func cameraService(
        _ cameraService: CameraService,
        didUpdatePhotoResolution capability: CameraPhotoResolutionCapability
    )
    func cameraService(_ cameraService: CameraService, didChangeDeviceID deviceID: String)
}

/// Owns the AVFoundation session and keeps session work off the UI thread.
///
/// The service reports facts through `CameraEvent` instead of deciding how a
/// screen should look. That keeps permission, hardware, and capture recovery
/// in the reducer and view model.
final class CameraService: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    weak var delegate: CameraServiceDelegate?

    private let sessionQueue = DispatchQueue(label: "com.framewise.camera.session")
    private var photoOutput = AVCapturePhotoOutput()
    private let captureSettingsLock = NSLock()
    private var videoInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentSettings = CameraSettings.defaults
    private var appliedSettings: CameraSettings?
    private var photoResolutionCapability: CameraPhotoResolutionCapability?
    private var photoDimensionsByPixelCount: [Int64: CMVideoDimensions] = [:]
    private var pinchNativeStart: Float = 1
    private var captureSettingsByID: [Int64: CameraSettings] = [:]
    private var isConfigured = false

    /// Starts permission handling and session configuration on the service queue.
    func start() {
        sessionQueue.async { [weak self] in
            self?.startOnQueue()
        }
    }

    /// Stops the running session without tearing down its configured inputs.
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    /// Replaces the current video input with the opposite camera when available.
    func flipCamera() {
        sessionQueue.async { [weak self] in
            self?.flipCameraOnQueue()
        }
    }

    /// Applies the latest user-selected values on the session queue.
    // [AC-CAMSET1014-F4] [AC-CAMSET1014-F7]
    func apply(settings: CameraSettings, animatedZoom: Bool = false) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.currentSettings = settings.normalized()

            guard self.isConfigured else { return }
            self.applySettingsOnQueue(animatedZoom: animatedZoom)
        }
    }

    /// Starts a pinch from the actual lens position, including during a preset ramp.
    func pinchZoom(
        magnification: Float,
        isStarting: Bool,
        completion: @escaping @MainActor @Sendable (Float) -> Void
    ) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.videoInput?.device,
                  self.session.isRunning else { return }
            if isStarting { self.pinchNativeStart = Float(device.videoZoomFactor) }
            self.currentSettings.zoomFactor = self.zoomScale(for: device).pinchFactor(
                nativeStart: self.pinchNativeStart, magnification: magnification
            )
            self.applySettingsOnQueue(force: isStarting)
            let zoom = self.currentSettings.zoomFactor
            Task { @MainActor in completion(zoom) }
        }
    }

    /// Focuses and meters at a normalized point from the preview layer.
    // [AC-CAMSET1014-F5] [AC-CAMSET1014-E1]
    func focus(at point: CameraFocusPoint) {
        sessionQueue.async { [weak self] in
            self?.focusOnQueue(at: point, lockFocus: false)
        }
    }

    /// Locks or unlocks focus at the last selected preview point.
    func setFocusLock(at point: CameraFocusPoint, locked: Bool) {
        sessionQueue.async { [weak self] in
            self?.focusOnQueue(at: point, lockFocus: locked)
        }
    }

    /// Requests one still photo from the configured photo output.
    // [AC-CAMSET1014-F2] [AC-CAMSET1014-E1]
    func capturePhoto(using settings: CameraSettings) {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, self.session.isRunning else {
                self?.emit(.captureFailed)
                return
            }

            let captureSettings = self.clampedSettingsOnQueue(settings)
            self.currentSettings = captureSettings
            // A capture must use the requested zoom even if a preset ramp is in flight.
            self.applySettingsOnQueue(force: true)

            let photoSettings = AVCapturePhotoSettings()
            if let maxPhotoDimensions = self.photoDimensionsOnQueue(
                for: captureSettings.photoResolution
            ) {
                photoSettings.maxPhotoDimensions = maxPhotoDimensions
            }
            if let angle = self.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
               let connection = self.photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if let flashMode = self.supportedFlashMode(for: captureSettings.flashMode) {
                photoSettings.flashMode = flashMode
            }

            self.captureSettingsLock.lock()
            self.captureSettingsByID[photoSettings.uniqueID] = captureSettings
            self.captureSettingsLock.unlock()
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    // MARK: - Session queue

    private func startOnQueue() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartOnQueue()
        case .notDetermined:
            emit(.requestPermission)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                self.sessionQueue.async {
                    if granted {
                        self.emit(.permissionGranted)
                        self.configureAndStartOnQueue()
                    } else {
                        self.emit(.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            emit(.permissionDenied)
        @unknown default:
            emit(.permissionDenied)
        }
    }

    private func configureAndStartOnQueue() {
        if isConfigured {
            if !session.isRunning {
                session.startRunning()
            }
            emit(session.isRunning ? .sessionStarted : .hardwareUnavailable)
            return
        }

        guard let input = makeInput(for: currentPosition) else {
            emit(.hardwareUnavailable)
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            emit(.hardwareUnavailable)
            return
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        session.commitConfiguration()

        videoInput = input
        appliedSettings = nil
        updateRotationCoordinator(for: input.device)
        updatePhotoResolutionOnQueue(for: input.device)
        isConfigured = true
        emit(.sessionConfigured)
        applySettingsOnQueue()
        emitCapabilities(for: input.device)

        session.startRunning()
        emit(session.isRunning ? .sessionStarted : .hardwareUnavailable)
    }

    private func flipCameraOnQueue() {
        guard isConfigured, let oldInput = videoInput else { return }

        let nextPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        guard let newInput = makeInput(for: nextPosition) else {
            emit(.hardwareUnavailable)
            return
        }

        session.beginConfiguration()
        session.removeInput(oldInput)

        guard session.canAddInput(newInput) else {
            session.addInput(oldInput)
            session.commitConfiguration()
            emit(.hardwareUnavailable)
            return
        }

        session.addInput(newInput)
        session.commitConfiguration()
        videoInput = newInput
        appliedSettings = nil
        updateRotationCoordinator(for: newInput.device)
        currentPosition = nextPosition
        updatePhotoResolutionOnQueue(for: newInput.device)
        applySettingsOnQueue()
        emitCapabilities(for: newInput.device)
    }

    private func makeInput(for position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        // Virtual rear cameras allow zooming out to the ultrawide constituent.
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: device) {
                return input
            }
        }
        return nil
    }

    private func updateRotationCoordinator(for device: AVCaptureDevice) {
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        let deviceID = device.uniqueID
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(self, didChangeDeviceID: deviceID)
        }
    }

    private func clampedSettingsOnQueue(_ settings: CameraSettings) -> CameraSettings {
        guard let device = videoInput?.device else {
            return settings.normalized()
        }

        return settings.clamped(
            exposureRange: exposureRange(for: device),
            zoomRange: zoomRange(for: device)
        )
    }

    private func applySettingsOnQueue(animatedZoom: Bool = false, force: Bool = false) {
        guard let device = videoInput?.device else { return }

        let exposureRange = exposureRange(for: device)
        let zoomRange = zoomRange(for: device)
        currentSettings = currentSettings.clamped(
            exposureRange: exposureRange,
            zoomRange: zoomRange
        )
        let changes = currentSettings.hardwareChanges(from: force ? nil : appliedSettings)
        guard changes.exposure || changes.zoom,
              (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        let supportsExposureBias = device.isExposureModeSupported(.continuousAutoExposure) ||
            device.isExposureModeSupported(.autoExpose)
        if changes.exposure && supportsExposureBias {
            if device.isExposureModeSupported(.continuousAutoExposure) {
                if device.exposureMode != .continuousAutoExposure {
                    device.exposureMode = .continuousAutoExposure
                }
            } else {
                if device.exposureMode != .autoExpose { device.exposureMode = .autoExpose }
            }
            device.setExposureTargetBias(currentSettings.exposureBias)
        }
        if changes.zoom {
            let nativeZoom = CGFloat(zoomScale(for: device).nativeFactor(display: currentSettings.zoomFactor))
            let target = min(max(nativeZoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.cancelVideoZoomRamp()
            if animatedZoom && session.isRunning {
                device.ramp(toVideoZoomFactor: target, withRate: 8)
            } else {
                device.videoZoomFactor = target
            }
        }
        appliedSettings = currentSettings
    }

    private func emitCapabilities(for device: AVCaptureDevice) {
        emitExposureRange(exposureRange(for: device))
        emitZoomRange(zoomRange(for: device))
        emitFlashAvailability(for: device)
        emitPhotoResolutionCapability()
    }

    private func updatePhotoResolutionOnQueue(for device: AVCaptureDevice) {
        var dimensionsByPixelCount: [Int64: CMVideoDimensions] = [:]
        let supportedDimensions = device.activeFormat.supportedMaxPhotoDimensions.map { dimensions in
            let coreDimensions = CameraPhotoDimensions(
                width: Int(dimensions.width),
                height: Int(dimensions.height)
            )
            dimensionsByPixelCount[coreDimensions.pixelCount] = dimensions
            return coreDimensions
        }

        if supportedDimensions.isEmpty, isConfigured {
            resetPhotoOutputOnQueue()
        }

        let capability = CameraPhotoResolutionCapability(
            supportedDimensions: supportedDimensions
        )
        photoDimensionsByPixelCount = dimensionsByPixelCount
        photoResolutionCapability = capability

        if let maximum = capability.maximum ?? capability.standard,
           let maxPhotoDimensions = dimensionsByPixelCount[maximum.pixelCount] {
            photoOutput.maxPhotoDimensions = maxPhotoDimensions
        }
    }

    private func resetPhotoOutputOnQueue() {
        let replacement = AVCapturePhotoOutput()

        session.beginConfiguration()
        session.removeOutput(photoOutput)
        guard session.canAddOutput(replacement) else {
            session.addOutput(photoOutput)
            session.commitConfiguration()
            return
        }

        session.addOutput(replacement)
        session.commitConfiguration()
        photoOutput = replacement
    }

    private func photoDimensionsOnQueue(
        for resolution: CameraPhotoResolution
    ) -> CMVideoDimensions? {
        let dimension = resolution == .maximum
            ? photoResolutionCapability?.maximum ?? photoResolutionCapability?.standard
            : photoResolutionCapability?.standard
        guard let dimension else { return nil }
        return photoDimensionsByPixelCount[dimension.pixelCount]
    }

    private func focusOnQueue(at point: CameraFocusPoint, lockFocus: Bool) {
        guard let device = videoInput?.device,
              (try? device.lockForConfiguration()) != nil else {
            return
        }

        let devicePoint = CGPoint(x: point.x, y: point.y)
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = devicePoint
            if lockFocus, device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
        }

        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = devicePoint
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        }

        device.unlockForConfiguration()
    }

    private func exposureRange(for device: AVCaptureDevice) -> CameraExposureRange {
        CameraExposureRange(
            minimum: device.minExposureTargetBias,
            maximum: device.maxExposureTargetBias
        )
    }

    private func zoomRange(for device: AVCaptureDevice) -> ClosedRange<Float> {
        let scale = zoomScale(for: device)
        let minimum = scale.displayFactor(native: Float(device.minAvailableVideoZoomFactor))
        let maximum = scale.displayFactor(native: Float(device.maxAvailableVideoZoomFactor))
        return minimum...maximum
    }

    private func zoomScale(for device: AVCaptureDevice) -> CameraZoomScale {
        if #available(iOS 18.0, *) {
            return CameraZoomScale(displayMultiplier: Float(device.displayVideoZoomFactorMultiplier))
        }
        // On iOS 17, the first switch-over on an ultrawide virtual device is 1x wide.
        if device.constituentDevices.contains(where: { $0.deviceType == .builtInUltraWideCamera }),
           let wideFactor = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            return CameraZoomScale(displayMultiplier: 1 / wideFactor.floatValue)
        }
        return CameraZoomScale(displayMultiplier: 1)
    }

    private func supportedFlashMode(
        for mode: CameraFlashMode
    ) -> AVCaptureDevice.FlashMode? {
        let requested: AVCaptureDevice.FlashMode
        switch mode {
        case .auto:
            requested = .auto
        case .on:
            requested = .on
        case .off:
            requested = .off
        }

        guard photoOutput.supportedFlashModes.contains(requested) else {
            return photoOutput.supportedFlashModes.contains(.off) ? .off : nil
        }

        return requested
    }

    private func emitExposureRange(_ range: CameraExposureRange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(self, didUpdateExposureRange: range)
        }
    }

    private func emitZoomRange(_ range: ClosedRange<Float>) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(self, didUpdateZoomRange: range)
        }
    }

    private func emitFlashAvailability(for device: AVCaptureDevice) {
        let isAvailable = device.hasFlash && !photoOutput.supportedFlashModes.isEmpty
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(
                self,
                didUpdateFlashAvailability: isAvailable
            )
        }
    }

    private func emitPhotoResolutionCapability() {
        guard let capability = photoResolutionCapability else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(
                self,
                didUpdatePhotoResolution: capability
            )
        }
    }

    private func emit(_ event: CameraEvent) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(self, didEmit: event)
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let captureSettings = removeCaptureSettings(
            for: photo.resolvedSettings.uniqueID
        ) ?? CameraSettings.defaults

        guard error == nil, let data = photo.fileDataRepresentation() else {
            emit(.captureFailed)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(
                self,
                didCapturePhoto: data,
                settings: captureSettings
            )
            self.delegate?.cameraService(self, didEmit: .captureSucceeded)
        }
    }

    private func removeCaptureSettings(for id: Int64) -> CameraSettings? {
        captureSettingsLock.lock()
        defer { captureSettingsLock.unlock() }
        return captureSettingsByID.removeValue(forKey: id)
    }
}
#endif
