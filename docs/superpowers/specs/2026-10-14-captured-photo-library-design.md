# Captured Photo Library — Design

Date: 2026-10-14

Feature SLUG: `PHOTO1014`

## User story

As a FrameWise user, I want each captured photo to briefly animate into a
local library while I remain on the camera, so that I can keep shooting and
review, share, save, or remove captures without losing the camera-first flow.

## Scope

This slice adds:

- An in-memory collection of captured photos for the current app process.
- A capture animation that shrinks the new image toward the Library control.
- A Library screen with a newest-first vertical list.
- A lower-right circular camera button that returns to the camera.
- A photo preview screen with Share, Save to Photos, Delete, and a disabled
  Edit placeholder.
- Add-only Photos permission handling for the Save action.

This slice does not add:

- Persistent FrameWise storage across app launches.
- Deletion from the iOS Photos app.
- Photo editing, cropping, filters, or adjustments.
- Cloud upload, remote AI processing, or a full Photos browser.

## Product behavior

### Capture flow

1. The user taps the existing shutter control.
2. The camera remains visible and usable after capture.
3. When valid photo data arrives, FrameWise adds a new item to the in-memory
   collection and updates the Library control to show the latest thumbnail.
4. A visual copy of the captured image starts at the preview size and shrinks
   toward the Library control. The app does not navigate automatically.
5. When Reduce Motion is enabled, the transition uses opacity and a brief
   thumbnail update without spatial movement.

### Library flow

- Tapping the Library control opens a `NavigationStack` destination.
- Photos appear newest first in a vertical, scrollable list.
- Each row contains a thumbnail and a compact capture-time label.
- An empty collection shows an explanatory empty state and the camera return
  button remains available.
- The lower-right circular camera button dismisses the Library destination and
  returns to the camera.
- Selecting a row pushes the corresponding preview screen.

### Preview actions

- **Share** presents the native iOS share sheet with the selected image.
- **Save** requests Photos add-only authorization when needed, writes the
  image to the iOS Photos library, and marks the item saved for this app
  session after success.
- **Delete** asks for confirmation, then removes only the selected item from
  FrameWise's in-memory collection. It never deletes a Photos copy. After a
  confirmed deletion, the preview dismisses to the Library.
- **Edit** is visible but disabled and communicates that editing is not yet
  available.

## Architecture and data flow

### Shared photo model

Add a hardware-independent `CapturedPhoto` value with:

- Stable in-session `UUID` identity.
- Original encoded image `Data` returned by `AVCapturePhoto`.
- Capture `Date` for list presentation.
- In-session saved status used to prevent repeated Save actions during the
  current process.

Add a small `CapturedPhotoLibrary`/store boundary that supports append,
newest-first access, saved-status updates, and removal by ID. The collection
is main-actor-owned because SwiftUI, navigation, and capture callbacks all
consume it on the main actor. It is intentionally not persisted.

### Screen ownership

- `ContentView` owns the camera view model and shared photo store inside one
  `NavigationStack`.
- `CameraScreen` receives the store, appends successful captures, renders the
  Library control thumbnail, and owns the capture animation state.
- `LibraryView` reads the store, renders the list, and provides the floating
  camera button.
- `PhotoPreviewView` reads one photo by ID and dispatches share, save, delete,
  and disabled edit actions.
- A small share-sheet bridge wraps `UIActivityViewController`.
- A Photos writer owns the add-only authorization request and
  `PHPhotoLibrary` creation request; it reports success or a user-facing
  failure without exposing PhotoKit types to the views.

The existing `CameraService` remains responsible only for AVFoundation
session and capture work. It continues to emit photo data through the current
view-model boundary; it does not know about navigation, Photos, or library
storage.

### Navigation

The camera stays the root of the `NavigationStack`. The Library is pushed from
the dock, and a selected photo is pushed from the Library. The Library's
floating camera button uses the current navigation dismissal action, so it
does not create a second camera screen or a second camera session.

When the Library covers the camera, the camera session should stop if the
existing service lifecycle can support it cleanly, and restart when the
camera screen becomes visible again. This is a battery-conscious refinement,
not a reason to couple the library to AVFoundation.

## Error handling and privacy

- Invalid or undecodable capture data is not added to the collection and
  leaves the camera usable.
- A Share presentation failure leaves the preview open and shows a concise
  retryable message when the platform reports an error.
- A denied or restricted Photos add-only request leaves the photo in FrameWise
  and offers a Settings route; it does not retry in a loop.
