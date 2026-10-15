# Composition Overlays Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a polished, persisted set of static composition guides to the live FrameWise camera without changing captured photo pixels or the existing camera interaction model.

**Architecture:** Store the selected guide and opacity in the existing hardware-independent `CameraSettings` contract. Render the guide through a shared SwiftUI artwork view used by both the live preview and the borderless Composition sheet, while keeping the camera service unchanged and excluding composition inputs from the photo processor boundary. Wire a separate Composition top control and sheet beside Photographic Styles.

**Tech Stack:** Swift 6, SwiftUI, Foundation, XCTest, existing FrameWiseCore settings persistence, and xtool.

**Spec:** `docs/superpowers/specs/2026-10-15-composition-overlays-design.md`

## Global Constraints

- The live camera preview remains the primary visual element.
- Composition is a separate concern from Photographic Styles, with its own top control and sheet.
- Guide choices inside the sheet have no borders, capsules, or individual backgrounds.
- The first slice includes only static guides; live horizon leveling, dynamic symmetry, perspective rays, technical safe areas, and AI guidance remain deferred.
- Guides are view-only and must never be passed into photo processing.
- The user-facing opacity range is `0.20...1.00`, with a default of `0.60`.
- Existing permission, hardware, capture, storage, settings, and camera gesture behavior must remain unchanged.
- Add no external dependency or icon library.

## Review Focus

- Legacy settings payloads missing composition keys must preserve existing camera values and default composition safely — pinned by Task 1's legacy decoding test.
- Non-finite and out-of-range opacity must not make the camera settings invalid — pinned by Task 1's normalization tests.
- The same guide must align with each selected preview aspect ratio, including square and portrait 16:9 — checked by Task 2's preview integration and device checklist.
- Guide rendering must not steal focus, exposure, pinch, or shutter hit testing — checked by Task 2's overlay integration and Task 4's device checklist.
- A captured image must remain free of guide pixels while the live guide is visible — checked by Task 4's source inspection and device capture checklist.

---

### Task 1: Add the composition settings contract

**Files:**
- Create: `Sources/FrameWiseCore/CompositionGuide.swift`
- Create: `Tests/FrameWiseCoreTests/CompositionGuideTests.swift`
- Modify: `Sources/FrameWiseCore/CameraSettings.swift`
- Modify: `Tests/FrameWiseCoreTests/CameraSettingsTests.swift`

**Interfaces:**
- Produces `public enum CameraCompositionGuide: String, CaseIterable, Codable, Equatable, Sendable` with the ordered cases `.off`, `.ruleOfThirds`, `.centreCross`, `.quadrant`, `.ruleOfFifths`, `.goldenRatio`, `.goldenSpiral`, `.goldenTriangle`, `.diagonalCross`, and `.horizon`.
- Produces `CameraCompositionGuide.title: String` with the user-facing guide names used by the sheet.
- Extends `CameraSettings` with `compositionGuide: CameraCompositionGuide` and `compositionGuideOpacity: Float`.
- Extends the existing `CameraSettings` initializer with defaulted composition parameters so existing call sites remain source-compatible.

- [ ] **Step 1: Write the failing model tests**

  Add tests with the project’s AC naming convention:

  - `testAC_COMP1015_F3_CompositionGuidesExposeApprovedCatalog()` asserts the exact case order and titles, including `Off`, `Rule of thirds`, `Centre cross`, `Quadrant grid`, `Rule of fifths`, `Golden ratio`, `Golden spiral`, `Golden triangle`, `Diagonal/X-Frame`, and `Horizon`.
  - `testAC_COMP1015_F7_CompositionSettingsRoundTripThroughCodable()` encodes and decodes a non-default guide with opacity `0.35` and asserts equality.
  - `testAC_COMP1015_E1_OlderSettingsDecodeWithCompositionDefaults()` decodes the existing pre-composition JSON shape and asserts the existing camera fields are preserved, the guide is `.off`, and opacity is `0.60`.
  - `testAC_COMP1015_E2_CompositionOpacityNormalizesToSafeBounds()` covers `NaN`, values below `0.20`, and values above `1.00`.
  - `testAC_COMP1015_F8_ResetRestoresCompositionDefaults()` asserts reset returns `.off` and `0.60` along with the existing camera defaults.
  - Add a default-value assertion to `testDefaultsUseSafeCameraValues()` or a focused companion test.

