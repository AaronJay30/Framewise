# Camera Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compact, test-backed settings flow for Flash, Timer, Exposure,
Tap Focus, Aspect, Zoom, and app-defined Photographic Styles without making
the camera screen feel crowded.

**Architecture:** Keep settings values, invariants, crop geometry, and style
parameters in the hardware-independent `FrameWiseCore` target. Extend the
existing `CameraService` session queue for AVFoundation device configuration,
keep timer/persistence/state in `CameraViewModel`, and add one SwiftUI bottom
sheet plus direct preview gestures in the camera screen. Process aspect/style
choices at the existing capture-to-library boundary, falling back to the
original bytes if image processing cannot complete.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, UIKit, Core Image,
`UserDefaults`, XCTest, xtool.

**Spec:** `docs/superpowers/specs/2026-10-14-camera-settings-design.md`

## Global Constraints

- Feature SLUG: `CAMSET1014`; acceptance IDs must appear in tests wherever the
  behavior is host-testable.
- Preserve the existing still-photo capture, permission recovery, library,
  and library/shutter/flip dock behavior.
- Keep AVFoundation work on `CameraService`'s existing serial session queue.
- Do not add external dependencies or network/photo-upload behavior.
- Unsupported hardware must leave the preview usable and must not discard a
  successful capture.
- All interactive controls keep a minimum 44 pt hit area and accessibility
  labels.
- The first-pass styles are app-defined Standard, Vivid, Warm, Cool, and Mono;
  do not attempt Apple's private Photographic Styles implementation.

## Review Focus

- Settings changed immediately before capture must be the settings used by
  that capture, not a later mutable value; test the codable request snapshot
  and verify the service passes a snapshot to the delegate.
- Exposure and zoom values must be clamped to the active device's reported
  range, including after flipping to a camera with a narrower range; test pure
  clamping and manually verify both cameras.
- Aspect cropping must be centered, preserve the requested ratio, and never
  upscale a source image; test wide, tall, and already-matching source sizes.
- A pending timer must be canceled when the camera disappears and must ignore
  a second shutter request; test duration/cancellation logic and manually
  verify lifecycle behavior on device.
- A photo processing failure must return the original bytes and keep capture
  delivery alive; test the processor fallback with invalid image data and
  manually verify a valid styled capture reaches the library.

---

## File Map

**Create:**

- `Sources/FrameWiseCore/CameraSettings.swift` — public settings enums,
  defaults, invariants, focus-point validation, crop geometry, and style
  parameters.
- `Sources/FrameWiseCore/CameraPhotoProcessingPolicy.swift` — pure original
  data fallback used by the iOS image processor.
- `Tests/FrameWiseCoreTests/CameraSettingsTests.swift` — host tests for all
  pure settings behavior and the acceptance IDs it covers.
- `Sources/FrameWise/CameraPhotoProcessor.swift` — UIKit/Core Image crop and
  style processing with original-data fallback.
- `Sources/FrameWise/CameraSettingsSheet.swift` — compact bottom-sheet UI for
  the seven settings.

**Modify:**

- `Sources/FrameWise/CameraService.swift` — apply flash, exposure, focus, and
  zoom on the session queue; pass capture-setting snapshots and exposure
  ranges through the delegate.
- `Sources/FrameWise/CameraViewModel.swift` — publish settings and ranges,
  persist/reset settings, own timer cancellation/countdown, route focus/zoom,
  and process captured data.
- `Sources/FrameWise/CameraPreview.swift` — report both preview and normalized
  device tap points from the existing preview layer.
- `Sources/FrameWise/CameraScreen.swift` — add the Controls entry point,
  settings sheet presentation, aspect/style preview treatment, focus marker,
  timer overlay, and pinch-to-zoom gesture while preserving the dock.
- `README.md` — update the current-state summary and project structure.
- `docs/code-walkthrough.md` — document the settings data flow and new
  hardware boundary.

**No package dependencies or target changes are expected.**

## Interfaces

The core target produces these stable interfaces for the app target:

