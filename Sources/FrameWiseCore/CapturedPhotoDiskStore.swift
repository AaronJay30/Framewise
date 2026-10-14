import Foundation

public enum CapturedPhotoDiskStoreError: Error, Equatable, Sendable {
    case corruptManifest
    case missingImage(UUID)
    case fileOperation(String)
}

public struct CapturedPhotoDiskLoadResult: Equatable, Sendable {
    public let photos: [CapturedPhoto]
    public let unavailableIDs: [UUID]

    public init(photos: [CapturedPhoto], unavailableIDs: [UUID]) {
        self.photos = photos
        self.unavailableIDs = unavailableIDs
    }
}

/// Persists captured photo bytes and metadata in FrameWise's private storage.
public actor CapturedPhotoDiskStore {
    private struct ManifestEntry: Codable, Equatable, Sendable {
        let id: UUID
        let filename: String
        let capturedAt: Date
        var isExported: Bool
    }

    private static let manifestFilename = "manifest.json"
    private static let manifestBackupFilename = "manifest.json.bak"
    private static let imageFileExtension = "data"

    private let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public nonisolated static func defaultDirectory() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("FrameWise", isDirectory: true)
            .appendingPathComponent("Photos", isDirectory: true)
    }

    public func load() throws -> [CapturedPhoto] {
        let entries = try readManifest()

        return try entries.map(readPhoto)
    }

    public func loadAvailable() throws -> CapturedPhotoDiskLoadResult {
        let entries = try readManifest()
        var photos: [CapturedPhoto] = []
        var unavailableIDs: [UUID] = []

        for entry in entries {
            do {
                photos.append(try readPhoto(entry))
            } catch {
                unavailableIDs.append(entry.id)
            }
        }

        return CapturedPhotoDiskLoadResult(
            photos: photos,
            unavailableIDs: unavailableIDs
        )
    }

    public func save(_ photo: CapturedPhoto) throws {
        var entries = try readManifest()
        try ensureDirectory()

        let filename = imageFilename(for: photo.id)
        let imageURL = directoryURL.appendingPathComponent(filename)
        do {
            try photo.data.write(to: imageURL, options: .atomic)
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }

        entries.removeAll { $0.id == photo.id }
        entries.insert(
            ManifestEntry(
                id: photo.id,
                filename: filename,
                capturedAt: photo.capturedAt,
                isExported: photo.isExported
            ),
            at: 0
        )
        try writeManifest(entries)
    }

    public func markExported(id: UUID) throws {
        var entries = try readManifest()
        guard let index = entries.firstIndex(where: { $0.id == id }), !entries[index].isExported else {
            return
        }

        entries[index].isExported = true
        try writeManifest(entries)
    }

    public func remove(id: UUID) throws {
        var entries = try readManifest()
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        let entry = entries[index]
        let imageURL = directoryURL.appendingPathComponent(entry.filename)
        entries.remove(at: index)
        try writeManifest(entries)

        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: imageURL)
        } catch {
            var rollbackEntries = entries
            rollbackEntries.insert(entry, at: min(index, rollbackEntries.count))
            try? writeManifest(rollbackEntries)
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }
    }

    private func readManifest() throws -> [ManifestEntry] {
        let manifestURL = directoryURL.appendingPathComponent(Self.manifestFilename)
        let backupURL = directoryURL.appendingPathComponent(Self.manifestBackupFilename)

        if FileManager.default.fileExists(atPath: manifestURL.path) {
            do {
                return try decodeManifest(at: manifestURL)
            } catch CapturedPhotoDiskStoreError.corruptManifest {
                if let backupEntries = try? decodeManifest(at: backupURL) {
                    try? restoreManifest(from: backupURL, to: manifestURL)
                    return backupEntries
                }
                throw CapturedPhotoDiskStoreError.corruptManifest
            }
        }

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            return []
        }

        let backupEntries = try decodeManifest(at: backupURL)
        try? restoreManifest(from: backupURL, to: manifestURL)
        return backupEntries
    }

    private func writeManifest(_ entries: [ManifestEntry]) throws {
        try ensureDirectory()

        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(
                to: directoryURL.appendingPathComponent(Self.manifestBackupFilename),
                options: .atomic
            )
            try data.write(
                to: directoryURL.appendingPathComponent(Self.manifestFilename),
                options: .atomic
            )
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }
    }

    private func decodeManifest(at url: URL) throws -> [ManifestEntry] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([ManifestEntry].self, from: data)
        } catch is DecodingError {
            throw CapturedPhotoDiskStoreError.corruptManifest
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }
    }

    private func restoreManifest(from sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destinationURL, options: .atomic)
    }

    private func ensureDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }
    }

    private func imageFilename(for id: UUID) -> String {
        "\(id.uuidString).\(Self.imageFileExtension)"
    }

    private func readPhoto(_ entry: ManifestEntry) throws -> CapturedPhoto {
        let imageURL = directoryURL.appendingPathComponent(entry.filename)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw CapturedPhotoDiskStoreError.missingImage(entry.id)
        }

        do {
            let data = try Data(contentsOf: imageURL)
            guard let photo = CapturedPhoto(
                id: entry.id,
                data: data,
                capturedAt: entry.capturedAt,
                isExported: entry.isExported
            ) else {
                throw CapturedPhotoDiskStoreError.fileOperation("Stored image data was empty")
            }
            return photo
        } catch let error as CapturedPhotoDiskStoreError {
            throw error
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }
    }
}
