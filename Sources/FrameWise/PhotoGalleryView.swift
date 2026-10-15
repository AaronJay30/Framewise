#if canImport(UIKit) && canImport(SwiftUI)
import FrameWiseCore
import SwiftUI
import UIKit

struct PhotoGalleryView: View {
    let title: String
    let photoIDs: [UUID]

    @ObservedObject var photoStore: CapturedPhotoStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    private let photoLibraryWriter: PhotoLibraryWriter
    @State private var isSelectionMode = false
    @State private var selectedPhotoIDs = Set<UUID>()
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleting = false
    @State private var isDownloading = false
    @State private var downloadMessage: String?
    @State private var shouldShowPhotoSettings = false

    init(
        title: String,
        photoStore: CapturedPhotoStore,
        photoIDs: [UUID],
        photoLibraryWriter: PhotoLibraryWriter = PhotoLibraryWriter()
    ) {
        self.title = title
        self.photoStore = photoStore
        self.photoIDs = photoIDs
        self.photoLibraryWriter = photoLibraryWriter
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
                            downloadMessage = nil
                        }
                    }
                    .disabled(isDeleting || isDownloading)
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
                        .disabled(isDeleting || isDownloading)
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
        VStack(spacing: 8) {
            if let downloadMessage {
                HStack(spacing: 8) {
                    Text(downloadMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)

                    if shouldShowPhotoSettings {
                        Button("Settings", action: openPhotoSettings)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(FrameWiseBrand.signalCoral)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("\(selectedPhotoIDs.count) Selected")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.white.opacity(0.14), in: Capsule())
                .accessibilityLabel("\(selectedPhotoIDs.count) selected")

            HStack(spacing: 8) {
                Button("Cancel", action: exitSelectionMode)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(isDeleting || isDownloading)

                Button {
                    downloadSelectedPhotos()
                } label: {
                    Label(isDownloading ? "Downloading…" : "Download", systemImage: "arrow.down.to.line")
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(FrameWiseBrand.signalCoral)
                .disabled(pendingDownloadIDs.isEmpty || isDeleting || isDownloading)

                Button("Delete", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(selectedPhotoIDs.isEmpty || isDeleting || isDownloading)
            }
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
        downloadMessage = nil
        shouldShowPhotoSettings = false
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotoIDs.removeAll()
        downloadMessage = nil
        shouldShowPhotoSettings = false
    }

    private func deleteSelectedPhotos() {
        guard !selectedPhotoIDs.isEmpty, !isDeleting, !isDownloading else { return }

        let idsToRemove = selectedPhotoIDs
        isDeleting = true
        downloadMessage = nil

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

    private var pendingDownloadIDs: Set<UUID> {
        PhotoGalleryDownload.pendingIDs(
            selectedIDs: selectedPhotoIDs,
            exportedIDs: Set(visiblePhotos.filter { $0.isExported }.map(\.id))
        )
    }

    private func downloadSelectedPhotos() {
        guard !selectedPhotoIDs.isEmpty,
              !isDownloading,
              !isDeleting else {
            return
        }

        let photosToExport = visiblePhotos.filter { pendingDownloadIDs.contains($0.id) }
        guard !photosToExport.isEmpty else {
            downloadMessage = "Selected photos are already saved to Photos."
            shouldShowPhotoSettings = false
            return
        }

        isDownloading = true
        downloadMessage = nil
        shouldShowPhotoSettings = false

        Task { @MainActor in
            var savedCount = 0
            var statusUpdateFailed = false
            var failureMessage: String?
            var shouldOpenSettings = false

            for photo in photosToExport {
                guard photoStore.beginExport(id: photo.id) else { continue }
                defer { photoStore.endExport(id: photo.id) }

                do {
                    try await photoLibraryWriter.save(data: photo.data)
                    savedCount += 1
                    if !(await photoStore.markExported(id: photo.id)) {
                        statusUpdateFailed = true
                    }
                } catch let error as PhotoLibraryWriterError {
                    failureMessage = error.errorDescription
                    shouldOpenSettings = error.shouldOpenSettings
                    break
                } catch {
                    failureMessage = "Some photos could not be saved to Photos. Try again."
                    break
                }
            }

            isDownloading = false
            shouldShowPhotoSettings = shouldOpenSettings

            if let failureMessage {
                downloadMessage = failureMessage
            } else if statusUpdateFailed {
                downloadMessage = "Saved \(savedCount) photo\(savedCount == 1 ? "" : "s") to Photos, but FrameWise could not update every status."
            } else {
                downloadMessage = "Saved \(savedCount) photo\(savedCount == 1 ? "" : "s") to Photos."
            }
        }
    }

    private func openPhotoSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
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
        GeometryReader { geometry in
            ZStack {
                Group {
                    if let image = UIImage(data: photo.data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        ZStack {
                            Color.secondary.opacity(0.12)
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)

                if photo.isExported {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, FrameWiseBrand.signalCoral)
                        .padding(7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }

                if isSelectionMode {
                    selectionIndicator
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .accessibilityValue(accessibilityValueText)
            .accessibilityAddTraits(isSelectionMode && isSelected ? .isSelected : [])
        }
        .aspectRatio(1, contentMode: .fit)
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

    private var accessibilityValueText: String {
        var values: [String] = []
        if isSelectionMode {
            values.append(isSelected ? "Selected" : "Not selected")
        }
        if photo.isExported {
            values.append("Downloaded to Photos")
        }
        return values.joined(separator: ", ")
    }

}
#endif
