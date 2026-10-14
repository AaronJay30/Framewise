import Foundation

public enum CapturedPhotoDiskStoreError: Error, Equatable, Sendable {
    case corruptManifest
    case missingImage(UUID)
    case fileOperation(String)
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

        return try entries.map { entry in
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

        let imageURL = directoryURL.appendingPathComponent(entries[index].filename)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw CapturedPhotoDiskStoreError.missingImage(id)
        }

        do {
            try FileManager.default.removeItem(at: imageURL)
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }

        entries.remove(at: index)
        try writeManifest(entries)
    }

    private func readManifest() throws -> [ManifestEntry] {
        let manifestURL = directoryURL.appendingPathComponent(Self.manifestFilename)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            return try JSONDecoder().decode([ManifestEntry].self, from: data)
        } catch is DecodingError {
            throw CapturedPhotoDiskStoreError.corruptManifest
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }
    }

    private func writeManifest(_ entries: [ManifestEntry]) throws {
        try ensureDirectory()

        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(
                to: directoryURL.appendingPathComponent(Self.manifestFilename),
                options: .atomic
            )
        } catch {
            throw CapturedPhotoDiskStoreError.fileOperation(error.localizedDescription)
        }
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
}
