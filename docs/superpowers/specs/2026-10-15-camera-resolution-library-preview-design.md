# Camera Resolution, Golden Spiral, and Library Preview — Design

Date: 2026-10-15  
Feature SLUG: `CAMLIB1015`  
Status: Design approved in conversation

## Intent

FrameWise should make the Golden Spiral feel like a real photographic
composition curve, expose the active camera's highest supported still-photo
resolution without pretending every device is a 45 MP camera, and make library
photos easier to inspect in their native framing. The camera and library should
continue to feel like one dark, photography-first surface.

## User story

As a photographer, I want a smooth Golden Spiral guide, a resolution choice
that reflects my device, and a library preview that respects my images so I
can compose, capture, and review photos without fighting the interface.

## Scope

### Included

- Replace the current Golden Spiral's segmented square-arc construction with a
  continuous smooth Fibonacci/logarithmic curve.
- Keep the spiral in the existing fixed canonical orientation: focal point
  toward the lower-right, opening toward the upper-left like the supplied
  reference image. Fit the curve to the active preview bounds for portrait,
  square, and landscape-shaped frames without clipping it.
- Make the top Composition control icon-only visually. Keep its accessibility
  label/value and a minimum 44-point hit target, but remove its capsule/glass
  background and shadow.
- Remove the decorative shadow from composition guide artwork so the overlay
  remains a crisp line drawing.
- Add a persisted `Standard` / `Maximum` still-photo resolution mode.
- Add a Resolution control and dedicated black resolution sheet. The sheet
  displays the active camera's actual maximum megapixel value when available,
  such as `Maximum (45 MP)`, and disables the maximum choice when unsupported.
- Configure each capture request with only dimensions supported by the active
  camera format. Switching cameras refreshes the reported capability.
- Change the Library camera action to a full-width black camera-style bottom
  bar without the floating shadow treatment.
- Preserve captured-photo aspect ratios in gallery tiles. A 16:9 image uses
  the available width and its matching height without cropping or overflowing.
- Pass the current gallery's ordered photo IDs into the preview and support
  horizontal paging between them.
- Let tapping the preview image hide or reveal the bottom action section. The
  hidden state lets the image use the available viewport while keeping the
  existing actions available after another tap.
- Keep delete, share, save, and unavailable-photo recovery behavior intact.

### Deferred

- User-selectable spiral rotation or focal-point editing.
- A full list of every intermediate sensor dimension exposed by a device.
- RAW/ProRAW capture, format selection, zoom-dependent sensor switching, or
  multi-camera capture.
- Non-destructive editing, crop tools, or gesture-based image zoom.
- Reordering or filtering the library while paging.

## Approaches considered

### Hard-coded 45 MP toggle

Rejected. It would show an option that many devices cannot satisfy and would
make a persisted setting unsafe when the user changes cameras or devices.

### Dynamic Standard/Maximum mode (selected)

Persist the intent rather than a device-specific pixel dimension. The camera
service discovers the active format's supported maximum dimensions, reports a
human-readable megapixel value to the view model, and chooses a valid maximum
dimension only when the user selects `Maximum`. This keeps the settings model
portable while making the UI honest.

### Full device-specific resolution list

Deferred. It could expose several valid dimensions, but it adds a second
device-dependent catalog and more persistence rules without being needed for
the requested Standard versus high-resolution workflow.

## Shared understanding

- The live camera preview remains the source of truth for overlay bounds.
- The Golden Spiral change is geometric and visual; it does not add motion,
  sensor leveling, or captured-image markup.
- Composition control buttons in the sheet remain borderless and backgroundless.
  This pass also removes the visible treatment from the top Composition icon.
- Resolution is a camera capture setting, separate from photographic styles
  and composition guides. It persists through the existing settings store.
- The stored setting is an intent (`Standard` or `Maximum`), not a hard-coded
  `45 MP` value. The active camera determines the displayed maximum label.
- Library paging is scoped to the photos currently shown by the gallery: All
  Photos pages through all visible photos; a day gallery pages through that
  day's photos.
- The composition overlay remains view-only and is never passed to the photo
  processor or written into library bytes.

## Camera composition UI

### Golden Spiral renderer

`CompositionGuideArtwork` will use one normalized continuous path for both the
live overlay and the miniature preview. The path will be generated from a
sampled logarithmic spiral rather than nested square arcs. Its geometry will:

1. Place the inner focal turn in the lower-right region of the bounds.
2. Expand by the golden-ratio growth factor over quarter turns.
3. Rotate so the outer curve sweeps toward the upper-left, matching the
   supplied reference.
4. Scale and translate the sampled points into an inset bounding rectangle so
   the stroke stays inside the visible preview at every supported aspect ratio.

The live overlay retains the selected opacity and the existing stroke color
conventions. Miniature selected artwork remains Signal Coral. No shadow is
applied to the Canvas.

### Icon-only Composition control

