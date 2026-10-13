# Captured Photo Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the user on Camera after capture while adding a session-only photo library with a shrink-to-library animation, preview actions, and explicit Save to Photos.

**Architecture:** Keep camera hardware in `CameraService` and camera lifecycle in `CameraViewModel`. Add a hardware-independent `CapturedPhoto`/`CapturedPhotoLibrary` model in `FrameWiseCore`, wrap it in a main-actor SwiftUI store, and share that store through a `NavigationStack` containing Camera, Library, and Preview screens. Use a small PhotoKit writer and UIKit share-sheet bridge at the iOS boundary.

**Tech Stack:** Swift 6, SwiftUI, UIKit, AVFoundation, Photos/PhotoKit, Swift Package Manager, XCTest, and xtool.

**Spec:** `docs/superpowers/specs/2026-10-14-captured-photo-library-design.md`

## Global Constraints

- Support the package's existing platform floors: iOS 17 and macOS 14.
- Keep the captured-photo collection in memory only; it is cleared when the app process ends.
- Keep the camera root visible after capture; do not auto-navigate to Library.
- Use Photos add-only authorization for Save and never request Photos read access.
- Delete removes only the FrameWise in-memory item and never deletes a Photos copy.
- Keep Edit visible but disabled until a later editing slice.
- Reduced Motion removes spatial capture movement while retaining a visible completion transition.
- Controls require descriptive accessibility labels and at least 44 pt hit areas.
- Add no external dependency or online service.

The model and collection behaviors are host-testable and use RED → GREEN
cycles. SwiftUI, UIKit, AVFoundation, and PhotoKit adapters are excluded from
the Linux host test target by the package's existing conditional compilation;
their gates are the iOS build plus the device checklist, with no speculative
test abstraction added just to make platform code look host-testable.

## Review Focus

- **Duplicate capture delivery:** a successful camera callback must add one library item even when SwiftUI views reappear; pinned by the core insert tests and device retest after navigation.
- **Malformed image data:** empty or undecodable data must not enter the library or block the camera; pinned by model/store validation tests.
- **Photos authorization failure:** denied/restricted add-only access must leave the item available in FrameWise and expose a Settings recovery path; pinned by typed writer errors and the manual permission check.
- **Destructive scope:** Delete must remove only the FrameWise item, not a Photos asset; pinned by the library removal test and device verification after Save.
- **Motion and navigation lifecycle:** Reduced Motion must avoid spatial flight, and Library must not create a second camera session; pinned by the device checklist for animation, return, and repeated camera entry.

---

### Task 1: Add the hardware-independent captured-photo model

**Files:**
- Create: `Sources/FrameWiseCore/CapturedPhoto.swift`
- Create: `Sources/FrameWiseCore/CapturedPhotoLibrary.swift`
- Create: `Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift`

**Interfaces:**
- `public struct CapturedPhoto: Identifiable, Equatable, Sendable` with `id: UUID`, `data: Data`, `capturedAt: Date`, `isSaved: Bool`, and a failable initializer `init?(id:data:capturedAt:isSaved:)` that rejects empty data.
- `public struct CapturedPhotoLibrary: Equatable, Sendable` with `public private(set) var photos: [CapturedPhoto]`, `init()`, `mutating func insert(_ photo: CapturedPhoto)`, `mutating func markSaved(id: UUID) -> Bool`, `mutating func remove(id: UUID) -> Bool`, and `func photo(withID: UUID) -> CapturedPhoto?`.
- `insert` places the newest item at index zero; `markSaved` and `remove` affect only the requested ID.

- [ ] **Step 1: Write the failing core tests**

  Add tests named with the acceptance IDs:

  - `[AC-PHOTO1014-F1] testInsertAddsExactlyOneCapture`
  - `[AC-PHOTO1014-F3] testInsertKeepsNewestCaptureFirst`
  - `[AC-PHOTO1014-F8] testRemoveDeletesOnlyTheRequestedCapture`
  - `[AC-PHOTO1014-F7] testMarkSavedChangesOnlyTheRequestedCapture`
  - `[AC-PHOTO1014-E1] testNewLibraryIsEmpty`
  - `[AC-PHOTO1014-E2] testEmptyDataCannotCreateCapture`

  Use fixed UUIDs and dates so order and identity assertions are deterministic.

- [ ] **Step 2: Run the focused tests to verify RED**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: FAIL because the model and library types do not exist yet.

- [ ] **Step 3: Implement the minimal model and collection**

  Reject empty `Data` in `CapturedPhoto.init`; insert valid photos at the
  front of `photos`; locate items by UUID; update only the matching item's
  saved flag; and return a Boolean from mutation methods so UI callers can
  report whether an operation actually changed the collection.

