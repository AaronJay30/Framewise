# Camera Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the starter screen with a branded, camera-first iOS shell using the selected Open Crop logo, a fade-in FrameWise opener, live preview, still capture, camera switching, and a rounded three-control dock.

**Architecture:** Keep camera hardware behind `CameraService` and the SwiftUI-facing state in `CameraViewModel`. Put permission/session state reduction in a small `FrameWiseCore` target so it can be tested without AVFoundation or a physical camera. Render the logo as reusable SwiftUI geometry for the opener, and use a generated 1024px symbol-only PNG through `xtool.yml` for the app icon.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, UIKit preview layer, Swift Package Manager, XCTest, xtool, and the approved flat Ink/Signal Coral SVG/PNG assets.

**Spec:** `docs/superpowers/specs/2026-10-13-camera-foundation-design.md`

## Global Constraints

- Support the package's existing platform floors: iOS 17 and macOS 14.
- Use the approved brand colors Ink `#10151B` and Signal Coral `#FF6B57` for the mark and artwork; the app icon may use neutral White `#FFFFFF` as its tile background.
- The selected Open Crop symbol is the app logo; the tightened `Frame`/`Wise` lockup is for the opener.
- The opener fades in while camera initialization is in progress and must not add an artificial wait.
- Reduced Motion removes scale movement and retains only an opacity transition.
- The bottom dock contains only library, shutter, and camera-flip controls.
- Captured photos must not contain UI, logo, guidance, or reference overlays.
- No external dependencies or online services are introduced.

## Review Focus

- **Permission denied or restricted:** show a clear recovery action and never leave the user on the opener; covered by `CameraStateReducerTests` and the device permission check in Task 6.
- **No rear or front camera available:** preserve the current usable state or show an unavailable state without crashing; covered by reducer tests and the service/device check in Task 4/6.
- **Capture failure:** keep the preview usable and expose retry state; covered by reducer tests and the device capture check in Task 6.
- **Reduced Motion enabled:** remove scale animation while retaining readable fade behavior; covered by `BrandIntroView` accessibility review in Task 3.
- **Tiny app-icon scale:** keep the Open Crop silhouette legible at 1024px source and 16–32px previews; covered by the asset dimension/color checks and logo audit in Task 2.

---

### Task 1: Add hardware-independent camera state contracts

**Files:**
- Modify: `Package.swift`
- Create: `Sources/FrameWiseCore/CameraState.swift`
- Create: `Sources/FrameWiseCore/CameraStateReducer.swift`
- Create: `Sources/FrameWiseCore/BrandingTokens.swift`
- Test: `Tests/FrameWiseCoreTests/CameraStateReducerTests.swift`
- Test: `Tests/FrameWiseCoreTests/BrandingTokenTests.swift`

**Interfaces:**
- Produces `public enum CameraState: Equatable`, `public enum CameraEvent: Equatable`, and `public enum CameraStateReducer` with `public static func reduce(_ state: CameraState, event: CameraEvent) -> CameraState`.
- Produces `public enum FrameWiseBrandToken` with `inkHex`, `signalCoralHex`, and `public static func shouldShowBrandIntro(for state: CameraState) -> Bool`.
- Later tasks consume the reducer without importing AVFoundation.

- [ ] **Step 1: Add the `FrameWiseCore` library target and test target to `Package.swift`**

  Keep the existing `FrameWise` product and make the app target depend on `FrameWiseCore`; place tests under `Tests/FrameWiseCoreTests` so the reducer can run on the host without camera hardware.

- [ ] **Step 2: Write failing reducer tests**

  Add tests for permission request, permission denial, unavailable hardware, configured/started session, capture failure, and retry returning to initialization. Assert exact enum cases rather than display strings.

- [ ] **Step 3: Run the focused tests to verify RED**

  Run: `swift test --filter CameraStateReducerTests`

  Expected: FAIL because the state types and reducer behavior are not implemented.

- [ ] **Step 4: Implement the minimal state enums and reducer**

  Use `CameraState` cases `.initializing`, `.requestingPermission`, `.permissionDenied`, `.unavailable`, `.ready`, `.running`, and `.captureFailed`; use events that express only transitions needed by the service and view model. Add `FrameWiseBrandToken.shouldShowBrandIntro(for:)` so only initialization and permission-request states keep the opener active.

