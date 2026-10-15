# Golden Spiral and Library Download UX

## Goal

Make the Golden Spiral guide follow the geometric construction of a golden
rectangle and nested square quarter-arcs, then refine the library and camera
controls without changing the existing private-library or Photos export
boundaries.

## Decisions

- Golden Ratio remains the phi-line grid. Golden Spiral draws a fitted golden
  rectangle and a continuous curve sampled from nested square quarter-arcs.
- The golden rectangle is fitted inside the available preview without
  stretching. Portrait bounds use a vertical golden rectangle; landscape
  bounds use a horizontal one.
- Library thumbnails use one square, center-cropped frame. The stored image
  and full preview keep their original aspect ratio.
- Library selection download means add-only export to Photos. Existing
  `isExported` photos are skipped, successful exports are marked, and private
  FrameWise files remain untouched.
- Downloaded status uses a download symbol in the tile's upper-right corner.
  Selection checkmarks remain available only while selection mode is active.
- Preview Share, Save, Delete, and Edit controls keep their labels and
  accessibility actions but use transparent, plain styling.
- Flash, Timer, and Aspect show their current values beside their symbols;
  other camera controls remain icon-only.

## Acceptance criteria

- `[AC-GOLDSPIRAL1015-F1]` Golden Spiral geometry exposes a fitted rectangle whose
  long side divided by short side equals phi and whose curve stays inside it.
- `[AC-GOLDSPIRAL1015-E1]` Invalid golden-geometry dimensions or sample counts
  produce no points and no rectangle.
- `[AC-GALLERYUX1015-F1]` Every library tile uses the same square crop frame.
- `[AC-GALLERYUX1015-F2]` Multi-select download exports only pending selected
  photos and preserves the existing add-only Photos behavior.
- `[AC-GALLERYUX1015-F3]` Exported tiles show a download indicator at top-right;
  selection state remains separate.
- `[AC-GALLERYUX1015-F4]` Preview actions use plain transparent button styling.
- `[AC-CAMERACTRL1015-F1]` Flash, Timer, and Aspect render their current values
  visibly while retaining 44-point hit areas and accessibility values.

## Verification

- Run focused geometry and export-helper tests before implementation and again
  after implementation.
- Run the complete Swift test suite, `xtool dev build`, and `git diff --check`.
- Perform a physical-device check for the camera overlay, Photos permission,
  and tile/preview rendering when an iPhone is available.
