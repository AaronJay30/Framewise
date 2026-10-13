public enum FrameWiseBrandToken {
    public static let inkHex = "#10151B"
    public static let signalCoralHex = "#FF6B57"

    public static func shouldShowBrandIntro(for state: CameraState) -> Bool {
        switch state {
        case .initializing, .requestingPermission:
            true
        case .permissionDenied, .unavailable, .ready, .running, .captureFailed:
            false
        }
    }
}
