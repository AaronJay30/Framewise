#if canImport(UIKit) && canImport(AVFoundation) && canImport(SwiftUI)
import AVFoundation
import Foundation
import SwiftUI
import UIKit
import FrameWiseCore

/// The camera-first screen: preview as the canvas, recovery states as needed,
/// with direct top controls and a quiet three-button capture dock.
struct CameraScreen: View {
    @ObservedObject var viewModel: CameraViewModel
    @ObservedObject var photoStore: CapturedPhotoStore

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var captureAnimationNamespace
    @State private var captureFlight: CapturedPhoto?
    @State private var isProcessingPendingCapture = false
    @State private var isSettingsPresented = false
    @State private var isPinching = false

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
                .padding(.bottom, showsControlDock ? 156 : 24)
            }
        }
        .background(FrameWiseBrand.surface(for: colorScheme).ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsControlDock {
                CameraTopControls(
                    settings: viewModel.settings,
                    flashAvailable: viewModel.flashAvailable,
                    onChange: { viewModel.updateSettings($0) },
                    onStyles: { isSettingsPresented = true }
                )
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.persistSettings()
        }
        .sheet(isPresented: $isSettingsPresented) {
            CameraSettingsSheet(
                settings: viewModel.settings,
                onChange: { viewModel.updateSettings($0) },
                onReset: viewModel.resetSettings
            )
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
        // [AC-CAMSET1014-F5] [AC-CAMSET1014-F6] [AC-CAMSET1014-F7]
        GeometryReader { proxy in
            let size = viewModel.settings.aspectRatio.previewSize(
                fittingWidth: proxy.size.width, height: proxy.size.height
            )
            ZStack {
                styledPreview
                    .contentShape(Rectangle())
                    .simultaneousGesture(zoomGesture)

                if viewModel.settings.compositionGuide != .off {
                    CompositionGuideOverlay(
                        guide: viewModel.settings.compositionGuide,
                        opacity: Double(viewModel.settings.compositionGuideOpacity)
                    )
                    .transition(reduceMotion ? .identity : .opacity)
                    .allowsHitTesting(false)
                }

                if let focusPoint = viewModel.focusPoint {
                    FocusExposureOverlay(
                        isLocked: viewModel.isFocusLocked,
                        exposure: viewModel.settings.exposureBias,
                        exposureRange: viewModel.exposureRange,
                        onExposureChange: viewModel.setExposureBias,
                        onToggleLock: viewModel.toggleFocusLock
                    )
                        .position(focusPoint)
                        .transition(.scale.combined(with: .opacity))
                }

                if let countdown = viewModel.countdown {
                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.36), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.18),
                value: viewModel.settings.compositionGuide
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.18),
                value: viewModel.settings.compositionGuideOpacity
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24),
                       value: viewModel.settings.aspectRatio)
            .overlay(alignment: .bottom) {
                if showsControlDock {
                    CameraZoomControls(value: viewModel.settings.zoomFactor,
                                       range: viewModel.zoomRange,
                                       onChange: { viewModel.setZoomFactor($0, animated: !reduceMotion) })
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.black)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: viewModel.focusPoint)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: viewModel.countdown)
    }

    private var styledPreview: some View {
        let adjustments = viewModel.settings.photographicStyle.adjustments(
            at: Double(viewModel.settings.styleIntensity)
        )
        let tint = Color(
            red: min(max(adjustments.redMultiplier, 0), 1),
            green: min(max(adjustments.greenMultiplier, 0), 1),
            blue: min(max(adjustments.blueMultiplier, 0), 1)
        )

        return CameraPreview(
            session: viewModel.session,
            deviceID: viewModel.activeDeviceID,
            onTap: { previewPoint, devicePoint in
                viewModel.focus(
                    previewPoint: previewPoint,
                    devicePoint: devicePoint
                )
            }
        )
        .saturation(adjustments.saturation)
        .contrast(adjustments.contrast)
        .brightness(adjustments.brightness)
        .colorMultiply(tint)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                viewModel.pinchZoom(magnification: Float(value), isStarting: !isPinching)
                isPinching = true
            }
            .onEnded { _ in
                isPinching = false
            }
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

    /// Keep capture actions separate from the live preview and settings.
    private var controlDock: some View {
        HStack(alignment: .center, spacing: 0) {
            libraryLink

            Spacer(minLength: 16)

            Button(action: viewModel.capturePhoto) {
                ZStack {
                    Circle().stroke(.white.opacity(0.7), lineWidth: 3)
                    Circle().fill(.white).padding(6)
                }
                .frame(width: 72, height: 72)
            }
            .accessibilityLabel("Take photo")
            .accessibilityHint("Captures a still photo from the camera preview.")

            Spacer(minLength: 16)

            Button(action: viewModel.flipCamera) {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .modifier(CameraGlass())
            }
            .accessibilityLabel("Flip camera")
            .accessibilityHint("Switches between the rear and front cameras.")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(.black)
        .environment(\.colorScheme, .dark)
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
        .padding(.bottom, 156)
    }

    private func openCameraSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

private struct FocusExposureOverlay: View {
    let isLocked: Bool
    let exposure: Float
    let exposureRange: CameraExposureRange
    let onExposureChange: (Float) -> Void
    let onToggleLock: () -> Void

    var body: some View {
        ZStack {
            FocusIndicator(isLocked: isLocked)

            FocusExposureSlider(
                value: exposure,
                range: exposureRange,
                onChange: onExposureChange
            )
            .offset(x: 52)
            .opacity(isLocked ? 0.68 : 1)

            Color.clear
                .frame(width: 68, height: 68)
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.45)
                        .onEnded { _ in onToggleLock() }
                )
                .accessibilityElement()
                .accessibilityLabel(isLocked ? "Focus locked" : "Focus point")
                .accessibilityValue(isLocked ? "Locked" : "Unlocked")
                .accessibilityHint("Long press to lock or unlock focus.")
        }
        .frame(width: 140, height: 128)
    }
}

