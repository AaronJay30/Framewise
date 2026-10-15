#if canImport(SwiftUI) && canImport(AVFoundation)
import FrameWiseCore
import SwiftUI

/// Native glass on current iOS, with accessible and older-system fallbacks.
struct CameraGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color.black, in: Capsule())
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(.black.opacity(0.35)), in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

struct CameraTopControls: View {
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 44
    let settings: CameraSettings
    let flashAvailable: Bool
    let photoResolutionCapability: CameraPhotoResolutionCapability?
    let onChange: (CameraSettings) -> Void
    let onStyles: () -> Void
    let onComposition: () -> Void
    let onResolution: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            controls
            ScrollView(.horizontal, showsIndicators: false) { controls }
        }
        .frame(height: max(44, rowHeight))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.black)
        .environment(\.colorScheme, .dark)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            control(
                "Flash", symbol: settings.flashMode == .off ? "bolt.slash.fill" : "bolt.fill",
                value: flashAvailable ? settings.flashMode.title : "—",
                active: flashAvailable && settings.flashMode != .off
            ) {
                var next = settings
                next.flashMode = settings.flashMode.next
                onChange(next)
            }
            .disabled(!flashAvailable)
            .accessibilityHint(flashAvailable ? "Cycles Off, Auto, and On." : "Unavailable on this camera.")

            control("Timer", symbol: "timer", value: settings.timerDuration.title,
                    active: settings.timerDuration != .off) {
                var next = settings
                next.timerDuration = settings.timerDuration.next
                onChange(next)
            }
            .accessibilityHint("Cycles Off, 3, 5, and 10 seconds.")

            control("Aspect", symbol: nil, value: settings.aspectRatio.title,
                    active: settings.aspectRatio != .fourByThree) {
                var next = settings
                next.aspectRatio = settings.aspectRatio.next
                onChange(next)
            }
            .accessibilityHint("Cycles portrait 4:3, square, and portrait 16:9.")

            control("Photographic styles", symbol: "camera.filters", value: nil,
                    active: settings.photographicStyle != .standard, action: onStyles)
                .accessibilityValue(settings.photographicStyle.title)

            control("Composition", symbol: "square.grid.3x3", value: nil,
                    active: settings.compositionGuide != .off, action: onComposition,
                    usesGlass: false)
                .accessibilityValue(settings.compositionGuide.title)

            control("Resolution", symbol: "camera.aperture", value: nil,
                    active: settings.photoResolution != .standard, action: onResolution,
                    usesGlass: false)
                .accessibilityValue(resolutionAccessibilityValue)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func control(
        _ title: String, symbol: String?, value: String?, active: Bool,
        action: @escaping () -> Void, usesGlass: Bool = true
    ) -> some View {
        Button(action: action) {
            controlSurface(
                symbol: symbol,
                value: value,
                active: active,
                usesGlass: usesGlass
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "")
    }

    @ViewBuilder
    private func controlSurface(
        symbol: String?, value: String?, active: Bool, usesGlass: Bool
    ) -> some View {
        if usesGlass {
            controlContent(symbol: symbol, value: value, active: active)
                .modifier(CameraGlass())
                .contentShape(Capsule())
        } else {
            controlContent(symbol: symbol, value: value, active: active)
                .contentShape(Rectangle())
        }
    }

    private func controlContent(
        symbol: String?, value: String?, active: Bool
    ) -> some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            if let value { Text(value).monospacedDigit() }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(active ? FrameWiseBrand.signalCoral : .white)
        .padding(.horizontal, value == nil ? 0 : 12)
        .frame(minWidth: 44, minHeight: 44)
    }

    private var resolutionAccessibilityValue: String {
        if settings.photoResolution == .maximum {
            return photoResolutionCapability?.maximumTitle ?? CameraPhotoResolution.maximum.title
        }
        return CameraPhotoResolution.standard.title
    }
}

struct CameraZoomControls: View {
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 54
    let value: Float
    let range: ClosedRange<Float>
    let onChange: (Float) -> Void

    private var presets: [Float] { CameraZoomScale.presets(in: range) }
    private var nearestPreset: Float? {
        presets.min { abs($0 - value) < abs($1 - value) }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            buttons
            ScrollView(.horizontal, showsIndicators: false) { buttons }
        }
        .frame(height: max(54, rowHeight))
        .background {
            Color.clear.modifier(CameraGlass()).allowsHitTesting(false)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom")
        .accessibilityValue(title(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(value + 0.5, range.upperBound))
            case .decrement: onChange(max(value - 0.5, range.lowerBound))
            @unknown default: break
            }
        }
        .accessibilityActions {
            ForEach(presets, id: \.self) { factor in
                Button("Zoom to \(title(factor))") { onChange(factor) }
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 4) {
            ForEach(presets, id: \.self) { factor in
                let selected = factor == nearestPreset
                Button { onChange(factor) } label: {
                    Text(selected ? title(value) : title(factor))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(selected ? FrameWiseBrand.signalCoral : .white)
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, selected && value >= 10 ? 4 : 0)
                        .background(selected ? Color.white.opacity(0.16) : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zoom to \(title(factor))")
                .accessibilityValue(selected ? "Current zoom \(title(value))" : "")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(5)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func title(_ factor: Float) -> String {
        if abs(factor - 0.5) < 0.01 { return ".5" }
        return factor == factor.rounded()
            ? String(format: "%.0f×", factor) : String(format: "%.1f×", factor)
    }
}

#endif
