import Foundation

/// The in-memory ordering and mutation boundary for captured photos.
public struct CapturedPhotoLibrary: Equatable, Sendable {
    public private(set) var photos: [CapturedPhoto]

    public init() {
        photos = []
    }

    public mutating func insert(_ photo: CapturedPhoto) {
        photos.insert(photo, at: 0)
    }

    @discardableResult
    public mutating func markExported(id: UUID) -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == id }), !photos[index].isExported else {
            return false
        }

        photos[index].isExported = true
        return true
    }

    @discardableResult
    public mutating func remove(id: UUID) -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == id }) else {
            return false
        }

        photos.remove(at: index)
        return true
    }

    public func photo(withID id: UUID) -> CapturedPhoto? {
        photos.first(where: { $0.id == id })
    }
}
