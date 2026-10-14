#if canImport(UIKit) && canImport(SwiftUI)
import FrameWiseCore
import SwiftUI
import UIKit

struct PhotoPreviewView: View {
    let photoID: UUID

    @ObservedObject var photoStore: CapturedPhotoStore

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var isSharePresented = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleting = false
    @State private var actionError: String?

    var body: some View {
        Group {
            if let photo = photoStore.photo(withID: photoID),
               let image = UIImage(data: photo.data) {
                photoContent(photo: photo, image: image)
                    .sheet(isPresented: $isSharePresented) {
                        ShareSheet(image: image)
                    }
            } else {
                unavailableState
            }
        }
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
    }

    private func photoContent(photo: CapturedPhoto, image: UIImage) -> some View {
        ScrollView {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
        }
        .background(Color.black)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if let actionError {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                HStack(spacing: 10) {
                    actionButton(
                        title: "Share",
                        systemImage: "square.and.arrow.up",
                        action: { isSharePresented = true }
                    )

                    actionButton(
                        title: "Save",
                        systemImage: "square.and.arrow.down",
                        action: {},
                        isDisabled: true
                    )
                    .accessibilityHint("Saving to Photos will be available soon.")

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
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(photo.isExported ? "Photo, saved to Photos" : "Captured photo")
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

            Button("Back") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(FrameWiseBrand.signalCoral)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func deletePhoto() {
        isDeleting = true
        actionError = nil

        Task { @MainActor in
            if await photoStore.remove(id: photoID) {
                dismiss()
            } else {
                actionError = photoStore.storageError ?? "FrameWise could not remove that photo. Try again."
                isDeleting = false
            }
        }
    }
}
#endif
