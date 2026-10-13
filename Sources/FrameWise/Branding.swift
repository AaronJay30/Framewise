#if canImport(SwiftUI)
import Foundation
import SwiftUI
import FrameWiseCore

/// SwiftUI colors and reusable geometry for the FrameWise identity.
///
/// The source hex values live in `FrameWiseCore` so host tests and app views
/// share one palette. This file is the platform-specific rendering layer.
enum FrameWiseBrand {
    static let ink = Color(hex: FrameWiseBrandToken.inkHex)
    static let signalCoral = Color(hex: FrameWiseBrandToken.signalCoralHex)

    /// Background used by the opener and camera recovery states.
    ///
    /// The logo colors remain fixed brand tokens, but app surfaces follow the
    /// user's system appearance so the mark stays legible in both themes.
    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }

    /// Foreground color that has enough contrast against the current surface.
    static func foreground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : ink
    }
}

private extension Color {
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(digits, radix: 16) ?? 0

        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// The Open Crop symbol used by the app icon and the branded opener.
struct OpenCropSymbol: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let dimension = min(proxy.size.width, proxy.size.height)

            ZStack {
                OpenCropMarkShape()
                    .fill(FrameWiseBrand.foreground(for: colorScheme))
                OpenCropDiamondShape()
                    .fill(FrameWiseBrand.signalCoral)
            }
            .frame(width: 256, height: 256)
            .scaleEffect(dimension / 256)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The tightened FrameWise wordmark for the opener.
struct FrameWiseLockup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: -6) {
            Text("Frame")
                .foregroundStyle(FrameWiseBrand.foreground(for: colorScheme))
                .kerning(-2)
            Text("Wise")
                .foregroundStyle(FrameWiseBrand.signalCoral)
                .kerning(-2)
        }
        .font(.system(size: 54, weight: .bold, design: .rounded))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("FrameWise")
    }
}

/// Draws the four rounded framing corners from the approved 256-point grid.
private struct OpenCropMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let dimension = min(rect.width, rect.height)
        let scale = dimension / 256
        let origin = CGPoint(
            x: rect.midX - dimension / 2,
            y: rect.midY - dimension / 2
        )

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()

        path.move(to: point(44, 102))
        path.addLine(to: point(44, 72))
        path.addCurve(
            to: point(78, 38),
            control1: point(44, 53.222),
            control2: point(59.222, 38)
        )
        path.addLine(to: point(108, 38))
        path.addLine(to: point(108, 58))
        path.addLine(to: point(80, 58))
        path.addCurve(
            to: point(66, 72),
            control1: point(72.268, 58),
            control2: point(66, 64.268)
        )
        path.addLine(to: point(66, 102))
        path.closeSubpath()

        path.move(to: point(154, 38))
        path.addLine(to: point(184, 38))
        path.addCurve(
            to: point(218, 72),
            control1: point(202.778, 38),
            control2: point(218, 53.222)
        )
        path.addLine(to: point(218, 102))
        path.addLine(to: point(196, 102))
        path.addLine(to: point(196, 72))
        path.addCurve(
            to: point(182, 58),
            control1: point(196, 64.268),
            control2: point(189.732, 58)
        )
        path.addLine(to: point(154, 58))
        path.closeSubpath()

        path.move(to: point(44, 154))
        path.addLine(to: point(66, 154))
        path.addLine(to: point(66, 184))
        path.addCurve(
            to: point(80, 198),
            control1: point(66, 191.732),
            control2: point(72.268, 198)
        )
        path.addLine(to: point(108, 198))
        path.addLine(to: point(108, 218))
        path.addLine(to: point(78, 218))
        path.addCurve(
            to: point(44, 184),
            control1: point(59.222, 218),
            control2: point(44, 202.778)
        )
        path.addLine(to: point(44, 154))
        path.closeSubpath()

        path.move(to: point(198, 154))
        path.addLine(to: point(218, 154))
        path.addLine(to: point(218, 184))
        path.addCurve(
            to: point(184, 218),
            control1: point(218, 202.778),
            control2: point(202.778, 218)
        )
        path.addLine(to: point(154, 218))
        path.addLine(to: point(154, 198))
        path.addLine(to: point(182, 198))
        path.addCurve(
            to: point(196, 184),
            control1: point(189.732, 198),
            control2: point(196, 191.732)
        )
        path.addLine(to: point(196, 154))
        path.closeSubpath()

        return path
    }
}

/// Draws the coral focal diamond at the center of the Open Crop symbol.
private struct OpenCropDiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        let dimension = min(rect.width, rect.height)
        let scale = dimension / 256
        let origin = CGPoint(
            x: rect.midX - dimension / 2,
            y: rect.midY - dimension / 2
        )

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()
        path.move(to: point(128, 96))
        path.addLine(to: point(160, 128))
        path.addLine(to: point(128, 160))
        path.addLine(to: point(96, 128))
        path.closeSubpath()
        return path
    }
}
#endif
