# FrameWise code walkthrough

This is the short map for walking through the camera foundation in the
repository. The code is intentionally split by responsibility so a screen
can be read from the outside in.

## Start here

1. `Sources/FrameWise/FrameWiseApp.swift` is the app entry point. It creates
   the SwiftUI scene and hands the first screen to `ContentView`.
2. `Sources/FrameWise/ContentView.swift` is the composition root. It owns one
   `CameraViewModel` and one `CapturedPhotoStore`, then places the camera root
   inside a `NavigationStack`; it does not configure AVFoundation directly.
3. `Sources/FrameWise/CameraViewModel.swift` is the bridge between service
   callbacks and SwiftUI. Its published `CameraState` and active photo
   resolution capability are what the views render, while it also restores
   settings, owns the timer/focus lifecycles, and turns each valid capture into
   a UUID-backed `CapturedPhoto` in a pending delivery queue until private
   storage accepts it.
4. `Sources/FrameWise/CameraService.swift` owns the AVFoundation session,
   camera selection, permissions, settings application, and photo capture. It
   keeps session work on its own queue so the UI stays responsive.

## Camera settings and capture flow

`Sources/FrameWiseCore/CameraSettings.swift` is the hardware-independent
contract for Flash, Timer, Exposure, Tap Focus, Aspect, Zoom, the five
app-defined Photographic Styles, the Standard/Maximum photo-resolution intent,
and the static `CameraCompositionGuide` catalog. It provides safe defaults,
Codable values for local persistence, normalized focus points, centered crop
geometry, pure style adjustments, and safe composition opacity normalization.
`CameraPhotoResolutionCapability` turns supported format dimensions into a
smallest Standard and largest distinct Maximum without assuming a particular
sensor. `CameraSettingsTests` and
`CompositionGuideTests` cover the choices, invariants, Codable round trips,
legacy settings decoding, reset behavior, and capture snapshot behavior on the
host.

`CameraScreen` uses `CameraTopControls` for cycling Flash, Timer, and Aspect;
Tap Focus places a `FocusExposureOverlay` beside the reticle, Styles opens the
adjustable `CameraSettingsSheet`, Composition opens the separate black
`CompositionGuideSheet`, and Resolution opens `CameraResolutionSheet` without
dismissing when the setting changes. Composition and Resolution are icon-only
top-row controls with descriptive accessibility labels/values.
`CameraZoomControls` places supported presets inside the preview. These views
live in `CameraControls.swift`, whose
`CameraGlass` modifier selects native Liquid Glass on iOS 26+, a legacy
material fallback, or opaque black when Reduce Transparency is enabled.
The bottom dock retains only Library/Shutter/Flip.

The preview uses `CameraAspectRatio.previewSize` to fit the selected aspect
into the available space. Its actual frame changes between square, portrait
4:3, and portrait 16:9; there is no fixed 3:4 crop-mask container. The preview
layer center-fills that frame, while photo processing uses the same selected
aspect for its centered `cropRect`. Preview and photo connections
use device-aware rotation coordinators, refreshed on camera changes, rather
than assuming every sensor uses a 90-degree portrait rotation. The service
publishes only the device ID to the main actor; preview rotation follows the
coordinator's observed updates. Tap Focus and pinch stay on the preview itself,
not the zoom controls above it. Long-pressing the reticle locks focus; the
attached vertical line maps upward dragging to positive EV and downward
dragging to negative EV. The user-facing range caps wide device ranges at ±2 EV.
Zoom buttons have explicit touch shapes and a non-interactive glass background.
`CameraControlTests` covers wraparound cycling, exposure drag direction/limits,
preview sizing, ruler coordinates, hardware-change selection, and
`CameraZoomScale` conversion and supported preset filtering.

`CameraService` applies device-dependent exposure, zoom, flash, focus, and
photo dimensions on its serial session queue. It reads the active format's
supported maximum photo dimensions, publishes the calculated capability, sets
the output maximum before capture, and chooses Standard or the supported
Maximum on each `AVCapturePhotoSettings` request. A capture stores its immutable `CameraSettings`
snapshot by photo request ID before it enters the existing callback boundary,
so a later settings change cannot alter that photo's processing choice. The
active camera publishes exposure and zoom ranges plus flash availability after
configuration and flips.

Focus locking changes only the focus mode, leaving continuous exposure available
for the attached exposure control.

