# Camera Foundation — Design

Date: 2026-10-13

## Goal

Replace the generated Hello World screen with a simple, camera-first shell
that can preview the selected camera and capture a still image without
embedding any future guidance overlays.

## Scope

The first implementation slice includes:

- FrameWise Open Crop branding in the app icon and launch opener.
- Rear and front camera selection.
- Camera permission request and recovery states.
- Full-screen live camera preview.
- Still-photo capture.
- A rounded bottom control dock with a library button, shutter, and camera
  flip control.
- Accessible labels and minimum 44 pt touch targets.
- Graceful unavailable and capture-error states.

The library button is a rounded entry point for the captured-photo/library
surface. Full photo-library browsing and saving workflows are deferred to a
later slice unless required by the platform capture flow.

The following are explicitly out of scope:

- Composition guides and overlay rendering.
- Vision/Core ML analysis and AI Auto.
- Reference-photo alignment.
- Focus/exposure controls.
- Voice guidance.
- Cloud services.

## Branding and opener

The selected Open Crop symbol is the app logo. The app icon uses a simplified
symbol-only version on a White rounded-square tile with Ink geometry and a
Signal Coral center diamond so it remains legible at small sizes while keeping
the two approved brand colors visible in the mark.

The app opens with a short branded opener while camera initialization is in
progress. It uses an Ink background, the Open Crop symbol, and the tightened
`FrameWise` lockup with the `Frame` and `Wise` word groups optically closer
together. The lockup fades and scales in gently, then transitions to the
camera preview as soon as initialization is ready. There is no artificial
wait added solely for the animation.

Reduced Motion removes the scale movement and keeps only a simple opacity
transition. Permission and hardware errors replace the opener with the
appropriate recovery state rather than leaving the user on a branded screen.

## User experience

The app opens directly to a full-screen camera preview. The preview remains
the dominant visual element. A rounded dark control dock sits above the home
indicator and contains:

1. A small library/last-photo button on the left.
2. A large circular shutter button in the center.
3. A circular camera-flip button on the right.

The dock stays visually quiet and does not introduce settings or additional
controls in this slice. Permission and failure states replace the preview
with concise explanatory text and one rounded recovery action, such as
`Allow Camera` or `Try Again`.

## Architecture

`CameraService` owns AVFoundation session setup, camera selection, permission
state, and photo capture. It runs session work on a dedicated serial queue so
session configuration and start/stop operations do not block SwiftUI.

`CameraPreview` is a small `UIViewRepresentable` that hosts an
`AVCaptureVideoPreviewLayer`. It receives the service's session and is
responsible only for displaying the live feed.

`CameraViewModel` is the SwiftUI-facing state boundary. It translates
service events into display states such as permission required, unavailable,
ready, running, and capture failed. It exposes user intents for starting the
camera, flipping cameras, and capturing a photo.

`BrandIntroView` owns only the branded opener animation. It receives the
camera initialization state from the app shell and does not configure
AVFoundation or add an independent timer. The Open Crop symbol is a reusable
SwiftUI shape so the opener and fallback UI do not depend on raster scaling.

`ContentView` composes the preview, state/recovery UI, and rounded control
dock. It does not configure AVFoundation directly.

The service exposes protocol-backed dependencies for permission and capture
coordination where needed by tests. Tests must not require a physical camera;
device verification is reserved for the preview, permission prompt, camera
switch, and actual capture path.

## Capture behavior

- The default camera is the rear wide-angle camera when available.
- The front camera is used when the user taps the flip control.
- If a requested camera is unavailable, the current camera remains active and
  the UI reports a recoverable error.
- Captured photos contain only the camera image. Guidance and reference
  overlays do not exist in this slice and must not be composited into the
  captured output.
- Capture failures leave the preview usable and expose a concise retry path.

## Accessibility and resilience

- Library, shutter, and flip controls have VoiceOver labels and hints.
- Controls meet a minimum 44 pt touch target.
- Permission denial explains how to recover through system settings.
- If no camera is available, the app presents a clear unavailable state
  instead of a blank preview.
- The control dock and recovery actions support Dynamic Type without covering
  the preview or home indicator.
- The opener's symbol, wordmark, and animation remain readable with Reduced
  Motion enabled.

## Acceptance criteria

- The app opens into the camera-first layout rather than Hello World.
- The app icon uses the Open Crop symbol-only mark with the approved Ink and
  Signal Coral colors.
- The opener presents the tightened FrameWise lockup and fades into the camera
  without an artificial delay.
- A user can grant camera access and see a live preview.
- A user can switch between rear and front cameras when both are available.
- A user can capture a still photo without guidance UI burned into it.
- The rounded dock contains only library, shutter, and camera-flip controls.
- Permission denial, unavailable hardware, and capture failure have clear
  recovery states.
- Camera state transitions are covered by tests that run without hardware.
