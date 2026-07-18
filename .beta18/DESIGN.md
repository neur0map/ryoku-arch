# RYOKU UI, DESIGN CONTRACT (beta18)

Paper and ink: a monochrome printed instrument. Black paper with grain, warm
bone ink, inversion for emphasis, one red sun in the art and nowhere else.

This document is the implementation contract for **app-class surfaces**: the
Hub (Ryoku Settings), the welcome tour, dialogs, and any future settings-grade
window. It is the detailed contract for these surfaces; `docs/ui-ux.md` is the
desktop-wide overview. It does **not** govern the shell's spatial chrome, the frame, the
bar, the popouts keep their own motion (`pill/Singletons/Motion.qml` springs)
and carry the accent. The two systems meet at the Hyprland frame: the frame is
vermillion `#e2342a` (or the wallust colour when the user's rice wins), and
everything inside an app window is paper and ink. That boundary is the whole
resolution of the rice-versus-brand tension; do not blur it.

Everything below was validated in the B6 prototype
(scratchpad `mock/B6.qml`). Where this contract corrects the prototype, the
correction is called out inline.

---

## 1. Palette

The paper is pure black. The warmth lives in the ink, not the paper, this
replaces the site's warm near-blacks (`#100d08` family) on app surfaces. The
references sample `#000000` with ±8 levels of grain; the grain **is** the
matte. A flat `#000000` without grain is a dead screen, not paper.

### Paper

| Token | Value | Rule |
|---|---|---|
| `paper` | `#000000` | Every app surface. There is no second background colour; depth comes from hairlines, not fills. |
| `paperRaised` | `#0a0a0a` | Overlays only (picker popup, menus, dialogs). The only permitted second fill, and it is never used on the page itself. |
| grain | tiled noise PNG, `opacity 0.055`, `Image.Tile` | One full-window layer at the top of the z-order, over everything including overlays. Never applied per-panel. The asset is 256×256 grey noise at ±8 levels. |

### Ink (on black)

Contrast-solved against `#000000`. Nothing below AA.

| Token | Value | Ratio | Rule |
|---|---|---|---|
| `ink` | `#cdc4ba` | 12.0:1 | Primary: values, titles, the changed-bar, selected fills, filled controls. The brightest thing on screen. Never used as a shadow or a wash. |
| `inkDim` | `#b0a9a0` | 9.0:1 | Secondary reading text: nav items, body copy, unselected control labels. |
| `inkMuted` | `#958f87` | 6.6:1 | Descriptions, cell labels, section context, text you read second. |
| `inkFaint` | `#7a756e` | 4.6:1 | Micro chrome only: source tags, keycaps, counts, struck defaults. Floor of the ramp; nothing dimmer may carry text. |
| `line` | `ink @ 26%` | n/a | Standard hairline: cell borders, dividers, control outlines. |
| `lineSoft` | `ink @ 13%` | n/a | Recessive rules: section leaders, row separators inside panels. |
| `lineStrong` | `ink @ 42%` | n/a | Hover borders and overlay borders. (Prototype used 0.42 and 0.50; collapsed to one token.) |
| `tint5` | `ink @ 5%` | n/a | Surface hover (a cell under the pointer). |
| `tint10` | `ink @ 10%` | n/a | Control hover and selected-tile tint. |
| `tint16` | `ink @ 16%` | n/a | Pressed. |

Focus (keyboard) is a 1px border in solid `ink`: brighter than any hover, no
second mechanism.

### Bone stock (inverted)

Inversion is the emphasis mechanism, the job colour used to do. The matched
reference pair (Dark Souls on cream, Berserk on black, identical system)
proves the stock flips exactly: the ink becomes the paper.

| Token | Value | Ratio on bone | Rule |
|---|---|---|---|
| `bone` | `#cdc4ba` | n/a | The inverted surface fill. Identical to `ink`: the stock flip is exact, no third value. |
| `inkOnBone` | `#000000` | 12.0:1 | Primary text on bone. |
| `inkOnBoneDim` | `black @ 62%` | 5.4:1 | Secondary text on bone. This is the **only** secondary level: 50% black on bone measures 3.9:1 and fails AA, so bone surfaces carry at most two ink levels. Keep bone content simple. |
| `lineOnBone` | `black @ 26%` | n/a | Hairlines on bone. |

**The bone-stock rule.** A surface inverts if and only if it is one of:

1. **The ON member of an exclusive set**: the active seg segment, the
   selected chip, the selected nav item's thumb, a `multi` member that is in
   the set.
2. **The armed primary action and the dirty state**: the SAVE button when
   there are unsaved changes; the state card while dirty.
3. **The pointed row in a dense list**: picker rows and credits rows invert
   under the cursor (a transient, one row at a time).
4. **One editorial plate per showcase surface**: a single deliberate
   bone block (the Credits testers placard). Never on settings pages.

Everything else stays black. If more than roughly a tenth of the screen is
bone, it is no longer emphasis, the dirty state card is the plate on a
settings page, and nothing else gets to be.

### Colour

There is none. Two exceptions, both of which are **data, not decoration**:

- **The red sun in art.** `marble-justice.png` carries a vermillion disc; on a
  monochrome screen it is the only colour and reads like a signature. Art is
  the one place chroma is manufactured.
- **Specimen swatches.** The wallust palette spectrum on the Profile page and
  any colour swatch that literally shows the user a colour. A swatch's job is
  to be its colour.

Rulings, made here so nobody relitigates them at review:

- **No red in the UI.** Not for errors, not for destructive actions. A
  destructive confirm is a bone plate with a 2px border and an unambiguous
  verb; an error is inverted text and the word. The hazard-label reference
  does exactly this in pure black and white, and it reads as *more* serious,
  not less.
- **Gold is retired from app surfaces entirely**: chrome and in-app art
  both. In monochrome art the kintsugi seams are drawn at the top of the bone
  range, where they read as light catching gold in a black-and-white
  photograph. Real gold survives on the website only.

---

## 2. Type

Three faces plus the kanji face. One role each; the roles do not trade.

| Face | Family string | Role |
|---|---|---|
| Fraunces | `Fraunces` | Display: page titles, showcase heroes. Never in a control, never under 20px. |
| Space Grotesk | `Space Grotesk` | Everything the instrument says: labels, values, buttons, body, numerals. |
| Space Mono | `SpaceMono Nerd Font` | File truth only (see boundary below). |
| Noto Sans CJK JP | `Noto Sans CJK JP` | The 力 seal and kanji marks. A mark, not decoration. |

**The mono/grotesk boundary.** Mono is for strings the machine said or will
be told: config keys, literals in the pending-write diff, file paths, source
tags (`shell.json`), version strings, struck defaults, keycaps, entry counts,
ranges, the barcode caption, hex codes, marginalia. Grotesk (with `tnum`)
is for every measurement the instrument *presents*: cell values, vitals, the
clock, the dirty count. Test: if the string would be valid pasted into a
config file or a terminal, it is mono; if it is the UI reporting a quantity,
it is Grotesk. Mono-everything read as a terminal in earlier mocks; this
demotion is what fixed it, do not creep mono back into presentation.

### Scale

| Role | Face | Size | Weight | Case / tracking | Default ink |
|---|---|---|---|---|---|
| hero | Fraunces | 72 | Regular | mixed, ls 0 | `ink`: showcase only |
| title | Fraunces | 44 | Regular | mixed, ls 0 | `ink`: one per page, in the head |
| value | Grotesk | 28 | Light | as-is, ls 0, `tnum` | `ink`: the cell's instrument numeral |
| valueCompact | Grotesk | 18 | Light | as-is | `ink`: value strings over 8 chars |
| nav / body | Grotesk | 14 | Regular | mixed, ls 0 | `inkDim` |
| listRow | Grotesk | 13 | Regular | mixed | `inkDim`: picker rows, search results. (Prototype used 12; 13 is the floor for rows you scan.) |
| desc | Grotesk | 12 | Regular | mixed | `inkMuted`: cell descriptions, 2 lines max |
| data | Mono | 12 | Regular | as-is, **never tracked** | diff keys and literals |
| button | Grotesk | 11 | Medium | CAPS, ls 1.4 | `ink` |
| section | Grotesk | 11 | Medium | CAPS, ls 2.2 | `ink` |
| chip | Grotesk | 10 | Medium | mixed | `inkDim` / `inkOnBone` |
| label | Grotesk | 10 | Medium | CAPS, ls 1.4 | `inkMuted`: cell labels |
| micro | Grotesk | 9 | Medium | CAPS, ls 2.0 | `inkMuted` labelling live content, `inkFaint` as pure chrome |
| segment | Grotesk | 9 | Medium | CAPS, ls 0.6 | `inkDim` / `inkOnBone` |
| tag | Mono | 9 | Regular | as-is, ls 0 | `inkFaint`: source tags, keycaps, counts, struck defaults |

Tracking rule: uppercase Grotesk is always tracked (the poster feel); mixed
case is never tracked; mono is never tracked (tracking a monospace breaks its
column alignment, which is the reason it exists). Ruling: 9px is chrome, not
reading matter, anything a user must actually read is 12px or larger.

---

## 3. Space

Base-4 scale. `s2` doubles as the grid gutter.

| Token | Value | For |
|---|---|---|
| `s1` | 4 | Glyph gaps: value–unit, dot–label. |
| `s2` | 8 | Related pairs; the grid gutter. |
| `s3` | 12 | Cell padding (top/right/bottom); sibling controls. |
| `s4` | 16 | Cell left padding; text-to-control reserve; panel inner padding. |
| `s5` | 24 | Section-to-section rhythm; rail margins. |
| `s6` | 32 | Page gutters (head and content left/right). |
| `s7` | 48 | Showcase block rhythm only. |
| `s8` | 64 | Showcase page margin only. |

Fixed structural dimensions: rail **268**, side panel **430**, preview
**300** tall, state card **88**, action bar **60**, nav row **34**, cell
module **104** tall, grid **12 columns / 8 gutter**, minimum window
**1280×820** (the side panel is load-bearing; the minimum guarantees it).
Multi-row cells are exact multiples of the module: 2 rows = 216, 3 rows = 328
(n·104 + (n−1)·8), which is what keeps Flow packing deterministic.

---

## 4. Geometry

- **Radius 2** on every rectangle: cells, controls, chips, buttons, overlays.
  True circles (status dots, and nothing else) stay circles. Full-bleed rules
  and hairlines have radius 0. Nothing else rounds.
- **Hairline is 1px always**, at `line` or `lineSoft`. There is no 1.5px
  anywhere in the app.
- **2px is reserved** for exactly two things: the changed-bar on a modified
  cell, and the border of a destructive-confirm plate. A 2px line means
  "state", never "style".
- **Shadows: none.** The Hub is print, a flat instrument sheet. Overlays
  separate from the page by `paperRaised` fill plus a `lineStrong` border,
  nothing else. The brutalist 8px offset shadow belongs to the website and
  the old warm-dark language; it does not enter app surfaces. (True drop
  shadows remain legitimate on desktop widgets sitting over an unknown
  wallpaper, outside this contract.)
- **No gradients, no blur, no translucency** on app surfaces. If a panel
  needs to feel raised, it gets a border.
- Sharp pixels where the shape is the point: sliders, toggle knobs, the
  changed-bar render with `antialiasing: false`.

---

## 5. Motion

Three durations. Nothing else.

| Token | Value | Easing | For |
|---|---|---|---|
| `snap` | 90ms | OutQuad | Colour, opacity, tint, every hover/press/selection recolour, and the toggle knob's travel. |
| `move` | 170ms | OutCubic | Position and size within a component: the nav thumb sliding, a control's indicator travelling. |
| `swap` | 210ms | OutCubic in, 90ms fade out | Content replacement: a panel's content changing, search results landing, the found-cell pulse. |

This is deliberately not the shell's 300–500ms Material-expressive springs,
and the choice is correct, keep it. The reasoning, so it survives review:
the shell's popouts are **bodies**: they travel across the screen, melt out
of a frame, and a spring with overshoot is what makes a body feel physical.
A settings page is an **instrument sheet**: nothing travels far, and every
motion is feedback on a manipulation the user is mid-way through. Feedback
must land inside one perceptual beat (~100ms) or the control feels laggy;
travel inside a panel over ~200ms reads as latency, not luxury. Mechanical
easing (decelerate, no bounce) matches the print/instrument references -
paper does not wobble. The Hub therefore does **not** import
`Motion.qml`; the two motion systems meet at the window edge, same as the
palette.

Corrections to the prototype: the stray 70ms values (toggle knob, picker
hover) are folded into `snap`; the unsaved-dot pulse re-times from 480/480 to
**600ms each way, opacity 1.0 ↔ 0.3**: it is a heartbeat, not an alarm. It
is also the only perpetual animation permitted on an app surface.

Two hard rules: **no entrance animation**: pages appear settled, the way a
printed sheet is simply there; and **reduced-motion sets every duration to
0**: state changes still land, instantly.

---

## 6. The control taxonomy

Eight controls. The choice is driven by option count and option kind, both
measured from the real Hub (14 controls with 2 options, 21 with 3, 9 with
4–6, one with 7, fonts with 25, plus one true set). A cell's span and row
count are **derived** from its control, `spanOf()` / `rowsOf()` are the
law; no cell is ever hand-placed.

Shared state grammar (every control): **rest** as specced below; **hover**
border → `lineStrong`, fills gain `tint10`; **pressed** `tint16`;
**focus** 1px solid-`ink` border; **changed** is expressed by the *cell*
(§7), never by recolouring the control; **disabled** whole control at 30%
opacity, no pointer events, cursor default.

1. **`sw`: boolean.** On/off only; two named modes are a `seg`, not a
   switch. Anatomy: 54×24 hairline frame, radius 2; knob 25×17 inset 3.
   OFF: knob is a hairline outline at left. ON: knob is solid `ink` at
   right. Knob travels on `snap`/OutQuad. Span 4, 1 row, inline right.

2. **`step`: bounded integer.** Discrete units where the exact number
   matters (px, s) and the range is ≤ ~120. Anatomy: the value lives in the
   cell's instrument numeral; two adjoining 29×24 hairline buttons, − then +.
   Step 1; ranges wider than 60 units step 4. Press-and-hold repeats after
   400ms at 8 steps/s. At a bound the exhausted button drops to disabled.
   Span 4, 1 row, inline right.

3. **`slid`: ratio.** Continuous quantities where the felt effect outranks
   the number (opacity, gain). Anatomy: 4px track as a hairline outline, ink
   fill from zero, a 6×17 rectangular thumb, all `antialiasing: false`.
   Click seats the thumb; drag scrubs; the cell numeral updates live. Track
   width is **42% of the cell width** (the prototype's `inlineW` said 180 but
   rendered 42%; 42% is the spec). Span 6, 1 row, inline right.

4. **`seg`: 2–4 exclusive named modes.** Labels ≤ 9 characters, segment/9
   caps. Anatomy: adjoining rects, min 52 wide (label + 18), 24 tall. The ON
   segment is fully inverted (bone fill, `inkOnBone` text); OFF segments are
   hairline with `inkDim` text. Five or more options is never a seg. Span 4
   for 2 options, 6 for 3, 8 for 4; 1 row, inline right.

5. **`chips`: 5–8 exclusive named options.** A wrapped Flow of chips
   (label + 18 wide, 24 tall, chip/10). Selected chip inverts. Span 10,
   2 rows, block band under the text.

6. **`pick`: a catalogue, 9+ options.** Never inline. Anatomy: a foot bar
   26 tall across the cell showing current value (Grotesk 11), the entry
   count and a caret as a mono tag. Opens a 330×330 overlay: `paperRaised`,
   `lineStrong` border; header = control name in caps + `N ENTRIES` tag;
   filter field 30 tall, focused on open, typing filters live; rows 30 tall
   at listRow/13; the current value carries a right-aligned dot; the pointed
   row fully inverts; Enter picks the top match, Esc closes. Span 5, 1 row;
   the description on a pick cell is capped at one line so the foot bar
   never collides.

7. **`multi`: set membership.** Not a choice: members toggle independently
   (the bar's module set). Anatomy: a chip per member with a `+` (out) or `✓`
   (in) prefix; in-set chips invert. If order matters, the cell description
   says what governs it ("Order follows the strip"). Span 12, 2 rows, block.

8. **`gallery`: visual options.** Options whose difference a word cannot
   carry (the ten bar skins, clock faces, wallpaper modes). Anatomy: tiles
   132×74, radius 2, each containing a **drawn 1-bit silhouette** of the
   option (never a screenshot, silhouettes stay monochrome and legible at
   32px), the option name at chip/12, an origin tag (mono 9:
   `reference` / `ryoku` / `inir`), and, when selected, an ink border,
   `tint10` fill and a corner dot. The cell's value line renders the
   selection name at 26 Light. Span 12, 3 rows, block.

---

## 7. The cell

The atom of every settings page. One module: 104px tall, radius 2, hairline
border, transparent fill.

Anatomy, top-left to bottom-right:

- **Label**: label/10 caps, `inkMuted`, elided to one line.
- **Value**: the instrument numeral: value/28 Light `ink` (valueCompact/18
  when over 8 characters). `sw` renders ON/OFF; `seg`/`pick` render the
  selected option; `gallery` renders the selection at 26 Light;
  `chips`/`multi` render no value line (the selection is visible in the
  band itself).
- **Unit**: micro/10 `inkMuted`, baseline-aligned beside the value with an
  `s1` gap.
- **Struck default**: when changed: the default value plus unit, tag/9 mono,
  `inkFaint`, `strikeout`, sitting after the unit. The default is always
  recoverable by eye.
- **Description**: desc/12 `inkMuted`, wrapped, 2 lines max (1 line on
  `pick` cells). Says what the setting does, not what it is called.
- **Source tag**: top-right corner, tag/9 mono `inkFaint`: the config file
  this key writes to, extension stripped (`shell`, `visualizer`). Out of the
  reading path; it brightens slightly on hover.
- **Control**: inline controls (`sw`, `step`, `slid`, `seg`) sit
  right-aligned, vertically centred; their footprint is reserved out of the
  text column so nothing can overlap. Block controls (`chips`, `multi`,
  `gallery`) take a full band beneath the text on rows 2 (and 3). `pick`
  takes the foot bar.

**How "changed" reads without colour**: three redundant cues, all ink:

1. a **2px solid-ink bar** down the cell's left edge (x 0, inset 8 top and
   bottom);
2. the **struck default** beside the live value;
3. the key surfaces in the **pending-write diff** and the dirty count ticks.

Hover: fill `tint5`, border `lineStrong`, both on `snap`. A cell never
casts a shadow and never raises.

---

## 8. Page anatomy

Five regions. Left to right, top to bottom: rail, head, sections, side
(state + diff), action bar. Only the rail is on every page. A page is one of
three layout classes, decided by its **section** and never by the loaded page
(so the chrome never reflows mid-swap): a **full-bleed** page owns the whole
content region and draws its own head and action bar; a **framed** page keeps
the rail, its own head, and the shared action bar; the two **ledger** pages
(Shell, Appearance) additionally get the pinned side column. The classes are
`framedSet` / `ledgerSet` in `Hub.qml`, and the page content crossfades
through two loaders on `swap`, so a section change never blanks to bare paper.

**Rail**: 268 wide, 1px `line` on its right. Contents: the brand block
(力 at 22, `RYOKU ARCH` at 14 caps ls 2.4, descriptor at 11 `inkMuted`); the
search field (36 tall, hairline, placeholder `inkMuted`, `CTRL K` keycap as
a mono tag); the nav. Nav groups are a 4px ink dot + micro/9 caps label + a
`lineSoft` leader. Nav items are 34 tall, nav/14 `inkDim`; hover `tint10`
with 1px vertical inset; the selected item is a full-bone thumb (ink fill,
`inkOnBone` text) that **slides** between items on `move`/OutCubic, the
one piece of travel on the page.

**Head**: the eyebrow row (a 16×1 ink rule, 力 at 11, the category in
micro/9 caps ls 2.2 `inkMuted`), then the page title in Fraunces 44 with the
page's utility actions beside it (`EDIT CONFIG` opens the raw file in the
user's editor). One Fraunces title per page; it is the only serif on a
settings page.

**Sections**: the scroll region, 12-col grid, gutter 8. Settings are
grouped by meaning, never by control type or size. A section header is a 4px
ink dot, the section name at section/11 caps, and a `lineSoft` leader
filling the line. Below it, a Flow packs the section's cells; spans come
from `spanOf()`. Scrollbar is a 3px `line` rectangle.

A section head is normally ink. The one exception: a single **featured** section
on a page -- a showcase surface, not a settings group -- may set `titleColor` to
the deep red `sunDeep` to mark it as special, used once per page. Input's live
KEYBOARD MAP (`Ryoku.Ui` `KeyboardMap`) is the first: it draws the keyboard,
shows the layout's legends (AZERTY, QWERTZ, Dvorak, Colemak, else QWERTY), and
lights every remapped key to bone (Caps Lock's new job, a swapped Alt/Super, the
Compose key, the layout-switch chord). It is pinned under the head in a compact mode (no number row, no readout), not left in the scroll, so it stays in view while you edit -- beside a `Decor` poster (below) that fills the space the small keyboard leaves.

**Side**: 360 wide, pinned to the ledger pages only; it never scrolls with the
sections. It is the **write ledger**, not a preview: the earlier pinned
wireframe of the desktop was cut, because the edit already shows live on the
real desktop and a mock of it only duplicated that and got in the way. Two
parts:

- *State card* (72 tall): the dirty count as a 36 Light numeral + `CHANGES`
  micro label, a divider, and one sentence of state. Clean: hairline,
  "Everything matches what is on disk." Dirty: **the card inverts to bone**,
  the settings page's single editorial plate, reading "Previewing live.
  Nothing is written until you save."
- *Pending write* (remaining height): the diff grouped by target file. File
  headings: 3px dot + filename in mono 10 + change count. Rows: the key in
  data/12 mono `inkDim`, then `was` struck `inkFaint` → `now` in `ink`, each
  in the file's own literal syntax (`true`, `"TOP"`, `["workspaces",
  "clock"]`). `lineSoft` separators. At rest, with nothing to write, the panel
  shows a framed **specimen** rather than a bare line of mono: the dithered
  torii under a solid `空 · AT REST` label bar, the brand set vertically as
  リョク (art per §10). The specimen and the diff crossfade on the first edit,
  never hard-cut.

**Action bar**: 60 tall, full width, 1px `line` on top. Left: the status -
a 6px ink dot (pulsing 600/600 only while dirty) and the state line in
button/11 caps: `N CHANGES · PREVIEWING · NOT SAVED` or
`SAVED · LIVE ON YOUR DESKTOP`. Right: `RESET TO DEFAULTS` | divider |
`REVERT` | `SAVE` (solid, the armed primary action, bone-filled when dirty,
disabled when clean).

**Semantics** (the prototype conflated these; the contract splits them):

- `REVERT`: discard unsaved edits: `v := d` for every key. Enabled only
  while dirty.
- `RESET TO DEFAULTS`: set every key to its factory value: `v := factory`.
  This *creates* dirt (the diff shows the walk back to stock); it still
  writes nothing until SAVE.
- `SAVE`: write the diff to the target files, then `d := v`.

**State machine**: `CLEAN → (any v≠d) DIRTY → (SAVE) WRITING → CLEAN`;
`DIRTY → (REVERT) CLEAN`. WRITING is sub-100ms in practice and shows no
spinner, the state card flipping back is the confirmation. If a target file
changes on disk while dirty, the diff panel heads gain `DISK MOVED` and a
`RELOAD` action; reloading rebases defaults (`d := disk`) and keeps the
user's unsaved `v`.

**Search**: Ctrl+K focuses the rail field; results are listRow/13 rows
(label + section + page) replacing the section area on `swap`; Enter
navigates and pulses the found cell's border `line → ink → line` once over
`swap`. No colour, no glow.

---

## 9. The showcase surfaces

Profile and Credits are not settings pages. They are the payoff, the two
screens a user posts. Design them as posters that happen to be true: the
Berserk sheet's editorial spine, the hazard label's placard data, the Fono
panel's instrument numerals, all pointed at *this user's machine*. No cells,
no controls, no preview. The rail stays (they are still Hub pages); the
content region becomes a plate. Both compose on `s7`/`s8` rhythm, both are
built so a 16:10 crop of the content region is a finished poster.

### Profile, the dossier

The screen answers "what is this machine" the way a museum label answers
"what is this object": specimen right, dossier left, edition strip bottom.

**Stage.** Full-bleed black. `marble-justice.png` (regraded per §10)
right-anchored and bottom-aligned at full content height, its left 35%
dissolving into the paper via alpha baked into the asset. The vermillion sun
disc in the art is the only colour on the screen apart from the palette
specimen, one red circle on a monochrome sheet. Art never underlaps text:
the dossier column ends where the dissolve begins.

**Marginalia.** Rotated 90°, reading bottom-up, along the far-left edge of
the content region: `RYOKU · <codename> · KERNEL <version> · SHOT ON BLACK`
in tag/9 mono, ls 2, the Berserk-poster spine move. It is chrome, set in
`inkFaint`.

**The dossier column** (max 560 wide, left-aligned on `s8`):

1. Eyebrow: `力 · SYSTEM DOSSIER`.
2. Identity: the username in **Fraunces 72**: the one place the serif goes
   monumental, with `@hostname` beneath it in mono 12 `inkMuted`.
3. Time masthead: `LOCAL TIME` micro label over a 42px `tnum` clock, with the
   date and `UPTIME · <n>` right-aligned in mono 11. Uptime is a brag; give
   it the numeral treatment.
4. Vitals: five hairline-split columns (Load / CPU / Proc / Batt / Disp),
   21px `tnum` figures over mono 8 caps labels. No boxes, hairlines only.
5. Runtime spec lines: label, `lineSoft` leader eating the gap, value -
   Compositor (Hyprland vX), Kernel, Architecture, GPU, CPU, Resolution @
   refresh. The museum-label motif.
6. Packages: the wave meter filled to the share the user installed
   themselves, captioned `N EXPLICIT · N AUR · N TOTAL` in mono 10. This is
   the r/unixporn flex rendered as an instrument.
7. Look: Cursor / UI font / Mono font spec lines.
8. Palette: the wallust spectrum as one contiguous swatch strip, 22 tall,
   hairline-framed, the user's rice as a specimen. Chromatic, and allowed:
   it is data.

**Edition strip** (bottom, full column width, above a closing hairline): a
real **Code 39 barcode** encoding `RYOKU-<CODENAME>-<INSTALL-YYYYMMDD>`,
drawn as ink bars 28 tall with the encoded string beneath in tag/9, it
scans, and people will scan it. Beside it: `EDITION No. <NNNN>`: a stable
4-digit number derived from the machine-id hash, the install date, and
`SYSTEM DOSSIER · 力` / `RYOKU · <codename>` split to the corners.

**Export.** The head carries one action: `EXPORT PLATE`. It renders the
content region (rail excluded) to PNG at 2× via `grabToImage` and writes
`~/Pictures/ryoku-dossier-<YYYYMMDD>.png`. The page screenshots itself,
composed, at print resolution, that is the feature that makes it the
default flex instead of a fastfetch screenshot.

**Privacy rule, unchanged:** no IPs, no MACs, no real names. Username,
hostname, hardware, uptime, packages, safe to post by construction.

### Credits, kansha

Gratitude as a poster: the Three Graces for the people the project stands on.

**Stage.** `three-graces.png` (regraded, and regenerated at 3:4 per §10 -
the current 541×879 asset is under-resolution for a full-height plate)
right-anchored, dissolving left, same construction as Profile.

**Left column:**

1. Eyebrow: `力 · KANSHA`.
2. Title: 感謝 in Noto Sans CJK JP at 64 over `GRATITUDE` in Fraunces 44 -
   the bilingual pair stacked, ink on paper.
3. **The standing-on list**: every project as an editorial type line, never
   a card, name in Grotesk 15, author in mono 10 `inkMuted`, role
   right-aligned in desc/12, a `lineSoft` leader between. Rows with a URL
   invert fully on hover (bone, `inkOnBone`) and open via xdg-open; rows
   without a home stay quiet, no hover, no invented links.
4. **The crash-test placard**: the page's one bone plate, and the only
   full-bone block in the entire app: an inverted band titled
   `THE CRASH TEST CREW` in caps, the alpha/beta testers' names in mono
   caps separated by ◆, black on bone, the hazard-label homage, aimed at
   the five people who earned it.
5. **Colophon**: the self-documenting block designers screenshot, each face
   set in itself at its role size (`Fraunces 44` in Fraunces,
   `Space Grotesk 14` in Grotesk, `SpaceMono 12` in Mono), then the ink ramp
   as four labelled chips (hex + contrast ratio printed in tag/9 under
   each), the grain note, and the disclosure line carried from the site:
   figurative art is AI-generated at dev time and graded by hand.

Why these two get screenshotted: each is a one-glance poster with a single
red accent, real personal data, typography doing the work colour used to do
- and Profile literally exports itself. Nothing else in the distro needs to
be the wallpaper shot; these are the wallpaper shot.

---

## 10. Art direction

The three existing pieces disagree (bust cool-grey, graces warm, justice
warm with the sun). The system needs one grade, applied to everything.

**The grade** (Pillow, dev-time, committed as PNG, Quickshell's Qt has no
webp):

1. Luminance via Rec.709.
2. **Duotone map: black `#000000` → bone `#cdc4ba`**, linear, with a gentle
   S-curve to hold the blacks. Art's tonal ceiling is the ink value, art
   sits at ink parity, behind the type, never outshining it.