The service compares requested exposure/zoom against the last applied settings
before locking the device. Preset zoom uses the device's native ramp; pinch and
Reduce Motion use direct updates. A pinch takes its starting zoom from the
actual device position on the session queue, so interrupting a preset ramp
does not jump to its unfinished target. Capture cancels any ramp before applying
its snapshot. Capability callbacks are not repeated for every drag update, and the
preview layer's session is only assigned when its identity changes. Settings
persistence is debounced by 250 ms, with an explicit flush on stop/resign-active.

Photographic styles are represented by pure adjustment values plus a persisted
intensity. The style studio uses generated gradient artwork rather than a
placeholder photo, while the same interpolated adjustments are applied to the
live preview and processed capture.

## Composition overlay flow

`CameraCompositionGuide` is deliberately hardware-independent. The separate
Composition button uses the existing top-row scrolling behavior and reports the
selected guide to VoiceOver. `CompositionGuideSheet` keeps the guide choices
borderless and black-blended, uses real miniature renderings, leaves the sheet
open while selection changes, and binds the 20–100% opacity slider directly to
the persisted `CameraSettings` value.

`CameraCompositionGeometry` supplies 160 normalized samples of a logarithmic
golden-ratio spiral. Its fixed orientation starts in the lower-right focal
region and opens toward the upper-left; normalization keeps the curve inset
for portrait, square, and landscape bounds. `CompositionGuideOverlay` and
`CompositionGuideArtwork` share one deterministic Canvas renderer for the
live preview and sheet thumbnails. The renderer draws
the first static catalog—thirds, centre cross, quadrant, fifths, golden ratio,
golden spiral, golden triangle, Diagonal/X-Frame, and horizon—inside the actual
aspect-sized preview frame. It is inserted after the styled preview and before
focus/exposure and countdown layers, with hit testing disabled and a reduced-
motion-aware opacity transition. `CameraPhotoProcessor` receives only the
aspect and photographic-style inputs it needs; composition fields are excluded
from that processing boundary, so guides are view-only and never modify
captured photo pixels.

Live horizon leveling, dynamic symmetry, perspective rays, target aspect/safe
areas, rotatable variants, and AI recommendations remain deferred to a later
design.

Rear-camera selection prefers triple/dual-wide/dual virtual devices before
falling back to the wide-angle camera. On iOS 18+, the system's display zoom
multiplier translates hardware zoom into familiar .5/1x/2x values; iOS 17
uses the first ultrawide-to-wide switch-over factor. Both published bounds and
applied zoom use the same scale, so a .5 selection is not silently clamped to 1.

`Sources/FrameWise/CameraPhotoProcessor.swift` normalizes the captured image,
applies centered aspect cropping and the selected style, then encodes the
result for the existing library flow. `CameraPhotoProcessingPolicy` is the
small pure fallback contract: if processing cannot decode, filter, crop, or
encode, the original capture bytes continue through storage. Processing is
serialized for capture order but runs off the main actor. Its invalid-data test
runs in the host suite; UIKit/Core Image execution is compile-checked by
`xtool dev build`.

## Composition acceptance traceability

The implementation and host/build evidence map to the approved `COMP1015`
criteria below. The physical-device pass remains pending for interaction,
accessibility, and saved-image confirmation.

- `[AC-COMP1015-F1]` and `[AC-COMP1015-F2]`: `CameraTopControls` presents a
  separate Composition button and `CompositionGuideSheet` uses a dedicated
  black sheet.
- `[AC-COMP1015-F3]`: `CameraCompositionGuide.allCases` and
  `CompositionGuideTests` cover the complete ordered catalog.
- `[AC-COMP1015-F4]`, `[AC-COMP1015-F5]`, and `[AC-COMP1015-F6]`:
  `CompositionGuideSheet` keeps selection and opacity changes live while the
  shared artwork follows the aspect-sized preview frame.
- `[AC-COMP1015-F7]` and `[AC-COMP1015-F8]`: `CameraSettings` Codable,
  normalization, and reset tests cover persistence and defaults.
- `[AC-COMP1015-F9]`: the preview ZStack places the non-interactive guide
  below focus/exposure and countdown layers.
- `[AC-COMP1015-S1]`: the guide exists only in SwiftUI preview/sheet code;
  `CameraPhotoProcessor` receives no composition fields and remains guide-free.