```swift
public enum CameraFlashMode: String, CaseIterable, Codable, Sendable {
    case auto, on, off
}

public enum CameraTimerDuration: Int, CaseIterable, Codable, Sendable {
    case off = 0, threeSeconds = 3, fiveSeconds = 5, tenSeconds = 10
}

public enum CameraAspectRatio: String, CaseIterable, Codable, Sendable {
    case fourByThree, square, sixteenByNine
}

public enum CameraPhotographicStyle: String, CaseIterable, Codable, Sendable {
    case standard, vivid, warm, cool, mono
}

public struct CameraSettings: Codable, Equatable, Sendable {
    public var flashMode: CameraFlashMode
    public var timerDuration: CameraTimerDuration
    public var exposureBias: Double
    public var aspectRatio: CameraAspectRatio
    public var zoomFactor: Double
    public var photographicStyle: CameraPhotographicStyle

    public static let defaults: CameraSettings
    public func clamped(exposureRange: CameraExposureRange,
                        zoomRange: ClosedRange<Double>) -> CameraSettings
}

public struct CameraFocusPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
}

public struct CameraExposureRange: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double
}
```

The app target extends its existing delegate boundary with:

```swift
func cameraService(_ cameraService: CameraService,
                   didCapturePhoto data: Data,
                   settings: CameraSettings)
func cameraService(_ cameraService: CameraService,
                   didUpdateExposureRange range: CameraExposureRange)
func cameraService(_ cameraService: CameraService,
                   didUpdateZoomRange range: ClosedRange<Float>)
func cameraService(_ cameraService: CameraService,
                   didUpdateFlashAvailability isAvailable: Bool)
```

`CameraService` exposes:

```swift
func apply(settings: CameraSettings)
func focus(at point: CameraFocusPoint)
func capturePhoto(using settings: CameraSettings)
```

`CameraPhotoProcessor.process(data:settings:) -> Data` is total: it returns
processed bytes on success and the input bytes on decode/encode failure.

### Task 1: Add the testable settings contracts

**Files:**

- Create: `Sources/FrameWiseCore/CameraSettings.swift`
- Test: `Tests/FrameWiseCoreTests/CameraSettingsTests.swift`

**Interfaces:**

- Produces the enums and structs in the Interfaces section.
- `CameraSettings.defaults` is Flash Auto, Timer Off, 0 EV, 4:3, 1.0x, and
  Standard.
- `CameraTimerDuration.seconds` returns `0`, `3`, `5`, or `10`.
- `CameraAspectRatio` exposes numeric ratios `4.0 / 3.0`, `1.0`, and
  `16.0 / 9.0` and returns a centered normalized crop rectangle.
- `CameraPhotographicStyle.adjustments` returns exact pure values:
  Standard `(1.00, 1.00, 0.00, 1.00, 1.00, 1.00)`, Vivid
  `(1.25, 1.08, 0.00, 1.00, 1.00, 1.00)`, Warm
  `(1.08, 1.00, 0.02, 1.06, 1.00, 0.94)`, Cool
  `(1.08, 1.00, 0.00, 0.94, 1.00, 1.06)`, and Mono
  `(0.00, 1.00, 0.00, 1.00, 1.00, 1.00)`.

- [ ] **Step 1: Write failing tests for the settings choices and defaults**

  Add tests named with the project convention and place the exact namespaced
  IDs in an adjacent comment:

  - `testAC_CAMSET1014_F2_FlashModesExposeAutoOnAndOff`
    `// [AC-CAMSET1014-F2]`
  - `testAC_CAMSET1014_F3_TimerDurationsExposeOffThreeFiveAndTen`
    `// [AC-CAMSET1014-F3]`
  - `testAC_CAMSET1014_F6_AspectRatiosExposeFourThreeSquareAndSixteenNine`
    `// [AC-CAMSET1014-F6]`
  - `testAC_CAMSET1014_F8_StylesExposeFiveDefinedLooks`
    `// [AC-CAMSET1014-F8]`
  - `testDefaultsUseSafeCameraValues`

  Assert exact `CaseIterable` order, titles/seconds, and default values.

- [ ] **Step 2: Run the focused tests and verify the expected RED failure**

  Run: `swift test --filter CameraSettingsTests`

  Expected: compilation/test failure because the new settings types do not
  exist yet.