- [ ] **Step 4: Run the focused tests to verify GREEN**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: all focused tests pass with zero failures.

- [ ] **Step 5: Commit the model slice**

  ```bash
  git add Sources/FrameWiseCore/CapturedPhoto.swift Sources/FrameWiseCore/CapturedPhotoLibrary.swift Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift
  git commit -m "feat: add captured photo library model"
  ```

### Task 2: Bridge captured photos into the camera view model and store

**Files:**
- Create: `Sources/FrameWise/CapturedPhotoStore.swift`
- Modify: `Sources/FrameWise/CameraViewModel.swift`

**Interfaces:**
- `@MainActor final class CapturedPhotoStore: ObservableObject` exposes `@Published private(set) var photos: [CapturedPhoto]`, `var latestPhoto: CapturedPhoto?`, `var count: Int`, `func add(_ photo: CapturedPhoto) -> Bool`, `func markSaved(id: UUID) -> Bool`, `func remove(id: UUID) -> Bool`, and `func photo(withID: UUID) -> CapturedPhoto?`.
- `CapturedPhotoStore.add` rejects data that cannot be decoded by `UIImage(data:)`, then delegates ordering and mutation to `CapturedPhotoLibrary`.
- `CameraViewModel` replaces `lastPhotoData` with `@Published private(set) var lastCapturedPhoto: CapturedPhoto?`, creates one new `CapturedPhoto` for each successful delegate callback, and exposes `func stop()` alongside `start()`.

- [ ] **Step 1: Re-run the core contract before the platform bridge**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: the Task 1 suite remains green. The `UIImage(data:)` validation
  is a thin iOS adapter and is verified by the platform build/device path,
  not duplicated as a host-only fake.

- [ ] **Step 2: Implement `CapturedPhotoStore`**

  Keep one private `CapturedPhotoLibrary`, publish its `photos` after each
  successful mutation, and perform `UIImage(data:)` validation in `add`.
  Do not persist data or expose a second ordering implementation.

- [ ] **Step 3: Implement the camera capture event bridge**

  In `CameraViewModel.cameraService(_:didCapturePhoto:)`, create one
  `CapturedPhoto` with a fresh UUID and current date and assign it to
  `lastCapturedPhoto`. Add `stop()` as a thin call to `CameraService.stop()`.
  Keep service callbacks and published state on the main actor.

- [ ] **Step 4: Build the iOS-facing target**

  From the documented WSL shell, run: `xtool dev build`

  Expected: the new UIKit/SwiftUI source is conditionally compiled without
  changing host-core test behavior.

- [ ] **Step 5: Commit the bridge slice**

  ```bash
  git add Sources/FrameWise/CapturedPhotoStore.swift Sources/FrameWise/CameraViewModel.swift
  git commit -m "feat: bridge camera captures into photo storage"
  ```

### Task 3: Keep Camera active and add the capture-to-library transition

**Files:**
- Modify: `Sources/FrameWise/ContentView.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**
- `ContentView` owns one `@StateObject CapturedPhotoStore` and places the existing camera root inside a `NavigationStack`.
- `CameraScreen` receives `@ObservedObject var photoStore: CapturedPhotoStore` and uses the store's `latestPhoto` for the Library control.
- Add a private capture-flight view/state in `CameraScreen`; it must accept a `CapturedPhoto`, the library-thumbnail destination, and the environment's Reduce Motion value.

- [ ] **Step 1: Run the core capture contract before UI changes**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: PASS before changing SwiftUI navigation; Task 1 already pins one
  collection item per inserted capture and newest-first ordering.

- [ ] **Step 2: Add the shared navigation root and store injection**

  Wrap the existing camera screen in `NavigationStack`, create the store once
  at `ContentView` scope, and pass it to `CameraScreen`. Preserve the existing
  opener overlay and camera startup timing.

- [ ] **Step 3: Route each new capture into the store once**

  Observe the `lastCapturedPhoto` identity from `CameraScreen`; add only the
  newly delivered photo, then set the local flight state. The route must not
  depend on view appearance, so navigating away and back cannot duplicate the
  item.

- [ ] **Step 4: Implement the capture animation and thumbnail destination**

  Render a temporary full-preview image over the live camera and animate it
  toward the Library control's latest-photo thumbnail using one
  `matchedGeometryEffect` keyed by the captured photo ID. Keep the camera
  screen mounted and clear the flight state after the short transition. When
  Reduce Motion is enabled, skip the spatial movement and use an opacity
  transition only.

- [ ] **Step 5: Verify the camera slice**

  Run the host suite and the iOS build. Confirm that only one
  `CameraViewModel` is owned by `ContentView`, the opener still overlays the
  camera, and the changed source has no compiler diagnostics.

- [ ] **Step 6: Commit the camera transition slice**

  ```bash
  git add Sources/FrameWise/ContentView.swift Sources/FrameWise/CameraScreen.swift Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift
  git commit -m "feat: animate captures into the library"
  ```

### Task 4: Add Library and Preview screens

**Files:**
- Create: `Sources/FrameWise/LibraryView.swift`
- Create: `Sources/FrameWise/PhotoPreviewView.swift`
- Create: `Sources/FrameWise/ShareSheet.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**
- `struct LibraryView: View` receives `@ObservedObject var photoStore: CapturedPhotoStore` and renders the store's `photos` newest first.
- `struct PhotoPreviewView: View` receives `photoID: UUID` and `@ObservedObject var photoStore: CapturedPhotoStore`; it resolves the current item by ID and handles Share, a disabled Save slot pending Task 5, Delete, and disabled Edit.
- `struct ShareSheet: UIViewControllerRepresentable` receives a `UIImage` and presents `UIActivityViewController` with that image as its activity item.

