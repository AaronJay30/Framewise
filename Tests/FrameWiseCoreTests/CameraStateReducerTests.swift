import XCTest
@testable import FrameWiseCore

final class CameraStateReducerTests: XCTestCase {
    func testRequestPermissionMovesToPermissionRequestState() {
        let next = CameraStateReducer.reduce(.initializing, event: .requestPermission)

        XCTAssertEqual(next, .requestingPermission)
    }

    func testPermissionDeniedMovesToPermissionDeniedState() {
        let next = CameraStateReducer.reduce(.requestingPermission, event: .permissionDenied)

        XCTAssertEqual(next, .permissionDenied)
    }

    func testUnavailableHardwareMovesToUnavailableState() {
        let next = CameraStateReducer.reduce(.initializing, event: .hardwareUnavailable)

        XCTAssertEqual(next, .unavailable)
    }

    func testConfiguredAndStartedSessionMovesToRunningState() {
        let ready = CameraStateReducer.reduce(.initializing, event: .sessionConfigured)
        let running = CameraStateReducer.reduce(ready, event: .sessionStarted)

        XCTAssertEqual(ready, .ready)
        XCTAssertEqual(running, .running)
    }

    func testCaptureFailureLeavesARecoverableFailureState() {
        let failed = CameraStateReducer.reduce(.running, event: .captureFailed)
        let retrying = CameraStateReducer.reduce(failed, event: .retry)

        XCTAssertEqual(failed, .captureFailed)
        XCTAssertEqual(retrying, .initializing)
    }

    func testGrantedPermissionReturnsToInitialization() {
        let next = CameraStateReducer.reduce(.requestingPermission, event: .permissionGranted)

        XCTAssertEqual(next, .initializing)
    }
}
