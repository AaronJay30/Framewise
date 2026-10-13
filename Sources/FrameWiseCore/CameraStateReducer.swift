/// Applies one camera event to the current UI-facing state.
///
/// Invalid event/state combinations are deliberately no-ops. That gives
/// asynchronous callbacks a safe default if they arrive after a retry or
/// after the user has already reached a terminal recovery state.
public enum CameraStateReducer {
    /// Returns the next camera state without mutating the input state.
    public static func reduce(_ state: CameraState, event: CameraEvent) -> CameraState {
        switch (state, event) {
        case (.initializing, .requestPermission):
            .requestingPermission
        case (.requestingPermission, .permissionGranted):
            .initializing
        case (.requestingPermission, .permissionDenied):
            .permissionDenied
        case (_, .hardwareUnavailable):
            .unavailable
        case (.initializing, .sessionConfigured):
            .ready
        case (.ready, .sessionStarted):
            .running
        case (.running, .captureSucceeded):
            .running
        case (.running, .captureFailed):
            .captureFailed
        case (.permissionDenied, .retry), (.unavailable, .retry), (.captureFailed, .retry):
            .initializing
        default:
            state
        }
    }
}
