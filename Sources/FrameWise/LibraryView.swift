#if canImport(UIKit) && canImport(SwiftUI)
import FrameWiseCore
import SwiftUI
import UIKit

struct LibraryView: View {
    @ObservedObject var photoStore: CapturedPhotoStore

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                cameraButton
            }
    }

    @ViewBuilder
    private var content: some View {
        if photoStore.isLoading && photoStore.photos.isEmpty {
            ProgressView("Loading your library…")
                .tint(FrameWiseBrand.signalCoral)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let storageError = photoStore.storageError, photoStore.photos.isEmpty {
            libraryError(storageError)
        } else if photoStore.photos.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                if let storageError = photoStore.storageError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(storageError)
                            .font(.footnote)
                            .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.78))

                        Button {
                            Task { await photoStore.load() }
                        } label: {
                            Text("Try Again")
                                .frame(minWidth: 110, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(FrameWiseBrand.signalCoral)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(FrameWiseBrand.signalCoral.opacity(0.14))
                }

                photoList
            }
        }
    }

    private var photoList: some View {
        List(photoStore.photos) { photo in
            NavigationLink {
                PhotoPreviewView(photoID: photo.id, photoStore: photoStore)
            } label: {
                PhotoRow(photo: photo)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(FrameWiseBrand.surface(for: colorScheme))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(FrameWiseBrand.signalCoral)

            Text("Your library is empty")
                .font(.title3.weight(.semibold))
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))

            Text("Captured photos will stay here until you delete them.")
                .font(.body)
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .background(FrameWiseBrand.surface(for: colorScheme))
    }

    private func libraryError(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(FrameWiseBrand.signalCoral)

            Text(message)
                .font(.body)
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                Task { await photoStore.load() }
            } label: {
                Text("Try Again")
                    .frame(minWidth: 110, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(FrameWiseBrand.signalCoral)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .background(FrameWiseBrand.surface(for: colorScheme))
    }

    private var cameraButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(FrameWiseBrand.signalCoral)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
        }
        .accessibilityLabel("Camera")
        .accessibilityHint("Returns to the camera without creating a new camera session.")
        .frame(minWidth: 44, minHeight: 44)
        .padding(.trailing, 20)
        .padding(.bottom, 12)
    }
}

private struct PhotoRow: View {
    let photo: CapturedPhoto

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(photo.capturedAt, style: .date)
                    .font(.headline)
                    .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))

                Text(photo.capturedAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.68))

                if photo.isExported {
                    Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(FrameWiseBrand.signalCoral)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = UIImage(data: photo.data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 76, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.secondary.opacity(0.18))
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, height: 92)
        }
    }
}
#endif
