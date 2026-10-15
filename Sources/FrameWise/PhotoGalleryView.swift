#if canImport(UIKit) && canImport(SwiftUI)
import FrameWiseCore
import SwiftUI
import UIKit

struct PhotoGalleryView: View {
    let title: String
    let photoIDs: [UUID]

    @ObservedObject var photoStore: CapturedPhotoStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSelectionMode = false
    @State private var selectedPhotoIDs = Set<UUID>()
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleting = false

    init(
        title: String,
        photoStore: CapturedPhotoStore,
        photoIDs: [UUID]
    ) {
        self.title = title
        self.photoStore = photoStore
        self.photoIDs = photoIDs
    }

    private var visiblePhotos: [CapturedPhoto] {
        let photosByID = Dictionary(uniqueKeysWithValues: photoStore.photos.map { ($0.id, $0) })
        return photoIDs.compactMap { photosByID[$0] }
    }

    private var visiblePhotoIDs: [UUID] {
        visiblePhotos.map(\.id)
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
        .toolbar {
            if !visiblePhotos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        if isSelectionMode {
                            exitSelectionMode()
                        } else {
                            isSelectionMode = true
                        }
                    }
                    .disabled(isDeleting)
                    .accessibilityHint(
                        isSelectionMode
                            ? "Stops selecting photos."
                            : "Select multiple photos for deletion."
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelectionMode {
                selectionActionBar
            }
        }
        .confirmationDialog(
            "Delete selected photos?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteSelectedPhotos)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the selected private FrameWise copies only. It does not delete copies already saved in Photos.")
        }
        .onChange(of: visiblePhotoIDs) { _, ids in
            selectedPhotoIDs = PhotoGallerySelection.reconciled(
                selectedPhotoIDs,
                with: ids
            )
        }
    }

    private var gallery: some View {
        let orderedIDs = visiblePhotos.map(\.id)

        return ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach(visiblePhotos) { photo in
                    if isSelectionMode {
                        Button {
                            toggleSelection(for: photo.id)
                        } label: {
                            GalleryPhotoTile(
                                photo: photo,
                                isSelectionMode: true,
                                isSelected: selectedPhotoIDs.contains(photo.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isDeleting)
                    } else {
                        NavigationLink {
                            PhotoPreviewView(
                                photoID: photo.id,
                                photoIDs: orderedIDs,
                                photoStore: photoStore
                            )
                        } label: {
                            GalleryPhotoTile(photo: photo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .background(FrameWiseBrand.surface(for: colorScheme))
    }

    private var selectionActionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: exitSelectionMode)
                .frame(minWidth: 72, minHeight: 44)
                .disabled(isDeleting)

            Spacer(minLength: 0)

            Text("\(selectedPhotoIDs.count) Selected")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button("Delete", role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            .frame(minWidth: 72, minHeight: 44)
            .disabled(selectedPhotoIDs.isEmpty || isDeleting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photo selection actions")
    }

    private func toggleSelection(for id: UUID) {
        selectedPhotoIDs = PhotoGallerySelection.toggled(
            id,
            in: selectedPhotoIDs
        )
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotoIDs.removeAll()
    }

    private func deleteSelectedPhotos() {
        guard !selectedPhotoIDs.isEmpty, !isDeleting else { return }

        let idsToRemove = selectedPhotoIDs
        isDeleting = true

        Task { @MainActor in
            for id in idsToRemove {
                _ = await photoStore.remove(id: id)
            }

            isDeleting = false
            let remainingIDs = PhotoGallerySelection.reconciled(
                idsToRemove,
                with: visiblePhotoIDs
            )

            if remainingIDs.isEmpty {
                exitSelectionMode()
            } else {
                selectedPhotoIDs = remainingIDs
            }
        }
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
    var isSelectionMode = false
    var isSelected = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = UIImage(data: photo.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
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
            .aspectRatio(photoAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if photo.isExported {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, FrameWiseBrand.signalCoral)
                    .padding(7)
            }

            if isSelectionMode {
                selectionIndicator
                    .padding(8)
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
        .accessibilityValue(
            isSelectionMode
                ? (isSelected ? "Selected" : "Not selected")
                : (photo.isExported ? "Saved to Photos" : "")
        )
        .accessibilityAddTraits(isSelectionMode && isSelected ? .isSelected : [])
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? FrameWiseBrand.signalCoral : Color.black.opacity(0.62))

            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 1.5)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 28, height: 28)
    }

    private var placeholderAspectRatio: CGFloat { 1 }

    private var photoAspectRatio: CGFloat {
        guard let image = UIImage(data: photo.data) else { return placeholderAspectRatio }
        return displayAspectRatio(for: image)
    }

    private func displayAspectRatio(for image: UIImage) -> CGFloat {
        guard image.size.width.isFinite,
              image.size.height.isFinite,
              image.size.width > 0,
              image.size.height > 0 else {
            return placeholderAspectRatio
        }

        return image.size.width / image.size.height
    }
}
#endif
