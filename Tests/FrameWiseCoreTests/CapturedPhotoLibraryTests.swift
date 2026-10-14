import XCTest
@testable import FrameWiseCore

final class CapturedPhotoLibraryTests: XCTestCase {
    func testAC_PHOTO1014_F1_InsertAddsExactlyOneCapture() {
        let id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let photo = CapturedPhoto(
            id: id,
            data: Data([0x01, 0x02, 0x03]),
            capturedAt: capturedAt,
            isExported: false
        )!
        var library = CapturedPhotoLibrary()

        library.insert(photo)

        XCTAssertEqual(library.photos, [photo])
        XCTAssertEqual(library.photo(withID: id), photo)
    }

    func testAC_PHOTO1014_F3_InsertKeepsNewestCaptureFirst() {
        let older = CapturedPhoto(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            data: Data([0x01]),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            isExported: false
        )!
        let newer = CapturedPhoto(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            data: Data([0x02]),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_001),
            isExported: false
        )!
        var library = CapturedPhotoLibrary()

        library.insert(older)
        library.insert(newer)

        XCTAssertEqual(library.photos, [newer, older])
    }

    func testAC_PHOTO1014_F8_RemoveDeletesOnlyTheRequestedCapture() {
        let first = makePhoto(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", byte: 0x01)
        let second = makePhoto(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", byte: 0x02)
        var library = CapturedPhotoLibrary()
        library.insert(first)
        library.insert(second)

        XCTAssertTrue(library.remove(id: first.id))
        XCTAssertFalse(library.remove(id: first.id))
        XCTAssertEqual(library.photos, [second])
    }

    func testAC_PHOTO1014_F7_MarkExportedChangesOnlyTheRequestedCapture() {
        let first = makePhoto(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", byte: 0x01)
        let second = makePhoto(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", byte: 0x02)
        var library = CapturedPhotoLibrary()
        library.insert(first)
        library.insert(second)

        XCTAssertTrue(library.markExported(id: first.id))
        XCTAssertFalse(library.markExported(id: first.id))
        XCTAssertEqual(library.photo(withID: first.id)?.isExported, true)
        XCTAssertEqual(library.photo(withID: second.id)?.isExported, false)
    }

    func testAC_PHOTO1014_ERR2_UnexportedPhotoRemainsUnexportedUntilMarkExported() {
        let photo = makePhoto(id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC", byte: 0x03)
        var library = CapturedPhotoLibrary()
        library.insert(photo)

        XCTAssertEqual(library.photo(withID: photo.id)?.isExported, false)

        XCTAssertTrue(library.markExported(id: photo.id))
        XCTAssertEqual(library.photo(withID: photo.id)?.isExported, true)
    }

    func testAC_PHOTO1014_E1_NewLibraryIsEmpty() {
        XCTAssertTrue(CapturedPhotoLibrary().photos.isEmpty)
    }

    func testAC_PHOTO1014_E2_EmptyDataCannotCreateCapture() {
        XCTAssertNil(
            CapturedPhoto(
                id: UUID(),
                data: Data(),
                capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
                isExported: false
            )
        )
    }

    private func makePhoto(id: String, byte: UInt8) -> CapturedPhoto {
        CapturedPhoto(
            id: UUID(uuidString: id)!,
            data: Data([byte]),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            isExported: false
        )!
    }
}
