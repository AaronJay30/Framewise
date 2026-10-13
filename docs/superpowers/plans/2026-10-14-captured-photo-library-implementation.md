# Captured Photo Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the user on Camera after capture while writing every capture to persistent FrameWise app storage, with a shrink-to-library animation, preview actions, and explicit export to iOS Photos.

**Architecture:** Keep camera hardware in `CameraService` and camera lifecycle in `CameraViewModel`. Add a hardware-independent `CapturedPhoto`/`CapturedPhotoLibrary` model and an actor-backed `CapturedPhotoDiskStore` in `FrameWiseCore`, wrap them in a main-actor SwiftUI store, and share that store through a `NavigationStack` containing Camera, Library, and Preview screens. Use PhotoKit only for the explicit Preview Save export and use a UIKit share-sheet bridge for Share.

**Tech Stack:** Swift 6, SwiftUI, UIKit, AVFoundation, Photos/PhotoKit, Swift Package Manager, XCTest, and xtool.

**Spec:** `docs/superpowers/specs/2026-10-14-captured-photo-library-design.md`

## Global Constraints

- Support the package's existing platform floors: iOS 17 and macOS 14.
- Write every valid capture to FrameWise's private Application Support storage before publishing it to the Library.
- Restore stored captures after app relaunch in newest-first order.
- Keep the camera root visible after capture; do not auto-navigate to Library.
- Use Photos add-only authorization only for the explicit Save-to-Photos export; never request Photos read access.
- Delete removes the FrameWise app-storage file and manifest entry only; it never deletes a Photos copy.
- Keep Edit visible but disabled until a later editing slice.
- Reduced Motion removes spatial capture movement while retaining a visible completion transition.
- Controls require descriptive accessibility labels and at least 44 pt hit areas.
- Add no external dependency or online service.

The model and disk-store behaviors are host-testable and use RED → GREEN
cycles. SwiftUI, UIKit, AVFoundation, and PhotoKit adapters are excluded from
the Linux host test target by the package's existing conditional compilation;
their gates are the iOS build plus the device checklist.

## Review Focus

- **Persistent capture delivery:** a successful callback must write and restore one library item even when views reappear; pinned by disk-store reload tests and relaunch verification.
- **Malformed image data:** empty or undecodable data must not be written or block the camera; pinned by model tests and the iOS adapter path.
- **Storage corruption/failure:** missing files or failed manifest operations must surface a recoverable state without false success; pinned by disk-store error tests.
- **Photos authorization failure:** denied/restricted add-only access must leave the app-stored item available and expose Settings recovery; pinned by typed writer errors and device permission checks.
- **Destructive scope and motion:** Delete must not remove a Photos copy, and Reduced Motion must avoid spatial flight; pinned by store tests and device checks.

---

### Task 1: Add the hardware-independent photo model and collection

**Files:**
- Create: `Sources/FrameWiseCore/CapturedPhoto.swift`
- Create: `Sources/FrameWiseCore/CapturedPhotoLibrary.swift`
- Create: `Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift`

**Interfaces:**
- `public struct CapturedPhoto: Identifiable, Equatable, Sendable` with `id: UUID`, `data: Data`, `capturedAt: Date`, `isExported: Bool`, and a failable initializer `init?(id:data:capturedAt:isExported:)` that rejects empty data.
- `public struct CapturedPhotoLibrary: Equatable, Sendable` with `public private(set) var photos: [CapturedPhoto]`, `init()`, `mutating func insert(_ photo: CapturedPhoto)`, `mutating func markExported(id: UUID) -> Bool`, `mutating func remove(id: UUID) -> Bool`, and `func photo(withID: UUID) -> CapturedPhoto?`.
- `insert` places the newest item at index zero; `markExported` and `remove` affect only the requested ID.

- [ ] **Step 1: Write the failing core tests**

  Add tests named with the acceptance IDs:

  - `[AC-PHOTO1014-F1] testInsertAddsExactlyOneCapture`
  - `[AC-PHOTO1014-F3] testInsertKeepsNewestCaptureFirst`
  - `[AC-PHOTO1014-F8] testRemoveDeletesOnlyTheRequestedCapture`
  - `[AC-PHOTO1014-F7] testMarkExportedChangesOnlyTheRequestedCapture`
  - `[AC-PHOTO1014-E1] testNewLibraryIsEmpty`
  - `[AC-PHOTO1014-E2] testEmptyDataCannotCreateCapture`

  Use fixed UUIDs, dates, and byte data so identity and ordering assertions
  are deterministic.

