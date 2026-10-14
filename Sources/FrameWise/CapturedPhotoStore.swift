#if canImport(UIKit) && canImport(SwiftUI)
import Combine
import FrameWiseCore
import SwiftUI
import UIKit

@MainActor
final class CapturedPhotoStore: ObservableObject {
    @Published private(set) var photos: [CapturedPhoto] = []
    @Published private(set) var isLoading = false
    @Published private(set) var storageError: String?

    private var library = CapturedPhotoLibrary()
    private let diskStore: CapturedPhotoDiskStore

    init(diskStore: CapturedPhotoDiskStore = CapturedPhotoDiskStore(
        directoryURL: CapturedPhotoDiskStore.defaultDirectory()
    )) {
        self.diskStore = diskStore
        isLoading = true

        Task { [weak self] in
            await self?.load()
        }
    }

    var latestPhoto: CapturedPhoto? {
        photos.first
    }

    var count: Int {
        photos.count
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedPhotos = try await diskStore.load()
            var loadedLibrary = CapturedPhotoLibrary()
            for photo in loadedPhotos.reversed() {
                loadedLibrary.insert(photo)
            }

            library = loadedLibrary
            photos = loadedLibrary.photos
            storageError = nil
        } catch {
            storageError = "Your saved photos are temporarily unavailable. Try again."
        }
    }

    func add(_ photo: CapturedPhoto) async -> Bool {
        guard UIImage(data: photo.data) != nil else {
            storageError = "That photo could not be saved in FrameWise."
            return false
        }

        do {
            try await diskStore.save(photo)
            if library.photo(withID: photo.id) != nil {
                _ = library.remove(id: photo.id)
            }
            library.insert(photo)
            photos = library.photos
            storageError = nil
            return true
        } catch {
            storageError = "FrameWise could not save that photo. Try again."
            return false
        }
    }

    func markExported(id: UUID) async -> Bool {
        do {
            try await diskStore.markExported(id: id)
            guard library.markExported(id: id) else { return false }

            photos = library.photos
            storageError = nil
            return true
        } catch {
            storageError = "FrameWise could not update that photo. Try again."
            return false
        }
    }

    func remove(id: UUID) async -> Bool {
        do {
            try await diskStore.remove(id: id)
            guard library.remove(id: id) else { return false }

            photos = library.photos
            storageError = nil
            return true
        } catch {
            storageError = "FrameWise could not remove that photo. Try again."
            return false
        }
    }

    func photo(withID id: UUID) -> CapturedPhoto? {
        library.photo(withID: id)
    }
}
#endif
