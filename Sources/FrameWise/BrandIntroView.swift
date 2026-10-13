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
    @State private var hasLockupEntered = false

    /// A restrained spring gives the mark a soft, spatial arrival without
    /// making the premium wordmark feel bouncy.
    private var entranceAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(response: 0.9, dampingFraction: 0.88)
    }

    /// The wordmark follows the symbol so the two parts read as one sequence.
    private var lockupEntranceAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.2)
            : .easeOut(duration: 0.7).delay(0.16)
    }

    private var exitAnimation: Animation {
        accessibilityReduceMotion
            ? .easeInOut(duration: 0.2)
            : .easeInOut(duration: 0.35)
    }

    var body: some View {
        ZStack {
            FrameWiseBrand.surface(for: colorScheme)
                .opacity(isActive ? 1 : 0)
                .ignoresSafeArea()
                .animation(exitAnimation, value: isActive)

            VStack(spacing: 22) {
                OpenCropSymbol()
                    .frame(width: 88, height: 88)
                    .opacity(hasEntered ? 1 : 0)
                    .scaleEffect(
                        accessibilityReduceMotion || hasEntered ? 1 : 0.9
                    )
                    .offset(
                        y: accessibilityReduceMotion || hasEntered ? 0 : 14
                    )
                    .animation(
                        isActive ? entranceAnimation : exitAnimation,
                        value: hasEntered
                    )

                FrameWiseLockup()
                    .opacity(hasLockupEntered ? 1 : 0)
                    .offset(
                        y: accessibilityReduceMotion || hasLockupEntered ? 0 : 8
                    )
                    .animation(
                        isActive ? lockupEntranceAnimation : exitAnimation,
                        value: hasLockupEntered
                    )
            }
            .padding(.horizontal, 24)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(!isActive)
        .onAppear {
            setEntranceActive(isActive)
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                setEntranceActive(true)
            } else {
                withAnimation(exitAnimation) {
                    hasEntered = false
                    hasLockupEntered = false
                }
            }
        }
    }

    private func setEntranceActive(_ active: Bool) {
        guard active else { return }

        withAnimation(entranceAnimation) {
            hasEntered = true
        }
        withAnimation(lockupEntranceAnimation) {
            hasLockupEntered = true
        }
    }
}
#endif
