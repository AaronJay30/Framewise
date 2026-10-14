import Foundation

/// Keeps user-facing lens factors separate from a virtual camera's native scale.
public struct CameraZoomScale: Sendable {
    private let displayMultiplier: Float

    public init(displayMultiplier: Float) {
        self.displayMultiplier = displayMultiplier.isFinite && displayMultiplier > 0
            ? displayMultiplier : 1
    }

    public func displayFactor(native: Float) -> Float {
        native * displayMultiplier
    }

    public func nativeFactor(display: Float) -> Float {
        display / displayMultiplier
    }

    public func pinchFactor(nativeStart: Float, magnification: Float) -> Float {
        displayFactor(native: nativeStart) * magnification
    }

    public static func presets(in range: ClosedRange<Float>) -> [Float] {
        let choices: [Float] = [0.5, 1, 2, 3, 5]
        let supported = choices.filter { range.contains($0) }
        return supported.isEmpty ? [range.lowerBound] : supported
    }
}
