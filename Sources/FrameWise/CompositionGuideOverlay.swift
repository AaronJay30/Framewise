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

    var body: some View {
        Canvas { context, size in
            guard guide != .off, size.width > 0, size.height > 0 else { return }
            drawGuide(guide, in: size, context: &context)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: .black.opacity(0.36), radius: 2)
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
        let lineColor = Color.white.opacity(safeOpacity)

        func stroke(_ path: Path, opacity: Double = 1) {
            context.stroke(
                path,
                with: .color(lineColor.opacity(opacity)),
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
        let phi = CGFloat((1 + sqrt(5.0)) / 2)
        var rectangle: CGRect

        if bounds.width >= bounds.height {
            let height = min(bounds.height, bounds.width / phi)
            rectangle = CGRect(
                x: bounds.midX - height * phi / 2,
                y: bounds.midY - height / 2,
                width: height * phi,
                height: height
            )
        } else {
            let width = min(bounds.width, bounds.height / phi)
            rectangle = CGRect(
                x: bounds.midX - width / 2,
                y: bounds.midY - width * phi / 2,
                width: width,
                height: width * phi
            )
        }

        var path = Path()
        var turn = rectangle.width >= rectangle.height ? 0 : 1

        for _ in 0..<8 {
            let side = min(rectangle.width, rectangle.height)
            guard side > 0.5 else { break }

            let square: CGRect
            switch turn % 4 {
            case 0:
                square = CGRect(
                    x: rectangle.minX,
                    y: rectangle.minY,
                    width: side,
                    height: side
                )
                path.addArc(
                    center: CGPoint(x: square.minX, y: square.maxY),
                    radius: side,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                rectangle = CGRect(
                    x: rectangle.minX + side,
                    y: rectangle.minY,
                    width: max(rectangle.width - side, 0),
                    height: rectangle.height
                )
            case 1:
                square = CGRect(
                    x: rectangle.minX,
                    y: rectangle.maxY - side,
                    width: side,
                    height: side
                )
                path.addArc(
                    center: CGPoint(x: square.maxX, y: square.maxY),
                    radius: side,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false
                )
                rectangle = CGRect(
                    x: rectangle.minX,
                    y: rectangle.minY,
                    width: rectangle.width,
                    height: max(rectangle.height - side, 0)
                )
            case 2:
                square = CGRect(
                    x: rectangle.maxX - side,
                    y: rectangle.minY,
                    width: side,
                    height: side
                )
                path.addArc(
                    center: CGPoint(x: square.maxX, y: square.minY),
                    radius: side,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false
                )
                rectangle = CGRect(
                    x: rectangle.minX,
                    y: rectangle.minY,
                    width: max(rectangle.width - side, 0),
                    height: rectangle.height
                )
            default:
                square = CGRect(
                    x: rectangle.minX,
                    y: rectangle.minY,
                    width: side,
                    height: side
                )
                path.addArc(
                    center: CGPoint(x: square.minX, y: square.minY),
                    radius: side,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false
                )
                rectangle = CGRect(
                    x: rectangle.minX,
                    y: rectangle.minY + side,
                    width: rectangle.width,
                    height: max(rectangle.height - side, 0)
                )
            }

            turn += 1
        }

        return path
    }
}
#endif
