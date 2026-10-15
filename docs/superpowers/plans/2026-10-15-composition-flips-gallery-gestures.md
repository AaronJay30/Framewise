# Composition Flips and Gallery Gestures Implementation Plan

> **For agentic workers:** Use the approved in-chat design and implement each task with a RED → GREEN → REFACTOR cycle.

**Goal:** Add useful flip controls to asymmetric composition guides, keep library thumbnails square and cropped, and make photo paging coexist with downward dismissal.

**Architecture:** Persist independent horizontal and vertical flip settings in `CameraSettings`, then transform composition artwork at the preview canvas. Keep library thumbnails inside a square clipped viewport. Keep native horizontal paging in `TabView` and move the downward-only dismissal gesture to the pager container so it does not update page content during a horizontal swipe. Draw the golden spiral without its rectangle outline and retain its circular construction arcs.

**Tech Stack:** Swift, SwiftUI, FrameWiseCore, XCTest.

**Spec:** Approved in-chat design in the conversation dated 2026-10-15.

## Global Constraints

- Preserve existing camera setting persistence and backward-compatible decoding.
- Preserve true circular arcs for the golden spiral; its fitted golden rectangle may leave margins.
- Keep the library thumbnail ratio at 1:1 and crop with clipping rather than distortion.
- Keep horizontal preview paging and downward preview dismissal as distinct gestures.

## Review Focus

- Older saved camera settings without flip keys decode to both flips off.
- Horizontal/vertical flips affect asymmetric guides independently; symmetric guides do not expose redundant controls.
- Portrait and landscape gallery images remain cropped within equal square tiles in normal and selection modes.
- Horizontal swipes do not change vertical drag offset; only downward-dominant swipes can dismiss.
- Golden spiral arcs remain circular and continuous after removing the boundary outline.

### Task 1: Composition guide flips and spiral rendering

**Files:** `Sources/FrameWiseCore/CameraSettings.swift`, `Sources/FrameWiseCore/CompositionGuide.swift`, `Sources/FrameWise/CompositionGuideSheet.swift`, `Sources/FrameWise/CompositionGuideOverlay.swift`, `Tests/FrameWiseCoreTests/CompositionGuideTests.swift`, `Tests/FrameWiseCoreTests/CameraSettingsTests.swift`.

- [x] Add failing tests for flip capability, independent persisted flip flags, and old settings decoding with absent flip fields.
- [x] Run the focused tests and confirm they fail on the missing behavior.
- [x] Implement optional flip controls for asymmetric guides and apply the selected transforms to the canvas.
- [x] Remove the golden rectangle outline and increase curve rendering smoothness while preserving circular geometry.
- [x] Run focused tests and review the resulting diff.

### Task 2: Square library tiles

**Files:** `Sources/FrameWise/PhotoGalleryView.swift`.

- [x] Rework tile sizing so the image, selection affordance, and download indicator share one square clipped viewport.
- [x] Ensure landscape and portrait images use fill-and-crop in both normal and selection modes.
- [x] Inspect the final layout modifiers for unintended overflow or fixed-device assumptions.

### Task 3: Stable preview swipe handling

**Files:** `Sources/FrameWise/PhotoPreviewView.swift`, `Sources/FrameWiseCore/PhotoPreviewDismissal.swift`, `Tests/FrameWiseCoreTests/PhotoPreviewDismissalTests.swift`.

- [x] Add failing direction tests that classify downward-dominant drags separately from horizontal paging gestures.
- [x] Run the focused tests and confirm the new classification behavior is missing.
- [x] Move the dismissal gesture to the pager container and only update drag presentation for downward-dominant motion.
- [x] Keep native horizontal paging intact and run focused tests.

### Task 4: Verification and review

- [x] Run the full Swift test suite and iOS build as supported by the project environment.
- [x] Review the complete diff for scope, accessibility, and persistence compatibility.
- [x] Report device-only gesture and visual behavior that cannot be verified without a connected iPhone.
