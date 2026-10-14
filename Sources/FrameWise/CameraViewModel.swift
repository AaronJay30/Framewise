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
    @Published private(set) var zoomRange: ClosedRange<Float> = 1...10
    @Published private(set) var focusPoint: CGPoint?
    @Published private(set) var countdown: Int?

    let session: AVCaptureSession

    private let service: CameraService
    private var pendingCaptureTask: Task<Void, Never>?
    private var focusIndicatorTask: Task<Void, Never>?

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
    }

    deinit {
        pendingCaptureTask?.cancel()
        focusIndicatorTask?.cancel()
    }

    /// Starts camera authorization and session setup.
    func start() {
        service.start()
    }

    /// Stops the running session while keeping its configuration available for reuse.
    func stop() {
        cancelPendingCapture()
        focusIndicatorTask?.cancel()
        focusIndicatorTask = nil
        focusPoint = nil
        service.stop()
    }

    /// Restarts the service after a permission, hardware, or capture failure.
    func retry() {
        state = CameraStateReducer.reduce(state, event: .retry)
        service.start()
    }

    /// Requests the opposite camera while keeping the service boundary intact.
    func flipCamera() {
        service.flipCamera()
    }

    /// Requests a still photo from the running session.
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

    /// Saves a normalized settings value and applies it to the active device.
    func updateSettings(_ settings: CameraSettings) {
        let normalized = settings.normalized()
        self.settings = normalized
        saveSettings(normalized)
        service.apply(settings: normalized)
    }

    /// Restores the safe defaults and applies them to the active device.
    func resetSettings() {
        updateSettings(.defaults)
    }

    /// Focuses the device at the preview tap and keeps the local marker visible.
    func focus(previewPoint: CGPoint, devicePoint: CameraFocusPoint) {
        focusPoint = previewPoint
        focusIndicatorTask?.cancel()
        focusIndicatorTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            self.focusPoint = nil
            self.focusIndicatorTask = nil
        }
        service.focus(at: devicePoint)
    }

    /// Updates zoom within the active device's published range.
    func setZoomFactor(_ zoomFactor: Float) {
        var updated = settings
        updated.zoomFactor = min(
            max(zoomFactor, zoomRange.lowerBound),
            zoomRange.upperBound
        )
        updateSettings(updated)
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

    func cameraService(_ cameraService: CameraService, didEmit event: CameraEvent) {
        state = CameraStateReducer.reduce(state, event: event)
    }

    func cameraService(
        _ cameraService: CameraService,
        didCapturePhoto data: Data,
        settings: CameraSettings
    ) {
        let processedData = CameraPhotoProcessor.process(
            data: data,
            settings: settings
        )

        guard let photo = CapturedPhoto(
            id: UUID(),
            data: processedData,
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
        exposureRange = range

        var adjusted = settings
        adjusted.exposureBias = min(
            max(settings.exposureBias, range.minimum),
            range.maximum
        )
        if adjusted.exposureBias != settings.exposureBias {
            settings = adjusted
            saveSettings(adjusted)
        }
    }

    func cameraService(
        _ cameraService: CameraService,
        didUpdateZoomRange range: ClosedRange<Float>
    ) {
        zoomRange = range

        var adjusted = settings
        adjusted.zoomFactor = min(
            max(settings.zoomFactor, range.lowerBound),
            range.upperBound
        )
        if adjusted.zoomFactor != settings.zoomFactor {
            settings = adjusted
            saveSettings(adjusted)
        }
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
