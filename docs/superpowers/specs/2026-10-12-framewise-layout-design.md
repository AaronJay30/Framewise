# Framewise — Layout and Visual Design

Date: 2026-10-12

## Design direction

**Framewise — Find the frame.**

Framewise is a camera-first tool. The live image is the canvas, the AI
guide is the instrument, and every other control stays quiet until it is
needed.

The interface should feel calm, precise, and photographic. It should not
look like a dashboard, an AI chatbot, or a collection of feature cards.

## Visual principles

- Keep the camera preview full-screen and visually dominant.
- Show one clear instruction at a time.
- Use the coral target, dot, and arrow as the memorable visual signature.
- Hide advanced controls in a compact bottom sheet or tool tray.
- Prefer native spacing and clear text over decorative effects.
- Never use color alone to communicate state.
- Keep overlays away from the detected subject whenever possible.

Avoid gradients, floating card stacks, persistent labels, heavy shadows,
large logos over the camera preview, and decorative AI sparkles.

## Visual tokens

### Color palette

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#10151B` | App chrome, sheets, dark controls |
| Warm Ivory | `#F5F1E8` | Light text, light surfaces, inactive guides |
| Signal Coral | `#FF6B57` | AI target, subject marker, arrow, primary action |
| Guide Mint | `#BDE8D2` | Aligned, ready, and confirmed states |
| Slate | `#7F8A95` | Secondary text and inactive controls |

The live preview supplies most of the screen color. App chrome should use
Ink with a light scrim rather than opaque panels. Coral and Mint should be
used sparingly so they retain meaning.

### Typography

- **App UI:** SF Pro Text and SF Pro Display.
- **Brand wordmark and marketing:** Space Grotesk SemiBold.
- **Guidance labels:** SF Pro Text Medium, sentence case.
- **Primary action labels:** SF Pro Text Semibold, sentence case.

Suggested type scale:

| Role | Size | Weight |
| --- | ---: | --- |
| Screen title | 20 pt | Semibold |
| Guidance message | 17 pt | Medium |
| Control label | 15 pt | Medium |
| Supporting hint | 13 pt | Regular |

Use Dynamic Type for user-facing text. Avoid all-caps labels and avoid
mixing several typefaces inside the camera experience.

### Shape and spacing

- Use an 8 pt spacing rhythm.
- Use a minimum 44 pt touch target.
- Use 12 pt corner radius for tool trays and compact controls.
- Use a circular shutter control and simple line icons.
- Use no shadow over the camera preview; use a scrim when contrast is
  needed.
- Respect the device safe areas, Dynamic Island, and home indicator.

## Main camera layout

The main camera screen has three quiet layers:

1. Full-screen live preview.
2. Guidance and guide overlays above the preview.
3. A bottom control area with the active mode and capture controls.

```text
┌──────────────────────────────────┐
│  AI Guide                 ···     │
│                                  │
│                                  │
│             ○  →  ●              │
│          live camera preview      │
│                                  │
│        Move camera left           │
│   Place the peak on the upper     │
│              third                │
│                                  │
│   AI Guide    Guides    Reference │
│                                  │
│  Library          ◉          Flip │
└──────────────────────────────────┘
```

The top bar contains only the active mode and essential camera settings.
The bottom dock contains the library button, shutter, camera switch, and
the mode rail. The preview should remain unobstructed between them.

## AI Guide mode

AI Guide is the primary experience.

### Overlay elements

- **Subject marker:** a small coral ring attached to the detected anchor.
- **Target dot:** a coral or ivory dot showing the desired position.
- **Direction arrow:** a thin coral arrow between the current and desired
  positions.
- **Guidance label:** a two-line maximum message above the mode rail.
- **Recommendation label:** an optional small label such as
  `Golden spiral` when AI Auto chooses a composition.

The target dot should not always be centered. It follows the active
composition strategy and may sit on a third, a spiral endpoint, or a
balanced negative-space position.

### Guidance states

| State | Visual treatment | Example copy |
| --- | --- | --- |
| Searching | Ivory text, no arrow | `Looking for a subject` |
| Adjusting | Coral marker and arrow | `Move camera left` |
| Almost aligned | Coral with reduced motion | `Almost there` |
| Ready | Mint marker and check | `Hold steady` |
| Low confidence | Ivory text and no target | `No clear subject detected` |

The arrow and marker use short, damped transitions. They should not jump
with every analyzed frame. The guidance label should change only after a
new instruction remains stable for a short interval.

## Manual Guides mode

Manual Guides keeps the chosen overlay visible and removes unnecessary AI
messaging. The AI may still show a subject marker and alignment feedback,
but it must follow the user-selected composition.

Tapping `Guides` opens a shallow bottom sheet:

```text
┌──────────────────────────────────┐
│                                  │
│        live camera preview        │
│                                  │
├──────────────────────────────────┤
│ Guides                       Done │
│                                  │
│  Rule of thirds   Golden spiral  │
│  Center            Diagonals     │
│  Horizon level                   │
│                                  │
│  Opacity  ───────────────●       │
└──────────────────────────────────┘
```

The sheet should feel like a tool selector, not a card grid. Selecting a
guide closes the sheet and returns the user to the preview.

## Reference mode

Reference mode places the selected photo over the live preview as a quiet
ghost image.

```text
┌──────────────────────────────────┐
│  Reference       Opacity  Lock   │
│                                  │
│       translucent reference       │
│       over live camera view       │
│                                  │
│        Align the mountain peak    │
│                                  │
│  Choose photo       ◉       Close │
└──────────────────────────────────┘
```

Default reference opacity should be approximately 35 percent, with a
manual range from 15 to 70 percent. The reference can be scaled, moved,
rotated, cropped, or locked. AI guidance remains available and points out
the next alignment adjustment.

The reference should never compete visually with the live preview. The
user must be able to reduce opacity immediately.

## Interaction model

- The app opens directly into the camera, not a home dashboard.
- The mode rail has three options: `AI Guide`, `Guides`, and `Reference`.
- Selecting a mode changes the tool behavior without changing the camera
  preview layout.
- Advanced settings open from the top-right overflow control.
- The shutter remains in the same position in every mode.
- A long press or separate control may lock focus and exposure, but these
  controls should not appear by default.

## Voice and interface copy

Use short, direct, user-facing language:

- `Move camera left`
- `Tilt up`
- `Level the horizon`
- `Leave space on the right`
- `Hold steady`
- `Choose a reference photo`
- `No clear subject detected`

Avoid technical language such as `saliency`, `confidence threshold`, or
`composition vector` in the interface.

## Accessibility and resilience

- Every icon has a VoiceOver label.
- Guidance is communicated with text, shape, and position, not color alone.
- Text supports Dynamic Type without covering the shutter or preview.
- Reduced Motion disables animated arrow movement and uses static state
  changes.
- If analysis is unavailable, the camera and manual guides remain usable.
- If the reference cannot be loaded, show a clear recovery action:
  `Choose another photo`.

## Design acceptance criteria

- The camera preview remains the primary visual element.
- A first-time user can understand the AI instruction without training.
- The subject marker, target dot, and arrow remain visible without hiding
  the important part of the scene.
- Manual composition choices are visually respected and are never silently
  replaced.
- Reference mode is adjustable in one tap and can be dismissed quickly.
- The interface feels quiet when no guidance is needed.
