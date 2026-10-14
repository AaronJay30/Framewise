#if canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import Combine
import Foundation
import FrameWiseCore
import SwiftUI

/// Main-actor state bridge between `CameraService` and SwiftUI.
@MainActor
final class CameraViewModel: ObservableObject, CameraServiceDelegate {
    @Published private(set) var state: CameraState = .initializing
    @Published private(set) var lastCapturedPhoto: CapturedPhoto?
    @Published private(set) var pendingCapturedPhotos: [CapturedPhoto] = []

    let session: AVCaptureSession

    private let service: CameraService

    /// Creates a view model around one camera service and exposes its session
    /// to the preview without exposing session configuration to the view.
    init(service: CameraService = CameraService()) {
        self.service = service
        self.session = service.session
        service.delegate = self
    }

    /// Starts camera authorization and session setup.
    func start() {
        service.start()
    }

    /// Stops the running session while keeping its configuration available for reuse.
    func stop() {
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
        service.capturePhoto()
    }

    /// Removes a capture from the model-owned delivery queue after storage succeeds.
    func consumeCapturedPhoto(id: UUID) {
        pendingCapturedPhotos.removeAll { $0.id == id }
    }

    // MARK: - CameraServiceDelegate

    func cameraService(_ cameraService: CameraService, didEmit event: CameraEvent) {
        state = CameraStateReducer.reduce(state, event: event)
    }

    func cameraService(_ cameraService: CameraService, didCapturePhoto data: Data) {
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
}
#endif
