#if canImport(UIKit) && canImport(SwiftUI)
import FrameWiseCore
import SwiftUI
import UIKit

struct PhotoGalleryView: View {
    let title: String
    let photoIDs: Set<UUID>?

    @ObservedObject var photoStore: CapturedPhotoStore
    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        photoStore: CapturedPhotoStore,
        photoIDs: Set<UUID>? = nil
    ) {
        self.title = title
        self.photoStore = photoStore
        self.photoIDs = photoIDs
    }

    private var visiblePhotos: [CapturedPhoto] {
        guard let photoIDs else {
            return photoStore.photos
        }

        return photoStore.photos.filter { photoIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if visiblePhotos.isEmpty {
                emptyGalleryState
            } else {
                gallery
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .background(FrameWiseBrand.surface(for: colorScheme).ignoresSafeArea())
    }

    private var gallery: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach(visiblePhotos) { photo in
                    NavigationLink {
                        PhotoPreviewView(photoID: photo.id, photoStore: photoStore)
                    } label: {
                        GalleryPhotoTile(photo: photo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(FrameWiseBrand.surface(for: colorScheme))
    }

    private var emptyGalleryState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(FrameWiseBrand.signalCoral)

            Text("No photos in this view")
                .font(.headline)
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))

            Text("Captured photos will appear here after they are saved in FrameWise.")
                .font(.subheadline)
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct GalleryPhotoTile: View {
    let photo: CapturedPhoto

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = UIImage(data: photo.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if photo.isExported {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, FrameWiseBrand.signalCoral)
                    .padding(7)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    FrameWiseBrand.foreground(for: colorScheme).opacity(0.12),
                    lineWidth: 1
                )
        }
        .accessibilityLabel(
            Text(
                "Photo captured "
                    + photo.capturedAt.formatted(date: .abbreviated, time: .shortened)
            )
        )
    }
}
#endif
