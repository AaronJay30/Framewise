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

    /// Whether the branded opener should remain visible for a camera state.
    public static func shouldShowBrandIntro(for state: CameraState) -> Bool {
        switch state {
        case .initializing, .requestingPermission:
            true
        case .permissionDenied, .unavailable, .ready, .running, .captureFailed:
            false
        }
    }
}
