import XCTest
@testable import FrameWiseCore

final class CameraSettingsTests: XCTestCase {
    // [AC-CAMSET1014-F2]
    func testAC_CAMSET1014_F2_FlashModesExposeAutoOnAndOff() {
        XCTAssertEqual(
            CameraFlashMode.allCases,
            [.auto, .on, .off]
        )
        XCTAssertEqual(CameraFlashMode.auto.title, "Auto")
        XCTAssertEqual(CameraFlashMode.on.title, "On")
        XCTAssertEqual(CameraFlashMode.off.title, "Off")
    }

    // [AC-CAMSET1014-F3]
    func testAC_CAMSET1014_F3_TimerDurationsExposeOffThreeFiveAndTen() {
        XCTAssertEqual(
            CameraTimerDuration.allCases,
            [.off, .threeSeconds, .fiveSeconds, .tenSeconds]
        )
        XCTAssertEqual(CameraTimerDuration.off.seconds, 0)
        XCTAssertEqual(CameraTimerDuration.threeSeconds.seconds, 3)
        XCTAssertEqual(CameraTimerDuration.fiveSeconds.seconds, 5)
        XCTAssertEqual(CameraTimerDuration.tenSeconds.seconds, 10)
        XCTAssertEqual(CameraTimerDuration.off.title, "Off")
        XCTAssertEqual(CameraTimerDuration.threeSeconds.title, "3s")
        XCTAssertEqual(CameraTimerDuration.fiveSeconds.title, "5s")
        XCTAssertEqual(CameraTimerDuration.tenSeconds.title, "10s")
    }

    // [AC-CAMSET1014-F6]
    func testAC_CAMSET1014_F6_AspectRatiosExposeFourThreeSquareAndSixteenNine() {
        XCTAssertEqual(
            CameraAspectRatio.allCases,
            [.fourByThree, .square, .sixteenByNine]
        )
        XCTAssertEqual(CameraAspectRatio.fourByThree.value, 3.0 / 4.0)
        XCTAssertEqual(CameraAspectRatio.square.value, 1.0)
        XCTAssertEqual(CameraAspectRatio.sixteenByNine.value, 9.0 / 16.0)
    }

    // [AC-CAMSET1014-F8]
    func testAC_CAMSET1014_F8_StylesExposeFiveDefinedLooks() {
        XCTAssertEqual(
            CameraPhotographicStyle.allCases,
            [.standard, .vivid, .warm, .cool, .mono]
        )
        XCTAssertEqual(CameraPhotographicStyle.standard.title, "Standard")
        XCTAssertEqual(CameraPhotographicStyle.vivid.title, "Vivid")
        XCTAssertEqual(CameraPhotographicStyle.warm.title, "Warm")
        XCTAssertEqual(CameraPhotographicStyle.cool.title, "Cool")
        XCTAssertEqual(CameraPhotographicStyle.mono.title, "Mono")
    }

    func testDefaultsUseSafeCameraValues() {
        XCTAssertEqual(CameraSettings.defaults.flashMode, .off)
        XCTAssertEqual(CameraSettings.defaults.timerDuration, .off)
        XCTAssertEqual(CameraSettings.defaults.exposureBias, 0)
        XCTAssertEqual(CameraSettings.defaults.aspectRatio, .fourByThree)
        XCTAssertEqual(CameraSettings.defaults.zoomFactor, 1)
        XCTAssertEqual(CameraSettings.defaults.photographicStyle, .standard)
    }

    // [AC-CAMSET1014-F4]
    func testAC_CAMSET1014_F4_ExposureIsClampedToDeviceRange() {
        let settings = CameraSettings(exposureBias: 4)
        let clamped = settings.clamped(
            exposureRange: CameraExposureRange(minimum: -2, maximum: 2),
            zoomRange: 1...4
        )

        XCTAssertEqual(clamped.exposureBias, 2)
    }

    func testUserExposureRangeCapsWideHardwareRange() {
        let hardware = CameraExposureRange(minimum: -8, maximum: 8)

        XCTAssertEqual(hardware.userVisibleRange, CameraExposureRange(minimum: -2, maximum: 2))
    }

