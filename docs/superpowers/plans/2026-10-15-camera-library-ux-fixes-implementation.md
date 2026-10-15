# Camera Orientation and Library UX Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix landscape capture output, remove decorative control chrome, correct the Golden Spiral, and add gallery multi-selection plus swipe-down preview dismissal.

**Architecture:** Keep camera and library boundaries intact. Put crop, geometry,
selection, and gesture decisions in small `FrameWiseCore` helpers with host
tests, then connect those helpers to the existing SwiftUI and AVFoundation
views. Preserve the existing rotation coordinator and private photo-store
deletion boundary.

**Tech Stack:** Swift 6, SwiftUI, UIKit, AVFoundation, Core Image, XCTest,
xtool.

**Spec:** `docs/superpowers/specs/2026-10-15-camera-library-ux-fixes-design.md`

## Global Constraints

- Support the existing iOS 17 minimum and current iOS 26 glass fallback paths.
- Do not add dependencies or hard-code device megapixel capabilities.
- Preserve newest-first library ordering and private FrameWise-only deletion.
- Keep all controls accessible with labels, state values, and at least 44 pt
  hit areas.
- Keep composition artwork out of captured photo bytes.
- Bulk deletion requires a confirmation dialog.

## Review Focus

- Landscape 16:9 input: the crop target must be 16:9 after orientation
  normalization — covered by Task 1's landscape crop test.
- Portrait and square inputs: existing framing must not regress — covered by
  Task 1's portrait/square tests.
- Portrait Golden Spiral bounds: the curve must remain aspect-correct — covered
  by Task 2's width/height span test.
- Mixed selection and disappearing photos: stale IDs must not remain selected —
  covered by Task 4's reconciliation test.
- Horizontal/upward preview drags: they must not dismiss — covered by Task 5's
  direction tests.

---

### Task 1: Orientation-aware photo cropping

**Files:**
- Modify: `Sources/FrameWiseCore/CameraSettings.swift`
- Modify: `Sources/FrameWise/CameraPhotoProcessor.swift`
- Test: `Tests/FrameWiseCoreTests/CameraControlTests.swift`

**Interfaces:**
- Consumes: existing `CameraAspectRatio.cropRect(forWidth:height:)` contract.
- Produces: the same public crop API with source-orientation-aware targets;
  the existing processor automatically receives the corrected crop.

- [ ] **Step 1: Write the failing tests**

  Add `[AC-CAMUX1015-F1]` asserting a 4:3 landscape source cropped to 16:9
  has `x == 0`, `width == 1`, `y == 0.125`, and `height == 0.75`. Add
  `[AC-CAMUX1015-F2]` checks for portrait 16:9 and square behavior.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `swift test --filter CameraControlTests`

  Expected: the new landscape crop assertion fails because the current target
  is always portrait 9:16.

- [ ] **Step 3: Implement the minimal crop change**

  In `CameraAspectRatio.cropRect(forWidth:height:)`, select the reciprocal
  target for non-square aspect ratios when `width > height`. Leave
  `previewSize` unchanged so the current portrait camera UI remains stable.
  `CameraPhotoProcessor` continues to normalize the image before asking for
  the crop rect.

- [ ] **Step 4: Run the focused tests and verify GREEN**

  Run: `swift test --filter CameraControlTests`

  Expected: all camera-control tests pass.

- [ ] **Step 5: Commit**

  Commit message: `fix: preserve landscape photo orientation`

### Task 2: Aspect-correct Golden Spiral geometry

**Files:**
- Modify: `Sources/FrameWiseCore/CameraCompositionGeometry.swift`
- Modify: `Sources/FrameWise/CompositionGuideOverlay.swift`
- Test: `Tests/FrameWiseCoreTests/CompositionGuideTests.swift`

**Interfaces:**
- Consumes: existing `CameraGoldenSpiralGeometry.points(sampleCount:)` API.
- Produces: `points(width:height:sampleCount:)` plus the existing square-default
  overload; the SwiftUI renderer uses the size-aware overload.

- [ ] **Step 1: Write the failing tests**

  Add `[AC-CAMUX1015-F4]` asserting a portrait geometry's x-span/y-span
  matches the supplied height/width relationship rather than equaling 1.
  Add `[AC-CAMUX1015-E3]` for invalid dimensions and empty samples.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `swift test --filter CompositionGuideTests`

  Expected: the size-aware API tests fail because it does not exist.

- [ ] **Step 3: Implement the minimal geometry mapping**

  Generate the current normalized spiral in a square coordinate space, then
  center that square inside the requested bounds using the smaller dimension.
  Map the resulting points back to normalized coordinates and call that API
  from `goldenSpiralPath`.

- [ ] **Step 4: Run the focused tests and verify GREEN**

  Run: `swift test --filter CompositionGuideTests`

  Expected: all composition tests pass, including the existing lower-right to
  upper-left direction test.

- [ ] **Step 5: Commit**

  Commit message: `fix: keep golden spiral aspect correct`