`CameraTopControls` keeps the Composition control beside Photographic Styles,
but its label is represented visually by the existing grid symbol only. It
uses `.plain` button styling, no `CameraGlass`, no background shape, and no
shadow. The control still exposes `Composition` as its accessibility label,
the selected guide as its accessibility value, and a minimum 44-point frame.
Other top controls retain their current visual treatment unless required by
the layout change.

## Resolution state and capture boundary

Add a hardware-independent core enum:

```swift
public enum CameraPhotoResolution: String, CaseIterable, Codable, Sendable {
    case standard
    case maximum
}
```

Add `photoResolution`, defaulting to `.standard`, to `CameraSettings`. The
custom decoder treats the field as optional so older settings restore safely.
`normalized()` leaves the enum value unchanged; capability fallback occurs at
the camera-service boundary because the core model cannot know the active
device.

`CameraService` will:

- inspect the active format's supported maximum photo dimensions when the
  session is configured or the camera is flipped;
- publish whether a maximum option is available and its calculated megapixel
  label through the existing delegate/view-model capability flow;
- keep the photo output's maximum dimensions within the active format's
  supported maximum before the session starts; and
- set `AVCapturePhotoSettings.maxPhotoDimensions` per capture to a valid
  standard or maximum dimension, falling back to the standard dimension when
  the requested maximum is unavailable.

Apple's AVFoundation contract requires requested photo dimensions to match a
dimension supported by the active format and not exceed the photo output's
maximum. The implementation will follow that contract rather than inventing a
pixel size.

The view model exposes the current maximum megapixel label and passes it to a
new `CameraResolutionSheet`. The sheet shows:

- `Standard` — the default and broadly supported option;
- `Maximum (N MP)` — selected only when a valid maximum is available; and
- a disabled explanatory state when the active camera cannot provide a
  separate maximum.

Changing the setting updates the view model immediately and leaves the sheet
open. The choice persists with the other camera settings. The active capture
request uses the snapshot of the setting taken when the shutter is pressed.

## Library and preview UI

### Library bottom action

Replace the floating coral camera button's rounded floating treatment with a
full-width black bottom bar matching the camera's top section. Keep the camera
icon and 44-point minimum target, remove the drop shadow, and preserve the
existing dismiss behavior and accessibility hint.

### Aspect-safe gallery tiles

`GalleryPhotoTile` will decode the image's display size and use its aspect
ratio for the tile. The image is rendered with `scaledToFit` inside the tile's
available width, with no fixed square crop. Placeholder tiles retain a stable
fallback ratio. The gallery's scroll container remains responsible for
vertical movement, so a wide 16:9 image cannot exceed the device width.

### Paged preview

`PhotoGalleryView` will pass its ordered visible IDs into
`PhotoPreviewView`. `LibraryView` will do the same for each day group and All
Photos entry. `PhotoPreviewView` will render a `TabView(selection:)` with page
style, one page per available photo, and initialize selection to the tapped
photo.

Each page uses `scaledToFit` against the available black viewport. The preview
will not crop or enlarge a 16:9 image beyond the viewport. The existing action
section remains a black safe-area inset at the bottom.

### Tap-to-toggle controls

The preview image area toggles `areControlsVisible`. When hidden, the bottom
action section is removed with a short opacity transition and the page view
uses the full available viewport. A second tap restores it. The transition is
disabled under Reduce Motion. The image/page container exposes an accessibility
action and value describing whether controls are shown so the interaction is
not dependent on an unlabeled gesture.

Deletion operates on the currently selected page. After a successful delete,
the preview selects the nearest remaining ID when one exists; if the current
gallery is empty, it dismisses. Share and Save always use the currently
selected photo, not the originally tapped ID.

## Failure and edge behavior

- A persisted `.maximum` selection on a device with no valid maximum falls
  back to standard for that capture and displays the disabled capability state;
  it does not fail camera startup.
- Flipping cameras refreshes the displayed megapixel capability and retains
  the user's Standard/Maximum intent.
- Older settings payloads decode with Standard resolution.
- A device whose supported-dimension list is empty uses the existing capture
  defaults and reports no maximum option.
- A malformed gallery image remains an unavailable placeholder and must not
  break paging for healthy photos.
- A single-photo gallery still supports the controls toggle but has no paging
  movement.
- Deleting the last photo dismisses the preview and leaves the gallery's empty
  state available.

## Accessibility and privacy

- Icon-only controls retain descriptive VoiceOver labels and values.
- Resolution choices announce Standard or the actual maximum megapixel value.
- The controls toggle has an explicit accessibility action for showing or
  hiding the bottom actions.
- All interactive targets remain at least 44 points.
- Reduce Motion removes overlay/control transitions without removing behavior.
- Resolution and composition choices remain local settings.
- Composition guides are never embedded into captured image bytes or uploaded.

## Acceptance criteria

### Functional

- `[AC-CAMLIB1015-F1]` Golden Spiral renders as one continuous smooth curve,
  not a visible sequence of square-based arc segments.
