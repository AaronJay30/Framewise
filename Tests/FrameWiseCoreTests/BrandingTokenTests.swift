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

    func testBrandIntroHonorsItsMinimumDisplayDuration() {
        XCTAssertEqual(FrameWiseBrandToken.minimumBrandIntroDuration, 2.5)
        XCTAssertTrue(
            FrameWiseBrandToken.shouldShowBrandIntro(
                for: .running,
                minimumDurationElapsed: false
            )
        )
        XCTAssertFalse(
            FrameWiseBrandToken.shouldShowBrandIntro(
                for: .running,
                minimumDurationElapsed: true
            )
        )
        XCTAssertTrue(
            FrameWiseBrandToken.shouldShowBrandIntro(
                for: .initializing,
                minimumDurationElapsed: true
            )
        )
    }

    func testTerminalRecoveryStatesCanReplaceBrandIntroImmediately() {
        XCTAssertFalse(
            FrameWiseBrandToken.shouldShowBrandIntro(
                for: .permissionDenied,
                minimumDurationElapsed: false
            )
        )
        XCTAssertFalse(
            FrameWiseBrandToken.shouldShowBrandIntro(
                for: .unavailable,
                minimumDurationElapsed: false
            )
        )
        XCTAssertFalse(
            FrameWiseBrandToken.shouldShowBrandIntro(
                for: .captureFailed,
                minimumDurationElapsed: false
            )
        )
    }
}
