# FrameWise code walkthrough

This is the short map for walking through the camera foundation in the
repository. The code is intentionally split by responsibility so a screen
can be read from the outside in.

## Start here

1. `Sources/FrameWise/FrameWiseApp.swift` is the app entry point. It creates
   the SwiftUI scene and hands the first screen to `ContentView`.
2. `Sources/FrameWise/ContentView.swift` is the composition root. It should
   own the screen-level view model and compose the camera screen, opener, and
   recovery states; it should not configure AVFoundation directly.
3. `Sources/FrameWise/CameraViewModel.swift` will be the bridge between
   service callbacks and SwiftUI. Its published `CameraState` is what the
   views render.
4. `Sources/FrameWise/CameraService.swift` will own the AVFoundation session,
   camera selection, permissions, and photo capture. It keeps session work on
   its own queue so the UI stays responsive.

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

The SwiftUI branding files will turn those tokens into reusable symbol and
lockup views. The app icon uses the symbol-only asset; the opener uses the
tightened `FrameWise` lockup.

## How to verify the core

From the project directory, run:

```text
swift test --filter CameraStateReducerTests
```

The focused test suite covers permission, hardware availability, session
startup, capture failure, and retry transitions.