- [ ] **Step 1: Add the empty/order/delete test coverage**

  Keep `[AC-PHOTO1014-E1] testNewLibraryIsEmpty`,
  `[AC-PHOTO1014-F3] testInsertKeepsNewestCaptureFirst`, and
  `[AC-PHOTO1014-F8] testRemoveDeletesOnlyTheRequestedCapture` as the core
  contract for the new screens.

- [ ] **Step 2: Run the core tests to verify the screen contract is green**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: PASS; the UI will consume an already-tested collection boundary.

- [ ] **Step 3: Implement the Library list and empty state**

  Use a scrollable vertical list with thumbnail, capture time, and a row
  navigation action. Show a clear empty state when there are no photos.
  Add a lower-right circular camera button with a 44 pt hit area; dismiss the
  current Library destination rather than constructing a new camera screen.

  Wire the Camera dock's Library link to this screen using the shared store.

- [ ] **Step 4: Implement the Preview screen**

  Render the selected image full-width with safe-area-aware action controls.
  Present Share, a disabled Save placeholder, Delete, and a disabled Edit
  button with accessible labels. If the item was removed before the screen renders, show a concise
  unavailable state and a Back action instead of force-unwrapping.

- [ ] **Step 5: Implement the share-sheet bridge**

  Convert the selected `Data` to `UIImage` at the screen boundary and present
  `ShareSheet` as a SwiftUI sheet. Keep the preview open after dismissal and
  do not request Photos permission for sharing.

- [ ] **Step 6: Verify the Library/Preview build**

  Run the host suite and the iOS build. Confirm that Library navigation does
  not introduce a second `CameraViewModel` or camera service.

- [ ] **Step 7: Commit the Library/Preview slice**

  ```bash
  git add Sources/FrameWise/LibraryView.swift Sources/FrameWise/PhotoPreviewView.swift Sources/FrameWise/ShareSheet.swift Sources/FrameWise/CameraScreen.swift
  git commit -m "feat: add in-memory library and photo preview"
  ```

### Task 5: Add Save to Photos and destructive-action handling

**Files:**
- Create: `Sources/FrameWise/PhotoLibraryWriter.swift`
- Modify: `Sources/FrameWise/PhotoPreviewView.swift`
- Modify: `FrameWise-Info.plist`

**Interfaces:**
- `enum PhotoLibraryWriterError: LocalizedError` includes invalid image, denied authorization, and write failure cases with user-facing descriptions.
- `final class PhotoLibraryWriter` exposes `func save(data: Data) async throws`, requests `.addOnly` authorization only when the current status is `.notDetermined`, and writes through `PHPhotoLibrary.performChanges`.
- `PhotoPreviewView` accepts a default writer, shows a saving state, marks the selected store item saved only after success, and keeps the preview usable after failure.

- [ ] **Step 1: Add the save-state contract test**

  Extend `CapturedPhotoLibraryTests` with
  `[AC-PHOTO1014-ERR2] testUnsavedPhotoRemainsUnsavedUntilMarkSaved` by
  asserting that a library item remains unsaved until `markSaved` is
  explicitly called after a successful writer result. Keep
  `[AC-PHOTO1014-F7] testMarkSavedChangesOnlyTheRequestedCapture` as the
  success contract.

- [ ] **Step 2: Run the focused tests to verify the save contract**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: PASS before PhotoKit integration; no test should require a device.

