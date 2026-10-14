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
    private let photoOutput = AVCapturePhotoOutput()
    private let captureSettingsLock = NSLock()
    private var videoInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var currentSettings = CameraSettings.defaults
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
    func apply(settings: CameraSettings) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.currentSettings = settings.normalized()

            guard self.isConfigured else { return }
            self.applySettingsOnQueue()
        }
    }

    /// Focuses and meters at a normalized point from the preview layer.
    // [AC-CAMSET1014-F5] [AC-CAMSET1014-E1]
    func focus(at point: CameraFocusPoint) {
        sessionQueue.async { [weak self] in
            self?.focusOnQueue(at: point)
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
            self.applySettingsOnQueue()

            let photoSettings = AVCapturePhotoSettings()
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
        isConfigured = true
        emit(.sessionConfigured)
        applySettingsOnQueue()

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
        currentPosition = nextPosition
        applySettingsOnQueue()
    }

    private func makeInput(for position: AVCaptureDevice.Position) -> AVCaptureDeviceInput? {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            return nil
        }

        return try? AVCaptureDeviceInput(device: device)
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

    private func applySettingsOnQueue() {
        guard let device = videoInput?.device else { return }

        let exposureRange = exposureRange(for: device)
        let zoomRange = zoomRange(for: device)
        currentSettings = currentSettings.clamped(
            exposureRange: exposureRange,
            zoomRange: zoomRange
        )

        guard (try? device.lockForConfiguration()) != nil else {
            emitExposureRange(exposureRange)
            emitZoomRange(zoomRange)
            emitFlashAvailability(for: device)
            return
        }

        let supportsExposureBias = device.isExposureModeSupported(.continuousAutoExposure) ||
            device.isExposureModeSupported(.autoExpose)
        if supportsExposureBias {
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            } else {
                device.exposureMode = .autoExpose
            }
            device.setExposureTargetBias(currentSettings.exposureBias)
        }
        device.videoZoomFactor = CGFloat(currentSettings.zoomFactor)
        device.unlockForConfiguration()
        emitExposureRange(exposureRange)
        emitZoomRange(zoomRange)
        emitFlashAvailability(for: device)
    }

    private func focusOnQueue(at point: CameraFocusPoint) {
        guard let device = videoInput?.device,
              (try? device.lockForConfiguration()) != nil else {
            return
        }

        let devicePoint = CGPoint(x: point.x, y: point.y)
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = devicePoint
            if device.isFocusModeSupported(.autoFocus) {
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
        Float(device.minAvailableVideoZoomFactor)...Float(device.maxAvailableVideoZoomFactor)
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