- [ ] **Step 5: Run the focused tests to verify GREEN**

  Run: `swift test --filter CameraStateReducerTests`

  Expected: all reducer tests pass with zero failures.

- [ ] **Step 6: Commit the state contract**

  ```bash
  git add Package.swift Sources/FrameWiseCore Tests/FrameWiseCoreTests
  git commit -m "test: define camera state transitions"
  ```

### Task 2: Package the selected Open Crop app icon

**Files:**
- Modify: `xtool.yml`
- Create: `Resources/FrameWiseAppIcon.svg`
- Create: `Resources/FrameWiseAppIcon.png`
- Modify: `docs/brand/logo-concepts/concept-a-open-crop-lockup.svg`

**Interfaces:**
- Produces `Resources/FrameWiseAppIcon.png` at exactly 1024×1024 for `xtool.yml`'s `iconPath`.
- The icon is a full-bleed White tile with a simplified, symbol-only Ink Open Crop mark and Signal Coral center diamond; the neutral tile keeps the small-size mark crisp.

- [ ] **Step 1: Write the asset validation check**

  Validate that the PNG exists, is 1024×1024, contains only the Ink and Signal Coral RGB colors, and that the SVG source is XML-valid.

- [ ] **Step 2: Run the validation to verify RED**

  Run: `py -3 -c "from PIL import Image; from pathlib import Path; p=Path('Resources/FrameWiseAppIcon.png'); assert p.exists(); im=Image.open(p).convert('RGB'); assert im.size==(1024,1024); assert set(im.getdata()) <= {(16,21,27),(255,107,87),(255,255,255)}"`

  Expected: FAIL because the production resource files do not exist yet.

- [ ] **Step 3: Create the final symbol source and raster icon**

  Tighten the `FrameWise` lockup by moving the `Wise` word group from x=620 to x=590 in the approved exploratory SVG. Create the white-tile icon SVG by scaling the Open Crop symbol to the 256px viewBox, keeping the framing geometry Ink, retaining the Signal Coral center diamond, and placing it on a full-bleed White background. Rasterize that SVG at 1024×1024 with the logo-design renderer; do not add gradients, shadows, or antialiasing colors to the source geometry.

- [ ] **Step 4: Point xtool at the icon**

  Add `iconPath: Resources/FrameWiseAppIcon.png` to `xtool.yml`; keep the existing bundle ID unchanged in this task.

- [ ] **Step 5: Run asset validation and logo audit**

  Run the PNG/XML checks and `py -3 C:\Users\User\.codex\skills\logo-design\scripts\svg_audit.py Resources/FrameWiseAppIcon.svg docs/brand/logo-concepts/concept-a-open-crop-lockup.svg`.

  Expected: the PNG checks pass and the icon/lockup contain only the approved flat colors plus the neutral White icon background; the lockup may still report exploratory live text until the UI lockup is represented by SwiftUI text.

- [ ] **Step 6: Commit the app-icon assets**

  ```bash
  git add xtool.yml Resources docs/brand/logo-concepts/concept-a-open-crop-lockup.svg
  git commit -m "feat: add FrameWise Open Crop app icon"
  ```

### Task 3: Add reusable brand geometry and the fade-in opener

**Files:**
- Create: `Sources/FrameWise/Branding.swift`
- Create: `Sources/FrameWise/BrandIntroView.swift`
- Modify: `Sources/FrameWiseCore/BrandingTokens.swift`
- Test: `Tests/FrameWiseCoreTests/BrandingTokenTests.swift`

**Interfaces:**
- Produces `FrameWiseBrand.ink`, `FrameWiseBrand.signalCoral`, and reusable SwiftUI views `OpenCropSymbol` and `FrameWiseLockup`.
- Produces `BrandIntroView(isActive: Bool)`; it uses the environment's `accessibilityReduceMotion` value and does not own a timer or camera setup.
- `Branding.swift` converts the core hex tokens into SwiftUI `Color` values; host tests assert the core hex tokens and opener mapping instead of importing SwiftUI.

- [ ] **Step 1: Write failing token tests**

  Assert that `FrameWiseBrandToken.inkHex == "#10151B"`, `FrameWiseBrandToken.signalCoralHex == "#FF6B57"`, and `shouldShowBrandIntro(for:)` is true only for `.initializing` and `.requestingPermission`.