- A failed Photos write leaves the item unsaved and shows a retryable error.
- Delete confirmation explicitly states that the Photos copy, if any, will
  remain untouched.
- Add `NSPhotoLibraryAddUsageDescription` to the app configuration. Do not
  request read access because this feature does not browse the Photos library.
- Photo data stays in process memory and is never sent to a network service.

## Accessibility and motion

- Library, camera, Share, Save, Delete, and Edit controls have descriptive
  VoiceOver labels and at least 44 pt hit areas.
- The camera button communicates that it returns to Camera.
- The Library label includes the number of in-memory captures when useful.
- Delete is styled as destructive and requires confirmation.
- Reduced Motion removes the capture image's spatial travel while retaining a
  clear state change.
- Dynamic Type and empty/error states must not obscure the floating camera
  control or safe-area content.

## Acceptance criteria

### Functional

- [AC-PHOTO1014-F1] A successful capture remains on the Camera screen and
  adds exactly one photo to the session-only library.
- [AC-PHOTO1014-F2] The captured image animates toward the Library control;
  capture does not automatically navigate to Library.
- [AC-PHOTO1014-F3] Library opens from the camera dock and shows captures in
  newest-first order with thumbnails.
- [AC-PHOTO1014-F4] Library provides a lower-right circular camera control
  that returns to the existing Camera screen.
- [AC-PHOTO1014-F5] Selecting a library item opens a preview with Share, Save,
  Delete, and a visible disabled Edit control.
- [AC-PHOTO1014-F6] Share presents the native iOS share sheet for the selected
  image.
- [AC-PHOTO1014-F7] Save writes the selected image to the iOS Photos library
  after add-only authorization succeeds.
- [AC-PHOTO1014-F8] Delete removes the item from FrameWise's in-memory
  library after confirmation and leaves any Photos copy untouched.

### Security and privacy

- [AC-PHOTO1014-S1] The app requests only Photos add-only authorization and
  does not request or browse read access.
- [AC-PHOTO1014-S2] Captured image data is not uploaded or sent to an online
  service by this feature.

### Edge cases

- [AC-PHOTO1014-E1] An empty library renders a clear empty state and remains
  navigable back to Camera.
- [AC-PHOTO1014-E2] Invalid capture data is ignored without crashing or
  blocking the camera.
- [AC-PHOTO1014-E3] The library is cleared when the app process ends; no
  persistence is implied.
- [AC-PHOTO1014-E4] Reduce Motion removes spatial capture movement while
  preserving a visible completion transition.

### Error handling

- [AC-PHOTO1014-ERR1] Denied or restricted Photos authorization leaves the
  photo in FrameWise and offers a recoverable Settings path.
- [AC-PHOTO1014-ERR2] A failed Photos write leaves the item unsaved and keeps
  the preview usable for retry or Share.
- [AC-PHOTO1014-ERR3] Delete requires explicit confirmation and clearly states
  that it does not remove the Photos copy.

## Testing and verification

### Host tests

Add hardware-independent tests for:

- Appending captures and preserving newest-first order.
- Removing only the requested ID.
- Marking one item saved without changing other items.
- Empty-library behavior and invalid-data rejection at the model boundary.

Use the AC IDs in test names so every criterion has traceable evidence.

### Build and device checks

- Run the complete host test suite.
- Run `xtool dev build`.
- On a connected iPhone, verify capture animation, continued camera use,
  Library navigation, list ordering, camera return, preview actions, Photos
  authorization outcomes, deletion behavior, and Reduced Motion.

## Change surface

Expected files include:

- `Sources/FrameWiseCore/CapturedPhoto.swift`
- `Sources/FrameWiseCore/CapturedPhotoLibrary.swift`
- `Sources/FrameWise/CapturedPhotoStore.swift`
- `Sources/FrameWise/LibraryView.swift`
- `Sources/FrameWise/PhotoPreviewView.swift`
- `Sources/FrameWise/ShareSheet.swift`
- `Sources/FrameWise/PhotoLibraryWriter.swift`
- `Sources/FrameWise/ContentView.swift`
- `Sources/FrameWise/CameraScreen.swift`
- `Sources/FrameWise/CameraViewModel.swift`
- `FrameWise-Info.plist`
- `Tests/FrameWiseCoreTests/CapturedPhotoLibraryTests.swift`
- `README.md` and the implementation plan

No external dependency is required.
