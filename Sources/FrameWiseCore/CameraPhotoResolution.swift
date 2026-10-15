import Foundation

public enum CameraPhotoResolution: String, CaseIterable, Codable, Sendable {
    case standard
    case maximum

    public var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .maximum:
            return "Maximum"
        }
    }
}

public struct CameraPhotoDimensions: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var pixelCount: Int64 {
        Int64(width) * Int64(height)
    }

    public var megapixels: Int {
        Int((Double(pixelCount) / 1_000_000).rounded())
    }
}

public struct CameraPhotoResolutionCapability: Equatable, Sendable {
    public let standard: CameraPhotoDimensions?
    public let maximum: CameraPhotoDimensions?

    public init(supportedDimensions: [CameraPhotoDimensions]) {
        var uniqueByPixelCount: [Int64: CameraPhotoDimensions] = [:]
        for dimension in supportedDimensions where uniqueByPixelCount[dimension.pixelCount] == nil {
            uniqueByPixelCount[dimension.pixelCount] = dimension
        }

        let dimensions = uniqueByPixelCount.values.sorted { lhs, rhs in
            lhs.pixelCount < rhs.pixelCount
        }
        standard = dimensions.first
        maximum = dimensions.count > 1 ? dimensions.last : nil
    }

    public var supportsMaximum: Bool {
        maximum != nil
    }

    public var maximumTitle: String? {
        maximum.map { "Maximum (\($0.megapixels) MP)" }
    }
}
