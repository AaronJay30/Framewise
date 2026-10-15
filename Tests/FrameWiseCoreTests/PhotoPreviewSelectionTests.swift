import XCTest
@testable import FrameWiseCore

final class PhotoPreviewSelectionTests: XCTestCase {
    private let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let middle = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let last = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    // [AC-CAMLIB1015-F13]
    func testAC_CAMLIB1015_F13_RemovingMiddleSelectsNextPhoto() {
        XCTAssertEqual(
            PhotoPreviewSelection.neighbor(afterRemoving: middle, from: [first, middle, last]),
            last
        )
    }

    // [AC-CAMLIB1015-F13]
    func testAC_CAMLIB1015_F13_RemovingFirstSelectsNextPhoto() {
        XCTAssertEqual(
            PhotoPreviewSelection.neighbor(afterRemoving: first, from: [first, middle, last]),
            middle
        )
    }

    // [AC-CAMLIB1015-F13]
    func testAC_CAMLIB1015_F13_RemovingLastSelectsPreviousPhoto() {
        XCTAssertEqual(
            PhotoPreviewSelection.neighbor(afterRemoving: last, from: [first, middle, last]),
            middle
        )
    }

    // [AC-CAMLIB1015-F13]
    func testAC_CAMLIB1015_F13_RemovingOnlyPhotoHasNoNeighbor() {
        XCTAssertNil(PhotoPreviewSelection.neighbor(afterRemoving: first, from: [first]))
    }
}
