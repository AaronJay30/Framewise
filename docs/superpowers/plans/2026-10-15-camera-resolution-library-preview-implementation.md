# Camera Resolution, Golden Spiral, and Library Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a smooth reference-matched Golden Spiral, capability-driven still-photo resolution, and an aspect-safe swipeable library preview with tap-to-hide controls.

**Architecture:** Keep persisted resolution intent and dimension-selection rules in `FrameWiseCore`; keep AVFoundation's active-format dimensions and per-capture configuration inside `CameraService`. Use a small pure Golden Spiral geometry provider for testable normalized points, then render those points through the existing SwiftUI overlay. Pass ordered gallery IDs into `PhotoPreviewView` so paging state belongs to the preview rather than the library grid.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, UIKit, XCTest, existing `xtool` iOS build.

**Spec:** `docs/superpowers/specs/2026-10-15-camera-resolution-library-preview-design.md`

## Global Constraints

- Preserve the package's existing iOS 17 and macOS 14 platform floors.
- Do not add dependencies.
- Store `Standard`/`Maximum` intent, never a hard-coded 45 MP device assumption.
- Request only dimensions returned by the active format's supported photo-dimension list.
- Keep composition guides out of photo-processing inputs and saved photo bytes.
- Keep icon-only controls accessible with minimum 44-point targets.
- Respect Reduce Motion, Dynamic Type, Reduce Transparency, and existing dark camera styling.
- Keep the existing composition sheet's borderless guide choices and live selection behavior.

## Review Focus

- An empty or single-item supported-dimension list must not make camera startup or capture fail; `CameraPhotoResolutionCapability` tests cover this in Task 1.
- A persisted `Maximum` choice must fall back safely after a camera flip or on hardware without a distinct maximum; capability and legacy-setting tests cover this in Tasks 1–2.
- A 16:9 image must remain inside both a grid column and the full preview viewport; aspect-ratio assertions and the iOS build/UI checklist cover this in Task 4.
- Deleting the selected page must not leave `TabView` selection pointing at a missing ID; selection-transition tests cover the pure neighbor helper in Task 4.
- Reduce Motion and VoiceOver must preserve the tap-to-toggle controls interaction; the accessibility transition checklist covers this in Task 4 and final verification.

---

### Task 1: Add the hardware-independent resolution model and persisted setting

**Files:**
- Create: `Sources/FrameWiseCore/CameraPhotoResolution.swift`
- Create: `Tests/FrameWiseCoreTests/CameraPhotoResolutionTests.swift`
- Modify: `Sources/FrameWiseCore/CameraSettings.swift`
- Modify: `Tests/FrameWiseCoreTests/CameraSettingsTests.swift`

**Interfaces:**
- Produces `public enum CameraPhotoResolution: String, CaseIterable, Codable, Sendable` with `.standard` and `.maximum`, plus `title` returning `Standard` and `Maximum`.
- Produces `public struct CameraPhotoDimensions: Equatable, Sendable` with `init(width: Int, height: Int)`, `pixelCount: Int64`, and rounded `megapixels: Int`.
- Produces `public struct CameraPhotoResolutionCapability: Equatable, Sendable` with `init(supportedDimensions: [CameraPhotoDimensions])`, optional `standard` and `maximum` dimensions, `supportsMaximum: Bool`, and `maximumTitle: String?` formatted as `Maximum (N MP)` when the largest dimension differs from the smallest.
- Adds `photoResolution: CameraPhotoResolution` to `CameraSettings`, default `.standard`, with optional decoding for legacy payloads.

- [ ] **Step 1: Write the failing model tests**

  Add tests with these AC IDs:

  - `[AC-CAMLIB1015-F5]` exact resolution case order, titles, defaults, reset, and Codable round trip;
  - `[AC-CAMLIB1015-F6]` megapixel rounding, pixel-count ordering, and unsorted/duplicate dimension selection;
  - `[AC-CAMLIB1015-E1]` decoding a payload without `photoResolution`;
  - `[AC-CAMLIB1015-E2]` empty and single-dimension capability behavior;
  - `[AC-CAMLIB1015-S1]` proof that resolution-only changes do not appear in `hardwareChanges(from:)` and composition state remains outside that hardware boundary.

- [ ] **Step 2: Run the focused tests to verify RED**

  Run:

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && swift test --filter CameraPhotoResolutionTests --scratch-path /home/aaronjay/framewise-camlib-build"`

  Expected: FAIL because the new resolution types and `CameraSettings.photoResolution` do not exist yet.

- [ ] **Step 3: Implement the minimal core model and settings persistence**

  Implement `CameraPhotoDimensions` using `Int64` multiplication before converting to a rounded million-pixel count. Build capability values by selecting the smallest and largest unique pixel counts; expose no maximum when both are the same. Add the setting's coding key, optional decode fallback, encode path, default, and reset participation without changing exposure/zoom hardware-change semantics.

