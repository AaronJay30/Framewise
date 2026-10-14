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
    @State private var storedCaptureIDs = Set<UUID>()

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
        }
        .background(FrameWiseBrand.surface(for: colorScheme).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsControlDock {
                controlDock
            }
        }
        .onChange(of: viewModel.lastCapturedPhoto?.id) { _, _ in
            storeLatestCapture()
        }
        .onAppear {
            viewModel.start()
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

    /// The only persistent controls in this slice: library, shutter, flip.
    private var controlDock: some View {
        HStack(alignment: .center, spacing: 28) {
            NavigationLink {
                LibraryView(photoStore: photoStore)
            } label: {
                libraryThumbnail
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Library")
            .accessibilityHint("Your latest captured photo will appear here.")

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

    private func storeLatestCapture() {
        guard let photo = viewModel.lastCapturedPhoto,
              storedCaptureIDs.insert(photo.id).inserted else {
            return
        }

        Task { @MainActor in
            guard await photoStore.add(photo) else {
                storedCaptureIDs.remove(photo.id)
                return
            }

            captureFlight = photo
        }
    }

    private func finishCaptureFlight() {
        captureFlight = nil
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

    @ViewBuilder
    var body: some View {
        if reduceMotion {
            flightImage
                .transition(.opacity)
        } else {
            flightImage
                .matchedGeometryEffect(id: photo.id, in: namespace)
        }
    }

    private var flightImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .background(.black)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .task(id: photo.id) {
                do {
                    try await Task.sleep(
                        for: .seconds(reduceMotion ? 0.18 : 0.55)
                    )
                } catch {
                    return
                }

                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.18)
                        : .easeInOut(duration: 0.55)
                ) {
                    onFinished()
                }
            }
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

            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(FrameWiseBrand.signalCoral)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 28)
    }
}
#endif
