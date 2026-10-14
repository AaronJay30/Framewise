# Camera Settings — Design

Date: 2026-10-14

Feature SLUG: `CAMSET1014`

## Goal

Add a compact, camera-first settings surface for the first seven practical
controls: Flash, Timer, Exposure, Tap Focus, Aspect, Zoom, and an app-defined
Photographic Style.

The preview and the existing library/shutter/flip dock remain visually
dominant. Settings are available from one controls entry point instead of
adding seven persistent buttons to the camera screen.

## User intent and constraints

- The user wants the first camera settings slice, not a complete replacement
  for Apple's Camera app.
- The controls must not make the camera screen feel crowded.
- The existing still-photo capture and local library flow must continue to
  work.
- Hardware-dependent controls must degrade gracefully on devices that do not
  support them.
- The app remains offline-first; this feature adds no network behavior.

## Scope

### Included

1. Flash: Auto, On, and Off when the active camera has a flash.
2. Timer: Off, 3 seconds, 5 seconds, and 10 seconds.
3. Exposure: a device-bounded exposure compensation slider, centered at 0 EV.
4. Tap Focus: tapping the preview sets the active camera focus and exposure
   point and shows a short-lived focus indicator.
5. Aspect: 4:3, 1:1, and 16:9 preview framing and saved-photo crop.
6. Zoom: pinch-to-zoom with a device-bounded zoom factor and a compact current
   value in the controls surface.
7. Photographic Style: app-defined Standard, Vivid, Warm, Cool, and Mono
   looks, applied consistently to the preview treatment and captured photo.

### Explicitly deferred

- Live Photo capture.
- Apple's private Photographic Styles implementation or model-specific tone,
  warmth, texture, and grain controls.
- Portrait depth, Night mode, ProRAW, macro lens switching, video modes,
  cinematic focus, and computational photography pipelines.
- A second permanent toolbar or a settings screen outside the camera flow.

## Visual design

The camera screen keeps the current bottom dock unchanged:

```text
                         [ Controls ]

                       Camera preview
                      [focus indicator]

                 [Library] [Shutter] [Flip]
```

The Controls button is a single compact sliders button placed above the
existing dock. It presents a bottom sheet with three quiet groups:

```text
              Camera Controls

        [Flash] [Timer] [Aspect] [Zoom]

        Exposure  ───────●────────  0.0

        Style   Standard  Vivid  Warm  Cool  Mono
```

- Flash, Timer, Aspect, and Zoom use compact selectable controls in one
  horizontally scrollable row so the sheet does not become a dense grid on
  narrow phones.
- Exposure gets the full available width because it is continuous rather than
  a small set of choices.
- Styles use a horizontally scrollable chip/preview row; only one is selected.
- Tap Focus is intentionally direct manipulation on the preview, so it does
  not consume a permanent control slot.
- The sheet respects a minimum 44 pt hit area, Dynamic Type, color scheme, and
  reduced-motion settings already used by the camera screen.

## Architecture

### Core settings model

Add hardware-independent, `Equatable`, `Codable`, `Sendable` values in
`FrameWiseCore`:

- `CameraFlashMode`
- `CameraTimerDuration`
- `CameraAspectRatio`
- `CameraPhotographicStyle`
- `CameraSettings`

`CameraSettings` stores the selected flash, timer, exposure bias, aspect
ratio, zoom factor, and style. It provides defaults and pure clamping or
normalization helpers where a value has a known invariant. Device-specific
limits remain in the AVFoundation service.

### AVFoundation service

`CameraService` remains the only owner of session and device configuration.
All device changes run on its existing serial session queue:

- flash is mapped into `AVCapturePhotoSettings.flashMode` for each capture;
- exposure bias is applied to the active `AVCaptureDevice` while holding its
  configuration lock;
- tap focus converts a preview point into a device point and updates supported
  focus/exposure points;
- zoom clamps to the active device's `minAvailableVideoZoomFactor` and
  `maxAvailableVideoZoomFactor`;
- camera flips reapply the current exposure and zoom values within the new
  device's supported range.

Unsupported hardware does not crash or remove the preview. The view model
keeps the selected value while the service ignores an unsupported operation
or reports a recoverable configuration failure when the operation is required
for capture.

