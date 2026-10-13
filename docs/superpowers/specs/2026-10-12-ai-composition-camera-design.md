# AI Composition Camera — Product Design

Date: 2026-10-12

## Product definition

An iOS camera app that helps people compose better photographs in real time. The app provides an offline AI composition coach, traditional composition overlays, and a reference-photo alignment mode. The captured photo is clean; guidance overlays are never embedded in the saved image.

The initial product focus is scenery and landscapes. The design can later extend to portraits, products, architecture, and other subjects.

## Core product rule

Composition selection and framing guidance are separate concerns:

- In **AI Auto** mode, the app recommends a composition strategy and guides the user toward it.
- In **Manual Guide** mode, the user selects the composition strategy and the AI only helps the user align the scene to that choice.
- In **Reference** mode, the reference image defines the target composition and the AI helps align the live scene to it.

AI must never silently replace a composition that the user selected manually.

## User modes

### AI Auto

The app analyzes the live scene and ranks suitable composition strategies. Candidate strategies include rule of thirds, Fibonacci/golden spiral, centered composition, symmetry, diagonals, and horizon placement.

The app presents the selected recommendation with a brief explanation, for example: “Recommended: golden spiral — the river leads toward the mountain.” The user may accept the recommendation or switch to a manual guide.

### Manual Guides

The user chooses a guide such as:

- Rule-of-thirds grid
- Fibonacci/golden spiral
- Center grid
- Diagonal lines
- Horizon-level guide

The user can adjust guide opacity, color, and visibility. Once selected, the guide remains active until the user changes it.

### Reference

The user imports a photo from the photo library and displays it over the live camera preview. Controls include opacity, scale, position, rotation, crop/aspect ratio, and lock/unlock.

When a reference is active, the app may use available image metadata to apply an approximate lens or zoom setting, then use visual alignment guidance for manual correction. Exact recreation is not promised because camera position, lens, perspective, crop, and aspect ratio affect the result.

## AI guidance interaction

The live preview contains:

- A subject marker showing the detected anchor, such as a mountain peak, tree, building, sun, or person.
- A target dot showing where that anchor should sit for the active composition.
- An arrow showing the required camera movement.
- A short explanation of why the adjustment is recommended.

Example guidance:

- “Move camera left — place the peak on the upper third.”
- “Tilt up — keep more foreground.”
- “Level the horizon.”
- “Leave space on the right.”

When the subject marker and target dot are sufficiently aligned, the target changes to a ready state:

- “Hold steady.”
- “Balanced composition.”

Only one primary instruction should be shown at a time. Guidance should be temporally smoothed to prevent jitter and should not change until the new recommendation is stable. If confidence is low, the app should say that it cannot identify a clear subject instead of giving a misleading instruction.

## Composition recommendation behavior

AI Auto considers scene signals such as the main subject, horizon, symmetry, leading lines, negative space, subject placement, and the selected output aspect ratio. It produces a recommendation and an explanation, not an absolute claim that one composition is objectively best.

If the scene does not provide enough evidence for a specific strategy, the app should use a simple balanced recommendation or ask the user to choose a guide manually.

## Offline and privacy requirements

- Camera-frame analysis must run on the device.
- Reference images must remain on the device unless the user explicitly shares them.
- No online AI service is required for capture or guidance.
- Users can disable AI guidance and use the camera and overlays manually.

## Initial MVP

The first release includes:

1. Custom camera preview and still-photo capture.
2. AI Auto guidance for scenery and landscapes.
3. Subject marker, target dot, movement arrow, and explanation label.
4. Rule-of-thirds, Fibonacci/golden spiral, and horizon overlays.
5. Reference-photo overlay with opacity, scale, position, and lock controls.
6. Approximate zoom matching with manual adjustment.
7. Local-only processing.

Voice guidance, advanced portrait guidance, automatic lens switching, automatic camera movement, cloud AI, and automatic photo editing are outside the initial MVP.

## Success criteria

- A user can understand the next camera movement at a glance.
- AI Auto can recommend a composition and explain the recommendation briefly.
- A manually selected guide is never overridden by AI.
- Reference mode allows a user to visually align a new shot with an existing photo.
- Guidance remains stable while the user is composing.
- Saved photos do not contain the guide, reference image, arrow, dot, or labels.
