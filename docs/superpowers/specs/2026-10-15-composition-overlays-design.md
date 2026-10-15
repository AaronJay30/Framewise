# Composition Overlays — Design

Date: 2026-10-15  
Feature SLUG: `COMP1015`  
Status: Design approved in conversation

## Intent

FrameWise should let a photographer place a quiet composition guide over the
live camera preview without changing the camera-first experience or embedding
the guide in a captured image. The first slice focuses on static geometric
guides that are useful immediately and do not require scene analysis or motion
sensor data.

The control should feel like Photographic Styles: a new top-row Composition
button opens a dedicated settings sheet. The sheet uses a black, camera-blended
surface with borderless guide choices rather than separate card backgrounds.

## Scope

### Included in this slice

- Rule of thirds.
- Centre cross.
- Quadrant grid with subtle quadrant treatment.
- Rule of fifths.
- Golden ratio / Phi grid.
- Golden spiral in one fixed canonical orientation.
- Golden triangle in one fixed canonical orientation.
- Diagonal/X-frame.
- A static horizon reference line.
- Guide selection persistence through the existing camera settings store.
- Adjustable guide opacity.
- Accessibility labels, selected state, and Reduced Motion behavior.

### Deferred

- Live horizon leveling driven by Core Motion.
- Rotatable golden spiral and golden triangle variants.
- Dynamic symmetry / armature systems.
- Perspective rays and configurable vanishing points.
- Aspect-ratio target frames beyond the existing camera aspect selection.
- Action/title-safe areas.
- AI recommendation or scene analysis.

## Shared understanding

- The live camera preview remains the primary visual element.
- Composition is a separate concern from Photographic Styles, with its own
  top control and sheet.
- Guide choices inside the sheet have no borders, capsules, or individual
  backgrounds; selection is communicated with Signal Coral and a checkmark.
- Selecting a guide updates the preview immediately and leaves the sheet open
  so the photographer can compare guides and adjust opacity.
- Selecting `Off` removes the guide without changing any camera settings.
- Guides are view-only and must never be passed into photo processing.

## User interface

### Top control

`CameraTopControls` gains a Composition button beside Photographic Styles. It
uses the existing horizontal `ViewThatFits` behavior, so the controls remain
usable on narrow devices by scrolling horizontally when necessary.

The button is active when a guide other than `Off` is selected. Its
accessibility value reports the selected guide title, or `Off` when no guide is
active.

### Composition sheet

`CompositionGuideSheet` follows the existing Photographic Styles sheet
structure while remaining a separate presentation:

- Black presentation background.
- Header titled `Composition` with a 44-point close target.
- Horizontally scrollable miniature guide previews.
- No tile border, capsule, or separate tile background.
- Signal Coral linework and a checkmark for the selected guide.
- `Off` appears first.
- An opacity slider appears below the guide previews.
- `.medium` and `.large` presentation detents, matching the existing settings
  sheet behavior.

Each miniature preview is a real rendering of the corresponding normalized
guide geometry so the user can recognize the choice before applying it.

## State and persistence

Add a hardware-independent `CameraCompositionGuide` enum in
`FrameWiseCore` with `CaseIterable`, `Codable`, `Equatable`, and `Sendable`
conformance. Add these fields to `CameraSettings`:

- `compositionGuide`, defaulting to `.off`.
- `compositionGuideOpacity`, defaulting to `0.60`.

The user-facing opacity range is `0.20...1.00`. `CameraSettings.normalized()`
clamps invalid, non-finite, or out-of-range values to that safe range.

The custom `CameraSettings` decoder treats both new fields as optional. A
settings payload written before this feature therefore restores with `Off` and
the default opacity while preserving the existing camera choices. Resetting
camera settings also resets composition selection and opacity.

Composition fields do not participate in
`CameraSettings.hardwareChanges(from:)`. The camera service receives the same
settings snapshot boundary as before but ignores composition-only fields.

## Rendering architecture

The camera preview remains the source of truth for the overlay bounds. Inside
the existing preview `ZStack`, the order is:

1. Styled camera preview.
2. `CompositionGuideOverlay` when a guide is active.
3. Focus/exposure overlay.
4. Timer countdown.

The guide overlay uses deterministic SwiftUI `Path` drawing normalized to the
actual preview width and height. It uses `.allowsHitTesting(false)` so tap to
focus, exposure dragging, pinch zoom, and the rest of the camera controls keep
their current interaction behavior.

Line rendering uses thin white strokes with the stored opacity and a restrained
shadow for contrast. Guide selection changes use a short opacity transition;
Reduced Motion removes the transition.

### Geometry definitions

- Rule of thirds: vertical and horizontal lines at `1/3` and `2/3`.
- Centre cross: vertical and horizontal lines at `0.5`.
- Quadrant grid: centre cross plus very low-opacity quadrant treatment.
- Rule of fifths: lines at `1/5`, `2/5`, `3/5`, and `4/5`.
- Golden ratio: lines at `1/phi` and `1 - 1/phi`, approximately `0.382`
  and `0.618`.
