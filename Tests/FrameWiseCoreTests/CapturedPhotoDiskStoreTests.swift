import Foundation
import XCTest
@testable import FrameWiseCore

final class CapturedPhotoDiskStoreTests: XCTestCase {
    func testAC_PHOTO1014_F1_SavedCaptureRestoresAfterNewStoreInstance() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = makePhoto(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", byte: 0x01)

        try await CapturedPhotoDiskStore(directoryURL: directory).save(photo)

        let restored = try await CapturedPhotoDiskStore(directoryURL: directory).load()

        XCTAssertEqual(restored, [photo])
    }

    func testAC_PHOTO1014_F3_ReloadPreservesNewestFirstOrder() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let older = makePhoto(
            id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            byte: 0x01,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let newer = makePhoto(
            id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB",
            byte: 0x02,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let store = CapturedPhotoDiskStore(directoryURL: directory)

        try await store.save(older)
        try await store.save(newer)

        let reloaded = try await CapturedPhotoDiskStore(directoryURL: directory).load()

        XCTAssertEqual(reloaded.map(\.id), [newer.id, older.id])
        XCTAssertEqual(try manifestEntries(in: directory).count, 2)
        XCTAssertEqual(try manifestEntries(in: directory)[0]["filename"] as? String, imageFilename(for: newer))
        XCTAssertEqual(try manifestEntries(in: directory)[1]["filename"] as? String, imageFilename(for: older))
    }

    func testAC_PHOTO1014_F8_RemoveDeletesFileAndManifestRecord() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = makePhoto(id: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA", byte: 0x01)
        let second = makePhoto(id: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", byte: 0x02)
        let store = CapturedPhotoDiskStore(directoryURL: directory)
        try await store.save(first)
        try await store.save(second)

        try await store.remove(id: first.id)

        let remaining = try await store.load()
        XCTAssertEqual(remaining, [second])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(imageFilename(for: first)).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(imageFilename(for: second)).path))
        XCTAssertEqual(try manifestEntries(in: directory).count, 1)
        XCTAssertEqual(try manifestEntries(in: directory)[0]["id"] as? String, second.id.uuidString)
    }

    func testAC_PHOTO1014_E3_FreshStoreReloadsPreviouslySavedCapture() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = makePhoto(id: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC", byte: 0x03, isExported: true)
        let firstStore = CapturedPhotoDiskStore(directoryURL: directory)
        try await firstStore.save(photo)

        let secondStore = CapturedPhotoDiskStore(directoryURL: directory)
        let restored = try await secondStore.load()

        XCTAssertEqual(restored.first?.isExported, true)
        XCTAssertEqual(restored.first?.data, Data([0x03]))
    }

    func testAC_PHOTO1014_ERR3_CorruptManifestThrowsRecoverableStorageError() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("manifest.json"))

        do {
            _ = try await CapturedPhotoDiskStore(directoryURL: directory).load()
            XCTFail("Expected corrupt manifest error")
        } catch let error as CapturedPhotoDiskStoreError {
            XCTAssertEqual(error, .corruptManifest)
        }
    }

    func testAC_PHOTO1014_ERR3_MissingImageThrowsRecoverableStorageError() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let photo = makePhoto(id: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD", byte: 0x04)
        let store = CapturedPhotoDiskStore(directoryURL: directory)
        try await store.save(photo)
        try FileManager.default.removeItem(at: directory.appendingPathComponent(imageFilename(for: photo)))

        do {
            _ = try await store.load()
            XCTFail("Expected missing image error")
        } catch let error as CapturedPhotoDiskStoreError {
            XCTAssertEqual(error, .missingImage(photo.id))
        }
    }

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FrameWiseTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func makePhoto(
        id: String,
        byte: UInt8,
        capturedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        isExported: Bool = false
    ) -> CapturedPhoto {
        CapturedPhoto(
            id: UUID(uuidString: id)!,
            data: Data([byte]),
            capturedAt: capturedAt,
            isExported: isExported
        )!
    }

    private func imageFilename(for photo: CapturedPhoto) -> String {
        "\(photo.id.uuidString).data"
    }

    private func manifestEntries(in directory: URL) throws -> [[String: Any]] {
        let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
}
