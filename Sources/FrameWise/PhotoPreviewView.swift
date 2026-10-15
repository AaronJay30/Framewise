#if canImport(UIKit) && canImport(SwiftUI)
import FrameWiseCore
import SwiftUI
import UIKit

struct PhotoPreviewView: View {
    let photoID: UUID
    let photoIDs: [UUID]

    @ObservedObject var photoStore: CapturedPhotoStore

    private let photoLibraryWriter: PhotoLibraryWriter
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPhotoID: UUID
    @State private var orderedPhotoIDs: [UUID]
    @State private var areControlsVisible = true
    @State private var isSharePresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleting = false
    @State private var isExporting = false
    @State private var didExportInThisPreview = false
    @State private var actionError: String?
    @State private var exportMessage: String?
    @State private var shouldShowPhotoSettings = false

    init(
        photoID: UUID,
        photoIDs: [UUID],
        photoStore: CapturedPhotoStore,
        photoLibraryWriter: PhotoLibraryWriter = PhotoLibraryWriter()
    ) {
        var normalizedPhotoIDs = photoIDs
        if normalizedPhotoIDs.isEmpty {
            normalizedPhotoIDs = [photoID]
        } else if !normalizedPhotoIDs.contains(photoID) {
            normalizedPhotoIDs.insert(photoID, at: 0)
        }

        self.photoID = photoID
        self.photoIDs = normalizedPhotoIDs
        self.photoStore = photoStore
        self.photoLibraryWriter = photoLibraryWriter
        _selectedPhotoID = State(initialValue: photoID)
        _orderedPhotoIDs = State(initialValue: normalizedPhotoIDs)
    }

