#if canImport(UIKit) && canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import SwiftUI
import UIKit

/// Displays a camera session without owning capture state or controls.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // The service owns configuration; SwiftUI only keeps the layer pointed
        // at the current session.
        uiView.videoPreviewLayer.session = session
    }
}

/// A UIView whose backing layer is the AVFoundation preview layer.
final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // `layerClass` guarantees this cast for every instance.
        layer as! AVCaptureVideoPreviewLayer
    }
}
#endif
