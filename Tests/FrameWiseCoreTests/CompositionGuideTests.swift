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
                "Diagonal/X-Frame",
                "Horizon",
            ]
        )
    }

    func testOnlyAsymmetricGuidesOfferFlipControls() {
        XCTAssertTrue(CameraCompositionGuide.goldenSpiral.supportsFlipControls)
        XCTAssertTrue(CameraCompositionGuide.goldenTriangle.supportsFlipControls)
        XCTAssertFalse(CameraCompositionGuide.ruleOfThirds.supportsFlipControls)
        XCTAssertFalse(CameraCompositionGuide.goldenRatio.supportsFlipControls)
        XCTAssertFalse(CameraCompositionGuide.diagonalCross.supportsFlipControls)
    }

    // [AC-COMP1015-F7]
    func testAC_COMP1015_F7_CompositionSettingsRoundTripThroughCodable() throws {
        let settings = CameraSettings(
            compositionGuide: .goldenSpiral,
            compositionGuideOpacity: 0.35,
            compositionGuideFlipHorizontal: true,
            compositionGuideFlipVertical: true
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
        XCTAssertFalse(decoded.compositionGuideFlipHorizontal)
        XCTAssertFalse(decoded.compositionGuideFlipVertical)
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

    // [AC-CAMLIB1015-F1]
    func testAC_CAMLIB1015_F1_GoldenSpiralProvidesAStableContinuousSample() {
        let points = CameraGoldenSpiralGeometry.points(sampleCount: 160)

        XCTAssertEqual(points.count, 160)
        XCTAssertEqual(
            CameraGoldenSpiralGeometry.points(sampleCount: 160).count,
            points.count
        )
        XCTAssertTrue(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }

    // [AC-CAMLIB1015-F2]
    func testAC_CAMLIB1015_F2_GoldenSpiralRemainsNormalizedAndContinuous() {
        let points = CameraGoldenSpiralGeometry.points(sampleCount: 160)
        XCTAssertTrue(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })

        for pair in zip(points, points.dropFirst()) {
            XCTAssertLessThan(
                hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y),
                0.20
            )
        }
    }

    func testGoldenSpiralDefaultSamplingKeepsTheRenderedCurveSmooth() {
        let width = 390.0
        let height = 844.0
        let points = CameraGoldenSpiralGeometry.points(width: width, height: height)
        let longestSegment = zip(points, points.dropFirst())
            .map {
                hypot(
                    ($0.0.x - $0.1.x) * width,
                    ($0.0.y - $0.1.y) * height
                )
            }
            .max() ?? .infinity

        XCTAssertGreaterThan(points.count, 500)
        XCTAssertLessThan(longestSegment, 5)
    }

    // [AC-CAMUX1015-F4]
    func testAC_CAMUX1015_F4_SizeAwareSpiralPreservesItsAspect() {
        let rectangle = try! XCTUnwrap(
            CameraGoldenSpiralGeometry.goldenRectangle(width: 390, height: 844)
        )
        XCTAssertEqual(
            max(rectangle.width, rectangle.height) / min(rectangle.width, rectangle.height),
            CameraGoldenSpiralGeometry.phi,
            accuracy: 0.02
        )

        let points = CameraGoldenSpiralGeometry.points(width: 390, height: 844)
        XCTAssertTrue(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }

    // [AC-CAMUX1015-E3]
    func testAC_CAMUX1015_E3_SizeAwareSpiralRejectsInvalidInputs() {
        XCTAssertTrue(CameraGoldenSpiralGeometry.points(width: .nan, height: 844).isEmpty)
        XCTAssertTrue(CameraGoldenSpiralGeometry.points(width: 390, height: 0).isEmpty)
        XCTAssertTrue(CameraGoldenSpiralGeometry.points(width: 390, height: 844, sampleCount: 0).isEmpty)
    }

    // [AC-GOLDSPIRAL1015-F1]
    func testAC_GOLDSPIRAL1015_F1_UsesAConstructionBasedGoldenRectangle() throws {
        let width = 390.0
        let height = 844.0
        let rectangle = try XCTUnwrap(
            CameraGoldenSpiralGeometry.goldenRectangle(width: width, height: height)
        )
        let phi = (1 + sqrt(5.0)) / 2

        XCTAssertEqual(
            max(rectangle.width, rectangle.height) / min(rectangle.width, rectangle.height),
            phi,
            accuracy: 0.000001
        )
        XCTAssertGreaterThanOrEqual(rectangle.x, 0)
        XCTAssertGreaterThanOrEqual(rectangle.y, 0)
        XCTAssertLessThanOrEqual(rectangle.x + rectangle.width, width)
        XCTAssertLessThanOrEqual(rectangle.y + rectangle.height, height)

        let points = CameraGoldenSpiralGeometry.points(
            width: width,
            height: height,
            sampleCount: 160
        )
        XCTAssertEqual(points.count, 160)
        XCTAssertTrue(points.allSatisfy { point in
            let x = point.x * width
            let y = point.y * height
            return x >= rectangle.x - 0.000001
                && x <= rectangle.x + rectangle.width + 0.000001
                && y >= rectangle.y - 0.000001
                && y <= rectangle.y + rectangle.height + 0.000001
        })
    }

    // [AC-GOLDSPIRAL1015-E1]
    func testAC_GOLDSPIRAL1015_E1_RejectsInvalidRectangleInputs() {
        XCTAssertNil(CameraGoldenSpiralGeometry.goldenRectangle(width: .nan, height: 844))
        XCTAssertNil(CameraGoldenSpiralGeometry.goldenRectangle(width: 390, height: .infinity))
        XCTAssertTrue(CameraGoldenSpiralGeometry.points(width: 390, height: 844, sampleCount: 0).isEmpty)
    }
}