    func testVerticalExposureDragMovesUpPositiveAndDownNegative() {
        let range = CameraExposureRange(minimum: -2, maximum: 2)

        XCTAssertEqual(
            range.verticalBias(startingAt: 0, translation: -40, height: 160),
            0.25,
            accuracy: 0.001
        )
        XCTAssertEqual(
            range.verticalBias(startingAt: 0, translation: 40, height: 160),
            -0.25,
            accuracy: 0.001
        )
        XCTAssertLessThan(
            abs(range.verticalBias(startingAt: 0, translation: 128, height: 128)),
            1
        )
        XCTAssertEqual(range.verticalPosition(for: 1, height: 160), 40, accuracy: 0.001)
        XCTAssertEqual(range.verticalPosition(for: -1, height: 160), 120, accuracy: 0.001)
    }

    // [AC-CAMSET1014-F7]
    func testAC_CAMSET1014_F7_ZoomIsClampedToDeviceRange() {
        let settings = CameraSettings(zoomFactor: 10)
        let clamped = settings.clamped(
            exposureRange: CameraExposureRange(minimum: -2, maximum: 2),
            zoomRange: 1...4
        )

        XCTAssertEqual(clamped.zoomFactor, 4)
    }

    // [AC-CAMSET1014-F5]
    func testAC_CAMSET1014_F5_FocusPointRejectsOutsideNormalizedBounds() {
        XCTAssertNotNil(CameraFocusPoint(x: 0, y: 1))
        XCTAssertNil(CameraFocusPoint(x: -0.01, y: 0.5))
        XCTAssertNil(CameraFocusPoint(x: 0.5, y: 1.01))
        XCTAssertNil(CameraFocusPoint(x: .infinity, y: 0.5))
    }

    func testAspectCropTrimsWidthForWiderSource() {
        let crop = CameraAspectRatio.square.cropRect(
            forWidth: 4000,
            height: 3000
        )

        XCTAssertEqual(crop.x, 0.125, accuracy: 0.000001)
        XCTAssertEqual(crop.y, 0, accuracy: 0.000001)
        XCTAssertEqual(crop.width, 0.75, accuracy: 0.000001)
        XCTAssertEqual(crop.height, 1, accuracy: 0.000001)
    }

    func testPortraitSixteenNineCropsSidesOfPortraitSensor() {
        let crop = CameraAspectRatio.sixteenByNine.cropRect(
            forWidth: 3000,
            height: 4000
        )

        XCTAssertEqual(crop.x, 0.125, accuracy: 0.000001)
        XCTAssertEqual(crop.y, 0, accuracy: 0.000001)
        XCTAssertEqual(crop.width, 0.75, accuracy: 0.000001)
        XCTAssertEqual(crop.height, 1, accuracy: 0.000001)
    }

    func testPortraitFourThreeKeepsWholePortraitSensor() {
        XCTAssertEqual(
            CameraAspectRatio.fourByThree.cropRect(forWidth: 3000, height: 4000),
            CameraCropRect(x: 0, y: 0, width: 1, height: 1)
        )
    }

    func testSquareCropsTopAndBottomOfPortraitSensor() {
        XCTAssertEqual(
            CameraAspectRatio.square.cropRect(forWidth: 3000, height: 4000),
            CameraCropRect(x: 0, y: 0.125, width: 1, height: 0.75)
        )
    }

    func testUltrawideSurvivesNormalizationAndHardwareClamping() {
        XCTAssertEqual(CameraSettings(zoomFactor: 0.5).normalized().zoomFactor, 0.5)
        XCTAssertEqual(CameraSettings(zoomFactor: 0.5).clamped(
            exposureRange: .defaults, zoomRange: 0.5...10
        ).zoomFactor, 0.5)
        XCTAssertEqual(CameraSettings(zoomFactor: 0.5).clamped(
            exposureRange: .defaults, zoomRange: 1...5
        ).zoomFactor, 1)
        XCTAssertEqual(CameraSettings(zoomFactor: -1).normalized().zoomFactor, 1)
    }

    // [AC-CAMSET1014-E1]
    func testAC_CAMSET1014_E1_NonFiniteSettingsNormalizeToSafeValues() {
        let normalized = CameraSettings(
            exposureBias: .nan,
            zoomFactor: .infinity
        ).normalized()

        XCTAssertEqual(normalized.exposureBias, 0)
        XCTAssertEqual(normalized.zoomFactor, 1)
    }