- Golden spiral: a deterministic sequence of quarter arcs generated from
  nested golden rectangles in one fixed orientation.
- Golden triangle: a deterministic diagonal and perpendicular construction in
  one fixed orientation.
- Diagonal/X-frame: both corner-to-corner diagonals.
- Horizon: a centered horizontal reference line.

The selected camera aspect ratio changes the preview bounds, and the overlay
uses those same bounds. No guide is drawn into the captured image or the
processed library bytes.

## Data flow and failure behavior

```text
Composition button
  -> CompositionGuideSheet
      -> CameraSettings update
          -> CameraViewModel persistence
          -> CameraScreen preview overlay
```

Invalid persisted opacity is normalized. Missing composition fields in older
settings payloads use safe defaults. Composition rendering has no external
resource or network dependency, so a drawing issue cannot block camera startup,
capture, or library storage. Existing permission, hardware, capture, and
storage recovery flows remain unchanged.

## Accessibility and privacy

- Every guide choice has a descriptive VoiceOver label and selected trait.
- The opacity control announces its percentage.
- Guide meaning is conveyed by geometry and text, not color alone.
- Hit targets remain at least 44 points.
- Reduced Motion avoids spatial or animated guide movement.
- Guide state is local `UserDefaults` data only.
- No guide, label, or selection metadata is uploaded or written into photo
  pixels.

## Acceptance criteria

### Functional

- `[AC-COMP1015-F1]` The camera top controls expose a separate Composition
  button beside Photographic Styles.
- `[AC-COMP1015-F2]` Activating Composition opens a dedicated black,
  camera-blended settings sheet.
- `[AC-COMP1015-F3]` The sheet offers Off, Rule of Thirds, Centre Cross,
  Quadrant Grid, Rule of Fifths, Golden Ratio, Golden Spiral, Golden Triangle,
  Diagonal/X-Frame, and Horizon.
- `[AC-COMP1015-F4]` Selecting a guide updates its overlay over the live
  preview without dismissing the sheet.
- `[AC-COMP1015-F5]` The overlay geometry follows the selected preview aspect
  ratio and remains aligned to the visible camera frame.
- `[AC-COMP1015-F6]` The opacity slider changes guide visibility within the
  supported range.
- `[AC-COMP1015-F7]` Guide selection and opacity persist through the existing
  settings persistence path.
- `[AC-COMP1015-F8]` Resetting camera settings turns composition guides Off and
  restores default opacity.
- `[AC-COMP1015-F9]` The static guide remains visible while the preview is
  running and does not interrupt focus, exposure, pinch zoom, or capture.

### Security and privacy

- `[AC-COMP1015-S1]` Composition guides remain local view state and are never
  uploaded or embedded in captured photo bytes.

### Edge cases

- `[AC-COMP1015-E1]` Settings saved before composition fields existed decode
  with Off and default opacity while preserving other settings.
- `[AC-COMP1015-E2]` Non-finite or out-of-range persisted opacity normalizes to
  the supported range.
- `[AC-COMP1015-E3]` Reduced Motion disables guide transition animation while
  preserving the selected geometry.
- `[AC-COMP1015-E4]` The guide sheet remains usable on narrow screens through
  horizontal scrolling and Dynamic Type-compatible labels.

## Verification plan

### Automated

- Add host tests for guide enumeration, titles, defaults, Codable round trips,
  legacy decoding, opacity normalization, and reset behavior.
- Run `swift test`.
- Run `xtool dev build`.
- Run `git diff --check`.
- Search implementation and tests for all `AC-COMP1015-*` identifiers.

### Device checks

- Open and close the Composition sheet from the physical camera.
- Select every guide and compare its miniature preview with the live overlay.
- Switch between 4:3, 1:1, and 16:9 while each guide is active.
- Adjust opacity from minimum to maximum.
- Confirm selection survives leaving and reopening the camera.
- Confirm focus, exposure, pinch zoom, timer, and shutter behavior remain
  responsive.
- Capture photos and confirm no guide lines or guide styling appear in the
  saved library image.
- Verify VoiceOver, large text, Reduce Motion, and Reduce Transparency.

## Planned implementation files

- Create `Sources/FrameWiseCore/CompositionGuide.swift`.
- Create `Sources/FrameWise/CompositionGuideSheet.swift`.
- Create `Tests/FrameWiseCoreTests/CompositionGuideTests.swift`.
- Modify `Sources/FrameWiseCore/CameraSettings.swift`.
- Modify `Sources/FrameWise/CameraControls.swift`.
- Modify `Sources/FrameWise/CameraScreen.swift`.
- Extend `Tests/FrameWiseCoreTests/CameraSettingsTests.swift`.
- Update `README.md` and `docs/code-walkthrough.md` after verification.

## Deferred follow-up

The next design should separately specify live horizon leveling, dynamic
symmetry, perspective rays, technical safe areas, and any orientation controls
for spiral and triangle variants. Those features should not expand this first
implementation without a new approved design.
