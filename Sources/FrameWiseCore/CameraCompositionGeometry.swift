import Foundation

public struct CameraGuidePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CameraGoldenRectangle: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum CameraGoldenSpiralGeometry {
    public static let phi = (1 + sqrt(5.0)) / 2

    /// Fits a golden rectangle inside the requested bounds without stretching.
    /// Landscape bounds receive a horizontal rectangle; portrait bounds receive
    /// a vertical rectangle so the long and short sides remain exact.
    public static func goldenRectangle(
        width: Double,
        height: Double
    ) -> CameraGoldenRectangle? {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return nil
        }

        if width >= height {
            let rectangleHeight = min(height, width / phi)
            let rectangleWidth = rectangleHeight * phi
            return CameraGoldenRectangle(
                x: (width - rectangleWidth) / 2,
                y: (height - rectangleHeight) / 2,
                width: rectangleWidth,
                height: rectangleHeight
            )
        }

        let rectangleWidth = min(width, height / phi)
        let rectangleHeight = rectangleWidth * phi
        return CameraGoldenRectangle(
            x: (width - rectangleWidth) / 2,
            y: (height - rectangleHeight) / 2,
            width: rectangleWidth,
            height: rectangleHeight
        )
    }

    /// Returns a construction-based spiral in normalized coordinates.
    ///
    /// The construction starts with a phi rectangle, removes alternating
    /// squares from its left, bottom, right, and top edges, then samples a
    /// quarter-circle in each square. The returned order runs from the inner
    /// focal turn toward the outer sweep.
    public static func points(sampleCount: Int = 1_600) -> [CameraGuidePoint] {
        points(width: 1, height: 1, sampleCount: sampleCount)
    }

    /// Returns construction-based spiral points fitted to the requested bounds
    /// without distorting any quarter-circle into an ellipse.
    public static func points(
        width: Double,
        height: Double,
        sampleCount: Int = 1_600
    ) -> [CameraGuidePoint] {
        guard sampleCount > 0,
              let rectangle = goldenRectangle(width: width, height: height) else {
            return []
        }

        let arcs = constructionArcs()
        guard !arcs.isEmpty else { return [] }

        let rawPoints: [(x: Double, y: Double)]
        if sampleCount == 1 {
            let arc = arcs[arcs.count - 1]
            rawPoints = [arcPoint(arc, progress: 1)]
        } else {
            rawPoints = (0..<sampleCount).map { index in
                let position = Double(index) / Double(sampleCount - 1)
                    * Double(arcs.count)
                let arcIndex = min(Int(position), arcs.count - 1)
                let progress = min(position - Double(arcIndex), 1)
                return arcPoint(arcs[arcIndex], progress: progress)
            }.reversed()
        }

        return rawPoints.map { point in
            let localX = point.x / phi
            let localY = point.y
            let fittedX: Double
            let fittedY: Double

            if rectangle.width >= rectangle.height {
                fittedX = localX
                fittedY = localY
            } else {
                // Rotate the horizontal construction clockwise for portrait
                // bounds. Circles stay circles because the fit is uniform.
                fittedX = 1 - localY
                fittedY = localX
            }

            return CameraGuidePoint(
                x: (rectangle.x + fittedX * rectangle.width) / width,
                y: (rectangle.y + fittedY * rectangle.height) / height
            )
        }
    }

    private enum Edge {
        case left
        case bottom
        case right
        case top
    }

    private struct Rectangle {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    private struct Arc {
        let centerX: Double
        let centerY: Double
        let radius: Double
        let startAngle: Double
    }

    private static func constructionArcs() -> [Arc] {
        var remaining = Rectangle(x: 0, y: 0, width: phi, height: 1)
        var arcs: [Arc] = []
        let edges: [Edge] = [.left, .bottom, .right, .top]

        for index in 0..<12 {
            let edge = edges[index % edges.count]
            let side = min(remaining.width, remaining.height)
            guard side.isFinite, side > 0.0001 else { break }

            let squareX: Double
            let squareY: Double

            switch edge {
            case .left:
                squareX = remaining.x
                squareY = remaining.y
                remaining.x += side
                remaining.width -= side
            case .bottom:
                squareX = remaining.x
                squareY = remaining.y + remaining.height - side
                remaining.height -= side
            case .right:
                squareX = remaining.x + remaining.width - side
                squareY = remaining.y
                remaining.width -= side
            case .top:
                squareX = remaining.x
                squareY = remaining.y
                remaining.y += side
                remaining.height -= side
            }

            arcs.append(
                arc(
                    for: edge,
                    squareX: squareX,
                    squareY: squareY,
                    side: side
                )
            )
        }

        return arcs
    }

    private static func arc(
        for edge: Edge,
        squareX: Double,
        squareY: Double,
        side: Double
    ) -> Arc {
        switch edge {
        case .left:
            return Arc(
                centerX: squareX,
                centerY: squareY + side,
                radius: side,
                startAngle: -.pi / 2
            )
        case .bottom:
            return Arc(
                centerX: squareX + side,
                centerY: squareY + side,
                radius: side,
                startAngle: .pi
            )
        case .right:
            return Arc(
                centerX: squareX + side,
                centerY: squareY,
                radius: side,
                startAngle: .pi / 2
            )
        case .top:
            return Arc(
                centerX: squareX,
                centerY: squareY,
                radius: side,
                startAngle: 0
            )
        }
    }

    private static func arcPoint(
        _ arc: Arc,
        progress: Double
    ) -> (x: Double, y: Double) {
        let angle = arc.startAngle + (.pi / 2) * progress
        return (
            arc.centerX + arc.radius * cos(angle),
            arc.centerY + arc.radius * sin(angle)
        )
    }
}
