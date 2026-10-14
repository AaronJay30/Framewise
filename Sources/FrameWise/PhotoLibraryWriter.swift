#if canImport(Photos) && canImport(UIKit)
import Photos
import UIKit

enum PhotoLibraryWriterError: LocalizedError {
    case invalidImage
    case denied
    case restricted
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "FrameWise could not read this photo for export."
        case .denied:
            return "Photos access is off. Allow access in Settings to export this photo."
        case .restricted:
            return "Photos export is restricted on this device."
        case .writeFailed:
            return "The photo could not be saved to Photos. Try again."
        }
    }

    var shouldOpenSettings: Bool {
        switch self {
        case .denied, .restricted:
            true
        case .invalidImage, .writeFailed:
            false
        }
    }
}

@MainActor
final class PhotoLibraryWriter {
    func save(data: Data) async throws {
        guard let image = UIImage(data: data) else {
            throw PhotoLibraryWriterError.invalidImage
        }

        let status = await addOnlyAuthorizationStatus()
        switch status {
        case .authorized, .limited:
            break
        case .denied:
            throw PhotoLibraryWriterError.denied
        case .restricted:
            throw PhotoLibraryWriterError.restricted
        case .notDetermined:
            throw PhotoLibraryWriterError.denied
        @unknown default:
            throw PhotoLibraryWriterError.denied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibraryWriterError.writeFailed)
                }
            }
        }
    }

    private func addOnlyAuthorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard currentStatus == .notDetermined else { return currentStatus }

        return await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
#endif
