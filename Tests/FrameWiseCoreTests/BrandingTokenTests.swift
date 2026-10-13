import XCTest
@testable import FrameWiseCore

final class BrandingTokenTests: XCTestCase {
    func testUsesTheApprovedInkAndSignalCoralTokens() {
        XCTAssertEqual(FrameWiseBrandToken.inkHex, "#10151B")
        XCTAssertEqual(FrameWiseBrandToken.signalCoralHex, "#FF6B57")
    }

    func testBrandIntroStaysActiveOnlyDuringCameraInitialization() {
        XCTAssertTrue(FrameWiseBrandToken.shouldShowBrandIntro(for: .initializing))
        XCTAssertTrue(FrameWiseBrandToken.shouldShowBrandIntro(for: .requestingPermission))

        let terminalStates: [CameraState] = [
            .permissionDenied,
            .unavailable,
            .ready,
            .running,
            .captureFailed,
        ]

        for state in terminalStates {
            XCTAssertFalse(
                FrameWiseBrandToken.shouldShowBrandIntro(for: state),
                "The opener should be dismissed for \(state)."
            )
        }
    }
}