3. **Sun preservation**: mask pixels with hue in [345°, 25°] and saturation
   ≥ 0.30; keep them at original chroma pulled toward `#e2342a`; feather the
   mask 8px. The disc survives the grade as the one colour.
4. Kintsugi seams get no colour pass, the duotone places them at the top of
   the bone range, where they read as gold catching light in a monochrome
   photograph.
5. Flood-fill the background to `#000000` from the edges (threshold ~36).
6. Bake the dissolve: an alpha ramp over the plate's left 35–40%, so
   composition never depends on a runtime gradient.
7. Export PNG, longest edge ≤ 1200, under ~850KB.

Regrade all three existing pieces now; `marble-bust.png` moves from cool
grey to the bone duotone like the rest.

**Generation** (fal.ai, dev-time only). Prompt grammar =
`[SUBJECT] + [COMPOSITION] + [STYLE]`, with the style block rewritten for
the monochrome system:

> black-and-white fine-art photograph of Greek marble statuary, irezumi
> rendered as engraved linework flowing across the marble, kintsugi crack
> seams catching light, a single vermillion-red sun disc as the only colour,
> deep pure-black background, dramatic chiaroscuro, razor-sharp fine detail,
> subtle film grain, premium poster art, no text, no words, no watermark.

Note the irezumi change: in monochrome the tattoos are **engraving, not
coloured ink**: teal/red/gold tattoo work would fight the grade.

