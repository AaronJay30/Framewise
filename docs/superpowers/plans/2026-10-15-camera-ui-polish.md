# Camera and Library UI Polish Implementation Plan

> **For agentic workers:** This plan is being executed inline in the current session. Keep each behavior narrowly scoped and verify before completion.

**Goal:** Refine the camera control spacing, library selection actions, live-preview rendering cost, and branded opener motion.

**Architecture:** Keep the camera and gallery changes within their existing SwiftUI views. Make photographic-style rendering explicitly identity-aware in `FrameWiseCore`, so the standard preview avoids unnecessary image-effect modifiers while non-standard looks preserve current behavior. Animate the existing four-corner mark as one shutter-like contraction and rebound.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, XCTest.

**Spec:** User-approved request in the conversation on 2026-10-15.

## Global Constraints

- Preserve all existing composition-overlay and library changes already present in the working tree.
- Keep the standard camera preview free of non-identity image effects; preserve selected photographic styles.
- Preserve existing accessibility labels, minimum tap targets, loading/disabled states, and Reduce Motion behavior.
- Do not commit or push as part of this task.

## Review Focus

- Non-standard style adjustments must still affect the preview.
- Selection controls remain reachable and the count stays distinct from the three actions.
- Reduce Motion must suppress the opener's shutter movement.
- Camera smoothness can only be confirmed on a physical device; use the iOS build and core tests as available checks.

---

### Task 1: Avoid identity preview filters

**Files:**
- Modify: `Sources/FrameWiseCore/CameraSettings.swift`
- Test: `Tests/FrameWiseCoreTests/CameraSettingsTests.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

- [x] Add tests that standard adjustments are identity and representative non-standard adjustments are not.
- [x] Run the focused test and confirm the missing identity check fails to compile/fail as expected.
- [x] Add the smallest identity predicate and use it to bypass preview effect modifiers only for identity adjustments.
- [x] Run focused and full core tests.

### Task 2: Camera top row and library select action layout

**Files:**
- Modify: `Sources/FrameWise/CameraControls.swift`
- Modify: `Sources/FrameWise/PhotoGalleryView.swift`

- [x] Increase camera top control spacing while retaining existing control hit areas.
- [x] Place the selected count in a centered badge above one three-action row: Cancel, Download, Delete.
- [x] Preserve existing status messaging, action behavior, and disabled states.

### Task 3: Shutter-like opener mark

**Files:**
- Modify: `Sources/FrameWise/BrandIntroView.swift`

- [x] Animate the existing mark through a brief contraction and settle as the opener appears.
- [x] Keep motion one-shot per entrance and suppress the shutter movement when Reduce Motion is enabled.

### Task 4: Verification and review

- [x] Run full Swift tests (100 passed) and the iOS app build (succeeded).
- [x] Review the final diff for scope and compatibility with the pre-existing working-tree changes; `git diff --check` reported no whitespace errors.
- [x] Note that live camera smoothness still needs a physical-device check; no device-level latency measurement was available.
