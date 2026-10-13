#if canImport(UIKit) && canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import SwiftUI

/// The composition root for the camera-first experience.
///
/// It owns one view model for the lifetime of the screen and starts camera
/// setup from SwiftUI's lifecycle. AVFoundation configuration stays in the
/// service, not in this view.
struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        CameraScreen(viewModel: viewModel)
            .task {
                viewModel.start()
            }
            .preferredColorScheme(.dark)
    }
}
#endif