- `[AC-COMP1015-E1]` and `[AC-COMP1015-E2]`: legacy decoding and safe opacity
  normalization are covered by `CompositionGuideTests`.
- `[AC-COMP1015-E3]`: Reduced Motion selects an identity transition while
  retaining the same guide geometry.
- `[AC-COMP1015-E4]`: the guide row scrolls horizontally and labels use
  Dynamic Type-compatible SwiftUI text styles.

## Camera resolution and library-preview traceability

- `[AC-CAMLIB1015-F1]` and `[AC-CAMLIB1015-F2]`: the pure geometry provider
  supplies a continuous, normalized lower-right-to-upper-left Golden Spiral;
  the Canvas maps it into the live and miniature preview bounds.
- `[AC-CAMLIB1015-F3]` and `[AC-CAMLIB1015-F4]`: Composition is an icon-only,
  backgroundless top control, and guide/library camera surfaces have no
  decorative shadow.
- `[AC-CAMLIB1015-F5]`, `[AC-CAMLIB1015-F6]`, `[AC-CAMLIB1015-F7]`, and
  `[AC-CAMLIB1015-F8]`: persisted resolution intent, active-format capability,
  per-capture dimension selection, and unsupported fallback are split between
  `CameraSettings`, `CameraPhotoResolution`, `CameraService`, and the host
  resolution tests.
- `[AC-CAMLIB1015-F9]` and `[AC-CAMLIB1015-F10]`: Library passes ordered IDs,
  uses aspect-safe tiles, and presents a full-width black camera bar.
- `[AC-CAMLIB1015-F11]`, `[AC-CAMLIB1015-F12]`, and
  `[AC-CAMLIB1015-F13]`: `PhotoPreviewView` pages with `TabView`, toggles its
  action inset with an accessibility action, and chooses the next/previous
  neighbor after deletion through the core helper.
- `[AC-CAMLIB1015-E1]` and `[AC-CAMLIB1015-E2]`: legacy settings and
  empty/single resolution capabilities are covered by the host-side core
  tests. `[AC-CAMLIB1015-E3]` through `[AC-CAMLIB1015-E5]` and
  `[AC-CAMLIB1015-S1]` are implemented at the camera/UI boundaries and remain
  device checks where camera flips, malformed image recovery, paging, tap
  interaction, accessibility, and motion settings are involved.

## Persistent captured-photo flow

`Sources/FrameWiseCore/CapturedPhoto.swift` is the hardware-independent photo
value. `CapturedPhotoLibrary` owns newest-first ordering and the narrow
export/delete mutations used by the UI.

`Sources/FrameWiseCore/CapturedPhotoDiskStore.swift` is an actor-backed private
storage boundary. It keeps one captured image file per UUID, an atomic JSON
manifest, and a manifest backup under `Application Support/FrameWise/Photos`.
Loading the manifest restores the same order after a fresh app launch; backup
recovery and tolerant loading preserve healthy records when another image is
missing, while unrecoverable storage problems surface as typed errors instead
of silently disappearing.

`Sources/FrameWise/CapturedPhotoStore.swift` bridges that actor to SwiftUI. A
capture is validated and written before it is published to the Library; a
failed write stays queued with a visible retry path. The store also persists
the exported flag only after PhotoKit reports success, coordinates in-flight
exports across preview instances, and removes the private file before
publishing a FrameWise-only deletion.

The screen flow is:

```text
Camera
  ├─ capture -> private app storage -> held card smoothly shrinks to dock thumbnail
  └─ Library
       ├─ By Day -> date group -> three-column gallery -> Preview
       └─ All Photos -> three-column gallery -> Preview
                                      ├─ swipe -> neighboring gallery photo
                                      ├─ tap -> hide/reveal action section
                                      ├─ Share -> native UIActivityViewController
                                      ├─ Save -> PhotoKit add-only export of a copy
                                      ├─ Delete -> private FrameWise file/manifest only
                                      └─ Edit -> visible disabled placeholder
```

