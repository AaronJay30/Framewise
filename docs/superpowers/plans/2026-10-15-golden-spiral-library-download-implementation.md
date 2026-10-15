# Golden Spiral and Library Download UX Implementation Plan

## Scope

Implement the approved geometry and library/camera presentation refinements
from `docs/superpowers/specs/2026-10-15-golden-spiral-library-download-design.md`.

## Tasks

1. Add failing core tests for golden-rectangle ratio, curve bounds, invalid
   inputs, and pending download selection. Implement the smallest core helpers
   needed to make them pass.
2. Replace the size-aware Golden Spiral points with nested square
   quarter-circle samples. Draw the fitted rectangle and curve in the SwiftUI
   overlay without distortion.
3. Change gallery thumbnails to one square center-cropped frame, move the
   downloaded indicator to the upper-right, and add multi-select download that
   uses the existing add-only Photos writer and export state.
4. Remove decorative backgrounds from preview actions and show visible values
   for Flash, Timer, and Aspect while retaining accessible labels and hit areas.
5. Update README and walkthrough traceability, then run the full host suite,
   iOS build, whitespace check, and final self-review.

## Constraints

- No new dependencies.
- Do not alter the private FrameWise deletion boundary.
- Do not request Photos read access.
- Do not bake composition guides into captured image data.
- Keep horizontal preview paging and downward dismissal behavior intact.
