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
   callbacks and SwiftUI. Its published `CameraState` is what the views render,
   and each valid capture becomes a UUID-backed `CapturedPhoto`.
4. `Sources/FrameWise/CameraService.swift` owns the AVFoundation session,
   camera selection, permissions, and photo capture. It keeps session work on
   its own queue so the UI stays responsive.

## Persistent captured-photo flow

`Sources/FrameWiseCore/CapturedPhoto.swift` is the hardware-independent photo
value. `CapturedPhotoLibrary` owns newest-first ordering and the narrow
export/delete mutations used by the UI.

`Sources/FrameWiseCore/CapturedPhotoDiskStore.swift` is an actor-backed private
storage boundary. It keeps one captured image file per UUID and an atomic JSON
manifest under `Application Support/FrameWise/Photos`. Loading the manifest
restores the same order after a fresh app launch; corrupt manifests and missing
image files surface typed recoverable errors instead of silently disappearing.

`Sources/FrameWise/CapturedPhotoStore.swift` bridges that actor to SwiftUI. A
capture is validated and written before it is published to the Library. The
store also persists the exported flag only after PhotoKit reports success and
removes the private file before publishing a FrameWise-only deletion.

The screen flow is:

```text
Camera
  ├─ capture -> private app storage -> shrink/opacity flight to dock thumbnail
  └─ Library -> Preview
                 ├─ Share -> native UIActivityViewController
                 ├─ Save -> PhotoKit add-only export of a copy
                 ├─ Delete -> private FrameWise file/manifest only
                 └─ Edit -> visible disabled placeholder
```

`LibraryView` keeps captures newest first and its lower-right Camera button
dismisses back to the existing camera root. `PhotoPreviewView` handles invalid
or removed records with an unavailable state rather than force-unwrapping an
image. The camera screen stops the existing session while Library is visible
and starts that same configured service again when Camera reappears.

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

The host suite covers camera/branding state, captured-photo ordering and
export/deletion state, disk restore ordering, manifest corruption, missing
images, and app-private removal. `xtool dev build` covers the SwiftUI,
AVFoundation, UIKit, and PhotoKit adapters that cannot run on the host.
