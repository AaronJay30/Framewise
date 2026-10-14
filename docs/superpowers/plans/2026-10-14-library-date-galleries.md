# Library Date Galleries and Capture Flight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make capture feedback visibly smooth and replace the flat Library list with date-grouped and all-photo gallery navigation.

**Architecture:** Keep camera capture, persistence, and preview actions unchanged. Add a hardware-independent calendar-day grouping helper in `FrameWiseCore`, render day groups and the All Photos mode in SwiftUI, and share one grid-based gallery destination for both scopes. Keep the capture flight mounted through a longer, explicit hold-and-flight transaction so matched geometry has time to render and complete.

**Tech Stack:** Swift 6, SwiftUI, UIKit, Foundation Calendar, XCTest, and xtool.

**Spec:** Approved follow-up design in the conversation, building on `docs/superpowers/specs/2026-10-14-captured-photo-library-design.md`.

## Global Constraints

- Preserve the existing app-private photo storage and newest-first source order.
- Keep Camera as the root flow; do not create a second camera service or view model.
- Preserve Share, Save, Delete, Edit, storage-error, and empty-state behavior.
- Group dates using the user’s current calendar and local day boundaries.
- Keep Reduced Motion spatially still and accessible labels/hit areas intact.
- Add no external dependencies or new icon library.

## Review Focus

- Captures around midnight must be assigned to the correct local calendar day; pinned by grouping boundary tests.
- Photos within a day and across day groups must remain newest first; pinned by grouping order tests.
- An empty library must keep the existing empty state and Camera return control; pinned by existing UI logic and build.
- Deleting a photo from a gallery must remove it from the visible grid after returning; pinned by the gallery reading the shared store by ID.
- The flight must remain visible long enough to show a spatial transition while not blocking camera controls; pinned by the explicit timing path and device verification.

### Task 1: Add the tested calendar-day grouping boundary

**Files:**
- Create: `Sources/FrameWiseCore/CapturedPhotoGrouping.swift`
- Create: `Tests/FrameWiseCoreTests/CapturedPhotoGroupingTests.swift`

- [x] Write failing tests for newest day first, newest photo first within a day, and calendar-day boundary handling.
- [x] Run the focused grouping tests and confirm they fail because the helper does not exist.
- [x] Implement `CapturedPhotoDayGroup` and `CapturedPhotoGrouping.groupByDay(_:calendar:)` with local `startOfDay` keys.
- [x] Run the focused grouping tests and the full host suite.

### Task 2: Replace the flat Library list with day groups and galleries

**Files:**
- Modify: `Sources/FrameWise/LibraryView.swift`
- Create: `Sources/FrameWise/PhotoGalleryView.swift`

- [x] Add a two-mode Library control: By Day and All Photos.
- [x] Render By Day as tappable Today/Yesterday/date groups with count and representative thumbnails.
- [x] Render All Photos and each date group through a shared three-column `LazyVGrid` gallery.
- [x] Keep each tile linked to `PhotoPreviewView` by photo ID and preserve the floating Camera button, loading, empty, and storage-error states.
- [x] Build the iOS target and inspect the navigation/data flow for stale deleted items.

### Task 3: Slow and stabilize the capture flight

**Files:**
- Modify: `Sources/FrameWise/CameraScreen.swift`

- [x] Keep the live preview and hit-testing behavior unchanged beneath the overlay.
- [x] Give the image card a visible 150–180 ms presentation hold before starting the matched-geometry removal.
- [x] Use a 560–620 ms ease-in-out flight and preserve the Reduced Motion opacity-only path.
- [x] Keep the overlay mounted until the completion callback so the image cannot disappear before the flight starts.
- [x] Run the full host suite and iOS build; record that device timing still needs connected-iPhone verification.

### Task 4: Document and verify the complete follow-up

**Files:**
- Modify: `README.md`
- Modify: `docs/code-walkthrough.md`

- [x] Document date-group and All Photos gallery navigation plus the smoother capture flight.
- [x] Run `swift test`, `xtool dev build`, and `git diff --check`.
- [x] Review the final diff for unnecessary abstractions, then commit and push the worktree branch for merge into `main`.
