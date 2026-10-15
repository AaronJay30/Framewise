import Foundation

public struct CameraGuidePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum CameraGoldenSpiralGeometry {
    /// Returns a smooth, normalized spiral from its lower-right focal turn to
    /// the upper-left outer sweep.
    public static func points(sampleCount: Int = 160) -> [CameraGuidePoint] {
        guard sampleCount > 0 else { return [] }
        guard sampleCount > 1 else {
            return [CameraGuidePoint(x: 0.56, y: 0.56)]
        }

        let phi = (1 + sqrt(5.0)) / 2
        let quarterTurns = 5.0
        let outerRadius = 0.95
        let innerRadius = outerRadius / pow(phi, quarterTurns)
        let startAngle = Double.pi / 4
        let totalAngle = Double.pi * 5
        let center = (x: 0.5, y: 0.5)

        let rawPoints = (0..<sampleCount).map { index -> (x: Double, y: Double) in
            let progress = Double(index) / Double(sampleCount - 1)
            let radius = innerRadius * pow(phi, quarterTurns * progress)
            let angle = startAngle - totalAngle * progress
            return (
                center.x + radius * cos(angle),
                center.y + radius * sin(angle)
            )
        }

        let minX = rawPoints.map(\.x).min() ?? center.x
        let maxX = rawPoints.map(\.x).max() ?? center.x
        let minY = rawPoints.map(\.y).min() ?? center.y
        let maxY = rawPoints.map(\.y).max() ?? center.y
        let inset = 0.06

        func normalized(_ value: Double, minimum: Double, maximum: Double) -> Double {
            guard maximum > minimum else { return 0.5 }
            let fraction = (value - minimum) / (maximum - minimum)
            return min(max(inset + fraction * (1 - inset * 2), 0), 1)
        }

        return rawPoints.map { point in
            CameraGuidePoint(
                x: normalized(point.x, minimum: minX, maximum: maxX),
                y: normalized(point.y, minimum: minY, maximum: maxY)
            )
        }
    }
}
