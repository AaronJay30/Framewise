#if canImport(SwiftUI) && canImport(AVFoundation)
import FrameWiseCore
import SwiftUI

/// Photographic Styles get their own panel; capture controls stay visible.
struct CameraSettingsSheet: View {
    let settings: CameraSettings
    let onChange: (CameraSettings) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Photographic styles")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .modifier(CameraGlass())
                    }
                    .accessibilityLabel("Close styles")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(CameraPhotographicStyle.allCases, id: \.rawValue) { style in
                            styleButton(style)
                        }
                    }
                    .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Style studio")
                        .font(.headline)

                    StyleArtwork(
                        style: settings.photographicStyle,
                        intensity: Double(settings.styleIntensity)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 172)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    HStack {
                        Text("Intensity")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(settings.styleIntensity * 100))%")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(FrameWiseBrand.signalCoral)
                    }

                    Slider(value: intensityBinding, in: 0...1)
                        .tint(FrameWiseBrand.signalCoral)
                        .accessibilityLabel("Style intensity")
                        .accessibilityValue("\(Int(settings.styleIntensity * 100)) percent")
                }

                Button(action: onReset) {
                    Text("Reset camera settings")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .modifier(CameraGlass())
                }
                .accessibilityHint("Restores flash, timer, exposure, aspect, zoom, style, and composition defaults.")
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .preferredColorScheme(.dark)
        .presentationBackground(reduceTransparency ? AnyShapeStyle(.black) : AnyShapeStyle(.regularMaterial))
        .presentationCornerRadius(32)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func styleButton(_ style: CameraPhotographicStyle) -> some View {
        let selected = settings.photographicStyle == style
        return Button {
            var next = settings
            next.photographicStyle = style
            next.styleIntensity = 1
            onChange(next)
        } label: {
            VStack(spacing: 10) {
                StyleArtwork(
                    style: style,
                    intensity: selected ? Double(settings.styleIntensity) : 0.82
                )
                .frame(width: 76, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.black, FrameWiseBrand.signalCoral)
                                .padding(7)
                        }
                    }
                Text(style.title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? FrameWiseBrand.signalCoral : .white)
            }
            .padding(4)
        }
        .accessibilityLabel("Photographic style \(style.title)")
        .accessibilityValue(selected ? "Selected, \(Int(settings.styleIntensity * 100)) percent intensity" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var intensityBinding: Binding<Float> {
        Binding(
            get: { settings.styleIntensity },
            set: { value in
                var next = settings
                next.styleIntensity = value
                onChange(next)
            }
        )
    }
}

private struct StyleArtwork: View {
    let style: CameraPhotographicStyle
    let intensity: Double

    private var adjustments: CameraStyleAdjustments {
        style.adjustments(at: intensity)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 132, height: 132)
                .blur(radius: 2)
                .offset(x: 38, y: -28)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.42), lineWidth: 1)
                .rotationEffect(.degrees(-12))
                .scaleEffect(x: 1.1, y: 0.7)

            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .medium))
                Text(style.title)
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .saturation(adjustments.saturation)
        .contrast(adjustments.contrast)
        .brightness(adjustments.brightness)
        .colorMultiply(Color(
            red: min(max(adjustments.redMultiplier, 0), 1),
            green: min(max(adjustments.greenMultiplier, 0), 1),
            blue: min(max(adjustments.blueMultiplier, 0), 1)
        ))
    }

    private var symbol: String {
        switch style {
        case .standard: "camera"
        case .vivid: "sparkles"
        case .warm: "sun.max.fill"
        case .cool: "snowflake"
        case .mono: "circle.lefthalf.filled"
        }
    }

    private var palette: [Color] {
        switch style {
        case .standard:
            [Color(white: 0.18), Color(white: 0.58), Color(white: 0.92)]
        case .vivid:
            [Color(red: 0.97, green: 0.18, blue: 0.28), .orange, .yellow]
        case .warm:
            [Color(red: 0.34, green: 0.08, blue: 0.05), Color(red: 0.86, green: 0.36, blue: 0.12), .yellow]
        case .cool:
            [Color(red: 0.03, green: 0.12, blue: 0.28), Color(red: 0.10, green: 0.48, blue: 0.76), .cyan]
        case .mono:
            [Color(white: 0.04), Color(white: 0.38), Color(white: 0.86)]
        }
    }
}
#endif
