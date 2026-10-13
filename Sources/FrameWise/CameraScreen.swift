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

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            cameraContent
        }
        .background(FrameWiseBrand.ink.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsControlDock {
                controlDock
            }
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
            Button(action: {}) {
                Image(systemName: viewModel.lastPhotoData == nil ? "photo" : "photo.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
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

/// One rounded recovery action for permission and hardware failures.
private struct RecoveryStateView: View {
    let symbolName: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(FrameWiseBrand.signalCoral)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.78))
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