Composition constraint for every plate: subject in the right 60%, left 40%
pure black (the dissolve and the text column need it), sun disc behind the
subject's upper third, disc diameter ≈ 55% of frame width.

Aspects: **3:4** for showcase plates (Profile, Credits), **1:1** for
emblems (About, fastfetch), **16:9** for the welcome band. To generate for
beta18: a 3:4 Three Graces replacement, a 16:9 welcome threshold, and, only
if the bust regrade disappoints, a 1:1 sentinel bust.

**The dither art.** Beyond the marble duotone there is a second, grittier
grade, for the decorative fields rather than the portraits: the at-rest ledger
specimen and any framed ornament that is texture, not figure. It is 1-bit, not
duotone: a dithered black-and-white that reads as risograph or newsprint, never
a photograph. `art/dither-torii.png` (a torii in rain) is the first of these.

- *Generation* (fal.ai, dev-time, `fal-ai/nano-banana-pro`): the same
  `[SUBJECT] + [COMPOSITION] + [STYLE]` grammar, with the style block:
  `gritty 1-bit dithered black-and-white, heavy halftone / error-diffusion
  texture, high contrast, pure-black background, no text, no watermark`.
- *Post-process* (Pillow, dev-time): convert to grayscale; crush the low end
  to pure `#000000` (map anything below ~44 to 0) so the plate melts into the
  paper with no seam; **downscale nearest-neighbour, never bilinear** -- the
  dither pattern is the point, and any smoothing turns it to grey mush; export
  PNG. In use it sits behind its solid label bar at `opacity 0.5`, at ink
  parity, so the caption on it always reads.

