# QS Player Disc Console Redesign

**Status:** Draft for implementation
**Date:** 2026-04-30
**Scope:** Redesign the Quickshell dashboard `PlayerCard` so the now-playing area stops using the generic blurred-album-art treatment and instead becomes a compact Ryoku-styled music console. The design is inspired by the Ambxst circular player reference shared by the user, but must fit Ryoku's existing dashboard layout, theme system, and cyber/control-surface visual language.

Reference: https://github.com/Axenide/Ambxst

---

## 1. Goal

The player in the dashboard should feel intentional within Ryoku rather than like a stock AI-generated media card.

The new player should:

- keep the Cava animation as a first-class visual element
- use album art as a controlled focal token, not a full-card blurred background
- read as a modern Japanese/cybersec dashboard component
- stay compact enough for the current center dashboard column
- preserve the existing MPRIS behavior, source filtering, player switching, playback controls, and seeking

## 2. User-Approved Direction

The approved direction is **Ryoku Disc Console**:

- circular album-art disc near the top
- partial waveform/orbit treatment around the disc
- compact centered metadata below the disc
- icon controls below metadata
- slim progress and mono time labels near the bottom
- Ryoku dashboard glass, active color, muted borders, and JetBrains Mono numeric details

The design should be similar in composition to the provided Ambxst screenshot, but not copied directly. Ryoku should look sharper, darker, less playful, and more like a cyber/control panel.

## 3. Non-Goals

This redesign should not:

- change dashboard dimensions
- rewrite the dashboard home layout
- alter MPRIS filtering or player selection semantics
- add a dependency outside existing QtQuick/Quickshell modules
- create a full Ambxst clone
- use a full-card blurred album-art wash

## 4. Visual Design

### 4.1 Card Surface

`PlayerCard` should use the same base language as the dashboard:

- dark translucent panel
- `Theme.cornerRadius`
- subtle one-pixel border
- restrained active-color accents
- no oversized blurred art background

The background may include very subtle HUD details:

- low-opacity vertical or horizontal rule segments
- a small source/status label
- faint grid/scan accents if they stay quiet
- restrained Ryoku/Japanese-system styling through spacing, mono labels, and signal-panel details

These details must not make the card noisy or reduce metadata readability. Do not add random decorative Japanese text. If Japanese-inspired labeling is used, it should be minimal, intentional, and render reliably with the existing fonts.

### 4.2 Album Disc

Album art becomes a circular disc token, not a background.

The disc should:

- sit near the upper center of the card
- be clipped to a circle
- use a fallback glyph or simple theme-colored fill when art is unavailable
- stay visually dominant without crowding the clock above it

The disc should have a subtle border or rim using the active color at low opacity. If album art is missing, the fallback should still look designed rather than empty.

### 4.3 Cava Ring

Cava should move from generic bottom bars into a Ryoku-specific orbit around the disc.

Recommended treatment:

- partial arc/ring above or around the disc
- bars or short ticks driven by `CavaService.bars`
- active color with opacity tied to amplitude
- restrained animation speed from the existing Cava values

The ring should feel like signal analysis rather than decoration. It should remain legible when the player is paused by falling back to a minimal baseline.

### 4.4 Metadata

Metadata should be compact and centered:

- title as the primary text
- artist below
- optional source label in small JetBrains Mono text

Text should elide cleanly and never overlap controls. The title should not use hero-scale typography inside the compact dashboard card.

### 4.5 Controls

Playback controls stay in the same functional order:

- previous
- play/pause
- next

The play/pause button is the only filled accent control. Previous/next are quieter icon buttons. The controls should use familiar media symbols and keep the current click behavior:

- toggle play/pause when possible
- previous only when supported
- next only when supported

Source switching should only be visible when multiple MPRIS players are available. In that state, it should become a small mono/source chip with a compact expanded list rather than a large upward-expanding pill that competes with the player body.

### 4.6 Progress

Progress should become a slim console line:

- thin track
- active progress fill
- optional segment marker or small thumb
- elapsed and total time in JetBrains Mono

Seeking by clicking the progress track must continue to work.

### 4.7 Secondary Cava Strip

If the disc ring alone feels too light, a low waveform strip can remain near the bottom. It must be shorter and quieter than the current bottom Cava bar wall so the visual hierarchy stays focused on the disc.

## 5. Layout

The implementation should preserve the existing `DashHome` center column:

- `ClockCard` remains above `PlayerCard`
- `PlayerCard` stays anchored from the clock to the dashboard bottom
- no dashboard width or height changes

Inside `PlayerCard`, use stable fixed zones so dynamic text or multiple players do not resize the card:

- top disc zone
- metadata zone
- control zone
- progress/source zone

The design should tolerate the current dashboard center column width of roughly 300 px.

## 6. Behavior

Existing behavior must remain:

- only allowed players are shown
- selected player persists when the MPRIS list changes
- play/pause, previous, and next commands call the current MPRIS player
- progress advances while playing
- clicking progress seeks
- Cava reads from the shared `CavaService`
- hiding the card closes transient player UI

If the source picker is restyled, it must still support multiple players.

## 7. Implementation Notes

Primary file:

- `config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml`

Likely reusable dependencies already exist:

- `Theme` for active/text colors, radius, and static motion mode
- `CavaService` for shared bars and playing state
- `Mpris` for media player state
- `MultiEffect` for circular album-art masking

The redesign can stay in a single QML file. A helper component is only justified if the Cava ring becomes complex enough to make `PlayerCard.qml` hard to read.

## 8. Testing

Static checks:

- run the relevant Quickshell grep/smoke test suite if available
- inspect `PlayerCard.qml` for syntax issues and stale generic blurred background code

Runtime checks:

- reload Quickshell with Ryoku tooling
- open the center dashboard while media is playing
- verify circular art renders with real album art
- verify no-art fallback renders
- verify Cava animates while playing
- verify play/pause, previous, next, and progress seek still work
- verify multiple-player source switching still works
- verify the card does not overlap the clock, calendar, or telemetry rail

## 9. Acceptance Criteria

The work is complete when:

- the dashboard player no longer uses a full-card blurred album-art background
- the player resembles the approved circular-disc console direction
- Cava remains visible and feels integrated into the design
- controls and seeking retain current behavior
- title, artist, time labels, and source text elide cleanly
- the design fits Ryoku's dashboard style and current dimensions
