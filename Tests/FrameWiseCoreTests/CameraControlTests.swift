import XCTest
@testable import FrameWiseCore

final class CameraControlTests: XCTestCase {
    func testTopControlsCycleAndWrap() {
        XCTAssertEqual(CameraFlashMode.off.next, .auto)
        XCTAssertEqual(CameraFlashMode.auto.next, .on)
        XCTAssertEqual(CameraFlashMode.on.next, .off)
        XCTAssertEqual(CameraTimerDuration.off.next, .threeSeconds)
        XCTAssertEqual(CameraTimerDuration.threeSeconds.next, .fiveSeconds)
        XCTAssertEqual(CameraTimerDuration.fiveSeconds.next, .tenSeconds)
        XCTAssertEqual(CameraTimerDuration.tenSeconds.next, .off)
        XCTAssertEqual(CameraAspectRatio.fourByThree.next, .square)
        XCTAssertEqual(CameraAspectRatio.square.next, .sixteenByNine)
        XCTAssertEqual(CameraAspectRatio.sixteenByNine.next, .fourByThree)
    }

    func testExposureDragMovesRightPositiveAndLeftNegative() {
        let range = CameraExposureRange(minimum: -2, maximum: 2)
        XCTAssertEqual(range.bias(startingAt: 0, translation: 80), 1)
        XCTAssertEqual(range.bias(startingAt: 0, translation: -80), -1)
        XCTAssertEqual(range.bias(startingAt: 0.5, translation: 24), 0.8, accuracy: 0.001)
        XCTAssertEqual(range.bias(startingAt: 1, translation: 1000), 2)
        XCTAssertEqual(range.bias(startingAt: -1, translation: -1000), -2)
        XCTAssertEqual(range.bias(startingAt: .nan, translation: .infinity), 0)
        XCTAssertEqual(CameraExposureRange(minimum: 0, maximum: 0)
            .bias(startingAt: 0, translation: 80), 0)
    }

    func testExposureMovesContinuouslyBetweenTenthStops() {
        XCTAssertEqual(CameraExposureRange.defaults.bias(startingAt: 0, translation: 4), 0.05,
                       accuracy: 0.0001)
    }

    func testPreviewResizesForEachAspectInsteadOfStayingFourThree() {
        let normal = CameraAspectRatio.fourByThree.previewSize(fittingWidth: 390, height: 800)
        let square = CameraAspectRatio.square.previewSize(fittingWidth: 390, height: 800)
        let tall = CameraAspectRatio.sixteenByNine.previewSize(fittingWidth: 390, height: 800)
        XCTAssertEqual(normal.width, 390)
        XCTAssertEqual(normal.height, 520)
        XCTAssertEqual(square.width, 390)
        XCTAssertEqual(square.height, 390)
        XCTAssertEqual(tall.width, 390)
        XCTAssertEqual(tall.height, 693.333333, accuracy: 0.0001)
        let compact = CameraAspectRatio.sixteenByNine.previewSize(fittingWidth: 390, height: 600)
        XCTAssertEqual(compact.width, 337.5)
        XCTAssertEqual(compact.height, 600)
        XCTAssertEqual(CameraAspectRatio.square.previewSize(fittingWidth: .nan, height: 600).width, 0)
    }

    // [AC-CAMUX1015-F1]
    func testAC_CAMUX1015_F1_LandscapeSixteenByNineUsesLandscapeCrop() {
        let crop = CameraAspectRatio.sixteenByNine.cropRect(
            forWidth: 4000,
            height: 3000
        )

        XCTAssertEqual(crop.x, 0, accuracy: 0.0001)
        XCTAssertEqual(crop.y, 0.125, accuracy: 0.0001)
        XCTAssertEqual(crop.width, 1, accuracy: 0.0001)
        XCTAssertEqual(crop.height, 0.75, accuracy: 0.0001)
    }

