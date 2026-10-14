#if canImport(SwiftUI) && canImport(AVFoundation)
import Foundation
import FrameWiseCore
import SwiftUI

struct CameraSettingsSheet: View {
    let settings: CameraSettings
    let exposureRange: CameraExposureRange
    let zoomRange: ClosedRange<Float>
    let onChange: (CameraSettings) -> Void
    let onReset: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CameraSettings

    init(
        settings: CameraSettings,
        exposureRange: CameraExposureRange,
        zoomRange: ClosedRange<Float>,
        onChange: @escaping (CameraSettings) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.settings = settings
        self.exposureRange = exposureRange
        self.zoomRange = zoomRange
        self.onChange = onChange
        self.onReset = onReset
        _draft = State(initialValue: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            quickControls
            Divider()
            exposureControl
            Divider()
            styleControl
            Spacer(minLength: 0)
            resetButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(FrameWiseBrand.surface(for: colorScheme))
        .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: settings) { _, newValue in
            draft = newValue
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Camera Controls")
                    .font(.title3.weight(.semibold))
                Text("Tune the next capture")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(FrameWiseBrand.signalCoral)
            .frame(minWidth: 54, minHeight: 44)
            .accessibilityLabel("Done")
        }
    }

    private var quickControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                flashMenu
                timerMenu
                aspectMenu
                zoomMenu
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera choices")
    }

    private var flashMenu: some View {
        Menu {
            ForEach(CameraFlashMode.allCases, id: \.rawValue) { mode in
                Button {
                    update { $0.flashMode = mode }
                } label: {
                    menuChoiceLabel(mode.title, isSelected: draft.flashMode == mode)
                }
            }
        } label: {
            controlLabel(
                symbol: "bolt.fill",
                title: "Flash",
                value: draft.flashMode.title
            )
        }
        .accessibilityLabel("Flash, \(draft.flashMode.title)")
    }

    private var timerMenu: some View {
        Menu {
            ForEach(CameraTimerDuration.allCases, id: \.rawValue) { duration in
                Button {
                    update { $0.timerDuration = duration }
                } label: {
                    menuChoiceLabel(duration.title, isSelected: draft.timerDuration == duration)
                }
            }
        } label: {
            controlLabel(
                symbol: "timer",
                title: "Timer",
                value: draft.timerDuration.title
            )
        }
        .accessibilityLabel("Timer, \(draft.timerDuration.title)")
    }

    private var aspectMenu: some View {
        Menu {
            ForEach(CameraAspectRatio.allCases, id: \.rawValue) { aspect in
                Button {
                    update { $0.aspectRatio = aspect }
                } label: {
                    menuChoiceLabel(aspect.title, isSelected: draft.aspectRatio == aspect)
                }
            }
        } label: {
            controlLabel(
                symbol: "rectangle.inset.filled",
                title: "Aspect",
                value: draft.aspectRatio.title
            )
        }
        .accessibilityLabel("Aspect, \(draft.aspectRatio.title)")
    }

    private var zoomMenu: some View {
        Menu {
            ForEach(zoomChoices, id: \.self) { zoom in
                Button {
                    update {
                        $0.zoomFactor = min(
                            max(zoom, safeZoomRange.lowerBound),
                            safeZoomRange.upperBound
                        )
                    }
                } label: {
                    menuChoiceLabel(zoomTitle(zoom), isSelected: draft.zoomFactor == zoom)
                }
            }
        } label: {
            controlLabel(
                symbol: "magnifyingglass",
                title: "Zoom",
                value: zoomTitle(clampedZoom(draft.zoomFactor))
            )
        }
        .accessibilityLabel("Zoom, \(zoomTitle(clampedZoom(draft.zoomFactor)))")
    }

    private var exposureControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Exposure", systemImage: "sun.max.fill")
                    .font(.body.weight(.medium))
                Spacer()
                Text(exposureTitle(draft.exposureBias))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: exposureBinding, in: safeExposureRange) {
                Text("Exposure")
            }
            .tint(FrameWiseBrand.signalCoral)
            .frame(minHeight: 44)
            .accessibilityLabel("Exposure")
            .accessibilityValue(exposureTitle(draft.exposureBias))
        }
    }

    private var styleControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Photographic Style", systemImage: "wand.and.stars")
                .font(.body.weight(.medium))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CameraPhotographicStyle.allCases, id: \.rawValue) { style in
                        styleButton(style)
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Photographic styles")
        }
    }

    private var resetButton: some View {
        Button {
            draft = .defaults
            onReset()
        } label: {
            Text("Reset to Defaults")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(FrameWiseBrand.signalCoral)
        .accessibilityLabel("Reset camera settings to defaults")
    }

    private func controlLabel(symbol: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .frame(width: 78, height: 56, alignment: .leading)
        .padding(.horizontal, 10)
        .background(FrameWiseBrand.ink.opacity(colorScheme == .dark ? 0.9 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FrameWiseBrand.signalCoral.opacity(0.22), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func menuChoiceLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func styleButton(_ style: CameraPhotographicStyle) -> some View {
        let isSelected = draft.photographicStyle == style

        return Button {
            update { $0.photographicStyle = style }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(styleSwatch(for: style))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.42), lineWidth: 1)
                    }
                Text(style.title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(width: 76, height: 68)
            .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))
            .background(
                isSelected
                    ? FrameWiseBrand.signalCoral.opacity(0.2)
                    : FrameWiseBrand.ink.opacity(colorScheme == .dark ? 0.9 : 0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                            ? FrameWiseBrand.signalCoral
                            : FrameWiseBrand.signalCoral.opacity(0.18),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photographic style \(style.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var exposureBinding: Binding<Double> {
        Binding(
            get: {
                min(
                    max(Double(draft.exposureBias), safeExposureRange.lowerBound),
                    safeExposureRange.upperBound
                )
            },
            set: { value in
                update { $0.exposureBias = Float(value) }
            }
        )
    }

    private var safeExposureRange: ClosedRange<Double> {
        let minimum = Double(exposureRange.minimum)
        let maximum = Double(exposureRange.maximum)
        guard minimum.isFinite, maximum.isFinite, minimum < maximum else {
            return -2...2
        }

        return minimum...maximum
    }

    private var zoomChoices: [Float] {
        let baseChoices: [Float] = [1, 1.5, 2, 3, 4, 5]
        var choices = baseChoices.filter { safeZoomRange.contains($0) }
        if !choices.contains(safeZoomRange.lowerBound) {
            choices.append(safeZoomRange.lowerBound)
        }
        if !choices.contains(safeZoomRange.upperBound) {
            choices.append(safeZoomRange.upperBound)
        }
        return choices.sorted()
    }

    private var safeZoomRange: ClosedRange<Float> {
        guard zoomRange.lowerBound.isFinite,
              zoomRange.upperBound.isFinite,
              zoomRange.lowerBound <= zoomRange.upperBound else {
            return 1...10
        }

        return zoomRange
    }

    private func clampedZoom(_ zoom: Float) -> Float {
        min(max(zoom, safeZoomRange.lowerBound), safeZoomRange.upperBound)
    }

    private func zoomTitle(_ zoom: Float) -> String {
        String(format: "%.1fx", Double(zoom))
    }

    private func exposureTitle(_ exposure: Float) -> String {
        String(format: "%+.1f EV", Double(exposure))
    }

    private func styleSwatch(for style: CameraPhotographicStyle) -> Color {
        switch style {
        case .standard:
            return .gray
        case .vivid:
            return .orange
        case .warm:
            return .red.opacity(0.78)
        case .cool:
            return .blue.opacity(0.78)
        case .mono:
            return .black
        }
    }

    private func update(_ change: (inout CameraSettings) -> Void) {
        var next = draft
        change(&next)
        draft = next
        onChange(next)
    }
}
#endif
