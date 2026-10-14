#if canImport(UIKit) && canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import Foundation
import SwiftUI
import UIKit
import FrameWiseCore

/// The camera-first screen: preview as the canvas, recovery states as needed,
/// and one quiet dock with exactly three controls.
struct CameraScreen: View {
    @ObservedObject var viewModel: CameraViewModel
    @ObservedObject var photoStore: CapturedPhotoStore

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var captureAnimationNamespace
    @State private var captureFlight: CapturedPhoto?
    @State private var isProcessingPendingCapture = false

    var body: some View {
        ZStack {
            cameraContent

            if let captureFlight,
               let image = UIImage(data: captureFlight.data) {
                CaptureFlightView(
                    photo: captureFlight,
                    image: image,
                    namespace: captureAnimationNamespace,
                    onFinished: finishCaptureFlight
                )
            }

            if let storageError = photoStore.storageError {
                VStack {
                    Spacer()
                    storageErrorCard(storageError)
                }
                .padding(.bottom, showsControlDock ? 112 : 24)
            }
        }
        .background(FrameWiseBrand.surface(for: colorScheme).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsControlDock {
                controlDock
            } else if showsLibraryAccessDock {
                libraryAccessDock
            }
        }
        .onChange(of: viewModel.pendingCapturedPhotos.count) { _, _ in
            processPendingCaptures()
        }
        .onChange(of: photoStore.isLoading) { _, isLoading in
            if !isLoading {
                processPendingCaptures()
            }
        }
        .onAppear {
            viewModel.start()
            processPendingCaptures()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        switch viewModel.state {
        case .permissionDenied:
            RecoveryStateView(
                symbolName: "camera.slash",
                title: "Camera access is off",
                message: "Turn on camera access in Settings to preview and capture photos.",
                actionTitle: "Open Settings",
                action: openCameraSettings
            )
        case .unavailable:
            RecoveryStateView(
                symbolName: "camera.metering.unknown",
                title: "Camera unavailable",
                message: "FrameWise could not find a usable camera on this device.",
                actionTitle: "Try Again",
                action: viewModel.retry
            )
        case .captureFailed:
            ZStack {
                preview
                captureFailureCard
            }
        case .initializing, .requestingPermission, .ready, .running:
            preview
        }
    }

    private var preview: some View {
        CameraPreview(session: viewModel.session)
            .ignoresSafeArea()
    }

    private var showsControlDock: Bool {
        switch viewModel.state {
        case .ready, .running, .captureFailed:
            true
        case .initializing, .requestingPermission, .permissionDenied, .unavailable:
            false
        }
    }

    private var showsLibraryAccessDock: Bool {
        switch viewModel.state {
        case .permissionDenied, .unavailable:
            true
        case .initializing, .requestingPermission, .ready, .running, .captureFailed:
            false
        }
    }

    /// The only persistent controls in this slice: library, shutter, flip.
    private var controlDock: some View {
        HStack(alignment: .center, spacing: 28) {
            libraryLink

            Button(action: viewModel.capturePhoto) {
                ZStack {
                    Circle()
                        .fill(.white)
                    Circle()
                        .fill(FrameWiseBrand.signalCoral)
                        .padding(5)
                }
                .frame(width: 72, height: 72)
            }
            .accessibilityLabel("Take photo")
            .accessibilityHint("Captures a still photo from the camera preview.")

            Button(action: viewModel.flipCamera) {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Flip camera")
            .accessibilityHint("Switches between the rear and front cameras.")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(FrameWiseBrand.ink.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var libraryAccessDock: some View {
        HStack {
            Spacer()
            libraryLink
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(FrameWiseBrand.ink.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var libraryLink: some View {
        NavigationLink {
            LibraryView(photoStore: photoStore)
        } label: {
            libraryThumbnail
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Library")
        .accessibilityHint("Opens your captured photos.")
    }

    @ViewBuilder
    private var libraryThumbnail: some View {
        if let photo = photoStore.latestPhoto,
           let image = UIImage(data: photo.data) {
            if reduceMotion {
                thumbnailImage(image)
                    .opacity(captureFlight?.id == photo.id ? 0 : 1)
            } else {
                thumbnailImage(image)
                    .matchedGeometryEffect(
                        id: photo.id,
                        in: captureAnimationNamespace,
                        isSource: captureFlight?.id != photo.id
                    )
                    .opacity(captureFlight?.id == photo.id ? 0 : 1)
            }
        } else {
            Image(systemName: "photo")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.12))
                .clipShape(Circle())
        }
    }

    private func thumbnailImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 44, height: 44)
            .clipShape(Circle())
    }

    private func processPendingCaptures() {
        guard !isProcessingPendingCapture,
              captureFlight == nil,
              !photoStore.isLoading,
              let photo = viewModel.pendingCapturedPhotos.first else {
            return
        }

        isProcessingPendingCapture = true
        Task { @MainActor in
            if await photoStore.add(photo) {
                viewModel.consumeCapturedPhoto(id: photo.id)
                captureFlight = photo
            }

            isProcessingPendingCapture = false
        }
    }

    private func finishCaptureFlight() {
        captureFlight = nil
        processPendingCaptures()
    }

    private func storageErrorCard(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button(action: retryStorageAndPendingCaptures) {
                Text("Try Again")
                    .frame(minWidth: 110, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(FrameWiseBrand.signalCoral)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(FrameWiseBrand.ink.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 24)
    }

    private func retryStorageAndPendingCaptures() {
        Task { @MainActor in
            await photoStore.load()
            processPendingCaptures()
        }
    }

    private var captureFailureCard: some View {
        VStack(spacing: 10) {
            Text("Photo not captured")
                .font(.headline)
                .foregroundStyle(.white)
            Text("The preview is still ready. Try the shutter again.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
            Button("Try Again", action: viewModel.retry)
                .buttonStyle(.borderedProminent)
                .tint(FrameWiseBrand.signalCoral)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(FrameWiseBrand.ink.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 112)
    }

    private func openCameraSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

private struct CaptureFlightView: View {
    let photo: CapturedPhoto
    let image: UIImage
    let namespace: Namespace.ID
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashVisible = true

    @ViewBuilder
    var body: some View {
        if reduceMotion {
            flightOverlay
                .transition(.opacity)
        } else {
            flightOverlay
        }
    }

    private var flightOverlay: some View {
        ZStack {
            Color.white
                .opacity(flashVisible ? 0.12 : 0)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    if reduceMotion {
                        flightImage(in: proxy.size)
                            .transition(.opacity)
                    } else {
                        flightImage(in: proxy.size)
                            .matchedGeometryEffect(id: photo.id, in: namespace)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .allowsHitTesting(false)
        .task(id: photo.id) {
            withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.16)) {
                flashVisible = false
            }

            do {
                try await Task.sleep(
                    for: .seconds(reduceMotion ? 0.12 : 0.06)
                )
            } catch {
                return
            }

            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.18)
                    : .easeOut(duration: 0.32)
            ) {
                onFinished()
            }
        }
    }

    private func flightImage(in size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(
                width: min(size.width * 0.78, 360),
                height: min(size.height * 0.62, 520)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.52), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
            .opacity(0.94)
    }
}

/// One rounded recovery action for permission and hardware failures.
private struct RecoveryStateView: View {
    let symbolName: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(FrameWiseBrand.signalCoral)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))

            Text(message)
                .font(.body)
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme).opacity(0.78))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 310)

            Button(action: action) {
                Text(actionTitle)
                    .frame(minWidth: 120, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(FrameWiseBrand.signalCoral)
        }
        .padding(.horizontal, 28)
    }
}
#endif
