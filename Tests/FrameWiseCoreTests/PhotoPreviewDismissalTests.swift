import XCTest
@testable import FrameWiseCore

final class PhotoPreviewDismissalTests: XCTestCase {
    func testOnlyDownwardDominantDragsMoveTheDismissalPreview() {
        XCTAssertTrue(PhotoPreviewDismissal.isDownwardDominant(translationX: 18, translationY: 40))
        XCTAssertFalse(PhotoPreviewDismissal.isDownwardDominant(translationX: 90, translationY: 40))
        XCTAssertFalse(PhotoPreviewDismissal.isDownwardDominant(translationX: 0, translationY: -40))
        XCTAssertFalse(PhotoPreviewDismissal.isDownwardDominant(translationX: .nan, translationY: 40))
    }

    func testAC_CAMUX1015_F7_DownwardDominantDragDismissesPreview() {
        XCTAssertTrue(
            PhotoPreviewDismissal.shouldDismiss(
                translationX: 18,
                translationY: 140
            )
        )
    }

    func testAC_CAMUX1015_E1_HorizontalUpwardAndInvalidDragsDoNotDismiss() {
        XCTAssertFalse(
            PhotoPreviewDismissal.shouldDismiss(
                translationX: 180,
                translationY: 32
            )
        )
        XCTAssertFalse(
            PhotoPreviewDismissal.shouldDismiss(
                translationX: 20,
                translationY: -160
            )
        )
        XCTAssertFalse(
            PhotoPreviewDismissal.shouldDismiss(
                translationX: 20,
                translationY: 119
            )
        )
        XCTAssertFalse(
            PhotoPreviewDismissal.shouldDismiss(
                translationX: .nan,
                translationY: 180
            )
        )
        XCTAssertFalse(
            PhotoPreviewDismissal.shouldDismiss(
                translationX: 0,
                translationY: 180,
                threshold: 0
            )
        )
    }
}
