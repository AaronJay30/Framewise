#if canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import Combine
import CoreGraphics
import Foundation
import FrameWiseCore
import SwiftUI

/// Main-actor state bridge between `CameraService` and SwiftUI.
@MainActor
final class CameraViewModel: ObservableObject, CameraServiceDelegate {
    @Published private(set) var state: CameraState = .initializing
    @Published private(set) var lastCapturedPhoto: CapturedPhoto?
    @Published private(set) var pendingCapturedPhotos: [CapturedPhoto] = []
    @Published private(set) var settings: CameraSettings
    @Published private(set) var exposureRange: CameraExposureRange = .defaults
    @Published private(set) var zoomRange: ClosedRange<Float> = 1...1
    @Published private(set) var flashAvailable = true
    @Published private(set) var focusPoint: CGPoint?
    @Published private(set) var isFocusLocked = false
    @Published private(set) var countdown: Int?
    @Published private(set) var activeDeviceID: String?

    let session: AVCaptureSession

    private let service: CameraService
    private var pendingCaptureTask: Task<Void, Never>?
    private var focusIndicatorTask: Task<Void, Never>?
    private var focusedDevicePoint: CameraFocusPoint?
    private var photoProcessingTask: Task<Void, Never>?
    private var settingsPersistence: AnyCancellable?
    private var zoomUpdateID = UUID()

    private static let settingsKey = "com.framewise.camera.settings"