- [ ] **Step 3: Write failing tests for invariants and pure geometry**

  Add tests named:

  - `testAC_CAMSET1014_F4_ExposureIsClampedToDeviceRange`
    `// [AC-CAMSET1014-F4]`
  - `testAC_CAMSET1014_F7_ZoomIsClampedToDeviceRange`
    `// [AC-CAMSET1014-F7]`
  - `testAC_CAMSET1014_F5_FocusPointRejectsOutsideNormalizedBounds`
    `// [AC-CAMSET1014-F5]`
  - `testAspectCropTrimsWidthForWiderSource`
    `// [AC-CAMSET1014-F6]`
  - `testAspectCropTrimsHeightForTallerSource`
    `// [AC-CAMSET1014-F6]`
  - `testAC_CAMSET1014_E1_NonFiniteSettingsNormalizeToSafeValues`
    `// [AC-CAMSET1014-E1]`
  - `testStyleAdjustmentsMatchTheDefinedPresets`
    `// [AC-CAMSET1014-F8]`
  - `testSettingsRoundTripThroughCodable`

  Assert centered crop coordinates, no source upscaling assumptions in the
  returned normalized rectangle, range clamping, invalid focus-point rejection,
  exact style tuples, and Codable equality.

- [ ] **Step 4: Run the focused tests and verify they fail for missing behavior**

  Run: `swift test --filter CameraSettingsTests`

  Expected: RED failures naming missing types/properties or unimplemented
  behavior, not a test-discovery or syntax error.

- [ ] **Step 5: Implement the minimum core model**

  Implement the enums, defaults, `CameraExposureRange`, `CameraFocusPoint`,
  style-adjustment struct, normalized centered crop geometry, Codable values,
  and `CameraSettings.clamped(exposureRange:zoomRange:)` in
  `Sources/FrameWiseCore/CameraSettings.swift`. Keep AVFoundation, UIKit,
  SwiftUI, and Core Image out of this target.

- [ ] **Step 6: Run focused and full host tests**

  Run: `swift test --filter CameraSettingsTests`

  Expected: all camera-settings tests PASS.

  Run: `swift test`

  Expected: the full existing suite and the new settings tests PASS.

- [ ] **Step 7: Commit the core contracts**

  ```text
  git add Sources/FrameWiseCore/CameraSettings.swift Tests/FrameWiseCoreTests/CameraSettingsTests.swift
  git commit -m "feat: add camera settings contracts"
  ```

### Task 2: Route settings through capture and persistence

**Files:**

- Modify: `Sources/FrameWise/CameraService.swift`
- Modify: `Sources/FrameWise/CameraViewModel.swift`

**Interfaces:**

- Consumes the `FrameWiseCore` settings contracts from Task 1.
- Produces the delegate and service methods in the Interfaces section.
- `CameraViewModel.settings` loads from `UserDefaults` key
  `com.framewise.camera.settings`, normalizes decoded values, and publishes
  changes. It also publishes the active exposure/zoom ranges and flash
  availability for the settings surface.
- `CameraViewModel.updateSettings(_:)` saves the normalized value and calls
  `service.apply(settings:)`.
- `CameraViewModel.resetSettings()` restores `CameraSettings.defaults`.
- `CameraViewModel.capturePhoto()` snapshots the current settings before any
  timer delay and uses that exact snapshot for the eventual service request.

- [ ] **Step 1: Add/extend core tests for the capture snapshot contract**

  Add `testCaptureSettingsSnapshotDoesNotChangeWhenCurrentSettingsChange`
  using a copied `CameraSettings` value, and
  `testResetSettingsRestoresAllDefaults`. Keep the tests
  hardware-independent. The snapshot test covers
  `[AC-CAMSET1014-F2]` and `[AC-CAMSET1014-F3]`; the timer lifecycle remains a
  device/manual check for `[AC-CAMSET1014-E2]`.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `swift test --filter CameraSettingsTests`

  Expected: the new snapshot/reset tests fail until the pure helpers and
  production wiring exist.

- [ ] **Step 3: Implement service configuration on the existing session queue**

  In `CameraService.swift`:

  - Store the latest settings snapshot on the session queue.
  - Apply exposure bias and zoom only after locking the active device and
    clamp to its reported range.
  - Publish the active exposure range after configuration and after camera
    flips.
  - Map Flash Auto/On/Off into `AVCapturePhotoSettings.flashMode`, falling
    back to Off when the active device/output does not support flash.
  - Apply the stored exposure and zoom settings after a successful camera flip.
  - Set supported focus and exposure points from `CameraFocusPoint` without
    changing the existing permission/session recovery behavior.
  - Pass the immutable settings snapshot to the capture delegate.

