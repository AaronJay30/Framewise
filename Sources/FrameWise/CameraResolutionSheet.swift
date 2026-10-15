#if canImport(SwiftUI) && canImport(AVFoundation)
import FrameWiseCore
import SwiftUI

struct CameraResolutionSheet: View {
    let settings: CameraSettings
    let capability: CameraPhotoResolutionCapability?
    let onChange: (CameraSettings) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Resolution")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .modifier(CameraGlass())
                    }
                    .accessibilityLabel("Close resolution")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Still photo size")
                        .font(.headline)

                    resolutionRow(
                        title: CameraPhotoResolution.standard.title,
                        detail: "Use the camera's standard capture size.",
                        resolution: .standard
                    )

                    if let maximumTitle = capability?.maximumTitle {
                        resolutionRow(
                            title: maximumTitle,
                            detail: "Use the largest size supported by this camera.",
                            resolution: .maximum
                        )
                    } else {
                        unavailableRow
                    }
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

    private func resolutionRow(
        title: String,
        detail: String,
        resolution: CameraPhotoResolution
    ) -> some View {
        let selected = isSelected(resolution)

        return Button {
            var next = settings
            next.photoResolution = resolution
            onChange(next)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? FrameWiseBrand.signalCoral : .white.opacity(0.7))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var unavailableRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "minus.circle")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("Maximum unavailable")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Text("This camera does not expose a separate maximum photo size.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.35))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Maximum unavailable")
        .accessibilityValue("This camera does not expose a separate maximum photo size")
    }

    private func isSelected(_ resolution: CameraPhotoResolution) -> Bool {
        switch resolution {
        case .standard:
            return settings.photoResolution == .standard || !supportsMaximum
        case .maximum:
            return settings.photoResolution == .maximum && supportsMaximum
        }
    }

    private var supportsMaximum: Bool {
        capability?.supportsMaximum == true
    }
}
#endif
