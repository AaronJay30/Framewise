import XCTest
@testable import FrameWiseCore

final class BrandingTokenTests: XCTestCase {
    func testUsesTheApprovedInkAndSignalCoralTokens() {
        XCTAssertEqual(FrameWiseBrandToken.inkHex, "#10151B")
        XCTAssertEqual(FrameWiseBrandToken.signalCoralHex, "#FF6B57")
    }
}