- [ ] **Step 4: Implement view-model settings, persistence, timer, and focus state**

  In `CameraViewModel.swift`:

  - Publish `settings`, `exposureRange`, `focusPoint`, and an optional integer
    countdown value.
  - Decode/encode settings with `JSONDecoder`/`JSONEncoder` and fall back to
    defaults for missing or invalid data.
  - Add `updateSettings(_:)`, `resetSettings()`, `focus(previewPoint:devicePoint:)`,
    `setZoomFactor(_:)`, and `cancelPendingCapture()`.
  - Use one cancellable `Task` for the timer; ignore a second capture while it
    is active, update the countdown once per second, and clear it on completion
    or cancellation.
  - Cancel the timer from `stop()` and before deallocation.
  - Process the delegate's capture data through the Task 3 processor before
    creating the existing `CapturedPhoto`.

- [ ] **Step 5: Build the app target and rerun host tests**

  Run: `swift test`

  Expected: host tests PASS and no core regression. The app-only AVFoundation
  code is compile-checked in the next xtool build gate.

- [ ] **Step 6: Commit the service/view-model routing**

  ```text
  git add Sources/FrameWise/CameraService.swift Sources/FrameWise/CameraViewModel.swift
  git commit -m "feat: route camera settings through capture"
  ```

### Task 3: Add capture processing and preview interaction plumbing

**Files:**

- Create: `Sources/FrameWise/CameraPhotoProcessor.swift`
- Create: `Sources/FrameWiseCore/CameraPhotoProcessingPolicy.swift`
- Modify: `Sources/FrameWise/CameraPreview.swift`

**Interfaces:**

- `CameraPhotoProcessor.process(data:settings:) -> Data` consumes a settings
  snapshot and always returns usable input/output bytes, falling back to the
  original data on decode, crop, filter, or encode failure.
- `CameraPreview` accepts an optional tap callback and reports the local
  preview point plus a normalized `CameraFocusPoint` obtained from
  `AVCaptureVideoPreviewLayer.captureDevicePointConverted`.

- [ ] **Step 1: Add the pure fallback test before image code**

  Add `CameraPhotoProcessingPolicyTests.swift` and a test named
  `testAC_CAMSET1014_E3_InvalidProcessedDataReturnsOriginalBytes`, with the
  adjacent exact ID comment `[AC-CAMSET1014-E3]`. Assert that nil or empty
  processed data returns the original non-empty bytes. Keep UIKit/Core Image
  out of this test.

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `swift test --filter CameraPhotoProcessingPolicyTests`

  Expected: RED because `CameraPhotoProcessingPolicy` does not exist.

- [ ] **Step 3: Implement the pure fallback policy and iOS processor**

  Implement `CameraPhotoProcessingPolicy.output(original:processed:)` in
  `Sources/FrameWiseCore/CameraPhotoProcessingPolicy.swift`, then use it from
  `CameraPhotoProcessor.process(data:settings:)`. The iOS processor should
  normalize the decoded `UIImage`, calculate the crop from the tested
  `CameraAspectRatio` geometry without enlarging the source, apply Core Image
  color controls and RGB multipliers from
  `CameraPhotographicStyle.adjustments`, and encode a JPEG. Return input data
  for every failed decode/crop/filter/encode path. Keep the processor behind
  the existing iOS/UIKit conditional compilation boundary.

- [ ] **Step 4: Add preview tap conversion**

  In `CameraPreview.swift`, install one tap recognizer on `PreviewView`, keep
  the callback current in `updateUIView`, and convert the tap using the
  preview layer. Do not let the preview own camera settings or session
  configuration.

- [ ] **Step 5: Run host tests and the iOS compile gate**

  Run: `swift test`

  Expected: all host tests PASS.

  Run: `xtool dev build`

  Expected: exit code 0 with the AVFoundation/UIKit/Core Image additions
  compiling successfully.

- [ ] **Step 6: Commit processing and preview plumbing**

  ```text
  git add Sources/FrameWiseCore/CameraPhotoProcessingPolicy.swift Tests/FrameWiseCoreTests/CameraPhotoProcessingPolicyTests.swift Sources/FrameWise/CameraPhotoProcessor.swift Sources/FrameWise/CameraPreview.swift
  git commit -m "feat: process camera settings in captures"
  ```

### Task 4: Build the uncluttered settings UI

**Files:**

