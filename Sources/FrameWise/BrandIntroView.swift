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
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasEntered = false

    /// The longer entrance lets the lockup read as an intentional opener even
    /// when the camera is already warm. It remains state-driven: there is no
    /// artificial startup delay before the camera can become interactive.
    private var entranceAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.2)
            : .easeOut(duration: 1.05)
    }

    private var exitAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.2)
            : .easeInOut(duration: 0.65)
    }

    var body: some View {
        ZStack {
            FrameWiseBrand.surface(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                OpenCropSymbol()
                    .frame(width: 88, height: 88)

                FrameWiseLockup()
            }
            .padding(.horizontal, 24)
            .scaleEffect(
                accessibilityReduceMotion || hasEntered
                    ? 1
                    : 0.96
            )
        }
        .opacity(hasEntered ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(!isActive)
        .onAppear {
            withAnimation(isActive ? entranceAnimation : exitAnimation) {
                hasEntered = isActive
            }
        }
        .onChange(of: isActive) { _, newValue in
            withAnimation(newValue ? entranceAnimation : exitAnimation) {
                hasEntered = newValue
            }
        }
    }
}
#endif
