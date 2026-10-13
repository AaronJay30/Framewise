/// The UI-facing phases of camera startup and capture.
///
/// These values describe what the app can safely show. They do not contain
/// AVFoundation objects, which keeps error and recovery behavior testable.
public enum CameraState: Equatable, Sendable {
    /// The service is checking authorization or configuring a session.
    case initializing
    /// The system permission prompt is being requested.
    case requestingPermission
    /// The user declined camera access.
    case permissionDenied
    /// No usable camera input is available.
    case unavailable
    /// A session is configured but has not started delivering frames yet.
    case ready
    /// The preview session is running and can capture a photo.
    case running
    /// A photo capture failed, but the preview can be retried.
    case captureFailed
}

/// Events emitted by the camera service and user recovery actions.
///
/// The reducer consumes these small events instead of exposing framework
/// types to the rest of the app.
public enum CameraEvent: Equatable, Sendable {
    /// Ask the system for camera permission.
    case requestPermission
    /// The permission request was granted.
    case permissionGranted
    /// The permission request was denied or restricted.
    case permissionDenied
    /// The requested hardware is not present or cannot be configured.
    case hardwareUnavailable
    /// Session inputs and outputs were configured successfully.
    case sessionConfigured
    /// The configured session has started.
    case sessionStarted
    /// A photo was delivered successfully.
    case captureSucceeded
    /// Photo capture failed without making the preview unusable.
    case captureFailed
    /// Return from a recoverable terminal state to camera initialization.
    case retry
}
