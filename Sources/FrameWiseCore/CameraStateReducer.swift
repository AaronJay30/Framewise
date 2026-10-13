public enum CameraStateReducer {
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
