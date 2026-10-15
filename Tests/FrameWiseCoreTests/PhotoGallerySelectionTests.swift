import XCTest
@testable import FrameWiseCore

final class PhotoGallerySelectionTests: XCTestCase {
    private let first = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    private let second = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    private let third = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!

    // [AC-CAMUX1015-F5]
    func testAC_CAMUX1015_F5_ToggleSelectsAndDeselectsGalleryPhotos() {
        let selected = PhotoGallerySelection.toggled(first, in: [])
        XCTAssertEqual(selected, [first])

        let multiple = PhotoGallerySelection.toggled(second, in: selected)
        XCTAssertEqual(multiple, [first, second])
        XCTAssertEqual(PhotoGallerySelection.toggled(first, in: multiple), [second])
    }

    // [AC-CAMUX1015-E2]
    func testAC_CAMUX1015_E2_ReconcileRemovesPhotoIDsNoLongerVisible() {
        let selected: Set<UUID> = [first, second, third]

        XCTAssertEqual(
            PhotoGallerySelection.reconciled(selected, with: [first, third]),
            [first, third]
        )
    }
}