- [ ] **Step 3: Implement the PhotoKit writer**

  Implement `save(data:)` by decoding the encoded data to `UIImage`, handle
  `.authorized`/`.limited` add-only success, request `.addOnly` for
  `.notDetermined`, and throw a typed error for `.denied`, `.restricted`, or
  failed `performChanges`. Bridge callback APIs to `async` without blocking
  the main actor.

- [ ] **Step 4: Add the Photos usage description**

  Add `NSPhotoLibraryAddUsageDescription` with concise copy explaining that
  FrameWise saves captured photos when the user chooses Save. Do not add a
  read-usage key.

- [ ] **Step 5: Wire Save, error recovery, and saved state**

  Use a task-backed saving state in `PhotoPreviewView`; on success call
  `photoStore.markSaved(id:)` and update the button to prevent duplicate saves
  in the current process. On denied/restricted access, show the error and an
  Open Settings action. On write failure, keep Share, Delete, and retry
  available.

- [ ] **Step 6: Wire Delete confirmation**

  Present an explicit destructive confirmation stating that the action removes
  the photo from FrameWise only and does not delete its Photos copy. On
  confirmation call `photoStore.remove(id:)` and dismiss the Preview.

- [ ] **Step 7: Verify the Photos slice**

  Run the host suite and iOS build. On device, test first-run authorization,
  denied authorization, successful save, repeated Save, and Delete after Save.

- [ ] **Step 8: Commit Photos actions**

  ```bash
  git add Sources/FrameWise/PhotoLibraryWriter.swift Sources/FrameWise/PhotoPreviewView.swift FrameWise-Info.plist Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift
  git commit -m "feat: add photo sharing saving and deletion"
  ```

### Task 6: Integrate lifecycle, documentation, and final verification

**Files:**
- Modify: `Sources/FrameWise/CameraScreen.swift`
- Modify: `Sources/FrameWise/ContentView.swift`
- Modify: `README.md`
- Modify: `docs/code-walkthrough.md`

**Interfaces:**
- Camera lifecycle remains one `CameraViewModel`/`CameraService` pair; Library presentation may stop the session and camera re-entry may start it again, without changing the existing reducer contract.
- Documentation describes the temporary library, Photos Save, FrameWise-only Delete, and disabled Edit scope.

- [ ] **Step 1: Add lifecycle-focused regression coverage**

  Add `[AC-PHOTO1014-E3] testNewLibraryStartsWithoutPersistedPhotos` to the
  core test suite by constructing a fresh `CapturedPhotoLibrary` and asserting
  it contains no items. Reduced Motion remains a device-only UI behavior and
  is verified in Step 5; do not invent a platform-independent abstraction for
  an animation implementation detail.

- [ ] **Step 2: Run all host tests**

  Run: `swift test`

  Expected: all existing camera/branding tests and all photo-library tests
  pass with zero failures.

- [ ] **Step 3: Build the iOS app**

  From the documented WSL shell, run: `xtool dev build`

  Expected: the iOS target builds with the new SwiftUI, PhotoKit, and Photos
  usage-description configuration.

- [ ] **Step 4: Update the walkthrough and README**

  Describe the new store, Library, Preview, Share, Save, Delete, and disabled
  Edit flow. Move the completed photo-library slice out of the next-step list
  and leave composition guides as the next product slice.

- [ ] **Step 5: Run the connected-device acceptance checklist**

  Verify and record evidence for:

  - `[AC-PHOTO1014-F1/F2]` capture stays on Camera and image flies to the dock;
  - `[AC-PHOTO1014-F3/F4]` Library list order and lower-right Camera return;
  - `[AC-PHOTO1014-F5/F6]` Preview actions and native Share sheet;
  - `[AC-PHOTO1014-F7]` add-only Photos prompt and successful Save;
  - `[AC-PHOTO1014-F8/ERR3]` FrameWise-only Delete after a saved photo;
  - `[AC-PHOTO1014-E1/E3]` empty and process-reset behavior;
  - `[AC-PHOTO1014-E4]` Reduced Motion opacity-only transition;
  - `[AC-PHOTO1014-ERR1/ERR2]` denied and failed Save recovery.

- [ ] **Step 6: Review the final diff for unnecessary complexity**

  Run `git diff --check`, inspect the complete diff, remove any duplicated
  ordering/state logic or speculative editing/persistence code, and rerun the
  affected tests/build if changes are made.

- [ ] **Step 7: Commit the verified documentation and integration**

  ```bash
  git add Sources/FrameWise/CameraScreen.swift Sources/FrameWise/ContentView.swift README.md docs/code-walkthrough.md Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift
  git commit -m "docs: verify captured photo library flow"
  ```