- [ ] **Step 2: Run the focused tests to verify RED**

  Run: `swift test --filter BrandingTokenTests`

  Expected: FAIL because the shared tokens and opener-state mapping do not exist yet.

- [ ] **Step 3: Implement the core tokens and Open Crop symbol**

  Add the exact hex tokens to `FrameWiseCore`, convert them to SwiftUI colors in `Branding.swift`, and draw the four rounded framing corners plus coral focal diamond as SwiftUI geometry. Build `FrameWiseLockup` from adjacent `Frame` and `Wise` text groups with negative spacing/kerning so the word groups are visibly closer than the exploratory lockup.

- [ ] **Step 4: Implement `BrandIntroView(isActive:)`**

  Animate the lockup from opacity 0 to 1 with a subtle scale from 0.96 to 1.0 on normal motion; use opacity-only animation under Reduced Motion. When `isActive` becomes false, fade the opener out so the camera underneath becomes visible immediately.

- [ ] **Step 5: Run the focused tests and package build**

  Run: `swift test --filter BrandingTokenTests` and the platform build command available for the project.

  Expected: token tests pass; the SwiftUI source compiles for the existing iOS/macOS package floors.

- [ ] **Step 6: Commit the branding views**

  ```bash
  git add Sources/FrameWise/Branding.swift Sources/FrameWise/BrandIntroView.swift Tests/FrameWiseCoreTests/BrandingTokenTests.swift
  git commit -m "feat: add FrameWise branded opener"
  ```

### Task 4: Implement the AVFoundation camera service and view model

**Files:**
- Create: `Sources/FrameWise/CameraService.swift`
- Create: `Sources/FrameWise/CameraViewModel.swift`
- Modify: `Sources/FrameWiseCore/CameraState.swift`
- Modify: `Sources/FrameWiseCore/CameraStateReducer.swift`
- Test: `Tests/FrameWiseCoreTests/CameraStateReducerTests.swift`

**Interfaces:**
- `CameraService` owns an `AVCaptureSession`, rear/front device selection, `AVCapturePhotoOutput`, session queue, permission request, and photo delegate callbacks. Its public surface is `init()`, `var session: AVCaptureSession { get }`, `var delegate: CameraServiceDelegate?`, `func start()`, `func stop()`, `func flipCamera()`, and `func capturePhoto()`.
- `@MainActor protocol CameraServiceDelegate: AnyObject` receives `func cameraService(_: CameraService, didEmit event: CameraEvent)` and `func cameraService(_: CameraService, didCapturePhoto data: Data)`.
- `CameraViewModel: ObservableObject` exposes `@Published var state: CameraState`, `let session: AVCaptureSession`, and intents `start()`, `retry()`, `flipCamera()`, and `capturePhoto()`.
- The view model maps service callbacks to the existing `CameraStateReducer` and keeps all UI-facing mutations on the main actor.

- [ ] **Step 1: Extend failing state tests for capture and retry callbacks**

  Add exact assertions for `.running` → `.captureFailed` and `.captureFailed` → `.initializing` so capture failures leave a recoverable state.

- [ ] **Step 2: Run tests to verify RED**

  Run: `swift test --filter CameraStateReducerTests`

  Expected: FAIL for the new transitions.

- [ ] **Step 3: Implement the minimal `CameraService`**

  Configure the default rear wide-angle camera, request video permission, add the video input and photo output on the serial session queue, start/stop the session, replace the input when flipping cameras, and report unavailable/capture failure without throwing UI work across queues.

- [ ] **Step 4: Implement `CameraViewModel`**

  Bridge service events into `CameraState`, expose the session for the preview, and ensure denied permission and unavailable hardware never leave the view model stuck in `.initializing`.

- [ ] **Step 5: Run the state tests and compile the camera service**

  Run: `swift test --filter CameraStateReducerTests` and the project build command.

  Expected: all state tests pass and the AVFoundation code compiles for the iOS target.

- [ ] **Step 6: Commit the camera service**

  ```bash
  git add Sources/FrameWise/CameraService.swift Sources/FrameWise/CameraViewModel.swift Sources/FrameWiseCore Tests/FrameWiseCoreTests/CameraStateReducerTests.swift
  git commit -m "feat: add camera session service"
  ```