- [ ] **Step 2: Run the focused tests to verify RED**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: FAIL because the model and library types do not exist yet.

- [ ] **Step 3: Implement the minimal model and collection**

  Reject empty `Data` in `CapturedPhoto.init`; insert valid photos at the
  front of `photos`; locate items by UUID; update only the matching item's
  exported flag; and return a Boolean from mutation methods so UI callers can
  report whether an operation actually changed the collection.

- [ ] **Step 4: Run the focused tests to verify GREEN**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: all focused tests pass with zero failures.

- [ ] **Step 5: Commit the model slice**

  ```bash
  git add Sources/FrameWiseCore/CapturedPhoto.swift Sources/FrameWiseCore/CapturedPhotoLibrary.swift Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift
  git commit -m "feat: add captured photo library model"
  ```

### Task 2: Add persistent app-private disk storage

**Files:**
- Create: `Sources/FrameWiseCore/CapturedPhotoDiskStore.swift`
- Create: `Tests/FrameWiseCoreTests/CapturedPhotoDiskStoreTests.swift`

**Interfaces:**
- `public actor CapturedPhotoDiskStore` with `init(directoryURL: URL)`, `public static func defaultDirectory() -> URL`, `func load() throws -> [CapturedPhoto]`, `func save(_ photo: CapturedPhoto) throws`, `func markExported(id: UUID) throws`, and `func remove(id: UUID) throws`.
- Store image bytes as one file per UUID and capture metadata (`id`, filename, `capturedAt`, `isExported`) in an atomic JSON manifest in the supplied directory.
- `load()` returns newest-first records and throws a typed storage error for a corrupt manifest, missing image file, or failed file operation; it does not silently drop records.

- [ ] **Step 1: Write failing disk-store tests**

  Use a unique temporary directory per test and add:

  - `[AC-PHOTO1014-F1] testSavedCaptureRestoresAfterNewStoreInstance`
  - `[AC-PHOTO1014-F3] testReloadPreservesNewestFirstOrder`
  - `[AC-PHOTO1014-F8] testRemoveDeletesFileAndManifestRecord`
  - `[AC-PHOTO1014-E3] testFreshStoreReloadsPreviouslySavedCapture`
  - `[AC-PHOTO1014-ERR3] testCorruptManifestThrowsRecoverableStorageError`
  - `[AC-PHOTO1014-ERR3] testMissingImageThrowsRecoverableStorageError`

  Assert restored IDs, bytes, dates, exported flags, manifest contents, and
  that removing one ID leaves another file and record intact.

- [ ] **Step 2: Run the focused tests to verify RED**

  Run: `swift test --filter CapturedPhotoDiskStoreTests`

  Expected: FAIL because the disk store and storage error type do not exist.

- [ ] **Step 3: Implement `CapturedPhotoDiskStore`**

  Create the supplied directory on first write, atomically write image bytes
  and the JSON manifest, preserve manifest order, and make load/save/mark/remove
  actor-isolated. Use stable UUID filenames and keep PhotoKit out of this
  target.

- [ ] **Step 4: Run the focused tests to verify GREEN**

  Run: `swift test --filter CapturedPhotoDiskStoreTests`

  Expected: all disk persistence and corruption tests pass with zero failures.

- [ ] **Step 5: Commit the persistent storage slice**

  ```bash
  git add Sources/FrameWiseCore/CapturedPhotoDiskStore.swift Tests/FrameWiseCoreTests/CapturedPhotoDiskStoreTests.swift
  git commit -m "feat: persist captured photos in app storage"
  ```

### Task 3: Bridge persistent storage into the camera view model

**Files:**
- Create: `Sources/FrameWise/CapturedPhotoStore.swift`
- Modify: `Sources/FrameWise/CameraViewModel.swift`

