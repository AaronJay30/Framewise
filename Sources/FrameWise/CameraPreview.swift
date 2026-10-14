#if canImport(UIKit) && canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import FrameWiseCore
import SwiftUI
import UIKit

/// Displays a camera session without owning capture state or controls.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let deviceID: String?
    var onTap: ((CGPoint, CameraFocusPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        view.configureRotation(for: deviceID)
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // The service owns configuration; SwiftUI only keeps the layer pointed
        // at the current session.
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        uiView.configureRotation(for: deviceID)
        uiView.onTap = onTap
    }
}

/// A UIView whose backing layer is the AVFoundation preview layer.
final class PreviewView: UIView {
    var onTap: ((CGPoint, CameraFocusPoint) -> Void)?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        installTapRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installTapRecognizer()
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // `layerClass` guarantees this cast for every instance.
        layer as! AVCaptureVideoPreviewLayer
    }

    private func installTapRecognizer() {
        let recognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        recognizer.cancelsTouchesInView = false
        addGestureRecognizer(recognizer)
    }

    func configureRotation(for deviceID: String?) {
        guard let deviceID, rotationCoordinator?.device?.uniqueID != deviceID,
              let device = AVCaptureDevice(uniqueID: deviceID) else { return }
        rotationObservation = nil
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: videoPreviewLayer)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview,
                                                   options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor [weak self] in
                guard let self, self.rotationCoordinator?.device?.uniqueID == deviceID,
                      let connection = self.videoPreviewLayer.connection,
                      connection.isVideoRotationAngleSupported(angle) else { return }
                connection.videoRotationAngle = angle
            }
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        // [AC-CAMSET1014-F5]
        let previewPoint = recognizer.location(in: self)
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(
            fromLayerPoint: previewPoint
        )
        guard let focusPoint = CameraFocusPoint(
            x: Double(devicePoint.x),
            y: Double(devicePoint.y)
        ) else {
            return
        }

        onTap?(previewPoint, focusPoint)
    }
}
#endif