    /// Creates a view model around one camera service and exposes its session
    /// to the preview without exposing session configuration to the view.
    init(service: CameraService = CameraService()) {
        let loadedSettings = Self.loadSettings()
        self.service = service
        self.session = service.session
        self.settings = loadedSettings
        service.delegate = self
        service.apply(settings: loadedSettings)
        settingsPersistence = $settings
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] settings in self?.saveSettings(settings) }
    }

    deinit {
        pendingCaptureTask?.cancel()
        focusIndicatorTask?.cancel()
        photoProcessingTask?.cancel()
    }

    /// Starts camera authorization and session setup.
    func start() {
        service.start()
    }

    /// Stops the running session while keeping its configuration available for reuse.
    func stop() {
        zoomUpdateID = UUID()
        persistSettings()
        cancelPendingCapture()
        focusIndicatorTask?.cancel()
        focusIndicatorTask = nil
        focusPoint = nil
        focusedDevicePoint = nil
        isFocusLocked = false
        service.stop()
    }

    /// Restarts the service after a permission, hardware, or capture failure.
    func retry() {
        state = CameraStateReducer.reduce(state, event: .retry)
        service.start()
    }

    /// Requests the opposite camera while keeping the service boundary intact.
    func flipCamera() {
        zoomUpdateID = UUID()
        focusIndicatorTask?.cancel()
        focusIndicatorTask = nil
        focusPoint = nil
        focusedDevicePoint = nil
        isFocusLocked = false
        service.flipCamera()
    }

    /// Requests a still photo from the running session.
    // [AC-CAMSET1014-F3] [AC-CAMSET1014-E2]
    func capturePhoto() {
        guard pendingCaptureTask == nil else { return }

        let snapshot = settings.normalized()
        guard snapshot.timerDuration != .off else {
            service.capturePhoto(using: snapshot)
            return
        }

        pendingCaptureTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for remaining in stride(
                from: snapshot.timerDuration.rawValue,
                through: 1,
                by: -1
            ) {
                guard !Task.isCancelled else {
                    self.clearPendingCapture()
                    return
                }

                self.countdown = remaining

                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    self.clearPendingCapture()
                    return
                }
            }

            guard !Task.isCancelled else {
                self.clearPendingCapture()
                return
            }

            self.clearPendingCapture()
            self.service.capturePhoto(using: snapshot)
        }
    }

    /// Publishes immediately; persistence is debounced and sensor writes are selective.
    func updateSettings(_ settings: CameraSettings, animatedZoom: Bool = false) {
        let normalized = settings.normalized()
        guard normalized != self.settings else { return }
        zoomUpdateID = UUID()
        if normalized.aspectRatio != self.settings.aspectRatio { focusPoint = nil }
        self.settings = normalized
        service.apply(settings: normalized, animatedZoom: animatedZoom)
    }

    func persistSettings() {
        saveSettings(settings)
    }

    /// Restores the safe defaults and applies them to the active device.
    func resetSettings() {
        updateSettings(.defaults)
    }

    /// Focuses the device at the preview tap and keeps the local marker visible.
    func focus(previewPoint: CGPoint, devicePoint: CameraFocusPoint) {
        focusPoint = previewPoint
        focusedDevicePoint = devicePoint
        isFocusLocked = false
        scheduleFocusIndicatorHide()
        service.focus(at: devicePoint)
    }

    func toggleFocusLock() {
        guard let focusedDevicePoint else { return }
        isFocusLocked.toggle()
        focusIndicatorTask?.cancel()
        focusIndicatorTask = nil
        if !isFocusLocked {
            scheduleFocusIndicatorHide()
        }
        service.setFocusLock(at: focusedDevicePoint, locked: isFocusLocked)
    }

    /// Updates zoom within the active device's published range.
    func setZoomFactor(_ zoomFactor: Float, animated: Bool = false) {
        var updated = settings
        updated.zoomFactor = min(
            max(zoomFactor, zoomRange.lowerBound),
            zoomRange.upperBound
        )
        updateSettings(updated, animatedZoom: animated)
    }

    func setExposureBias(_ exposureBias: Float) {
        var updated = settings
        updated.exposureBias = min(
            max(exposureBias, exposureRange.minimum),
            exposureRange.maximum
        )
        updateSettings(updated)
        refreshFocusIndicatorTimeout()
    }

    func pinchZoom(magnification: Float, isStarting: Bool) {
        let updateID = UUID()
        zoomUpdateID = updateID
        service.pinchZoom(magnification: magnification, isStarting: isStarting) { [weak self] zoom in
            guard let self, self.zoomUpdateID == updateID else { return }
            if self.settings.zoomFactor != zoom { self.settings.zoomFactor = zoom }
        }
    }

    /// Cancels a pending timer without affecting an already completed capture.
    func cancelPendingCapture() {
        pendingCaptureTask?.cancel()
        clearPendingCapture()
    }

    /// Removes a capture from the model-owned delivery queue after storage succeeds.
    func consumeCapturedPhoto(id: UUID) {
        pendingCapturedPhotos.removeAll { $0.id == id }
    }

    // MARK: - CameraServiceDelegate

    private func scheduleFocusIndicatorHide() {
        focusIndicatorTask?.cancel()
        focusIndicatorTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }

            guard let self, !Task.isCancelled, !self.isFocusLocked else { return }
            self.focusPoint = nil
            self.focusedDevicePoint = nil
            self.focusIndicatorTask = nil
        }
    }

    private func refreshFocusIndicatorTimeout() {
        guard focusPoint != nil, !isFocusLocked else { return }
        scheduleFocusIndicatorHide()
    }

    func cameraService(_ cameraService: CameraService, didChangeDeviceID deviceID: String) {
        focusIndicatorTask?.cancel()
        focusIndicatorTask = nil
        activeDeviceID = deviceID
        focusPoint = nil
        focusedDevicePoint = nil
        isFocusLocked = false
    }

    func cameraService(_ cameraService: CameraService, didEmit event: CameraEvent) {
        state = CameraStateReducer.reduce(state, event: event)
    }

    func cameraService(
        _ cameraService: CameraService,
        didCapturePhoto data: Data,
        settings: CameraSettings
    ) {
        // [AC-CAMSET1014-E3] Keep image work off the main actor.
        // Keep the delivery order stable while processing each image off-main.
        let previousProcessingTask = photoProcessingTask
        photoProcessingTask = Task { @MainActor [weak self] in
            if let previousProcessingTask {
                await previousProcessingTask.value
            }

            guard !Task.isCancelled else { return }
            let processedData = await Task.detached(priority: .userInitiated) {
                CameraPhotoProcessor.process(
                    data: data,
                    aspectRatio: settings.aspectRatio,
                    photographicStyle: settings.photographicStyle,
                    styleIntensity: settings.styleIntensity
                )
            }.value

            guard let self, !Task.isCancelled else { return }
            self.appendCapturedPhoto(data: processedData)
        }
    }

    private func appendCapturedPhoto(data: Data) {

        guard let photo = CapturedPhoto(
            id: UUID(),
            data: data,
            capturedAt: Date(),
            isExported: false
        ) else {
            return
        }

        lastCapturedPhoto = photo
        pendingCapturedPhotos.append(photo)
    }

    func cameraService(
        _ cameraService: CameraService,
        didUpdateExposureRange range: CameraExposureRange
    ) {
        let visibleRange = range.userVisibleRange
        if exposureRange != visibleRange { exposureRange = visibleRange }

        var adjusted = settings
        adjusted.exposureBias = min(
            max(settings.exposureBias, visibleRange.minimum),
            visibleRange.maximum
        )
        if adjusted.exposureBias != settings.exposureBias {
            updateSettings(adjusted)
        }
    }

    func cameraService(
        _ cameraService: CameraService,
        didUpdateZoomRange range: ClosedRange<Float>
    ) {
        if zoomRange != range { zoomRange = range }

        var adjusted = settings
        adjusted.zoomFactor = min(
            max(settings.zoomFactor, range.lowerBound),
            range.upperBound
        )
        if adjusted.zoomFactor != settings.zoomFactor {
            settings = adjusted
        }
    }

    func cameraService(
        _ cameraService: CameraService,
        didUpdateFlashAvailability isAvailable: Bool
    ) {
        if flashAvailable != isAvailable { flashAvailable = isAvailable }
    }

    private func clearPendingCapture() {
        pendingCaptureTask = nil
        countdown = nil
    }

    private static func loadSettings() -> CameraSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(
                CameraSettings.self,
                from: data
              ) else {
            return .defaults
        }

        return settings.normalized()
    }

    private func saveSettings(_ settings: CameraSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
    }
}
#endif