    // [AC-CAMSET1014-F8]
    func testStyleAdjustmentsMatchTheDefinedPresets() {
        XCTAssertEqual(
            CameraPhotographicStyle.standard.adjustments,
            CameraStyleAdjustments(
                saturation: 1,
                contrast: 1,
                brightness: 0,
                redMultiplier: 1,
                greenMultiplier: 1,
                blueMultiplier: 1
            )
        )
        XCTAssertEqual(
            CameraPhotographicStyle.vivid.adjustments,
            CameraStyleAdjustments(
                saturation: 1.25,
                contrast: 1.08,
                brightness: 0,
                redMultiplier: 1,
                greenMultiplier: 1,
                blueMultiplier: 1
            )
        )
        XCTAssertEqual(
            CameraPhotographicStyle.warm.adjustments,
            CameraStyleAdjustments(
                saturation: 1.08,
                contrast: 1,
                brightness: 0.02,
                redMultiplier: 1.06,
                greenMultiplier: 1,
                blueMultiplier: 0.94
            )
        )
        XCTAssertEqual(
            CameraPhotographicStyle.cool.adjustments,
            CameraStyleAdjustments(
                saturation: 1.08,
                contrast: 1,
                brightness: 0,
                redMultiplier: 0.94,
                greenMultiplier: 1,
                blueMultiplier: 1.06
            )
        )
        XCTAssertEqual(
            CameraPhotographicStyle.mono.adjustments,
            CameraStyleAdjustments(
                saturation: 0,
                contrast: 1,
                brightness: 0,
                redMultiplier: 1,
                greenMultiplier: 1,
                blueMultiplier: 1
            )
        )
    }

    func testStyleIntensityBlendsFromStandardToSelectedLook() {
        let standard = CameraPhotographicStyle.standard.adjustments
        let warm = CameraPhotographicStyle.warm.adjustments

        XCTAssertEqual(CameraPhotographicStyle.warm.adjustments(at: 0), standard)
        XCTAssertEqual(CameraPhotographicStyle.warm.adjustments(at: 1), warm)
        XCTAssertEqual(
            CameraPhotographicStyle.warm.adjustments(at: 0.5).brightness,
            0.01,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CameraPhotographicStyle.warm.adjustments(at: 3).blueMultiplier,
            warm.blueMultiplier,
            accuracy: 0.0001
        )
    }

    func testStyleIntensityNormalizesToSafeBounds() {
        XCTAssertEqual(CameraSettings(styleIntensity: .nan).normalized().styleIntensity, 1)
        XCTAssertEqual(CameraSettings(styleIntensity: -1).normalized().styleIntensity, 0)
        XCTAssertEqual(CameraSettings(styleIntensity: 2).normalized().styleIntensity, 1)
    }

    func testSettingsRoundTripThroughCodable() throws {
        let settings = CameraSettings(
            flashMode: .on,
            timerDuration: .fiveSeconds,
            exposureBias: -1.25,
            aspectRatio: .sixteenByNine,
            zoomFactor: 2.5,
            photographicStyle: .warm,
            styleIntensity: 0.65
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    func testOlderSettingsDecodeWithDefaultStyleIntensity() throws {
        let data = #"{"flashMode":"off","timerDuration":0,"exposureBias":0,"aspectRatio":"fourByThree","zoomFactor":1,"photographicStyle":"standard"}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)

        XCTAssertEqual(decoded.styleIntensity, 1)
    }

    func testCaptureSettingsSnapshotDoesNotChangeWhenCurrentSettingsChange() {
        var current = CameraSettings.defaults
        let captureSnapshot = current
        current.exposureBias = 1.5
        current.aspectRatio = .square

        XCTAssertEqual(captureSnapshot, CameraSettings.defaults)
        XCTAssertNotEqual(captureSnapshot, current)
    }

    func testResetSettingsRestoresAllDefaults() {
        var settings = CameraSettings(
            flashMode: .on,
            timerDuration: .tenSeconds,
            exposureBias: -2,
            aspectRatio: .square,
            zoomFactor: 4,
            photographicStyle: .mono
        )

        settings.reset()

        XCTAssertEqual(settings, CameraSettings.defaults)
    }
}
