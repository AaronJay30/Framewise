# Camera Orientation and Library UX Fixes

**Feature SLUG:** `CAMUX1015`

## Goal

Make camera captures preserve the user's landscape orientation, keep camera
controls visually quiet and icon-only, correct the Golden Spiral geometry, and
add familiar multi-selection and swipe-down dismissal behavior to the library.

## Approved design

1. Preserve the existing `AVCaptureDevice.RotationCoordinator` capture-angle
   path, and make post-capture aspect cropping follow the source image's
   orientation. A landscape source uses the landscape form of 4:3 or 16:9;
   a portrait source keeps the existing portrait form.
2. Render the five requested top controls and the camera-flip control with
   plain icon-only buttons. Active states remain coral and state details stay
   available through accessibility values.
3. Generate the Golden Spiral inside an aspect-fitted square within the live
   preview. This keeps the curve circular in portrait and landscape frames.
4. Add selection mode to each photo gallery. Select/Done controls toggle the
   mode, tiles toggle selection, and a confirmed bulk Delete removes selected
   private FrameWise copies. Individual preview actions remain unchanged.
5. Add a vertical, downward-only dismissal gesture to preview pages. A
   sufficiently long vertical drag dismisses the navigation page; horizontal
   drags continue to belong to the existing `TabView` pager.

## Acceptance criteria

- `[AC-CAMUX1015-F1]` A landscape source cropped as 16:9 uses a 16:9 target,
  not the portrait 9:16 target.
- `[AC-CAMUX1015-F2]` Square and portrait sources retain their expected crop
  orientation, including safe behavior for invalid dimensions.
- `[AC-CAMUX1015-F3]` Flash, Timer, Aspect, Photographic Style, Composition,
  Resolution, and camera-flip controls have no decorative border, capsule, or
  background while retaining usable hit areas and accessibility state.
- `[AC-CAMUX1015-F4]` Golden Spiral geometry preserves its aspect instead of
  stretching into an oval.
- `[AC-CAMUX1015-F5]` A gallery can enter selection mode, select and deselect
  multiple photos, and display the selected count.
- `[AC-CAMUX1015-F6]` Bulk deletion requires confirmation and removes only the
  selected private FrameWise copies.
- `[AC-CAMUX1015-F7]` A downward vertical swipe from preview dismisses the
  preview page.
- `[AC-CAMUX1015-E1]` Horizontal and upward drags do not dismiss preview;
  horizontal paging remains available.
- `[AC-CAMUX1015-E2]` Selection state is reconciled when a photo disappears
  from the gallery.
- `[AC-CAMUX1015-E3]` Invalid or degenerate spiral dimensions return safe
  geometry without crashing or producing non-finite coordinates.
- `[AC-CAMUX1015-S1]` Bulk deletion never starts without an explicit user
  confirmation.

## Non-goals

- No new camera format picker, RAW/ProRAW support, or device-specific
  megapixel assumptions.
- No changes to the existing composition-guide catalog or photo preview
  share/save/delete actions.
- No online services or new dependencies.

## Verification boundary

Core geometry, crop, selection, and gesture-direction contracts run in the
host XCTest suite. The SwiftUI/AVFoundation adapters are verified by the iOS
build. Physical landscape capture, final Photos metadata, gesture feel,
VoiceOver, and Reduce Motion behavior require a connected iPhone.