### Task 3: Borderless icon-only camera controls

**Files:**
- Modify: `Sources/FrameWise/CameraControls.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**
- Consumes: existing settings, accessibility values, and `CameraGlass` zoom
  control only.
- Produces: icon-only top controls and a plain camera-flip button with the
  existing actions and state colors.

- [ ] **Step 1: Verify the visual regression boundary**

  Confirm the existing control code still routes Flash, Timer, Aspect, Styles,
  Composition, and Resolution through `CameraTopControls`, and camera flip
  through `CameraScreen.controlDock`.

- [ ] **Step 2: Implement the visual behavior**

  Render only the system symbol in each top control, pass `usesGlass: false`
  for every top setting control, choose a symbol for Aspect, and remove
  `CameraGlass` from camera flip. Keep plain button styles, accessibility
  labels/values, active coral tint, and 44 pt minimum frames.

- [ ] **Step 3: Build the iOS adapter**

  Run: `xtool dev build`

  Expected: the app target compiles with the borderless control changes.

- [ ] **Step 4: Commit**

  Commit message: `style: simplify camera control chrome`

### Task 4: Gallery multiple selection

**Files:**
- Create: `Sources/FrameWiseCore/PhotoGallerySelection.swift`
- Modify: `Sources/FrameWise/PhotoGalleryView.swift`
- Test: `Tests/FrameWiseCoreTests/PhotoGallerySelectionTests.swift`

**Interfaces:**
- Consumes: `CapturedPhotoStore.remove(id:)` and the gallery's ordered photo
  IDs.
- Produces: `PhotoGallerySelection.toggled(_:in:)` and
  `PhotoGallerySelection.reconciled(_:with:)` for SwiftUI selection state.

- [ ] **Step 1: Write the failing tests**

  Add `[AC-CAMUX1015-F5]` tests for selecting/deselecting IDs and
  `[AC-CAMUX1015-E2]` for removing IDs that no longer exist in the gallery.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `swift test --filter PhotoGallerySelectionTests`

  Expected: the helper tests fail because the helper does not exist.

- [ ] **Step 3: Implement the helper and gallery UI**

  Add the pure helper with set-based behavior. In `PhotoGalleryView`, add
  Select/Done toolbar state, selection-aware tile buttons with coral checkmarks,
  selected-count feedback, a bottom black action bar, and a confirmation dialog
  before sequentially calling `photoStore.remove(id:)` for selected IDs. Keep
  normal mode as the current NavigationLink gallery.

- [ ] **Step 4: Run focused tests and build**

  Run: `swift test --filter PhotoGallerySelectionTests` and `xtool dev build`

  Expected: helper tests pass and the SwiftUI app target compiles.

- [ ] **Step 5: Commit**

  Commit message: `feat: add gallery multi-selection`

### Task 5: Swipe-down preview dismissal and documentation

**Files:**
- Create: `Sources/FrameWiseCore/PhotoPreviewDismissal.swift`
- Modify: `Sources/FrameWise/PhotoPreviewView.swift`
- Modify: `README.md`
- Modify: `docs/code-walkthrough.md`
- Test: `Tests/FrameWiseCoreTests/PhotoPreviewDismissalTests.swift`

**Interfaces:**
- Consumes: existing `PhotoPreviewView` horizontal `TabView` paging and
  `dismiss` environment action.
- Produces: `PhotoPreviewDismissal.shouldDismiss(translationX:translationY:threshold:)`
  used to distinguish vertical dismissal from paging.

- [ ] **Step 1: Write the failing tests**

  Add `[AC-CAMUX1015-F7]` for a downward drag over the threshold and
  `[AC-CAMUX1015-E1]` for horizontal, upward, zero, and non-finite drags.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `swift test --filter PhotoPreviewDismissalTests`

  Expected: the helper tests fail because the helper does not exist.

- [ ] **Step 3: Implement the gesture**

  Add the pure direction helper, then attach a simultaneous vertical
  `DragGesture` to preview pages. Apply a bounded downward offset while the
  drag is active, dismiss once the helper returns true, and animate back to
  zero for canceled/upward/horizontal drags. Preserve tap-to-hide controls and
  horizontal `TabView` paging.

- [ ] **Step 4: Update documentation and run the full verification**

  Document orientation-aware crop behavior, icon-only controls, gallery
  selection, and swipe-down dismissal. Run:

  `swift test --scratch-path /home/aaronjay/framewise-camlib-build`

  `xtool dev build`

  `git diff --check`

  Expected: the full host suite passes, the iOS build succeeds, and the diff
  has no whitespace errors.

- [ ] **Step 5: Commit**

  Commit message: `feat: refine camera and library interactions`

## Final acceptance review

- [ ] Search for every `AC-CAMUX1015-*` ID in spec, implementation, tests, and
  documentation.
- [ ] Confirm no stale selection IDs remain after store mutations.
- [ ] Confirm the final diff does not alter unrelated camera settings or the
  existing preview share/save/delete contracts.
- [ ] Perform a separate final code review before any push.
