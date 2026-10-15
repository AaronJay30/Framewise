import XCTest
@testable import FrameWiseCore

final class CompositionGuideTests: XCTestCase {
    // [AC-COMP1015-F3]
    func testAC_COMP1015_F3_CompositionGuidesExposeApprovedCatalog() {
        XCTAssertEqual(
            CameraCompositionGuide.allCases,
            [
                .off,
                .ruleOfThirds,
                .centreCross,
                .quadrant,
                .ruleOfFifths,
                .goldenRatio,
                .goldenSpiral,
                .goldenTriangle,
                .diagonalCross,
                .horizon,
            ]
        )
        XCTAssertEqual(
            CameraCompositionGuide.allCases.map(\.title),
            [
                "Off",
                "Rule of thirds",
                "Centre cross",
                "Quadrant grid",
                "Rule of fifths",
                "Golden ratio",
                "Golden spiral",
                "Golden triangle",
                "Diagonal cross",
                "Horizon",
            ]
        )
    }

    // [AC-COMP1015-F7]
    func testAC_COMP1015_F7_CompositionSettingsRoundTripThroughCodable() throws {
        let settings = CameraSettings(
            compositionGuide: .goldenSpiral,
            compositionGuideOpacity: 0.35
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    // [AC-COMP1015-E1]
    func testAC_COMP1015_E1_OlderSettingsDecodeWithCompositionDefaults() throws {
        let data = #"{"flashMode":"on","timerDuration":5,"exposureBias":-1.25,"aspectRatio":"square","zoomFactor":2,"photographicStyle":"warm","styleIntensity":0.7}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)

        XCTAssertEqual(decoded.flashMode, .on)
        XCTAssertEqual(decoded.timerDuration, .fiveSeconds)
        XCTAssertEqual(decoded.exposureBias, -1.25)
        XCTAssertEqual(decoded.aspectRatio, .square)
        XCTAssertEqual(decoded.zoomFactor, 2)
        XCTAssertEqual(decoded.photographicStyle, .warm)
        XCTAssertEqual(decoded.styleIntensity, 0.7)
        XCTAssertEqual(decoded.compositionGuide, .off)
        XCTAssertEqual(decoded.compositionGuideOpacity, 0.60)
    }

    // [AC-COMP1015-E2]
    func testAC_COMP1015_E2_CompositionOpacityNormalizesToSafeBounds() {
        XCTAssertEqual(
            CameraSettings(compositionGuideOpacity: .nan).normalized().compositionGuideOpacity,
            0.60
        )
        XCTAssertEqual(
            CameraSettings(compositionGuideOpacity: 0).normalized().compositionGuideOpacity,
            0.20
        )
        XCTAssertEqual(
            CameraSettings(compositionGuideOpacity: 2).normalized().compositionGuideOpacity,
            1.00
        )
    }

    // [AC-COMP1015-F8]
    func testAC_COMP1015_F8_ResetRestoresCompositionDefaults() {
        var settings = CameraSettings(
            flashMode: .on,
            aspectRatio: .square,
            photographicStyle: .mono,
            compositionGuide: .diagonalCross,
            compositionGuideOpacity: 0.25
        )

        settings.reset()

        XCTAssertEqual(settings, CameraSettings.defaults)
        XCTAssertEqual(settings.compositionGuide, .off)
        XCTAssertEqual(settings.compositionGuideOpacity, 0.60)
    }

    func testDefaultsUseSafeCompositionValues() {
        XCTAssertEqual(CameraSettings.defaults.compositionGuide, .off)
        XCTAssertEqual(CameraSettings.defaults.compositionGuideOpacity, 0.60)
    }
}
