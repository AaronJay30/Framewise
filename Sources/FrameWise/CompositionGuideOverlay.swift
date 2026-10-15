#if canImport(SwiftUI) && canImport(AVFoundation)
import SwiftUI
import FrameWiseCore

struct CompositionGuideOverlay: View {
    let guide: CameraCompositionGuide
    let opacity: Double

    var body: some View {
        CompositionGuideArtwork(guide: guide, opacity: opacity)
    }
}

struct CompositionGuideArtwork: View {
    let guide: CameraCompositionGuide
    let opacity: Double
    let lineColor: Color

    init(
        guide: CameraCompositionGuide,
        opacity: Double,
        lineColor: Color = .white
    ) {
        self.guide = guide
        self.opacity = opacity
        self.lineColor = lineColor
    }

    var body: some View {
        Canvas { context, size in
            guard guide != .off, size.width > 0, size.height > 0 else { return }
            drawGuide(guide, in: size, context: &context)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawGuide(
        _ guide: CameraCompositionGuide,
        in size: CGSize,
        context: inout GraphicsContext
    ) {
        let safeOpacity = opacity.isFinite ? min(max(opacity, 0.20), 1) : 0.60
        let strokeWidth = max(1, min(size.width, size.height) * 0.0035)
        let strokeStyle = StrokeStyle(
            lineWidth: strokeWidth,
            lineCap: .round,
            lineJoin: .round
        )
        let strokeColor = lineColor.opacity(safeOpacity)

        func stroke(_ path: Path, opacity: Double = 1) {
            context.stroke(
                path,
                with: .color(strokeColor.opacity(opacity)),
                style: strokeStyle
            )
        }

        func verticalLine(at fraction: CGFloat) -> Path {
            line(
                from: CGPoint(x: size.width * fraction, y: 0),
                to: CGPoint(x: size.width * fraction, y: size.height)
            )
        }

        func horizontalLine(at fraction: CGFloat) -> Path {
            line(
                from: CGPoint(x: 0, y: size.height * fraction),
                to: CGPoint(x: size.width, y: size.height * fraction)
            )
        }

        switch guide {
        case .off:
            break
        case .ruleOfThirds:
            stroke(verticalLine(at: 1.0 / 3.0))
            stroke(verticalLine(at: 2.0 / 3.0))
            stroke(horizontalLine(at: 1.0 / 3.0))
            stroke(horizontalLine(at: 2.0 / 3.0))
        case .centreCross:
            stroke(verticalLine(at: 0.5))
            stroke(horizontalLine(at: 0.5))
        case .quadrant:
            let halfWidth = size.width * 0.5
            let halfHeight = size.height * 0.5
            let quadrants = [
                CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight),
                CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight),
                CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight),
                CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)
            ]
            for quadrant in quadrants {
                context.fill(
                    Path(quadrant),
                    with: .color(Color.white.opacity(safeOpacity * 0.045))
                )
            }
            stroke(verticalLine(at: 0.5))
            stroke(horizontalLine(at: 0.5))
        case .ruleOfFifths:
            for fraction in [0.2, 0.4, 0.6, 0.8] {
                stroke(verticalLine(at: CGFloat(fraction)))
                stroke(horizontalLine(at: CGFloat(fraction)))
            }
        case .goldenRatio:
            let phi = (1 + sqrt(5.0)) / 2
            let first = CGFloat(1 / phi)
            let second = CGFloat(1 - 1 / phi)
            stroke(verticalLine(at: first))
            stroke(verticalLine(at: second))
            stroke(horizontalLine(at: first))
            stroke(horizontalLine(at: second))
        case .goldenSpiral:
            stroke(goldenRectanglePath(in: CGRect(origin: .zero, size: size)), opacity: 0.55)
            stroke(goldenSpiralPath(in: CGRect(origin: .zero, size: size)))
        case .goldenTriangle:
            let start = CGPoint.zero
            let end = CGPoint(x: size.width, y: size.height)
            stroke(line(from: start, to: end))
            let oppositeCorners = [
                CGPoint(x: size.width, y: 0),
                CGPoint(x: 0, y: size.height)
            ]
            for corner in oppositeCorners {
                let foot = projectedPoint(corner, ontoLineFrom: start, to: end)
                stroke(line(from: corner, to: foot))
            }
        case .diagonalCross:
            stroke(line(
                from: CGPoint.zero,
                to: CGPoint(x: size.width, y: size.height)
            ))
            stroke(line(
                from: CGPoint(x: size.width, y: 0),
                to: CGPoint(x: 0, y: size.height)
            ))
        case .horizon:
            stroke(horizontalLine(at: 0.5))
        }
    }

    private func line(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }

    private func projectedPoint(
        _ point: CGPoint,
        ontoLineFrom start: CGPoint,
        to end: CGPoint
    ) -> CGPoint {
        let vector = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let lengthSquared = vector.x * vector.x + vector.y * vector.y
        guard lengthSquared > 0 else { return start }

        let offset = CGPoint(x: point.x - start.x, y: point.y - start.y)
        let fraction = min(
            max((offset.x * vector.x + offset.y * vector.y) / lengthSquared, 0),
            1
        )
        return CGPoint(
            x: start.x + vector.x * fraction,
            y: start.y + vector.y * fraction
        )
    }

    private func goldenSpiralPath(in bounds: CGRect) -> Path {
        let points = CameraGoldenSpiralGeometry.points(
            width: Double(bounds.width),
            height: Double(bounds.height)
        )
        guard let first = points.first else { return Path() }
        var path = Path()
        path.move(
            to: CGPoint(
                x: bounds.minX + CGFloat(first.x) * bounds.width,
                y: bounds.minY + CGFloat(first.y) * bounds.height
            )
        )
        for point in points.dropFirst() {
            path.addLine(
                to: CGPoint(
                    x: bounds.minX + CGFloat(point.x) * bounds.width,
                    y: bounds.minY + CGFloat(point.y) * bounds.height
                )
            )
        }
        return path
    }

    private func goldenRectanglePath(in bounds: CGRect) -> Path {
        guard let rectangle = CameraGoldenSpiralGeometry.goldenRectangle(
            width: Double(bounds.width),
            height: Double(bounds.height)
        ) else {
            return Path()
        }

        return Path(
            CGRect(
                x: bounds.minX + rectangle.x,
                y: bounds.minY + rectangle.y,
                width: rectangle.width,
                height: rectangle.height
            )
        )
    }
}
#endif
