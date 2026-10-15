import XCTest
@testable import FrameWiseCore

final class CameraPhotoResolutionTests: XCTestCase {
    // [AC-CAMLIB1015-F5]
    func testAC_CAMLIB1015_F5_ResolutionCasesExposeStableTitlesAndRoundTrip() throws {
        XCTAssertEqual(CameraPhotoResolution.allCases, [.standard, .maximum])
        XCTAssertEqual(CameraPhotoResolution.standard.title, "Standard")
        XCTAssertEqual(CameraPhotoResolution.maximum.title, "Maximum")

        let data = try JSONEncoder().encode(CameraPhotoResolution.maximum)
        XCTAssertEqual(
            try JSONDecoder().decode(CameraPhotoResolution.self, from: data),
            .maximum
        )
        XCTAssertEqual(CameraSettings.defaults.photoResolution, .standard)

        var settings = CameraSettings(photoResolution: .maximum)
        settings.reset()
        XCTAssertEqual(settings.photoResolution, .standard)
    }

    // [AC-CAMLIB1015-F6]
    func testAC_CAMLIB1015_F6_DimensionsRoundMegapixelsAndSelectUniqueExtremes() {
        let standard = CameraPhotoDimensions(width: 4000, height: 3000)
        let maximum = CameraPhotoDimensions(width: 8064, height: 6048)
        let capability = CameraPhotoResolutionCapability(
            supportedDimensions: [
                maximum,
                standard,
                standard,
                CameraPhotoDimensions(width: 4032, height: 3024),
            ]
        )

        XCTAssertEqual(standard.pixelCount, 12_000_000)
        XCTAssertEqual(standard.megapixels, 12)
        XCTAssertEqual(capability.standard, standard)
        XCTAssertEqual(capability.maximum, maximum)
        XCTAssertTrue(capability.supportsMaximum)
        XCTAssertEqual(capability.maximumTitle, "Maximum (49 MP)")
    }

    // [AC-CAMLIB1015-F7]
    func testAC_CAMLIB1015_F7_StandardAndMaximumUseTheSupportedExtremes() {
        let small = CameraPhotoDimensions(width: 1920, height: 1080)
        let large = CameraPhotoDimensions(width: 7680, height: 4320)
        let capability = CameraPhotoResolutionCapability(
            supportedDimensions: [large, small]
        )

        XCTAssertEqual(capability.standard, small)
        XCTAssertEqual(capability.maximum, large)
    }

    // [AC-CAMLIB1015-F7]
    func testAC_CAMLIB1015_F7_MaximumIsUnavailableWithoutDistinctDimensions() {
        let supported = CameraPhotoDimensions(width: 4032, height: 3024)
        let capability = CameraPhotoResolutionCapability(
            supportedDimensions: [supported, supported]
        )

        XCTAssertFalse(capability.supportsMaximum)
        XCTAssertNil(capability.maximum)
    }

    // [AC-CAMLIB1015-E1]
    func testAC_CAMLIB1015_E1_LegacySettingsDecodeToStandardResolution() throws {
        let data = #"{"flashMode":"off","timerDuration":0,"exposureBias":0,"aspectRatio":"fourByThree","zoomFactor":1,"photographicStyle":"standard"}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CameraSettings.self, from: data)

        XCTAssertEqual(decoded.photoResolution, .standard)
    }

    // [AC-CAMLIB1015-E2]
    func testAC_CAMLIB1015_E2_CapabilityHandlesEmptyAndSingleDimensionLists() {
        let empty = CameraPhotoResolutionCapability(supportedDimensions: [])
        XCTAssertNil(empty.standard)
        XCTAssertNil(empty.maximum)
        XCTAssertFalse(empty.supportsMaximum)
        XCTAssertNil(empty.maximumTitle)

        let single = CameraPhotoDimensions(width: 1920, height: 1080)
        let capability = CameraPhotoResolutionCapability(supportedDimensions: [single, single])
        XCTAssertEqual(capability.standard, single)
        XCTAssertNil(capability.maximum)
        XCTAssertFalse(capability.supportsMaximum)
        XCTAssertNil(capability.maximumTitle)
    }

    // [AC-CAMLIB1015-S1]
    func testAC_CAMLIB1015_S1_ResolutionDoesNotBecomeHardwareOrCompositionChange() {
        var previous = CameraSettings.defaults
        previous.compositionGuide = .goldenSpiral
        var current = previous
        current.photoResolution = .maximum

        XCTAssertEqual(current.hardwareChanges(from: previous).exposure, false)
        XCTAssertEqual(current.hardwareChanges(from: previous).zoom, false)
        XCTAssertEqual(current.compositionGuide, .goldenSpiral)
    }
}