- `[AC-CAMLIB1015-F2]` Golden Spiral uses the approved lower-right focal-point
  orientation, opens toward the upper-left, and remains inside the visible
  preview bounds for supported aspect ratios.
- `[AC-CAMLIB1015-F3]` The top Composition control is visually icon-only,
  has no capsule/glass background or shadow, and still opens the composition
  sheet with an accessible label/value.
- `[AC-CAMLIB1015-F4]` The composition artwork and library camera action have
  no decorative drop shadow, while required interaction targets remain intact.
- `[AC-CAMLIB1015-F5]` Camera settings expose Standard and Maximum photo
  resolution modes with Standard as the default and persist the choice.
- `[AC-CAMLIB1015-F6]` The Resolution sheet displays the active camera's actual
  maximum megapixel value and disables Maximum when no separate maximum is
  available.
- `[AC-CAMLIB1015-F7]` A Maximum capture requests only dimensions supported by
  the active camera format; Standard remains a safe fallback.
- `[AC-CAMLIB1015-F8]` Flipping cameras refreshes resolution capability without
  losing the user's resolution intent.
- `[AC-CAMLIB1015-F9]` The Library camera action uses a full-width black
  camera-style bottom bar and preserves its dismiss behavior.
- `[AC-CAMLIB1015-F10]` Gallery tiles preserve image aspect ratio, and 16:9
  photos fit the available width without crop or overflow.
- `[AC-CAMLIB1015-F11]` Preview pages can be swiped horizontally in the order
  supplied by the current gallery.
- `[AC-CAMLIB1015-F12]` Tapping the preview image hides and reveals the bottom
  action section while the image expands to the available viewport when hidden.
- `[AC-CAMLIB1015-F13]` Share, Save, and Delete operate on the currently
  selected paged photo, and deletion selects a valid neighbor or dismisses
  when no photos remain.

### Security and privacy

- `[AC-CAMLIB1015-S1]` Resolution and composition state remain local, and
  composition guides are never embedded in or uploaded with captured bytes.

### Edge cases

- `[AC-CAMLIB1015-E1]` Settings written before `photoResolution` existed decode
  with Standard and preserve all existing camera settings.
- `[AC-CAMLIB1015-E2]` A persisted Maximum choice on unsupported hardware falls
  back to a valid standard capture without blocking startup or capture.
- `[AC-CAMLIB1015-E3]` Flipping to a camera with different supported dimensions
  updates the displayed maximum label without corrupting the settings payload.
- `[AC-CAMLIB1015-E4]` Malformed images, a single-photo gallery, and deletion of
  the last photo leave the library and preview recoverable.
- `[AC-CAMLIB1015-E5]` Reduce Motion and VoiceOver preserve the controls-toggle
  behavior without relying on animation or color alone.

## Verification plan

### Automated

- Add host tests for resolution catalog/defaults, Codable legacy decoding,
  and safe setting behavior.
- Add pure tests for megapixel labeling, supported-dimension selection, and
  standard fallback without importing AVFoundation into `FrameWiseCore`.
- Run the focused tests before implementation and record RED/GREEN results.
- Run the full `swift test` suite.
- Run the iOS target build with `xtool dev build`.
- Run `git diff --check`.
- Search implementation, tests, and documentation for all
  `AC-CAMLIB1015-*` identifiers.

### Device checks

- Open Composition and confirm the icon-only control has no visible backplate.
- Compare the Golden Spiral to the supplied reference in 4:3, 1:1, and 16:9.
- Open Resolution on supported and unsupported cameras and verify the actual
  maximum label.
- Capture Standard and Maximum photos and inspect their pixel dimensions.
- Flip cameras and confirm capability labels update.
- Open All Photos and a day gallery, swipe between pages, and confirm order.
- Open a 16:9 photo, confirm it fits without overflow, tap to hide/show
  actions, then delete the current page and verify neighbor selection.
- Verify VoiceOver, Reduce Motion, and large text behavior.

## Planned implementation files

- Create `Sources/FrameWiseCore/CameraPhotoResolution.swift`.
- Create `Sources/FrameWise/CameraResolutionSheet.swift`.
- Extend `Tests/FrameWiseCoreTests/CameraSettingsTests.swift` or add a focused
  resolution test file.
- Modify `Sources/FrameWiseCore/CameraSettings.swift`.
- Modify `Sources/FrameWise/CameraService.swift`.
- Modify `Sources/FrameWise/CameraViewModel.swift`.
- Modify `Sources/FrameWise/CameraControls.swift` and
  `Sources/FrameWise/CameraScreen.swift`.
- Modify `Sources/FrameWise/CompositionGuideOverlay.swift`.
- Modify `Sources/FrameWise/LibraryView.swift`.
- Modify `Sources/FrameWise/PhotoGalleryView.swift`.
- Modify `Sources/FrameWise/PhotoPreviewView.swift`.
- Update `README.md` and `docs/code-walkthrough.md` after verification.

