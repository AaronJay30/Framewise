/// Shared brand values that can be consumed by both app code and host tests.
///
/// UI rendering converts these stable hex values into platform colors later;
/// keeping the source values here prevents the opener and app icon from
/// drifting apart.
public enum FrameWiseBrandToken {
    /// Deep ink used for the symbol geometry and dark surfaces.
    public static let inkHex = "#10151B"
    /// Signal Coral used for the focal diamond and wordmark accent.
    public static let signalCoralHex = "#FF6B57"

    /// Minimum time the opening brand animation remains visible while the
    /// camera starts in parallel.
    public static let minimumBrandIntroDuration: Double = 2.5

    /// Whether the branded opener should remain visible for a camera state.
    public static func shouldShowBrandIntro(for state: CameraState) -> Bool {
        switch state {
        case .initializing, .requestingPermission:
            true
        case .permissionDenied, .unavailable, .ready, .running, .captureFailed:
            false
        }
    }

    /// Keep the opener visible until both its minimum display time has passed
    /// and camera startup no longer needs it.
    public static func shouldShowBrandIntro(
        for state: CameraState,
        minimumDurationElapsed: Bool
    ) -> Bool {
        if minimumDurationElapsed {
            return shouldShowBrandIntro(for: state)
        }

        return switch state {
        case .permissionDenied, .unavailable, .captureFailed:
            false
        case .initializing, .requestingPermission, .ready, .running:
            true
        }
    }
}