    var body: some View {
        previewContent
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
        .confirmationDialog(
            "Remove this photo from FrameWise?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deletePhoto)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the private FrameWise copy only. It does not delete a copy already saved in Photos.")
        }
        .onChange(of: selectedPhotoID) { _, _ in
            resetSelectedPhotoMessages()
        }
    }

    private var previewContent: some View {
        TabView(selection: $selectedPhotoID) {
            ForEach(orderedPhotoIDs, id: \.self) { id in
                photoPage(for: id)
                    .tag(id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: orderedPhotoIDs.count > 1 ? .automatic : .never))
        .background(Color.black)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if areControlsVisible {
                actionSection
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: areControlsVisible)
        .sheet(isPresented: $isSharePresented) {
            if let selectedImage {
                ShareSheet(image: selectedImage)
            } else {
                unavailableState
            }
        }
    }

    private func photoPage(for id: UUID) -> some View {
        ZStack {
            Color.black

            if let photo = photoStore.photo(withID: id),
               let image = UIImage(data: photo.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                unavailablePage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleControls)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(pageAccessibilityLabel(for: id))
        .accessibilityValue(areControlsVisible ? "Actions shown" : "Actions hidden")
        .accessibilityAction(named: Text(areControlsVisible ? "Hide actions" : "Show actions")) {
            toggleControls()
        }
    }

    private var unavailablePage: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(FrameWiseBrand.signalCoral)

            Text("Photo unavailable")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("This photo is no longer available in FrameWise.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)

            Button {
                dismiss()
            } label: {
                Text("Back")
                    .frame(minWidth: 110, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(FrameWiseBrand.signalCoral)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 8) {
            if let actionError {
                Text(actionError)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if let exportMessage {
                Text(exportMessage)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if shouldShowPhotoSettings {
                Button(action: openPhotoSettings) {
                    Text("Open Settings")
                        .frame(minWidth: 130, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            if let photo = selectedPhoto, selectedImage != nil {
                let exportInProgress = isExporting || photoStore.isExporting(id: selectedPhotoID)

                HStack(spacing: 10) {
                    actionButton(
                        title: "Share",
                        systemImage: "square.and.arrow.up",
                        action: { isSharePresented = true }
                    )

                    actionButton(
                        title: saveTitle(for: photo),
                        systemImage: "square.and.arrow.down",
                        action: { saveToPhotos(photo) },
                        isDisabled: exportInProgress || didExportInThisPreview || photo.isExported
                    )
                    .accessibilityHint(
                        photo.isExported || didExportInThisPreview
                            ? "This photo is already saved to Photos."
                            : "Exports a copy to Photos."
                    )

                    actionButton(
                        title: isDeleting ? "Deleting…" : "Delete",
                        systemImage: "trash",
                        action: { isDeleteConfirmationPresented = true },
                        isDisabled: isDeleting
                    )

                    actionButton(
                        title: "Edit",
                        systemImage: "slider.horizontal.3",
                        action: {},
                        isDisabled: true
                    )
                    .accessibilityHint("Editing will be available soon.")
                }
            } else {
                Text("Actions unavailable for this photo.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void,
        isDisabled: Bool = false
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(isDisabled ? .gray : FrameWiseBrand.signalCoral)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }

    private var unavailableState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(FrameWiseBrand.signalCoral)

            Text("Photo unavailable")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text("This photo is no longer available in FrameWise.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)

            Button {
                dismiss()
            } label: {
                Text("Back")
                    .frame(minWidth: 110, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(FrameWiseBrand.signalCoral)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func toggleControls() {
        if reduceMotion {
            areControlsVisible.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                areControlsVisible.toggle()
            }
        }
    }

    private func deletePhoto() {
        let removedID = selectedPhotoID
        isDeleting = true
        actionError = nil

        Task { @MainActor in
            if await photoStore.remove(id: removedID) {
                let nextID = PhotoPreviewSelection.neighbor(
                    afterRemoving: removedID,
                    from: orderedPhotoIDs
                )
                orderedPhotoIDs.removeAll { $0 == removedID }

                guard let nextID else {
                    dismiss()
                    return
                }

                selectedPhotoID = nextID
                isDeleting = false
            } else {
                actionError = photoStore.storageError ?? "FrameWise could not remove that photo. Try again."
                isDeleting = false
            }
        }
    }

    private func saveTitle(for photo: CapturedPhoto) -> String {
        if isExporting || photoStore.isExporting(id: selectedPhotoID) { return "Saving…" }
        if photo.isExported || didExportInThisPreview { return "Saved" }
        return "Save"
    }

    private func saveToPhotos(_ photo: CapturedPhoto) {
        let exportID = selectedPhotoID
        guard !isExporting,
              !photoStore.isExporting(id: exportID),
              !photo.isExported,
              !didExportInThisPreview,
              photoStore.beginExport(id: exportID) else {
            return
        }

        isExporting = true
        exportMessage = nil
        shouldShowPhotoSettings = false

        Task { @MainActor in
            defer {
                photoStore.endExport(id: exportID)
                isExporting = false
            }

            do {
                try await photoLibraryWriter.save(data: photo.data)
                didExportInThisPreview = true
                if await photoStore.markExported(id: exportID) {
                    exportMessage = "Saved a copy to Photos."
                } else {
                    exportMessage = "Saved a copy to Photos, but FrameWise could not update its export status."
                }
            } catch let error as PhotoLibraryWriterError {
                exportMessage = error.errorDescription
                shouldShowPhotoSettings = error.shouldOpenSettings
            } catch {
                exportMessage = "The photo could not be saved to Photos. Try again."
            }
        }
    }

    private func openPhotoSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private var selectedPhoto: CapturedPhoto? {
        photoStore.photo(withID: selectedPhotoID)
    }

    private var selectedImage: UIImage? {
        guard let selectedPhoto else { return nil }
        return UIImage(data: selectedPhoto.data)
    }

    private func pageAccessibilityLabel(for id: UUID) -> String {
        guard let photo = photoStore.photo(withID: id) else { return "Photo unavailable" }
        return photo.isExported ? "Photo, saved to Photos" : "Captured photo"
    }

    private func resetSelectedPhotoMessages() {
        actionError = nil
        exportMessage = nil
        didExportInThisPreview = false
        shouldShowPhotoSettings = false
    }
}
#endif
