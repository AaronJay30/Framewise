import XCTest
@testable import FrameWiseCore

final class PhotoGalleryDownloadTests: XCTestCase {
    private let first = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
    private let second = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
    private let third = UUID(uuidString: "00000000-0000-0000-0000-000000000023")!

    // [AC-GALLERYUX1015-F2]
    func testAC_GALLERYUX1015_F2_PendingDownloadSkipsAlreadyExportedPhotos() {
        XCTAssertEqual(
            PhotoGalleryDownload.pendingIDs(
                selectedIDs: [first, second, third],
                exportedIDs: [second]
            ),
            [first, third]
        )
    }

    // [AC-GALLERYUX1015-E1]
    func testAC_GALLERYUX1015_E1_PendingDownloadIsEmptyWhenAllSelectedAreExported() {
        XCTAssertTrue(
            PhotoGalleryDownload.pendingIDs(
                selectedIDs: [first, second],
                exportedIDs: [first, second, third]
            ).isEmpty
        )
    }
}