- [ ] **Step 2: Run the focused tests and verify they fail**

  Run: `swift test --filter CameraSettingsTests`

  Expected: FAIL to compile or fail assertions because the composition enum and settings fields do not exist yet.

- [ ] **Step 3: Implement the minimal model contract**

  Add `CameraCompositionGuide` in `CompositionGuide.swift`. Keep UI-only symbols out of `FrameWiseCore`; expose only the enum cases and titles needed by the settings sheet.

  Add the two properties to `CameraSettings`, include them in `CodingKeys`, encode them, and decode them with `decodeIfPresent` fallbacks so older persisted JSON remains valid. In `normalized()`, preserve `.off` and clamp opacity to `0.20...1.00`; treat non-finite values as `0.60`. Leave `hardwareChanges(from:)` unchanged because composition does not affect the sensor.

- [ ] **Step 4: Run the focused tests and verify they pass**

  Run: `swift test --filter CameraSettingsTests`

  Expected: PASS, including the new `AC-COMP1015` cases and all existing camera-settings tests.

- [ ] **Step 5: Commit the model contract**

  ```bash
  git add Sources/FrameWiseCore/CompositionGuide.swift Sources/FrameWiseCore/CameraSettings.swift Tests/FrameWiseCoreTests/CompositionGuideTests.swift Tests/FrameWiseCoreTests/CameraSettingsTests.swift
  git commit -m "feat: add composition guide settings"
  ```

### Task 2: Build the shared guide renderer and preview integration

**Files:**
- Create: `Sources/FrameWise/CompositionGuideOverlay.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**
- Produces `CompositionGuideOverlay(guide: CameraCompositionGuide, opacity: Double)` for the live preview.
- Produces a reusable internal `CompositionGuideArtwork(guide: CameraCompositionGuide, opacity: Double)` used later by the Composition sheet thumbnails.
- The artwork fills its parent, draws no background, and has no hit testing.

- [ ] **Step 1: Implement the shared artwork view**

  In `CompositionGuideOverlay.swift`, use one deterministic SwiftUI drawing implementation for both the full preview and thumbnails. Draw normalized geometry into the supplied `Canvas` size:

  - thirds at `1/3` and `2/3`;
  - centre lines at `0.5`;
  - quadrant treatment using very low-opacity fills plus the centre lines;
  - fifths at `1/5`, `2/5`, `3/5`, and `4/5`;
  - Phi lines at `1/phi` and `1 - 1/phi`, where `phi = (1 + sqrt(5)) / 2`;
  - a fixed-orientation nested-golden-rectangle quarter-arc spiral;
  - a fixed-orientation golden-triangle diagonal/perpendicular construction;
  - both corner-to-corner diagonals for the X-frame;
  - one centered horizontal line for the static horizon.

  Use thin white strokes, the passed opacity, and a restrained shadow. The `.off` case draws nothing. Keep the renderer independent from `CameraViewModel` and camera hardware.

- [ ] **Step 2: Mount the overlay in the live preview**

  In `CameraScreen.preview`, render `CompositionGuideOverlay` from `viewModel.settings.compositionGuide` and `viewModel.settings.compositionGuideOpacity` immediately after `styledPreview`, only when the guide is not `.off`. Keep focus/exposure and countdown above it. Apply an opacity transition only when Reduce Motion is disabled, and preserve the existing preview frame and clipping. The overlay must use `.allowsHitTesting(false)`.

- [ ] **Step 3: Build the iOS target and inspect the interaction boundary**

  Run: `xtool dev build`

  Expected: PASS. Confirm source inspection still shows the overlay is inserted after `styledPreview`, before `FocusExposureOverlay`, is non-interactive, and composition inputs are excluded from `CameraPhotoProcessor`.

- [ ] **Step 4: Commit the renderer and preview integration**

  ```bash
  git add Sources/FrameWise/CompositionGuideOverlay.swift Sources/FrameWise/CameraScreen.swift
  git commit -m "feat: render composition guides over camera preview"
  ```

### Task 3: Add the Composition control and borderless sheet

**Files:**
- Create: `Sources/FrameWise/CompositionGuideSheet.swift`
- Modify: `Sources/FrameWise/CameraControls.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**
- `CameraTopControls` gains `onComposition: () -> Void` while retaining its existing settings, flash availability, change, and styles inputs.
- `CompositionGuideSheet` accepts `settings: CameraSettings` and `onChange: (CameraSettings) -> Void`.
- `CompositionGuideSheet` updates selection and opacity through `onChange` without dismissing itself.