**Interfaces:**
- `@MainActor final class CapturedPhotoStore: ObservableObject` exposes `@Published private(set) var photos: [CapturedPhoto]`, `@Published private(set) var isLoading: Bool`, `@Published private(set) var storageError: String?`, `var latestPhoto: CapturedPhoto?`, `var count: Int`, `func load() async`, `func add(_ photo: CapturedPhoto) async -> Bool`, `func markExported(id: UUID) async -> Bool`, `func remove(id: UUID) async -> Bool`, and `func photo(withID: UUID) -> CapturedPhoto?`.
- `CapturedPhotoStore` validates `UIImage(data:)`, awaits the disk store before publishing a new item, reloads stored items during initialization, and preserves the collection when an operation fails.
- `CameraViewModel` replaces `lastPhotoData` with `@Published private(set) var lastCapturedPhoto: CapturedPhoto?`, creates one new `CapturedPhoto` for each successful delegate callback, and exposes `func stop()` alongside `start()`.

- [ ] **Step 1: Re-run the model and disk contracts before the UI bridge**

  Run: `swift test --filter 'CapturedPhoto(Library|DiskStore)Tests'`

  Expected: the Task 1 and Task 2 suites pass before platform-specific code
  is added.

- [ ] **Step 2: Implement `CapturedPhotoStore`**

  Wrap one `CapturedPhotoLibrary` and one `CapturedPhotoDiskStore`, load the
  persisted records at startup, publish only after a successful disk write,
  persist exported-state changes, and remove disk records before publishing a
  deletion. Keep storage errors user-visible and retryable.

- [ ] **Step 3: Implement the camera capture event bridge**

  In `CameraViewModel.cameraService(_:didCapturePhoto:)`, create one
  `CapturedPhoto` with a fresh UUID and current date and assign it to
  `lastCapturedPhoto`. Add `stop()` as a thin call to `CameraService.stop()`.
  Keep service callbacks and published state on the main actor.

- [ ] **Step 4: Build the iOS-facing target**

  From the documented WSL shell, run: `xtool dev build`

  Expected: the UIKit/SwiftUI adapter compiles, and host-core tests remain
  green.

- [ ] **Step 5: Commit the store bridge**

  ```bash
  git add Sources/FrameWise/CapturedPhotoStore.swift Sources/FrameWise/CameraViewModel.swift
  git commit -m "feat: bridge camera captures into persistent storage"
  ```

### Task 4: Keep Camera active and add the capture-to-library transition

