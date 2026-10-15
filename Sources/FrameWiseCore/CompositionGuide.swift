import Foundation

public enum CameraCompositionGuide: String, CaseIterable, Codable, Equatable, Sendable {
    case off
    case ruleOfThirds
    case centreCross
    case quadrant
    case ruleOfFifths
    case goldenRatio
    case goldenSpiral
    case goldenTriangle
    case diagonalCross
    case horizon

    public var supportsFlipControls: Bool {
        self == .goldenSpiral || self == .goldenTriangle
    }

    public var title: String {
        switch self {
        case .off:
            return "Off"
        case .ruleOfThirds:
            return "Rule of thirds"
        case .centreCross:
            return "Centre cross"
        case .quadrant:
            return "Quadrant grid"
        case .ruleOfFifths:
            return "Rule of fifths"
        case .goldenRatio:
            return "Golden ratio"
        case .goldenSpiral:
            return "Golden spiral"
        case .goldenTriangle:
            return "Golden triangle"
        case .diagonalCross:
            return "Diagonal/X-Frame"
        case .horizon:
            return "Horizon"
        }
    }
}