### View model and persistence

`CameraViewModel` publishes `CameraSettings` and exposes user intents for
updating each setting. It owns the timer task so the service only receives a
capture request after the selected delay. A second shutter tap while a timer
is active is ignored until that request completes.

The selected settings are persisted in the app's existing local scope and
restored when the view model starts. A Reset action returns to the defaults:
Flash Auto, Timer Off, Exposure 0 EV, Aspect 4:3, device minimum zoom, and
Standard style.

### Photo processing

The existing capture delivery remains the boundary for saved photos. A small
photo-processing step applies the selected aspect crop and style before the
photo enters the existing `CapturedPhoto`/library flow. If processing cannot
decode or encode a photo, the original capture is delivered and the preview
remains usable; the failure is not allowed to discard a successful camera
capture.

## Behavior and edge cases

- Flash controls are disabled or hidden when the active device has no flash;
  capture remains available.
- Exposure values are clamped to the active device's reported minimum and
  maximum bias. A device without exposure-bias support keeps automatic
  exposure.
- Focus taps outside the preview are ignored. A device without focus-point
  support keeps continuous autofocus.
- Zoom never sends a value outside the active device's range and resets to a
  valid value when flipping to a camera with a narrower range.
- Aspect cropping is centered and does not upscale the captured image.
- Timer cancellation on view disappearance prevents a delayed capture after
  leaving the camera screen.
- Style processing failure falls back to the unstyled captured image rather
  than failing the capture.
- Permission denial, unavailable hardware, and existing capture failure
  recovery remain unchanged.

## Security and privacy

- The feature uses the existing camera permission boundary and does not
  request new permissions.
- Settings contain no user identity or external data and are stored locally.
- Photo data remains in the existing app-private capture pipeline; no network
  calls or third-party processing are introduced.

## Verification strategy

- Add hardware-independent tests for defaults, Codable persistence values,
  supported choices, reset behavior, and invariant clamping.
- Add pure tests for aspect crop geometry and style parameter mapping.
- Run the complete Swift test suite and the documented `xtool dev build`.
- On a physical iPhone, manually verify the permission path, flash
  availability, timer delay/cancellation, exposure response, focus indicator,
  aspect crop, pinch zoom, style preview/capture, and VoiceOver labels.

## Acceptance criteria

- [AC-CAMSET1014-F1] A single Controls entry point opens the camera settings
  sheet without changing the existing library/shutter/flip dock.
- [AC-CAMSET1014-F2] The settings sheet exposes Flash Auto/On/Off and each
  supported choice is used for the next still capture.
- [AC-CAMSET1014-F3] The settings sheet exposes Timer Off/3s/5s/10s and a
  shutter request waits for the selected delay before capture.
- [AC-CAMSET1014-F4] The Exposure control changes the active device's exposure
  bias within its supported range and displays the current value.
- [AC-CAMSET1014-F5] A tap on the preview updates the supported focus and
  exposure point and presents a visible focus indicator.
- [AC-CAMSET1014-F6] Aspect choices are 4:3, 1:1, and 16:9, and the selected
  framing is reflected in both preview and saved photo output.
- [AC-CAMSET1014-F7] Pinch-to-zoom changes the active camera zoom without
  exceeding device limits, and the current zoom is visible in Controls.
- [AC-CAMSET1014-F8] The style row offers Standard, Vivid, Warm, Cool, and
  Mono, and the selected app-defined style is reflected in preview and output.
- [AC-CAMSET1014-F9] All settings controls meet the existing 44 pt touch-target
  and accessibility-label requirements and remain usable with Dynamic Type.
- [AC-CAMSET1014-E1] Unsupported flash, focus, exposure, or zoom capabilities
  leave the preview usable and do not crash or discard the capture.
- [AC-CAMSET1014-E2] Leaving the camera while a timer is pending cancels the
  delayed capture.
- [AC-CAMSET1014-E3] A photo-processing failure preserves the original photo
  capture and keeps the camera recoverable.
- [AC-CAMSET1014-S1] The feature retains the existing camera permission and
  app-private storage boundaries and introduces no network photo processing.
