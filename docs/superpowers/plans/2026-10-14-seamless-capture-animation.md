# Seamless Capture Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the live camera preview perceptibly active while a captured image briefly travels into the Library thumbnail.

**Architecture:** Leave `CameraService`, `CameraViewModel`, persistent storage, and the pending-capture queue unchanged. Replace only the opaque full-screen `CaptureFlightView` treatment with a contained image card, an explicit presentation hold, a 560–620 ms ease-in-out flight, and an opacity-only reduced-motion path. Keep the existing matched-geometry destination so queued captures continue through the same storage boundary.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, XCTest, and xtool.

**Approved behavior:** The camera remains mounted and running after capture; rapid captures remain queued; the first capture is written to app storage before its flight starts; storage failures do not create a thumbnail; Reduced Motion avoids spatial movement; no new dependency or icon is required.

## Task 1: Update the capture-flight presentation

**Files:**
- Modify: `Sources/FrameWise/CameraScreen.swift`
- Create: `docs/superpowers/plans/2026-10-14-seamless-capture-animation.md`

- [x] Inspect the existing camera lifecycle, queue, matched-geometry destination, and reducer coverage.
- [x] Keep the live preview visible by presenting the captured image as a centered, contained card rather than an opaque full-screen overlay.
- [x] Use a visible 150–180 ms hold followed by a 560–620 ms ease-in-out flight; preserve the existing Reduced Motion opacity transition.
- [x] Preserve the existing queue/storage ordering and make no changes to capture-session lifecycle calls.
- [x] Run the host tests, build the iOS target, and review the diff for unnecessary complexity.

## Verification

- `swift test`
- `xtool dev build`
- `git diff --check`
- Confirm source inspection shows `capturePhoto()` does not stop the session and `.captureSucceeded` keeps the reducer in `.running`.