- [ ] **Step 4: Run focused and existing settings tests to verify GREEN**

  Run:

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && swift test --filter CameraPhotoResolutionTests --scratch-path /home/aaronjay/framewise-camlib-build"`

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && swift test --filter CameraSettingsTests --scratch-path /home/aaronjay/framewise-camlib-build"`

  Expected: both focused suites pass.

- [ ] **Step 5: Commit the model boundary**

  `git add Sources/FrameWiseCore/CameraPhotoResolution.swift Sources/FrameWiseCore/CameraSettings.swift Tests/FrameWiseCoreTests/CameraPhotoResolutionTests.swift Tests/FrameWiseCoreTests/CameraSettingsTests.swift`

  `git commit -m "feat: add camera photo resolution settings"`

### Task 2: Wire active-camera resolution capability into capture

**Files:**
- Modify: `Sources/FrameWise/CameraService.swift`
- Modify: `Sources/FrameWise/CameraViewModel.swift`

**Interfaces:**
- Extends `CameraServiceDelegate` with `cameraService(_:didUpdatePhotoResolution:)` receiving `CameraPhotoResolutionCapability`.
- Adds `@Published private(set) var photoResolutionCapability: CameraPhotoResolutionCapability?` to `CameraViewModel`.
- `CameraService` maintains a queue-confined mapping from `CameraPhotoDimensions` to the matching `CMVideoDimensions` for the active device format.

- [ ] **Step 1: Add capability delivery and capture-boundary tests/fixtures**

  Extend `CameraPhotoResolutionTests` with `[AC-CAMLIB1015-F7]` pure cases the service relies on: standard selects the smallest valid dimension, maximum selects the largest distinct valid dimension, and a maximum request is represented as unavailable when no distinct dimension exists. These tests are the RED gate for the selection contract before AVFoundation code uses it.

- [ ] **Step 2: Run the focused capability tests to verify RED**

  Run the `CameraPhotoResolutionTests` command from Task 1 and confirm the new assertions fail for the missing capability behavior rather than for a test typo.

- [ ] **Step 3: Implement active-format discovery and per-capture selection**

  In `CameraService`, convert `videoInput.device.activeFormat.supportedMaxPhotoDimensions` into core dimensions when configuring or flipping cameras. Set the photo output's maximum to the largest valid dimension before the session starts or before the new input is committed. Emit the capability after each active-device change. In `capturePhoto(using:)`, choose the mapped standard or maximum `CMVideoDimensions`, assign it to `AVCapturePhotoSettings.maxPhotoDimensions`, and fall back to standard when the requested maximum is unavailable. Do not reconfigure exposure/zoom for a resolution-only settings update. This implements `[AC-CAMLIB1015-F6]`, `[AC-CAMLIB1015-F7]`, and `[AC-CAMLIB1015-F8]`.

  In `CameraViewModel`, publish the delegate capability, retain the user's `.standard`/`.maximum` intent across camera flips, and leave the existing capture snapshot/processing boundary unchanged. The unsupported-device and camera-flip fallback behavior covers `[AC-CAMLIB1015-E2]` and `[AC-CAMLIB1015-E3]`.

- [ ] **Step 4: Build the iOS target and rerun host tests**

  Run:

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && swift test --scratch-path /home/aaronjay/framewise-camlib-build"`

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && xtool dev build"`

  Expected: host tests pass and the AVFoundation target compiles with no new dependency or platform-floor changes.

- [ ] **Step 5: Commit the AVFoundation integration**

  `git add Sources/FrameWise/CameraService.swift Sources/FrameWise/CameraViewModel.swift Tests/FrameWiseCoreTests/CameraPhotoResolutionTests.swift`

  `git commit -m "feat: apply supported photo resolution at capture"`

### Task 3: Replace the Golden Spiral and add camera resolution UI

**Files:**
- Create: `Sources/FrameWiseCore/CameraCompositionGeometry.swift`
- Create: `Sources/FrameWise/CameraResolutionSheet.swift`
- Modify: `Sources/FrameWise/CompositionGuideOverlay.swift`
- Modify: `Sources/FrameWise/CameraControls.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`
- Modify: `Tests/FrameWiseCoreTests/CompositionGuideTests.swift`

**Interfaces:**
- Produces `public struct CameraGuidePoint: Equatable, Sendable` with normalized `x` and `y` values.
- Produces `public enum CameraGoldenSpiralGeometry` with `static func points(sampleCount: Int = 160) -> [CameraGuidePoint]`, ordered from the lower-right focal turn toward the upper-left outer sweep.
- Produces `CameraResolutionSheet(settings:capability:onChange:)` and keeps the sheet open while the selection changes.