The rule that picks the grade: a **portrait** (a statue, a figure, the
showcase plates) takes the §10 duotone and keeps the red sun; a **texture**
(a backdrop field, an at-rest specimen) takes the 1-bit dither and carries no
colour at all.

---

## 11. The rules

A reviewer checks any diff against this list. Violation = rejection.

1. No hex, font family, radius, duration, or spacing literal outside
   `Theme.qml`: components read tokens.
2. No colour on an app surface except the art's sun, literal colour swatches,
   and one deliberate landmark: a featured/showcase section head may carry the
   deep red `sunDeep` (`Section.titleColor`), once per page. No red states
   otherwise, no gold chrome.
3. No text dimmer than `inkFaint`; nothing the user must read below 12px;
   bone surfaces carry at most two ink levels.
4. Inversion only per the bone-stock rule (§1); at most one editorial bone
   plate per screen.
5. Radius 2; circles only for dots; hairlines 1px; 2px only for state.
6. No shadows, gradients, or translucency on app surfaces; overlays are
   `paperRaised` + `lineStrong`. The one blur exception is a `Watermark`: a
   faint background typographic haze, far behind the content, is background art,
   not a surface, so it may blur and be translucent (§12).
7. Mono only for file-truth strings; presentation numerals are Grotesk
   `tnum`. Caps Grotesk is tracked; mixed case and mono never are.