- [ ] **Step 1: Implement the borderless Composition sheet**

  Build the sheet with the existing dark settings conventions but set its presentation background to black. Use a close button with a minimum 44-point target, a horizontally scrolling row of `CompositionGuideArtwork` previews, and plain buttons with no `CameraGlass`, capsule, border, or tile background. Apply Signal Coral to the selected artwork/title and add a checkmark. Put `Off` first. Add an opacity `Slider` bound to a copied `CameraSettings` value through `onChange`, with an accessibility value expressed as a percentage. Keep `.medium` and `.large` detents and the drag indicator. The sheet must keep the existing style sheet unchanged.

- [ ] **Step 2: Add the top control and sheet presentation**

  Add the Composition control beside Photographic Styles in `CameraTopControls`. Use the existing control styling for the top-row button, expose the selected guide through its accessibility value, and mark it active whenever the guide is not `.off`. Add `isCompositionPresented` to `CameraScreen`, pass `onComposition`, and present `CompositionGuideSheet` in a separate `.sheet` without changing the existing Photographic Styles presentation.

- [ ] **Step 3: Build the iOS target and verify the sheet contract**

  Run: `xtool dev build`

  Expected: PASS. Inspect the built-source diff for the absence of guide tile backgrounds/borders and confirm the existing Photographic Styles sheet was not unintentionally redesigned. The device review must cover `[AC-COMP1015-F1]`, `[AC-COMP1015-F2]`, `[AC-COMP1015-F4]`, `[AC-COMP1015-F6]`, and `[AC-COMP1015-E4]`.

- [ ] **Step 4: Commit the Composition sheet and control**

  ```bash
  git add Sources/FrameWise/CompositionGuideSheet.swift Sources/FrameWise/CameraControls.swift Sources/FrameWise/CameraScreen.swift
  git commit -m "feat: add composition guide controls"
  ```

### Task 4: Document and verify the complete slice

**Files:**
- Modify: `README.md`
- Modify: `docs/code-walkthrough.md`

**Interfaces:**
- Documents the new Composition control, static guide catalog, opacity persistence, clean capture boundary, and deferred live/advanced guides.
- Produces the final AC traceability report for `AC-COMP1015`.

- [ ] **Step 1: Update the user-facing project documentation**

  Add the Composition control and guide catalog to the current-state and camera-settings sections of `README.md`. Update `docs/code-walkthrough.md` with the new settings fields, sheet/overlay relationship, and the fact that composition inputs are excluded from `CameraPhotoProcessor`. Keep live horizon leveling and advanced guide families in the next-work/deferred list.

- [ ] **Step 2: Run the full automated verification**

  Run:

  ```bash
  swift test
  xtool dev build
  git diff --check
  rg -n "AC-COMP1015-(F|S|E|ERR)[0-9]+" Sources Tests docs README.md
  ```

  Expected: the host suite passes, the iOS target builds, `git diff --check` is silent, and every `AC-COMP1015` criterion appears in the relevant implementation/test or verification documentation.

- [ ] **Step 3: Perform the physical-device acceptance pass**

  On the connected iPhone, open and close Composition, select every guide, compare thumbnails to the live overlay, switch 4:3/1:1/16:9, sweep opacity from minimum to maximum, leave and re-enter Camera, and verify focus, exposure, pinch zoom, timer, and shutter remain responsive. Capture photos and confirm no guide pixels are saved. Check VoiceOver, large text, Reduce Motion, and Reduce Transparency.

- [ ] **Step 4: Review the final diff for scope and simplicity**

  Confirm no changes were made to `CameraService`, no external dependencies were added, no guide tile backgrounds or borders were introduced, and no deferred live/advanced features slipped into this slice. Confirm `CameraPhotoProcessor` receives only aspect/style inputs. Resolve any legitimate findings and rerun the affected verification.

- [ ] **Step 5: Commit the documentation and verified slice**

  ```bash
  git add README.md docs/code-walkthrough.md Sources Tests docs/superpowers/plans/2026-10-15-composition-overlays-implementation.md
  git commit -m "docs: document composition overlays"
  ```