- [ ] **Step 1: Write failing geometry tests**

  Add `[AC-CAMLIB1015-F1]` and `[AC-CAMLIB1015-F2]` tests that request 160 points, assert the count is stable, assert every point lies in `0...1`, and assert the inner start is in the lower-right half while the outer end is in the upper-left half. These tests must fail before the geometry provider exists.

- [ ] **Step 2: Run the focused geometry tests to verify RED**

  Run:

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && swift test --filter CompositionGuideTests --scratch-path /home/aaronjay/framewise-camlib-build"`

  Expected: FAIL because `CameraGuidePoint` and `CameraGoldenSpiralGeometry` are not defined.

- [ ] **Step 3: Implement the pure smooth spiral geometry**

  Generate a sampled logarithmic spiral using the golden-ratio growth factor over a fixed number of quarter turns, then rotate, scale, and translate the points into normalized bounds. Clamp only numerical edge cases; preserve the lower-right-to-upper-left orientation rather than introducing user rotation. Keep this helper independent of SwiftUI and AVFoundation.

- [ ] **Step 4: Switch the overlay renderer to the tested points**

  Replace the current nested-rectangle `goldenSpiralPath` implementation with a path that moves through the normalized geometry points mapped to the Canvas size. Keep the other guides unchanged, remove the Canvas shadow, preserve opacity and hit-testing behavior, and keep selected thumbnails coral. This covers `[AC-CAMLIB1015-F1]`, `[AC-CAMLIB1015-F2]`, and `[AC-CAMLIB1015-F4]`.

- [ ] **Step 5: Add the resolution sheet and top-row entry point**

  Add `CameraResolutionSheet` with a black presentation surface, `Standard`, and dynamic `Maximum (N MP)` selection. Use a disabled explanatory row when `capability?.supportsMaximum == false`. Add `onResolution` to `CameraTopControls`, use an icon-only camera-aperture/resolution symbol with accessibility value, present the sheet from `CameraScreen`, and pass `viewModel.photoResolutionCapability`. Keep the Composition control icon-only with no `CameraGlass` modifier or shadow; leave unrelated controls unchanged. This covers `[AC-CAMLIB1015-F3]`, `[AC-CAMLIB1015-F5]`, and `[AC-CAMLIB1015-F6]`.

- [ ] **Step 6: Run geometry/settings tests and the iOS build**

  Run the focused `CompositionGuideTests`, the full host suite, and `xtool dev build`. Expected: all tests pass and the camera UI compiles with the new sheet and geometry path.

- [ ] **Step 7: Commit the camera UI changes**

  `git add Sources/FrameWiseCore/CameraCompositionGeometry.swift Sources/FrameWise/CompositionGuideOverlay.swift Sources/FrameWise/CameraResolutionSheet.swift Sources/FrameWise/CameraControls.swift Sources/FrameWise/CameraScreen.swift Tests/FrameWiseCoreTests/CompositionGuideTests.swift`

  `git commit -m "feat: refine composition spiral and resolution controls"`

### Task 4: Make library browsing aspect-safe and swipeable

**Files:**
- Modify: `Sources/FrameWise/LibraryView.swift`
- Modify: `Sources/FrameWise/PhotoGalleryView.swift`
- Modify: `Sources/FrameWise/PhotoPreviewView.swift`
- Create: `Sources/FrameWiseCore/PhotoPreviewSelection.swift`
- Create: `Tests/FrameWiseCoreTests/PhotoPreviewSelectionTests.swift`

**Interfaces:**
- `PhotoGalleryView` passes `photoIDs: [UUID]` in newest-first visible order to each `PhotoPreviewView` destination.
- `PhotoPreviewView` initializer becomes `init(photoID: UUID, photoIDs: [UUID], photoStore: CapturedPhotoStore, photoLibraryWriter: PhotoLibraryWriter = PhotoLibraryWriter())`.
- Produces `PhotoPreviewSelection.neighbor(afterRemoving removedID: UUID, from orderedIDs: [UUID]) -> UUID?`; `orderedIDs` is the pre-removal order, and the helper returns the next item at the removed index, the previous item when the removed item was last, or `nil` when it was the only item.

- [ ] **Step 1: Write failing selection tests**

  Add `[AC-CAMLIB1015-F13]` tests for neighbor selection after removing a middle, first, last, or only ID. The gallery aspect behavior is UI glue and is verified by the implementation contract and device checklist rather than by introducing a second core abstraction.

- [ ] **Step 2: Run the focused selection tests to verify RED**

  Run:

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && swift test --filter PhotoPreviewSelectionTests --scratch-path /home/aaronjay/framewise-camlib-build"`

  Expected: FAIL because the selection helper is not defined.

