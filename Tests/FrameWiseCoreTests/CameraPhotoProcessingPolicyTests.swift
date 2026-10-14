import XCTest
@testable import FrameWiseCore

final class CameraPhotoProcessingPolicyTests: XCTestCase {
    // [AC-CAMSET1014-E3]
    func testAC_CAMSET1014_E3_InvalidProcessedDataReturnsOriginalBytes() {
        let original = Data([0x10, 0x20, 0x30])

        XCTAssertEqual(
            CameraPhotoProcessingPolicy.output(
                original: original,
                processed: nil
            ),
            original
        )
        XCTAssertEqual(
            CameraPhotoProcessingPolicy.output(
                original: original,
                processed: Data()
            ),
            original
        )
        XCTAssertEqual(
            CameraPhotoProcessingPolicy.output(
                original: original,
                processed: Data([0x40])
            ),
            Data([0x40])
        )
    }
}
