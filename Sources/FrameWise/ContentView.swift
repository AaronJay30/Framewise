#if canImport(UIKit) && canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import FrameWiseCore
import SwiftUI

/// The composition root for the camera-first experience.
///
/// It owns one view model for the lifetime of the screen and starts camera
/// setup from SwiftUI's lifecycle. AVFoundation configuration stays in the
/// service, not in this view.
struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var minimumIntroDurationElapsed = false

    var body: some View {
        ZStack {
            CameraScreen(viewModel: viewModel)

            BrandIntroView(
                isActive: FrameWiseBrandToken.shouldShowBrandIntro(
                    for: viewModel.state,
                    minimumDurationElapsed: minimumIntroDurationElapsed
                )
            )
        }
        .task {
            viewModel.start()

            do {
                try await Task.sleep(
                    for: .seconds(FrameWiseBrandToken.minimumBrandIntroDuration)
                )
            } catch {
                // A canceled view task should not update its startup state.
                return
            }

            minimumIntroDurationElapsed = true
        }
    }
}
#endif