**Files:**
- Modify: `Sources/FrameWise/ContentView.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**
- `ContentView` owns one `@StateObject CapturedPhotoStore` and places the existing camera root inside a `NavigationStack`.
- `CameraScreen` receives `@ObservedObject var photoStore: CapturedPhotoStore` and uses the store's `latestPhoto` for the Library control.
- Add a private capture-flight view/state in `CameraScreen`; it accepts a `CapturedPhoto`, uses the library-thumbnail destination, and reads the environment's Reduce Motion value.

- [ ] **Step 1: Run the storage-backed core tests before UI changes**

  Run: `swift test --filter 'CapturedPhoto(Library|DiskStore)Tests'`

  Expected: PASS before changing SwiftUI navigation or animation.

- [ ] **Step 2: Add the shared navigation root and store injection**

  Wrap the existing camera screen in `NavigationStack`, create the store once
  at `ContentView` scope, and pass it to `CameraScreen`. Preserve the existing
  opener overlay and camera startup timing.

- [ ] **Step 3: Route each new capture into storage once**

  Observe the `lastCapturedPhoto` identity from `CameraScreen`; call the
  async store add operation once for that ID, and start the flight only after
  the app-storage write succeeds. The route must not depend on view
  appearance, so navigating away and back cannot duplicate the item.

- [ ] **Step 4: Implement the capture animation and thumbnail destination**

  Render a temporary full-preview image over the live camera and animate it
  toward the Library control's latest-photo thumbnail using one
  `matchedGeometryEffect` keyed by the captured photo ID. Keep the camera
  screen mounted and clear the flight state after the short transition. When
  Reduce Motion is enabled, skip the spatial movement and use an opacity
  transition only.

- [ ] **Step 5: Verify the camera slice**

  Run the host suite and `xtool dev build`. Confirm that only one
  `CameraViewModel` is owned by `ContentView`, the opener still overlays the
  camera, a storage failure does not add a phantom thumbnail, and the changed
  source has no compiler diagnostics.

- [ ] **Step 6: Commit the camera transition slice**

  ```bash
  git add Sources/FrameWise/ContentView.swift Sources/FrameWise/CameraScreen.swift
  git commit -m "feat: animate captures into the persistent library"
  ```

### Task 5: Add Library, Preview, and Share screens

**Files:**
- Create: `Sources/FrameWise/LibraryView.swift`
- Create: `Sources/FrameWise/PhotoPreviewView.swift`
- Create: `Sources/FrameWise/ShareSheet.swift`
- Modify: `Sources/FrameWise/CameraScreen.swift`

**Interfaces:**
- `struct LibraryView: View` receives `@ObservedObject var photoStore: CapturedPhotoStore` and renders the store's persisted `photos` newest first.
- `struct PhotoPreviewView: View` receives `photoID: UUID` and `@ObservedObject var photoStore: CapturedPhotoStore`; it resolves the current item by ID and initially renders Share, a disabled Save slot pending Task 6, Delete, and disabled Edit.
- `struct ShareSheet: UIViewControllerRepresentable` receives a `UIImage` and presents `UIActivityViewController` with that image as its activity item.

- [ ] **Step 1: Run the persistence contract before adding screens**

  Run: `swift test --filter 'CapturedPhoto(Library|DiskStore)Tests'`

  Expected: PASS; the UI will consume an already-tested persistent boundary.

- [ ] **Step 2: Implement the Library list, load state, and empty state**

  Use a scrollable vertical list with thumbnail, capture time, and a row
  navigation action. Show loading and recoverable storage-error states, plus a
  clear empty state when there are no stored photos.

- [ ] **Step 3: Wire the Camera dock to Library and add the return button**

  Make the existing left dock control navigate to `LibraryView` using the
  shared store. Add a lower-right circular camera button with a 44 pt hit
  area; dismiss the current Library destination rather than constructing a
  new camera screen.

- [ ] **Step 4: Implement the Preview screen**

  Render the selected image full-width with safe-area-aware action controls.
  Present Share, a disabled Save placeholder, Delete, and a disabled Edit
  button with accessible labels. If the item was removed or cannot decode,
  show a concise unavailable state and a Back action instead of force-
  unwrapping.

- [ ] **Step 5: Implement the share-sheet bridge**

  Convert the selected `Data` to `UIImage` at the screen boundary and present
  `ShareSheet` as a SwiftUI sheet. Keep the preview open after dismissal and
  do not request Photos permission for sharing.

- [ ] **Step 6: Verify the Library/Preview build**

  Run the host suite and `xtool dev build`. Confirm Library navigation does not
  introduce a second `CameraViewModel` or camera service and that stored items
  are visible after recreating the store.

- [ ] **Step 7: Commit the Library/Preview slice**

  ```bash
  git add Sources/FrameWise/LibraryView.swift Sources/FrameWise/PhotoPreviewView.swift Sources/FrameWise/ShareSheet.swift Sources/FrameWise/CameraScreen.swift
  git commit -m "feat: add persistent library and photo preview"
  ```

### Task 6: Add Save-to-Photos export and app-storage deletion

**Files:**
- Create: `Sources/FrameWise/PhotoLibraryWriter.swift`
- Modify: `Sources/FrameWise/PhotoPreviewView.swift`
- Modify: `FrameWise-Info.plist`

**Interfaces:**
- `enum PhotoLibraryWriterError: LocalizedError` includes invalid image, denied authorization, and write failure cases with user-facing descriptions.
- `final class PhotoLibraryWriter` exposes `func save(data: Data) async throws`, requests `.addOnly` authorization only when the current status is `.notDetermined`, and writes through `PHPhotoLibrary.performChanges`.
- `PhotoPreviewView` accepts a default writer, shows an export state, marks the selected store item exported only after PhotoKit success, and keeps the preview usable after failure.

- [ ] **Step 1: Add the export-state contract test**

  Extend `CapturedPhotoLibraryTests` with
  `[AC-PHOTO1014-ERR2] testUnexportedPhotoRemainsUnexportedUntilMarkExported`
  by asserting that an app-stored item remains unexported until
  `markExported` is explicitly called after a successful writer result. Keep
  `[AC-PHOTO1014-F7] testMarkExportedChangesOnlyTheRequestedCapture` as the
  success contract.

- [ ] **Step 2: Run the focused tests to verify the export contract**

  Run: `swift test --filter CapturedPhotoLibraryTests`

  Expected: PASS before PhotoKit integration; no test requires a device.

- [ ] **Step 3: Implement the PhotoKit writer**

  Decode `Data` to `UIImage`, handle `.authorized`/`.limited` add-only
  success, request `.addOnly` for `.notDetermined`, and throw a typed error
  for `.denied`, `.restricted`, or failed `performChanges`. Bridge callback
  APIs to `async` without blocking the main actor.

- [ ] **Step 4: Add the Photos usage description**

  Add `NSPhotoLibraryAddUsageDescription` with concise copy explaining that
  FrameWise exports captured photos when the user chooses Save. Do not add a
  read-usage key.

- [ ] **Step 5: Wire Save, error recovery, and exported state**

  Use a task-backed export state in `PhotoPreviewView`; on success call
  `await photoStore.markExported(id:)` and update the button to prevent
  duplicate exports in the current stored item. On denied/restricted access,
  show the error and an Open Settings action. On write failure, keep Share,
  Delete, and retry available.

- [ ] **Step 6: Wire app-storage Delete confirmation**

  Present an explicit destructive confirmation stating that the action removes
  the photo from FrameWise only and does not delete its Photos copy. On
  confirmation call `await photoStore.remove(id:)` and dismiss the Preview
  only after the disk removal succeeds; otherwise show a recoverable error.

- [ ] **Step 7: Verify the Photos and deletion slice**

  Run the host suite and `xtool dev build`. On device, test first-run
  add-only authorization, denied authorization, successful export, repeated
  Save, Delete after export, and confirmation copy.

- [ ] **Step 8: Commit Photos actions**

  ```bash
  git add Sources/FrameWise/PhotoLibraryWriter.swift Sources/FrameWise/PhotoPreviewView.swift FrameWise-Info.plist Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift
  git commit -m "feat: export photos and delete app copies"
  ```

### Task 7: Integrate lifecycle, documentation, and final verification

**Files:**
- Modify: `Sources/FrameWise/CameraScreen.swift`
- Modify: `Sources/FrameWise/ContentView.swift`
- Modify: `README.md`
- Modify: `docs/code-walkthrough.md`

**Interfaces:**
- Camera lifecycle remains one `CameraViewModel`/`CameraService` pair; Library presentation may stop the session and camera re-entry may start it again without changing the reducer contract.
- Documentation describes persistent private storage, Share, Save-to-Photos export, FrameWise-only Delete, and disabled Edit scope.

- [ ] **Step 1: Run all host tests**

  Run: `swift test`

  Expected: all existing camera/branding tests and all persistent photo tests
  pass with zero failures.

- [ ] **Step 2: Build the iOS app**

  From the documented WSL shell, run: `xtool dev build`

  Expected: the iOS target builds with the new SwiftUI, PhotoKit, storage,
  and Photos usage-description configuration.

- [ ] **Step 3: Update the walkthrough and README**

  Describe the persistent app-private storage location, Library restore on
  relaunch, Share, Save-to-Photos export, FrameWise-only Delete, and disabled
  Edit flow. Move the completed photo-library slice out of the next-step list
  and leave composition guides as the next product slice.

- [ ] **Step 4: Run the connected-device acceptance checklist**

  Verify and record evidence for:

  - `[AC-PHOTO1014-F1/F2]` capture stays on Camera, writes to app storage, and image flies to the dock;
  - `[AC-PHOTO1014-F3/F4/E3]` Library order, lower-right Camera return, and relaunch restoration;
  - `[AC-PHOTO1014-F5/F6]` Preview actions and native Share sheet;
  - `[AC-PHOTO1014-F7/ERR1/ERR2]` add-only Photos prompt, successful export, denial, and failed export recovery;
  - `[AC-PHOTO1014-F8/ERR4]` FrameWise-only Delete after a Photos export;
  - `[AC-PHOTO1014-E1/E2/ERR3]` empty state, invalid capture, and storage failure recovery;
  - `[AC-PHOTO1014-E4]` Reduced Motion opacity-only transition.

- [ ] **Step 5: Review the final diff for unnecessary complexity**

  Run `git diff --check`, inspect the complete diff, remove duplicated
  ordering/state logic or speculative editing/persistence features, and rerun
  affected tests/build if changes are made.

- [ ] **Step 6: Commit the verified documentation and integration**

  ```bash
  git add Sources/FrameWise/CameraScreen.swift Sources/FrameWise/ContentView.swift README.md docs/code-walkthrough.md
  git commit -m "docs: verify persistent captured photo library flow"
  ```