    // [AC-CAMUX1015-F2]
    func testAC_CAMUX1015_F2_PortraitSquareAndInvalidCropInputsStaySafe() {
        let portrait = CameraAspectRatio.sixteenByNine.cropRect(
            forWidth: 2250,
            height: 4000
        )
        XCTAssertEqual(portrait, CameraCropRect(x: 0, y: 0, width: 1, height: 1))

        let square = CameraAspectRatio.square.cropRect(forWidth: 3000, height: 3000)
        XCTAssertEqual(square, CameraCropRect(x: 0, y: 0, width: 1, height: 1))

        let invalid = CameraAspectRatio.sixteenByNine.cropRect(forWidth: .nan, height: 3000)
        XCTAssertEqual(invalid, CameraCropRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testExposureIndicatorMovesInTheSameDirectionAsTheDrag() {
        let range = CameraExposureRange.defaults
        let left = range.bias(startingAt: 0, translation: -80)
        let right = range.bias(startingAt: 0, translation: 80)
        XCTAssertEqual(range.rulerPosition(for: left, width: 320), 80)
        XCTAssertEqual(range.rulerPosition(for: 0, width: 320), 160)
        XCTAssertEqual(range.rulerPosition(for: right, width: 320), 240)
        XCTAssertEqual(range.rulerPosition(for: -99, width: 320), 0)
        XCTAssertEqual(range.rulerPosition(for: 99, width: 320), 320)
        XCTAssertEqual(CameraExposureRange(minimum: 0, maximum: 0)
            .rulerPosition(for: 0, width: 320), 160)
    }

    func testExposureDragTracksFingerDistanceOnDifferentRulerWidths() {
        let range = CameraExposureRange.defaults
        XCTAssertEqual(range.rulerBias(startingAt: 0, translation: -40, width: 160), -1)
        XCTAssertEqual(range.rulerBias(startingAt: 0, translation: 80, width: 320), 1)
        XCTAssertEqual(range.rulerBias(startingAt: 1, translation: 1000, width: 320), 2)
        XCTAssertEqual(range.rulerBias(startingAt: 1, translation: 80, width: 0), 1)
    }

    func testOnlyChangedHardwareSettingsRequireCameraWrites() {
        let previous = CameraSettings.defaults
        let unchanged = previous.hardwareChanges(from: previous)
        XCTAssertFalse(unchanged.exposure)
        XCTAssertFalse(unchanged.zoom)
        var appearance = previous
        appearance.aspectRatio = .square
        appearance.photographicStyle = .mono
        appearance.timerDuration = .tenSeconds
        appearance.flashMode = .on
        XCTAssertFalse(appearance.hardwareChanges(from: previous).exposure)
        XCTAssertFalse(appearance.hardwareChanges(from: previous).zoom)
        var zoom = previous
        zoom.zoomFactor = 2
        XCTAssertTrue(zoom.hardwareChanges(from: previous).zoom)
        XCTAssertFalse(zoom.hardwareChanges(from: previous).exposure)
        var exposure = previous
        exposure.exposureBias = 1
        XCTAssertTrue(exposure.hardwareChanges(from: previous).exposure)
        XCTAssertFalse(exposure.hardwareChanges(from: previous).zoom)
        XCTAssertTrue(previous.hardwareChanges(from: nil).zoom)
        XCTAssertTrue(previous.hardwareChanges(from: nil).exposure)
    }

    func testZoomConvertsBetweenDisplayAndNativeDeviceScale() {
        let ultrawide = CameraZoomScale(displayMultiplier: 0.5)
        XCTAssertEqual(ultrawide.displayFactor(native: 1), 0.5)
        XCTAssertEqual(ultrawide.nativeFactor(display: 1), 2)
        XCTAssertEqual(ultrawide.nativeFactor(display: 2), 4)
        XCTAssertEqual(CameraZoomScale(displayMultiplier: 1).nativeFactor(display: 2), 2)
        XCTAssertEqual(CameraZoomScale(displayMultiplier: .nan).nativeFactor(display: 1), 1)
        XCTAssertEqual(CameraZoomScale(displayMultiplier: 0).nativeFactor(display: 1), 1)
    }

    func testZoomPresetsOnlyContainSupportedFactors() {
        XCTAssertEqual(CameraZoomScale.presets(in: 0.5...10), [0.5, 1, 2, 3, 5])
        XCTAssertEqual(CameraZoomScale.presets(in: 1...4), [1, 2, 3])
        XCTAssertEqual(CameraZoomScale.presets(in: 1...1), [1])
        XCTAssertEqual(CameraZoomScale.presets(in: 1.2...1.8), [1.2])
    }

    func testPinchStartsFromActualNativeZoomDuringPresetRamp() {
        let scale = CameraZoomScale(displayMultiplier: 0.5)
        // A 5x preset is still approaching its target: hardware is currently 2x native.
        XCTAssertEqual(scale.pinchFactor(nativeStart: 2, magnification: 0.9), 0.9,
                       accuracy: 0.0001)
        XCTAssertEqual(scale.pinchFactor(nativeStart: 2, magnification: 1.2), 1.2,
                       accuracy: 0.0001)
    }
}
