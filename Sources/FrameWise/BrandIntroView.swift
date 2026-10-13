#if canImport(SwiftUI)
import SwiftUI

/// The camera-independent branded opener shown during startup.
///
/// `ContentView` owns the `isActive` value. This view only animates its
/// artwork; it does not start the camera, wait on a timer, or decide when the
/// app is ready.
struct BrandIntroView: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var hasEntered = false

    private var transitionAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.2)
            : .easeOut(duration: 0.45)
    }

    var body: some View {
        ZStack {
            FrameWiseBrand.ink
                .ignoresSafeArea()

            VStack(spacing: 22) {
                OpenCropSymbol()
                    .frame(width: 88, height: 88)

                FrameWiseLockup()
            }
            .padding(.horizontal, 24)
            .opacity(hasEntered ? 1 : 0)
            .scaleEffect(
                accessibilityReduceMotion || hasEntered
                    ? 1
                    : 0.96
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(!isActive)
        .onAppear {
            withAnimation(transitionAnimation) {
                hasEntered = isActive
            }
        }
        .onChange(of: isActive) { _, newValue in
            withAnimation(transitionAnimation) {
                hasEntered = newValue
            }
        }
    }
}
#endif