### Task 5: Build the camera preview and rounded control dock

**Files:**
- Create: `Sources/FrameWise/CameraPreview.swift`
- Create: `Sources/FrameWise/CameraScreen.swift`
- Modify: `Sources/FrameWise/ContentView.swift`
- Create: `FrameWise-Info.plist`
- Modify: `xtool.yml`

**Interfaces:**
- `CameraPreview(session: AVCaptureSession)` hosts an `AVCaptureVideoPreviewLayer` and owns no capture state.
- `CameraScreen(viewModel: CameraViewModel)` renders preview, permission/unavailable/failure recovery states, and the rounded dock with only library, shutter, and flip controls.

- [ ] **Step 1: Add the camera usage description configuration**

  Create `FrameWise-Info.plist` with `NSCameraUsageDescription` explaining that FrameWise needs the camera to preview and capture photos, then reference it through `infoPath` in `xtool.yml`.

- [ ] **Step 2: Implement `CameraPreview`**

  Use a small `UIViewRepresentable` and preview-layer-backed `UIView`; set `videoGravity` to `.resizeAspectFill` and update the layer's session without reconfiguring AVFoundation in SwiftUI.

- [ ] **Step 3: Implement `CameraScreen` and dock controls**

  Place the preview full screen, overlay a dark rounded dock above the safe-area bottom inset, and expose exactly three controls with 44 pt minimum hit areas: library/last-photo placeholder, shutter, and camera flip. Show one rounded recovery action for permission or hardware failure.

- [ ] **Step 4: Replace the Hello World body in `ContentView`**

  Own one `CameraViewModel`, start it from the view lifecycle, and render `CameraScreen` with no direct AVFoundation calls in `ContentView`.

- [ ] **Step 5: Compile the iOS app**

  Run: `xtool dev build` from the documented WSL shell.

  Expected: the app target builds with the camera usage description, icon path, preview bridge, and rounded dock.

- [ ] **Step 6: Commit the camera UI**

  ```bash
  git add Sources/FrameWise/ContentView.swift Sources/FrameWise/CameraPreview.swift Sources/FrameWise/CameraScreen.swift FrameWise-Info.plist xtool.yml
  git commit -m "feat: add camera-first interface"
  ```

### Task 6: Integrate opener-to-camera transition and verify on device

**Files:**
- Modify: `Sources/FrameWise/ContentView.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`
- Modify: `README.md`
- Test: `Tests/FrameWiseCoreTests/CameraStateReducerTests.swift`

**Interfaces:**
- `ContentView` overlays `BrandIntroView(isActive:)` while camera state is initializing/requesting permission, dismisses it when the camera reaches `.running` or a terminal recovery state, and never uses a fixed sleep to gate the camera.

- [ ] **Step 1: Add transition-state assertions**

  Assert through `FrameWiseBrandToken.shouldShowBrandIntro(for:)` that `.initializing` and `.requestingPermission` keep the opener active, while `.running`, `.permissionDenied`, and `.unavailable` dismiss the opener in favor of the camera or recovery view.

- [ ] **Step 2: Run tests to verify RED**

  Run: `swift test --filter CameraStateReducerTests`

  Expected: FAIL until the integration mapping is represented in the testable state contract.

- [ ] **Step 3: Implement the opener integration**

  Render the camera/recovery view underneath the opener, animate only the opener's opacity/scale, and allow reduced-motion users to see the same state change without scale movement.

- [ ] **Step 4: Run all host tests and build**

  Run: `swift test`, then `xtool dev build`.

  Expected: all host tests pass and the iOS build succeeds.

- [ ] **Step 5: Verify on the connected iPhone**

  Run: `xtool dev` from WSL and check: opener appears, `FrameWise` lockup is tight, fade transitions into preview, permission denial shows recovery, rear/front switching works, shutter capture succeeds, and the three dock controls remain rounded and accessible. Repeat once with Reduced Motion enabled.

- [ ] **Step 6: Update documentation and commit the verified slice**

  Update the README's current-state and next-step sections to describe the branded opener and camera foundation. Commit with:

  ```bash
  git add README.md Sources/FrameWise Tests/FrameWiseCoreTests
  git commit -m "feat: complete branded camera foundation"
  ```