private struct FocusExposureSlider: View {
    let value: Float
    let range: CameraExposureRange
    let onChange: (Float) -> Void
    @State private var dragStart: Float?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.82))
                    .frame(width: 2, height: proxy.size.height - 20)

                Circle()
                    .fill(FrameWiseBrand.signalCoral)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .position(
                        x: proxy.size.width / 2,
                        y: range.verticalPosition(
                            for: value,
                            height: max(proxy.size.height - 20, 1)
                        ) + 10
                    )

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .opacity(0.86)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if dragStart == nil { dragStart = value }
                        onChange(range.verticalBias(
                            startingAt: dragStart ?? value,
                            translation: gesture.translation.height,
                            height: max(proxy.size.height - 20, 1)
                        ))
                    }
                    .onEnded { _ in dragStart = nil }
            )
        }
        .frame(width: 32, height: 128)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus exposure")
        .accessibilityValue(String(format: "%+.1f EV", value))
        .accessibilityHint("Swipe up to brighten or down to darken.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onChange(range.bias(startingAt: value, translation: 8))
            case .decrement:
                onChange(range.bias(startingAt: value, translation: -8))
            @unknown default:
                break
            }
        }
    }
}

private struct FocusIndicator: View {
    let isLocked: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FrameWiseBrand.signalCoral, lineWidth: 2)
                .frame(width: 68, height: 68)
                .shadow(color: .black.opacity(0.25), radius: 3)
                .opacity(isLocked ? 0.48 : 1)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(.black.opacity(0.86), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.32), lineWidth: 1))
                    .offset(x: 7, y: -7)
            }
        }
        .accessibilityHidden(true)
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
                    for: .seconds(reduceMotion ? 0.14 : 0.18)
                )
            } catch {
                return
            }

            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.18)
                    : .easeInOut(duration: 0.62)
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
