#if canImport(UIKit) && canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import FrameWiseCore
import SwiftUI
import UIKit

/// Displays a camera session without owning capture state or controls.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onTap: ((CGPoint, CameraFocusPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // The service owns configuration; SwiftUI only keeps the layer pointed
        // at the current session.
        uiView.videoPreviewLayer.session = session
        uiView.onTap = onTap
    }
}

/// A UIView whose backing layer is the AVFoundation preview layer.
final class PreviewView: UIView {
    var onTap: ((CGPoint, CameraFocusPoint) -> Void)?

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
