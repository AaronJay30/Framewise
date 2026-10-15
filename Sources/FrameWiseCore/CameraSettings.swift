import Foundation

public enum CameraFlashMode: String, CaseIterable, Codable, Sendable {
    case auto
    case on
    case off

    public var next: Self {
        switch self {
        case .off: .auto
        case .auto: .on
        case .on: .off
        }
    }

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

    public var next: Self {
        switch self {
        case .off: .threeSeconds
        case .threeSeconds: .fiveSeconds
        case .fiveSeconds: .tenSeconds
        case .tenSeconds: .off
        }
    }

    public var seconds: TimeInterval {
        TimeInterval(rawValue)
    }

    public var title: String {
        rawValue == 0 ? "Off" : "\(rawValue)s"
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

    public var next: Self {
        switch self {
        case .fourByThree: .square
        case .square: .sixteenByNine
        case .sixteenByNine: .fourByThree
        }
    }

    /// Width divided by height for the portrait camera UI.
    public var value: Double {
        switch self {
        case .fourByThree:
            return 3.0 / 4.0
        case .square:
            return 1
        case .sixteenByNine:
            return 9.0 / 16.0
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

    public func previewSize(fittingWidth width: Double, height: Double) -> (width: Double, height: Double) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return (0, 0) }
        let fittedWidth = min(width, height * value)
        return (fittedWidth, fittedWidth / value)
    }

    public func cropRect(forWidth width: Double, height: Double) -> CameraCropRect {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return CameraCropRect(x: 0, y: 0, width: 1, height: 1)
        }

        // The live camera frame remains portrait, but a landscape source must
        // keep its landscape aspect when the captured image is processed.
        let targetValue = width > height ? 1 / value : value
        let sourceValue = width / height
        if sourceValue > targetValue {
            let cropWidth = targetValue / sourceValue
            return CameraCropRect(
                x: (1 - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: 1
            )
        }

        if sourceValue < targetValue {
            let cropHeight = sourceValue / targetValue
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

    /// Keeps the user-facing control compact even when hardware exposes a wider range.
    public var userVisibleRange: CameraExposureRange {
        let hardware = safeBounds
        let preferred = Self.defaults.safeBounds
        let minimum = max(hardware.minimum, preferred.minimum)
        let maximum = min(hardware.maximum, preferred.maximum)
        guard minimum <= maximum else { return Self.defaults }
        return CameraExposureRange(minimum: minimum, maximum: maximum)
    }

    /// One EV per 80 points, without quantizing continuous drags.
    public func bias(startingAt start: Float, translation: Double) -> Float {
        let origin = start.isFinite ? start : 0
        let delta = translation.isFinite ? Float(translation / 80) : 0
        let bounds = safeBounds
        return min(max(origin + delta, bounds.minimum), bounds.maximum)
    }

    /// Fixed scale: negative values on the left, positive values on the right.
    public func rulerBias(startingAt start: Float, translation: Double, width: Double) -> Float {
        guard width.isFinite, width > 0 else { return bias(startingAt: start, translation: 0) }
        let bounds = safeBounds
        let equivalentTranslation = translation / width * Double(bounds.maximum - bounds.minimum) * 80
        return bias(startingAt: start, translation: equivalentTranslation)
    }

    /// Maps vertical dragging to exposure: up increases EV, down decreases EV.
    public func verticalBias(startingAt start: Float, translation: Double, height: Double) -> Float {
        let safeHeight = height.isFinite && height > 0 ? height : 160
        let pointsPerEV = max(safeHeight, 160)
        let scaledTranslation = translation.isFinite
            ? translation * 80 / pointsPerEV
            : 0
        return bias(startingAt: start, translation: -scaledTranslation)
    }

    public func rulerPosition(for bias: Float, width: Double) -> Double {
        guard width.isFinite, width > 0 else { return 0 }
        let bounds = safeBounds
        guard bounds.maximum > bounds.minimum else { return width / 2 }
        let value = min(max(bias.isFinite ? bias : 0, bounds.minimum), bounds.maximum)
        return Double((value - bounds.minimum) / (bounds.maximum - bounds.minimum)) * width
    }

    public func verticalPosition(for bias: Float, height: Double) -> Double {
        guard height.isFinite, height > 0 else { return 0 }
        return height - rulerPosition(for: bias, width: height)
    }

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

    public var isIdentity: Bool {
        saturation == 1 && contrast == 1 && brightness == 0
            && redMultiplier == 1 && greenMultiplier == 1 && blueMultiplier == 1
    }

    public func blended(with target: CameraStyleAdjustments, amount: Double) -> CameraStyleAdjustments {
        let value = min(max(amount.isFinite ? amount : 0, 0), 1)
        func mix(_ start: Double, _ end: Double) -> Double {
            start + (end - start) * value
        }

        return CameraStyleAdjustments(
            saturation: mix(saturation, target.saturation),
            contrast: mix(contrast, target.contrast),
            brightness: mix(brightness, target.brightness),
            redMultiplier: mix(redMultiplier, target.redMultiplier),
            greenMultiplier: mix(greenMultiplier, target.greenMultiplier),
            blueMultiplier: mix(blueMultiplier, target.blueMultiplier)
        )
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

    public func adjustments(at intensity: Double) -> CameraStyleAdjustments {
        CameraPhotographicStyle.standard.adjustments.blended(
            with: adjustments,
            amount: intensity
        )
    }
}

public struct CameraSettings: Equatable, Codable, Sendable {
    public var flashMode: CameraFlashMode
    public var timerDuration: CameraTimerDuration
    public var exposureBias: Float
    public var aspectRatio: CameraAspectRatio
    public var zoomFactor: Float
    public var photographicStyle: CameraPhotographicStyle
    public var styleIntensity: Float
    public var compositionGuide: CameraCompositionGuide
    public var compositionGuideOpacity: Float
    public var compositionGuideFlipHorizontal: Bool
    public var compositionGuideFlipVertical: Bool
    public var photoResolution: CameraPhotoResolution

    public init(
        flashMode: CameraFlashMode = .off,
        timerDuration: CameraTimerDuration = .off,
        exposureBias: Float = 0,
        aspectRatio: CameraAspectRatio = .fourByThree,
        zoomFactor: Float = 1,
        photographicStyle: CameraPhotographicStyle = .standard,
        styleIntensity: Float = 1,
        compositionGuide: CameraCompositionGuide = .off,
        compositionGuideOpacity: Float = 0.60,
        compositionGuideFlipHorizontal: Bool = false,
        compositionGuideFlipVertical: Bool = false,
        photoResolution: CameraPhotoResolution = .standard
    ) {
        self.flashMode = flashMode
        self.timerDuration = timerDuration
        self.exposureBias = exposureBias
        self.aspectRatio = aspectRatio
        self.zoomFactor = zoomFactor
        self.photographicStyle = photographicStyle
        self.styleIntensity = styleIntensity
        self.compositionGuide = compositionGuide
        self.compositionGuideOpacity = compositionGuideOpacity
        self.compositionGuideFlipHorizontal = compositionGuideFlipHorizontal
        self.compositionGuideFlipVertical = compositionGuideFlipVertical
        self.photoResolution = photoResolution
    }

    public static let defaults = CameraSettings()

    private enum CodingKeys: String, CodingKey {
        case flashMode
        case timerDuration
        case exposureBias
        case aspectRatio
        case zoomFactor
        case photographicStyle
        case styleIntensity
        case compositionGuide
        case compositionGuideOpacity
        case compositionGuideFlipHorizontal
        case compositionGuideFlipVertical
        case photoResolution
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.flashMode = try values.decode(CameraFlashMode.self, forKey: .flashMode)
        self.timerDuration = try values.decode(CameraTimerDuration.self, forKey: .timerDuration)
        self.exposureBias = try values.decode(Float.self, forKey: .exposureBias)
        self.aspectRatio = try values.decode(CameraAspectRatio.self, forKey: .aspectRatio)
        self.zoomFactor = try values.decode(Float.self, forKey: .zoomFactor)
        self.photographicStyle = try values.decode(CameraPhotographicStyle.self, forKey: .photographicStyle)
        self.styleIntensity = try values.decodeIfPresent(Float.self, forKey: .styleIntensity) ?? 1
        self.compositionGuide = try values.decodeIfPresent(CameraCompositionGuide.self, forKey: .compositionGuide) ?? .off
        self.compositionGuideOpacity = try values.decodeIfPresent(Float.self, forKey: .compositionGuideOpacity) ?? 0.60
        self.compositionGuideFlipHorizontal = try values.decodeIfPresent(Bool.self, forKey: .compositionGuideFlipHorizontal) ?? false
        self.compositionGuideFlipVertical = try values.decodeIfPresent(Bool.self, forKey: .compositionGuideFlipVertical) ?? false
        self.photoResolution = try values.decodeIfPresent(CameraPhotoResolution.self, forKey: .photoResolution) ?? .standard
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(flashMode, forKey: .flashMode)
        try values.encode(timerDuration, forKey: .timerDuration)
        try values.encode(exposureBias, forKey: .exposureBias)
        try values.encode(aspectRatio, forKey: .aspectRatio)
        try values.encode(zoomFactor, forKey: .zoomFactor)
        try values.encode(photographicStyle, forKey: .photographicStyle)
        try values.encode(styleIntensity, forKey: .styleIntensity)
        try values.encode(compositionGuide, forKey: .compositionGuide)
        try values.encode(compositionGuideOpacity, forKey: .compositionGuideOpacity)
        try values.encode(compositionGuideFlipHorizontal, forKey: .compositionGuideFlipHorizontal)
        try values.encode(compositionGuideFlipVertical, forKey: .compositionGuideFlipVertical)
        try values.encode(photoResolution, forKey: .photoResolution)
    }

    /// Flash is set per capture; aspect, timer, and style don't reconfigure the sensor.
    public func hardwareChanges(from previous: CameraSettings?) -> (exposure: Bool, zoom: Bool) {
        (previous?.exposureBias != exposureBias, previous?.zoomFactor != zoomFactor)
    }

    public func normalized() -> CameraSettings {
        var normalized = self
        normalized.exposureBias = exposureBias.isFinite ? exposureBias : 0
        normalized.zoomFactor = zoomFactor.isFinite && zoomFactor > 0 ? zoomFactor : 1
        normalized.styleIntensity = styleIntensity.isFinite
            ? min(max(styleIntensity, 0), 1)
            : 1
        normalized.compositionGuideOpacity = compositionGuideOpacity.isFinite
            ? min(max(compositionGuideOpacity, 0.20), 1.00)
            : 0.60
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
