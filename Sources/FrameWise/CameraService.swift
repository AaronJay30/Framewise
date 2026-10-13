#if canImport(AVFoundation)
import AVFoundation
import Foundation
import FrameWiseCore

/// Main-actor callbacks emitted by the camera service.
@MainActor
protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ cameraService: CameraService, didEmit event: CameraEvent)
    func cameraService(_ cameraService: CameraService, didCapturePhoto data: Data)
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
    private var videoInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back
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

    /// Requests one still photo from the configured photo output.
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, self.session.isRunning else {
                self?.emit(.captureFailed)
                return
            }

            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
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
        guard error == nil, let data = photo.fileDataRepresentation() else {
            emit(.captureFailed)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(self, didCapturePhoto: data)
            self.delegate?.cameraService(self, didEmit: .captureSucceeded)
        }
    }
}
#endif
