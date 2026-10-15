#if canImport(SwiftUI) && canImport(AVFoundation)
import FrameWiseCore
import SwiftUI

struct CompositionGuideSheet: View {
    let settings: CameraSettings
    let onChange: (CameraSettings) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Composition")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .modifier(CameraGlass())
                    }
                    .accessibilityLabel("Close composition")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Guide")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(CameraCompositionGuide.allCases, id: \.rawValue) { guide in
                                guideButton(guide)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Opacity")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(settings.compositionGuideOpacity * 100))%")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(FrameWiseBrand.signalCoral)
                    }

                    Slider(value: opacityBinding, in: 0.20...1.00, step: 0.01)
                        .tint(FrameWiseBrand.signalCoral)
                        .accessibilityLabel("Composition guide opacity")
                        .accessibilityValue("\(Int(settings.compositionGuideOpacity * 100)) percent")
                }
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .preferredColorScheme(.dark)
        .presentationBackground(.black)
        .presentationCornerRadius(32)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func guideButton(_ guide: CameraCompositionGuide) -> some View {
        let selected = settings.compositionGuide == guide

        return Button {
            var next = settings
            next.compositionGuide = guide
            onChange(next)
        } label: {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    CompositionGuideArtwork(
                        guide: guide,
                        opacity: Double(settings.compositionGuideOpacity)
                    )
                    .frame(width: 82, height: 96)

                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.black, FrameWiseBrand.signalCoral)
                            .font(.body.weight(.semibold))
                    }
                }

                Text(guide.title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? FrameWiseBrand.signalCoral : .white)
                    .multilineTextAlignment(.center)
                    .frame(width: 92)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Composition guide \(guide.title)")
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var opacityBinding: Binding<Float> {
        Binding(
            get: { settings.compositionGuideOpacity },
            set: { value in
                var next = settings
                next.compositionGuideOpacity = value
                onChange(next)
            }
        )
    }
}
#endif
