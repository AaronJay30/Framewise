import Foundation

public enum CameraFlashMode: String, CaseIterable, Codable, Sendable {
    case auto
    case on
    case off

    public var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .on:
            return "On"
        case .off:
            return "Off"
        }
    }
}

public enum CameraTimerDuration: Int, CaseIterable, Codable, Sendable {
    case off = 0
    case threeSeconds = 3
    case fiveSeconds = 5
    case tenSeconds = 10

    public var seconds: TimeInterval {
        TimeInterval(rawValue)
    }

    public var title: String {
        rawValue == 0 ? "Off" : "(rawValue)s"
    }
}

public struct CameraCropRect: Equatable, Codable, Sendable {
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

public enum CameraAspectRatio: String, CaseIterable, Codable, Sendable {
    case fourByThree
    case square
    case sixteenByNine

    public var value: Double {
        switch self {
        case .fourByThree:
            return 4.0 / 3.0
        case .square:
            return 1
        case .sixteenByNine:
            return 16.0 / 9.0
        }
    }

    public var title: String {
        switch self {
        case .fourByThree:
            return "4:3"
        case .square:
            return "1:1"
        case .sixteenByNine:
            return "16:9"
        }
    }

    public func cropRect(forWidth width: Double, height: Double) -> CameraCropRect {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return CameraCropRect(x: 0, y: 0, width: 1, height: 1)
        }

        let sourceValue = width / height
        if sourceValue > value {
            let cropWidth = value / sourceValue
            return CameraCropRect(
                x: (1 - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: 1
            )
        }

        if sourceValue < value {
            let cropHeight = sourceValue / value
            return CameraCropRect(
                x: 0,
                y: (1 - cropHeight) / 2,
                width: 1,
                height: cropHeight
            )
        }

        return CameraCropRect(x: 0, y: 0, width: 1, height: 1)
    }
}

public struct CameraExposureRange: Equatable, Codable, Sendable {
    public let minimum: Float
    public let maximum: Float

    public init(minimum: Float, maximum: Float) {
        self.minimum = minimum
        self.maximum = maximum
    }

    public static let defaults = CameraExposureRange(minimum: Float(-2), maximum: Float(2))

    var safeBounds: (minimum: Float, maximum: Float) {
        guard minimum.isFinite, maximum.isFinite, minimum <= maximum else {
            return (Self.defaults.minimum, Self.defaults.maximum)
        }

        return (minimum, maximum)
    }
}

public struct CameraFocusPoint: Equatable, Codable, Sendable {
    public let x: Double
    public let y: Double

    public init?(x: Double, y: Double) {
        guard x.isFinite, y.isFinite, (0...1).contains(x), (0...1).contains(y) else {
            return nil
        }

        self.x = x
        self.y = y
    }
}

public struct CameraStyleAdjustments: Equatable, Codable, Sendable {
    public let saturation: Double
    public let contrast: Double
    public let brightness: Double
    public let redMultiplier: Double
    public let greenMultiplier: Double
    public let blueMultiplier: Double

    public init(
        saturation: Double,
        contrast: Double,
        brightness: Double,
        redMultiplier: Double,
        greenMultiplier: Double,
        blueMultiplier: Double
    ) {
        self.saturation = saturation
        self.contrast = contrast
        self.brightness = brightness
        self.redMultiplier = redMultiplier
        self.greenMultiplier = greenMultiplier
        self.blueMultiplier = blueMultiplier
    }
}

public enum CameraPhotographicStyle: String, CaseIterable, Codable, Sendable {
    case standard
    case vivid
    case warm
    case cool
    case mono

    public var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .vivid:
            return "Vivid"
        case .warm:
            return "Warm"
        case .cool:
            return "Cool"
        case .mono:
            return "Mono"
        }
    }

    public var adjustments: CameraStyleAdjustments {
        switch self {
        case .standard:
            return CameraStyleAdjustments(
                saturation: 1,
                contrast: 1,
                brightness: 0,
                redMultiplier: 1,
                greenMultiplier: 1,
                blueMultiplier: 1
            )
        case .vivid:
            return CameraStyleAdjustments(
                saturation: 1.25,
                contrast: 1.08,
                brightness: 0,
                redMultiplier: 1,
                greenMultiplier: 1,
                blueMultiplier: 1
            )
        case .warm:
            return CameraStyleAdjustments(
                saturation: 1.08,
                contrast: 1,
                brightness: 0.02,
                redMultiplier: 1.06,
                greenMultiplier: 1,
                blueMultiplier: 0.94
            )
        case .cool:
            return CameraStyleAdjustments(
                saturation: 1.08,
                contrast: 1,
                brightness: 0,
                redMultiplier: 0.94,
                greenMultiplier: 1,
                blueMultiplier: 1.06
            )
        case .mono:
            return CameraStyleAdjustments(
                saturation: 0,
                contrast: 1,
                brightness: 0,
                redMultiplier: 1,
                greenMultiplier: 1,
                blueMultiplier: 1
            )
        }
    }
}

public struct CameraSettings: Equatable, Codable, Sendable {
    public var flashMode: CameraFlashMode
    public var timerDuration: CameraTimerDuration
    public var exposureBias: Float
    public var aspectRatio: CameraAspectRatio
    public var zoomFactor: Float
    public var photographicStyle: CameraPhotographicStyle

    public init(
        flashMode: CameraFlashMode = .auto,
        timerDuration: CameraTimerDuration = .off,
        exposureBias: Float = 0,
        aspectRatio: CameraAspectRatio = .fourByThree,
        zoomFactor: Float = 1,
        photographicStyle: CameraPhotographicStyle = .standard
    ) {
        self.flashMode = flashMode
        self.timerDuration = timerDuration
        self.exposureBias = exposureBias
        self.aspectRatio = aspectRatio
        self.zoomFactor = zoomFactor
        self.photographicStyle = photographicStyle
    }

    public static let defaults = CameraSettings()

    public func normalized() -> CameraSettings {
        var normalized = self
        normalized.exposureBias = exposureBias.isFinite ? exposureBias : 0
        normalized.zoomFactor = zoomFactor.isFinite ? max(1, zoomFactor) : 1
        return normalized
    }

    public func clamped(
        exposureRange: CameraExposureRange,
        zoomRange: ClosedRange<Float>
    ) -> CameraSettings {
        var clamped = normalized()
        let exposureBounds = exposureRange.safeBounds
        let safeZoomRange = zoomRange.lowerBound.isFinite && zoomRange.upperBound.isFinite &&
            zoomRange.lowerBound <= zoomRange.upperBound
            ? zoomRange
            : 1...1

        clamped.exposureBias = min(
            max(clamped.exposureBias, exposureBounds.minimum),
            exposureBounds.maximum
        )
        clamped.zoomFactor = min(
            max(clamped.zoomFactor, safeZoomRange.lowerBound),
            safeZoomRange.upperBound
        )
        return clamped
    }

    public mutating func reset() {
        self = .defaults
    }
}
