#if canImport(UIKit) && canImport(SwiftUI)
import FrameWiseCore
import SwiftUI
import UIKit

struct LibraryView: View {
    @ObservedObject var photoStore: CapturedPhotoStore

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var mode: LibraryMode = .byDay

    private var calendar: Calendar { .current }

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
                    storageErrorBanner(storageError)
                }

                modePicker
                modeContent
            }
        }
    }

    private var modePicker: some View {
        Picker("Library view", selection: $mode) {
            ForEach(LibraryMode.allCases) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Library view")
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .byDay:
            dayGroups
        case .allPhotos:
            PhotoGalleryView(title: "All Photos", photoStore: photoStore)
        }
    }

    private var dayGroups: some View {
        let groups = CapturedPhotoGrouping.groupByDay(
            photoStore.photos,
            calendar: calendar
        )

        return ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(groups) { group in
                    NavigationLink {
                        PhotoGalleryView(
                            title: dayTitle(for: group.day),
                            photoStore: photoStore,
                            photoIDs: Set(group.photos.map(\.id))
                        )
                    } label: {
                        DayGroupCard(
                            group: group,
                            title: dayTitle(for: group.day)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(FrameWiseBrand.surface(for: colorScheme))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayTitle(for day: Date) -> String {
        if calendar.isDateInToday(day) {
            return "Today"
        }

        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }

        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private func storageErrorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message)
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

private enum LibraryMode: String, CaseIterable, Identifiable {
    case byDay
    case allPhotos

    var id: Self { self }

    var title: String {
        switch self {
        case .byDay:
            "By Day"
        case .allPhotos:
            "All Photos"
        }
    }
}

private struct DayGroupCard: View {
    let group: CapturedPhotoDayGroup
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))

                    Text(photoCountLabel)
                        .font(.subheadline)
                        .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.68))
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.55))
            }

            HStack(spacing: 8) {
                ForEach(Array(group.photos.prefix(4))) { photo in
                    GroupThumbnail(photo: photo)
                }

                if group.photos.count > 4 {
                    Text("+\(group.photos.count - 4)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.72))
                        .frame(width: 52, height: 64)
                        .background(.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    FrameWiseBrand.foreground(for: colorScheme).opacity(0.1),
                    lineWidth: 1
                )
        }
    }

    private var photoCountLabel: String {
        group.photos.count == 1 ? "1 photo" : "\(group.photos.count) photos"
    }
}

private struct GroupThumbnail: View {
    let photo: CapturedPhoto

    var body: some View {
        Group {
            if let image = UIImage(data: photo.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 52, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
#endif