`CapturedPhotoGrouping` assigns each capture to a local calendar day while
preserving newest-first order. `LibraryView` presents those groups and the
All Photos mode; `PhotoGalleryView` passes each gallery's ordered IDs into
Preview and renders each decoded image with its own aspect ratio and
`scaledToFit`, so a 16:9 image uses the available width without a square crop.
The full-width black Camera bar dismisses back to the existing camera root.
`PhotoPreviewView` uses a `TabView(selection:)` for horizontal paging, keeps
healthy pages available when another image is malformed, and toggles its black
action section from the image area with an explicit accessibility action and
Reduce Motion-aware transition. `PhotoPreviewSelection` chooses the next ID,
the previous ID when the last page is removed, or no ID for the only photo.
The camera screen stops the existing session while Library is visible and
starts that same configured service again when Camera reappears.

PhotoKit is intentionally limited to `PHPhotoLibrary` add-only authorization
for an explicit Preview Save. FrameWise requests no Photos read permission and
does not send images to a network service.

## The testable state boundary

`Sources/FrameWiseCore/CameraState.swift` contains plain Swift enums only.
`CameraState` describes what the UI can safely show, while `CameraEvent`
describes facts or user recovery actions.

`Sources/FrameWiseCore/CameraStateReducer.swift` is a pure function:

```text
current state + one event -> next state
```

For example, a successful startup goes through:

```text
initializing
  -> sessionConfigured -> ready
  -> sessionStarted    -> running
```

If capture fails, the preview remains recoverable:

```text
running -> captureFailed -> retry -> initializing
```

Because this target does not import SwiftUI, UIKit, or AVFoundation, the
transition tests can run on the host without an iPhone or camera hardware.

## Brand flow

`Sources/FrameWiseCore/BrandingTokens.swift` is the single source of truth
for the approved Ink and Signal Coral hex values. It also answers whether the
opener belongs on screen: only `initializing` and `requestingPermission` keep
the opener active. Permission, hardware, and capture failures therefore
replace the opener with a recovery state instead of trapping the user behind
branding.

The SwiftUI branding files turn those tokens into reusable symbol and lockup
views. The app icon uses the symbol-only asset; the opener uses the tightened
`FrameWise` lockup. `Resources/FrameWiseAppIcon.png` is the single icon source:
black background, white frame, and coral center. `xtool.yml` packages it
directly through `iconPath`, avoiding the experimental asset-catalog compiler.
iOS may still render Dark and Clear Home Screen treatments automatically;
Clear is presented as monochrome glass. `FrameWiseBrand` chooses a light or
dark surface and a contrasting framing/wordmark color from the system color
scheme.
The opener mark settles into place first, then the wordmark follows. The
camera starts immediately in parallel, while the opener stays visible for at
least 2.5 seconds and longer only if camera startup is still in progress.
Reduce Motion replaces the spatial entrance with a short opacity transition.

## How to verify the core

From the project directory, run:

```text
swift test
xtool dev build
```

The host suite covers camera/branding state, camera settings contracts,
resolution capability/persistence, processing fallback, captured-photo ordering
and export/deletion state, preview neighbor selection, disk restore ordering,
manifest corruption, missing images, and app-private removal. `xtool dev build`
covers the SwiftUI, AVFoundation, UIKit, Core Image, and PhotoKit adapters that
cannot run on the host. Physical-device checks are still required for actual
maximum megapixel labels/output dimensions, timer cancellation on disappearance,
focus/exposure response, flash behavior, and accessibility across device
sizes. Also verify 16:9 tile fitting, paging, tap-to-toggle controls, VoiceOver,
Reduce Motion, and camera-flip capability refresh on a connected iPhone. The
2026-10-15 verification run had no connected iPhone (`idevice_id -l` could not
retrieve a device list), so actual maximum output dimensions, 16:9 viewport
fit, paging, tap behavior, and accessibility remain device checks. The
remaining manual acceptance map is `[AC-CAMSET1014-F1]` and
`[AC-CAMSET1014-F9]` for top controls, styles layout, and touch targets,
`[AC-CAMSET1014-F4]`/`[AC-CAMSET1014-F5]`/`[AC-CAMSET1014-F7]` for live
exposure, focus, preset/pinch zoom, and preview-to-capture framing,
`[AC-CAMSET1014-E1]` for unsupported device
capabilities, `[AC-CAMSET1014-E2]` for timer cancellation, and
`[AC-CAMSET1014-S1]` for the existing permission and app-private storage
boundaries. `[AC-CAMSET1014-E3]` has a host fallback-policy test and still
needs one valid-image/failure-path device check.
