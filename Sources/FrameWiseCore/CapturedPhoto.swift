import Foundation

/// A photo captured by FrameWise and kept in the app's private library.
public struct CapturedPhoto: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let data: Data
    public let capturedAt: Date
    public var isExported: Bool

    public init?(id: UUID, data: Data, capturedAt: Date, isExported: Bool) {
        guard !data.isEmpty else { return nil }

        self.id = id
        self.data = data
        self.capturedAt = capturedAt
        self.isExported = isExported
    }
}
