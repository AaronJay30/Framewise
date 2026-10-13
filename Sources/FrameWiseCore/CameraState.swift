public enum CameraState: Equatable, Sendable {
    case initializing
    case requestingPermission
    case permissionDenied
    case unavailable
    case ready
    case running
    case captureFailed
}

public enum CameraEvent: Equatable, Sendable {
    case requestPermission
    case permissionGranted
    case permissionDenied
    case hardwareUnavailable
    case sessionConfigured
    case sessionStarted
    case captureSucceeded
    case captureFailed
    case retry
}