8. Three motion tokens only; nothing over 210ms; no springs; no entrance
   animation; reduced-motion zeroes everything.
9. Cell spans and rows come from `spanOf()`/`rowsOf()`: a hand-placed or
   hand-sized cell is a bug.
10. Every changed value shows its struck default and the 2px bar, and
    appears in the pending-write diff in the target file's own syntax.
11. The side ledger is pinned and never scrolls; nothing writes to disk except
    SAVE.
12. Grain is one full-window layer at 5.5%, topmost; art is graded through
    §10 before it ships, no raw generations, no runtime generation, PNG
    only.
13. Decoration lives only in the chrome dead zones (the rail foot, the action
    bar's centre, an empty head margin), never in the content and never over a
    control. It is ink only; the accent stays on state (§1). See §12.
14. Pixel glyphs come from the brand vocabulary -- a Greek key, a torii, a
    wave, a column, an asanoha (§12) -- never arcade sprites.
15. A section change crossfades the page through two loaders and never blanks
    to bare paper; the layout class (full-bleed / framed / ledger) comes from
    the section, never the loading page (§8).

---

## 12. The poster layer

The instrument sheet is dressed like a printed poster: registration marks, a
barcode, corner ticks, numbered plates, katakana glosses, pixel dingbats. This
is the layer that makes the paper read as an instrument before a control lands
on it. The reference is the acid-grotesk techno-poster sheet
(`.beta18/art/ref-acid-grotesk.png`), not a UI kit. It is entirely **ink**,
lives entirely in the **dead zones**, and never touches a control.

Two boundaries keep it from becoming clutter:

- **Dead zones only.** Ornament goes in the chrome margins a page leaves empty:
  the rail foot, the action bar's centre, an empty head margin, an at-rest
  ledger panel, an empty state. It never lands in the content, over a cell, or
  on a subtab/segment/button. If the margin already holds a control, the
  ornament is skipped for that page, not squeezed in beside it.
- **Ink, never accent.** The poster layer is `inkFaint` / `line`. The one acid
  drop stays on state (the active nav thumb, the dirty dot). Two accents on a
  screen is one too many.

### The ornament primitives

All in `Ryoku.Ui`, all static (no animation), all ink:

| Component | What it is |
|---|---|
| `Reg` | The registration backdrop: a faint dot grid with `+` marks on a sparse beat and print-register crosses in the corners. One static `Canvas` behind all content. It is what makes the paper an instrument sheet. |
| `Ticks` | Four HUD corner brackets registering a framed block's corners. Goes on a framed thing (a specimen, the state plate), never on every cell. |
| `Barcode` | A real, scannable **Code 39** plate (`tests/ui/barcode.sh` reads it back with zbarimg). Give it room: a clipped barcode drops its stop bars and silently stops scanning. Used for the rail-foot totem (`RYOKU HUB`) and the Profile edition strip. |
| `Motif` | Line ornaments in ink: `rings`, `steps`, `burst`, `dither`. They dress a genuinely empty zone; they never sit behind live content. |
| `Empty` | The composed empty-state plate: `空` in a ring `Motif` over a `// EMPTY_` caption. An empty zone is dressed, never a bare line of mono in a void. |
| `Tabs` | The one tab bar. Selection is typography, not a coloured bar: the active plate inverts to bone and takes the sheet's `//` lead (`001 // ABOUT`). It replaces every hand-rolled tab strip. |

### Marginalia

`Marginalia` is the running head of the sheet: the poster's masthead row
distilled to a thin strip that fills a dead margin. Left to right: a pixel
dingbat, a katakana gloss, a hairline-boxed numbered index plate (`003 //
PALETTE`), a second dingbat, a chevron run. Every field is optional and it
self-sizes, so it right-aligns into whatever dead width a page leaves. Ink only.

It runs app-wide through the shared chrome, so most pages get it for free:

- **Rail foot** (`Hub.qml`): an edition register (`BETA // 18`) above the
  `RYOKU HUB` barcode -- on every page, since the rail is the one always-present
  chrome.
- **Action bar centre** (`ActionBar.qml`): a running register (`設定`) between
  the status and the verbs -- on every framed page.
- **A full-bleed page's head margin and its own bar centre**: each page sets its
  section's kana gloss and group index (`操作 · 02 // SYSTEM`) and varies the
  glyph pairing for texture -- only where those margins are genuinely empty.

### Pixel

`Pixel` draws a small 1-bit glyph on an 8×8 grid, the poster's dingbats. The
vocabulary is the brand's own, Greek and Japanese, **never arcade-alien**:

| Kind | Motif |
|---|---|
| `meander` | the Greek key / fret |
| `torii` | the gate |
| `wave` | seigaiha wave arcs |
| `column` | a fluted Doric column |
| `asanoha` | the hemp-leaf star |
| `star` | a plain 4-point register star |

To add a glyph, add an 8-row grid of `0`/`1` strings to the `grids` map (a `1`
is an ink cell). Keep it legible at 16px, the marginalia size, and on-brand: if
it reads as a space invader, it is wrong.

### Background watermark

`Watermark` sets a page's section kanji (入力 for Input, 描画 for GPU) huge and
faint behind the whole page, bled off the lower-right, so the page has a face
without a photo. It is the one place a blur and translucency are allowed on an
app surface, because it is **background art, not a surface**: strength ~0.05,
softened by a light `MultiEffect` blur so the giant glyph reads as haze, never
as words to read. It sits behind the head and the scroll (the content is on top
at full ink, so legibility never drops), and it fills the dead lower margin that
settings alone leave empty. Static, so the blur layer captures once. Give each
section its own kanji; keep the strength a whisper -- if you can read it as
text, it is too strong.

### Decorative filler

`Decor` is the poster made a first-class cell. Where a section's grid leaves a
dead slot -- a lone control on a half-row, or the flush end of a section -- a
`Decor` fills it with a noir mini-poster instead of empty black: a real image or
gif behind a big Japanese title, a vertical tategaki line, a fine-print caption,
a scannable `Barcode` and a kanji seal. It holds no control and means nothing; it
exists to give a section a face and to stop a ragged row reading as a mistake.

The art is real, not drawn in code: a small public-domain set (a Muybridge or
phenakistoscope motion loop, a marble statue, the moon, Newton's cradle, a
rotating earth) baked at build time to 1-bit bone-on-transparent through an
ordered (Bayer) dither, so a photograph reads as the same halftone sheet as the
rest of the poster layer. With no image, `Decor` falls back to `DitherField`, a
fractal-noise field dithered live in a Canvas. Right-click the art to open its editor: frame it the way the App Launcher frames its hero: the image is sized to cover the
panel and placed by a 0..1 focal point you drag, with a zoom (scroll, pinch, or
the -/+ buttons; below 100% reveals more of the image, above crops in). Pick from
the gallery underneath (the baked set or a custom file, desaturated to noir) and
Save (or Enter; Cancel/Esc discards). The choice and
framing persist per box through `DecorStore` (`~/.config/ryoku/decor.json`), so a
box you frame stays framed across a reopen; gifs autoplay. Used on Input (a
poster per section) and Connections (a shared head hero).

`Decor` earns two exceptions to the sheet's rules, because it is art in a dead
cell and never chrome over a surface: its source may be a **gif and animate**
(the one perpetual motion allowed, and only here), and a colour source is
auto-**noir** (desaturated) so anything dropped in still fits. It never sits over
a control and never carries the acid accent.

### Putting it together

A page is built in four passes, outermost to innermost:

1. **Chrome.** The shell draws the rail (always); for a framed page it also
   draws the head, the side ledger (ledger pages only) and the action bar. A
   full-bleed page draws its own head and bar. The layout class is the
   section's, from `framedSet` / `ledgerSet` -- decided there, never from the
   loaded page, so the chrome holds still across a crossfade.
2. **Content.** List the surfaces first, build them as full-width blocks, then
   let the cells flow around them (§7, §8). Cells take spans from `Spans`; a
   section packs them into flush rows (`Spans.pack`) so no row ends ragged.
3. **Decoration.** Drop `Marginalia` into the dead margins the content left
   empty (head-right, bar-centre); the rail foot and framed action bar already
   carry theirs. Skip any margin a control occupies. `Reg` is already behind
   everything; `Ticks` go on framed specimens; `Empty` dresses an empty state.
4. **Motion.** Nothing enters (§5). The page crossfades on `swap`; the nav
   thumb slides on `move`; every recolour is `snap`; the at-rest specimen and
   the diff crossfade on the first edit.

The test for any ornament: remove it and the page must still be complete and
legible. Decoration is the sheet's texture, never its content.