- Create: `Sources/FrameWise/CameraSettingsSheet.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**

- `CameraSettingsSheet` receives the current `CameraSettings`,
  `CameraExposureRange`, `onChange`, and `onReset` closures.
- The sheet presents Flash, Timer, Aspect, Zoom, Exposure, and Style using the
  visual arrangement in the spec; Tap Focus remains a direct preview action.

- [ ] **Step 1: Reuse the tested settings contract at the UI boundary**

  Confirm the sheet renders only the `CaseIterable` choices and the tested
  exposure/zoom ranges from `FrameWiseCore`. Record the manual UI checks for
  `[AC-CAMSET1014-F1]` and `[AC-CAMSET1014-F9]`; no UIKit mocks or speculative
  UI test target is needed because the current package has no host-runnable
  SwiftUI test target.

- [ ] **Step 2: Run the existing tests/build before the UI change**

  Run: `swift test`

  Expected: existing host tests remain green before the SwiftUI-only change.

- [ ] **Step 3: Implement `CameraSettingsSheet`**

  Use one compact horizontal control row, a full-width exposure slider, and a
  horizontal style row. Use the existing Ink/Signal Coral tokens, subtle
  dividers only where they clarify grouping, and system controls where they
  preserve accessibility. Include Reset and a concise countdown-independent
  dismiss action.

- [ ] **Step 4: Integrate the sheet and direct gestures into `CameraScreen`**

  Add one Controls button above the unchanged dock, present the sheet, apply
  style adjustments to the preview, render the selected aspect mask, show the
  focus indicator and timer countdown, and attach a pinch gesture that updates
  the view model's clamped zoom. Preserve recovery states, storage-error
  placement, reduced-motion behavior, and existing library navigation.

- [ ] **Step 5: Build and manually inspect the layout**

  Run: `xtool dev build`

  Expected: exit code 0.

  On a simulator or connected iPhone, inspect portrait narrow-screen layout,
  Dynamic Type, dark/light appearance, reduced motion, VoiceOver labels, and
  the sheet's dismissal while the preview remains visible. Record
  `[AC-CAMSET1014-F1]`, `[AC-CAMSET1014-F9]`, and
  `[AC-CAMSET1014-S1]` from this inspection.

- [ ] **Step 6: Commit the settings surface**

  ```text
  git add Sources/FrameWise/CameraSettingsSheet.swift Sources/FrameWise/CameraScreen.swift
  git commit -m "feat: add compact camera settings sheet"
  ```

### Task 5: Documentation, full verification, and final review

**Files:**

- Modify: `README.md`
- Modify: `docs/code-walkthrough.md`

- [ ] **Step 1: Update current-state documentation**

  Add the seven settings and the single-sheet interaction to the README
  current-state summary, project structure, and camera flow. Update the code
  walkthrough to explain the settings model, service queue, snapshot capture,
  and photo-processing fallback. Do not rewrite historical camera-foundation
  design decisions; link the new design document instead.

- [ ] **Step 2: Run the complete verification set**

  Run: `swift test`

  Expected: all host tests pass with zero failures.

  Run: `xtool dev build`

  Expected: exit code 0.

  Run: `git diff --check`

  Expected: no whitespace errors.

- [ ] **Step 3: Verify acceptance-criterion traceability**

  Run: `rg -n "AC-CAMSET1014" Sources Tests docs`

  Confirm every acceptance ID in the design has either a genuine automated
  test, a file-level implementation reference, or an explicitly documented
  physical-device/manual verification note. In particular, record manual
  checks for `[AC-CAMSET1014-E1]` unsupported hardware, `[AC-CAMSET1014-E2]`
  timer cancellation, `[AC-CAMSET1014-E3]` processor fallback,
  `[AC-CAMSET1014-F1]` layout, `[AC-CAMSET1014-F4]` live exposure,
  `[AC-CAMSET1014-F5]` tap focus, `[AC-CAMSET1014-F7]` pinch zoom, and
  `[AC-CAMSET1014-S1]` permission/storage boundaries. Do not mark
  unsupported hardware behavior as host-tested.

- [ ] **Step 4: Perform final code review and Ponytail pass**

  Review `git diff HEAD~N` for accidental scope expansion, duplicated settings
  state, unneeded abstractions, silent errors, missing accessibility labels,
  and settings applied outside `CameraService`'s queue. Simplify only where
  behavior and the acceptance criteria remain intact, then rerun the affected
  verification commands.

- [ ] **Step 5: Commit documentation and final verified diff**

  ```text
  git add README.md docs/code-walkthrough.md
  git commit -m "docs: document camera settings flow"
  ```