- [ ] **Step 3: Implement the tested selection helper**

  Implement `PhotoPreviewSelection.neighbor(afterRemoving:from:)` against the pre-removal ordered IDs: return the next ID at the removed index when available, otherwise the previous ID, and `nil` when there is no neighbor. Keep the helper independent of SwiftUI and storage.

- [ ] **Step 4: Update gallery routing and aspect-safe tiles**

  Pass the ordered IDs from All Photos and day galleries. Decode each tile's `UIImage.size`, render with `scaledToFit`, and apply that display aspect ratio inside the available column width; use a stable fallback for malformed data. Replace the Library floating camera button with a full-width black bottom bar, icon-only camera action, no shadow, and the existing dismiss/accessibility behavior. This covers `[AC-CAMLIB1015-F9]` and `[AC-CAMLIB1015-F10]`.

- [ ] **Step 5: Add paged preview state and tap-to-toggle controls**

  Initialize `@State selectedPhotoID` from the tapped ID and render a `TabView(selection:)` with page style over the supplied IDs. Use `scaledToFit` on black for every page. Bind Share, Save, and Delete to the selected photo. Add `areControlsVisible`, toggle it from the image area, remove/reveal the bottom safe-area action section with a Reduce Motion-aware opacity transition, and expose an accessibility action/value for the toggle. After deletion, use `PhotoPreviewSelection.neighbor` to select the nearest remaining photo or dismiss if none remain. This covers `[AC-CAMLIB1015-F11]`, `[AC-CAMLIB1015-F12]`, `[AC-CAMLIB1015-F13]`, `[AC-CAMLIB1015-E4]`, and `[AC-CAMLIB1015-E5]`.

- [ ] **Step 6: Build and run the host suite**

  Run the focused selection tests, the full `swift test` suite, `xtool dev build`, and `git diff --check`. Expected: all commands exit successfully; no photo-processing or storage API changes are introduced.

- [ ] **Step 7: Commit the library changes**

  `git add Sources/FrameWise/LibraryView.swift Sources/FrameWise/PhotoGalleryView.swift Sources/FrameWise/PhotoPreviewView.swift Sources/FrameWiseCore/PhotoPreviewSelection.swift Tests/FrameWiseCoreTests/PhotoPreviewSelectionTests.swift`

  `git commit -m "feat: add aspect-safe swipeable photo previews"`

### Task 5: Update documentation and perform final verification

**Files:**
- Modify: `README.md`
- Modify: `docs/code-walkthrough.md`
- Modify: `docs/superpowers/specs/2026-10-15-camera-resolution-library-preview-design.md` only if implementation wording needs a factual correction.

**Interfaces:**
- Documentation describes the persisted resolution intent, active-device capability fallback, smooth Golden Spiral orientation, aspect-safe gallery, and paged/tap-toggle preview behavior without promising unsupported hardware.

- [ ] **Step 1: Update documentation**

  Add the new resolution setting, capture boundary, Golden Spiral renderer, library aspect behavior, and preview paging/control toggle to the existing current-state and walkthrough sections. Keep deferred RAW/ProRAW and intermediate-dimension selection explicit.

- [ ] **Step 2: Run the complete verification commands**

  Run:

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && swift test --scratch-path /home/aaronjay/framewise-camlib-build"`

  `wsl.exe -e bash -lc "cd '/mnt/c/Users/User/.codex/worktrees/composition-overlays/FrameWise' && source /home/aaronjay/.bashrc && xtool dev build"`

  `git diff --check`

  `rg -n "AC-CAMLIB1015-(F|S|E)[0-9]+" Sources Tests docs README.md`

  Expected: full host suite passes, iOS build completes, diff check is silent, and every acceptance ID appears in implementation/tests or verification documentation.

- [ ] **Step 3: Perform the final code review and simplification pass**

  Inspect the full diff for unintended changes, stale square-arc code, hard-coded 45 MP assumptions, duplicated navigation state, dropped accessibility labels, or unnecessary abstractions. Confirm `CameraService.swift` still owns all AVFoundation dimension handling and composition remains outside processing.

- [ ] **Step 4: Record device-only limitations**

  If no physical iPhone is connected, record that hardware-dependent resolution labels, actual output dimensions, swipe/tap behavior, VoiceOver, Reduce Motion, and 16:9 viewport fit remain device checks rather than claim them as verified.

- [ ] **Step 5: Commit documentation and verification artifacts**

  `git add README.md docs/code-walkthrough.md docs/superpowers/plans/2026-10-15-camera-resolution-library-preview-implementation.md`

  `git commit -m "docs: document camera resolution and library preview"`

