# RYOKU APPS, ryowalls + ryovm (beta18)

The contract for the two first-party Quickshell apps. DESIGN.md governs; this
document extends it to browse-and-act windows and does not restate it. Where a
rule here amends the contract, the amendment is called out and numbered so a
reviewer has one place to check.

The Shell-port lesson applies with more force here, not less. Between them
these two apps carry roughly twenty settings and close to fifty surfaces. The
schema is nearly nothing; the surface inventory (sections 2.4 and 3.5) is the
contract. A port is done when every surface listed there is present and
wire-probed, not when the window renders.

Both state singletons (`Wallhaven.qml`, 729 lines; `Vm.qml`, 703 lines) are
pure state and survive untouched. Every visual file in both apps is replaced.

---

## 1. The shared skeleton

The two apps are siblings: one skeleton, different organs. Anything specced
here is built once.

**Window.** `FloatingWindow`, minimum 1180x760. Paper `#000000`, one `Grain`
layer topmost over everything including overlays. The background gradient
dies. The compositor frame carries the vermillion; inside is paper and ink.

**Head.** Eyebrow row (16x1 ink rule, 力 at 11, app mark in micro/9 caps ls
2.2 `inkMuted`: `RYOKU WALLS` / `RYOKU VM`), then the title line, then one
desc/12 `inkMuted` sentence (the current subtitle copy survives, it is good).
Top right: a utility `IconBtn` pair (settings, close), plain ink, no danger
red on the close button.

**The serif names the object.** One Fraunces string per window, and it is not
a static page title:

- ryowalls: the title is the **source being browsed** ("Wallhaven",
  "MoeWalls", the library's name), Fraunces at `fTitle`, with the source
  count and caret beside it as the picker's opener.
- ryovm: the head carries **no Fraunces title**; the serif goes to the
  machine or OS name on the stage (Fraunces 28, dropping to 21 past 22
  characters, as the current VmStage already does). The object is the star.

**Toolbar.** One 40-tall row under the head: the lane `Seg` (module control,
segment/9 caps), the search `Field` (36 tall), then per-lane controls
right-aligned. Nothing in the toolbar is bespoke chrome.

**The split.** Content is a 12-column grid (`Spans.cols`, gutter `s2` scaled
up to `s5` at the seam). The left column spans 5, the right spans 7, with a
1px `line` hairline in the seam. This replaces `parent.width * 0.44` and
`0.46`: the number now comes from the same grid the cells use, and the two
apps stop disagreeing by accident. Left is the collection (grid or list),
right is the hero. In ryowalls the hero is pinned across all lanes (it is the
feedback loop); in ryovm the hero is the lane's work surface. Lane changes
swap columns on `swap`; no entrance animation, panels appear settled.

**Bottom bar.** 60 tall, 1px `line` on top, same anatomy as ActionBar: left,
a 6px ink dot plus a state line in button/11 caps; right, the verbs as `Btn`.
The dot pulses 600/600 only while something is genuinely pending (a preview
not yet set, a download running). The far right corner carries the backend
identity as a mono tag (`wallhaven.cc`, `quickemu 4.9`): file truth, mono.

**Overlays** (in-app settings, the source picker, destructive confirms):
`paperRaised` fill, `lineStrong` border, radius 2, per contract SS1/SS6. The
scrim is the one translucency exception already implied by overlays; keep it
at black 55%. Destructive confirms are bone plates with a 2px border and an
unambiguous verb, never red.

**Scroll.** ryovm's `BoardScrollBar` was right all along. It is promoted into
the module as `ScrollRail`: a square 4px thumb, `inkFaint`, `ink` when
pressed, no background, `antialiasing: false`. Every Flickable, ListView and
GridView in both apps uses it. The bare Qt pill in ryowalls dies.

**Progress.** One spec for enhance, downloads, everything: a 4px track drawn
as a hairline outline with a square ink fill from zero, `antialiasing:
false` (the Slid track without the thumb), percent and rate right-aligned in
Grotesk `tnum`. Indeterminate work gets **no sweeping bar**: a 6px dot on a
1Hz square-wave blink (the annunciator's wave, not a fade) beside the live
log line in mono. Reduced-motion: the dot holds solid.

**Keyboard, unified on ryovm's grammar.** Esc peels one layer (overlay,
search focus, filter text, lane) and never quits; ryowalls' Esc-quits dies.
Ctrl+Q quits, with the arm-timer handshake when a download or enhance would
die with the window. `/` and Ctrl+K focus search. Arrows walk the left
column, Enter acts on the pick (Set wallpaper / Launch-Stop).

**Empty and loading states.** The app's line-art mark (section 2.7 / 3.7) at
96px, ink fraction as generated, then one sentence at desc/12. The current
copy ("No live wallpapers yet", "Loading your machines") survives; the icons
die.

**Module additions.** Three components these apps force, built in `ryoku/ui/`
so the Hub inherits them too:

- `Field`: the text input. 30 tall (36 in a toolbar), hairline rect, radius
  2; focus is a 1px solid-`ink` border, no colour. Content follows the
  mono/grotesk boundary: paths, keys, package lists, ssh users are mono;
  names and searches are Grotesk. Placeholder `inkMuted`.
- `ScrollRail`: as above.
- `IconBtn`: the 30x30 utility button both apps currently inline
  byte-identically. Ink tints only.

`FlapCell/FlapHalf/FlapWord`, `Annunciator`, `GuardSwitch`, `HankoSeal`,
`RegMark` stay in ryovm: one consumer, no promotion. `BrutalPanel` is not
ported anywhere (see 3.4).

**Theme deletion.** Both `Singletons/Theme.qml` files are deleted. They are
hand-copied forks ("kept in step by hand" is drift by design), and they
disagree with the module on the mono face (`JetBrainsMono` vs `SpaceMono`),
the ramp, and the motion table. Apps import `Ryoku.Ui` and read `Tokens`;
their `Singletons/qmldir` keeps only the state singleton. Motion mapping for
the port: `quick(120)->snap`, `medium(240)->move` for travel and `swap` for
content, `slow(360)` dies, `OutExpo->ease`/`easeSnap`.

### Amendments to the contract

Made here, by the design authority, so nobody relitigates them at review:

1. **Instrument faces may fill `paperLift`.** The contract restricts
   `paperRaised/paperLift` to overlays. Flap-cell plates and annunciator
   glass are depictions of physical hardware faces, the same license the
   gallery tile's silhouette has; they may fill `#0a0a0a`. Panels and cards
   may not; this license covers faces smaller than a coin, never a surface.
2. **Content may move forever inside a Preview.** The MockDesktop's cava
   bars and a looping video wallpaper are the desktop being depicted, not
   chrome. Perpetual motion stays banned outside the preview canvas.
3. **The hanko keeps its vermillion.** A bone hanko is a rubber stamp of
   nothing. The seal is ryovm's sun: at most one red hanko per screen, on
   the stage only, only when it certifies something (a sealed machine, the
   thud of a new one). The per-card grey seals die; absence, not greyness.
4. **OS brand logos stay chromatic.** A logo's job is to be its mark, the
   same clause as the swatch. They are the catalogue's data. Their keycap
   gradient plates die; the monogram fallback becomes a Fraunces initial in
   ink on a hairline tile.
5. **A warning tag may invert.** The low-res badge on a thumbnail and the
   FAULT tile render as bone plates: inversion is the emphasis mechanism,
   and a warning is emphasis. Budget: tag-sized, never a panel.
6. **A wallpaper thumbnail, a video frame, and the candidate palette are
   content** and carry their own colour. Everything around them is ink.

---

## 2. ryowalls

### 2.1 What it is for

Pick a wallpaper and see what it does to your whole rice before committing:
the app's real product is the preview loop, not the download. What the
current UI makes harder than it should be: knowing where you stand. Tune
writes to disk immediately, Adjust is session-only and bakes on Set, the
desktop sometimes retunes live (frame scrub) and sometimes on the next Set,
and nothing on screen says which. The instrument shows a preview but never
states what is pending against the actual desktop. That, plus the drift: the
app bypasses its own radius token 42% of the time, never renders its display
face, and reads as a different product from the Hub it sits beside.

### 2.2 Information architecture

Three lanes stay; two are renamed and re-scoped: **BROWSE / GRADE /
PALETTE**.

"Adjust" and "Tune" are synonyms; no user can predict which edits the image
and which edits the scheme, and TunePanel's "Adjust" section header inside
Tune while Adjust is a top-level mode is the proof. The fix is naming the
target, not the gesture:

- **GRADE** edits the image: looks, brightness/contrast/saturation/warmth,
  vignette, and Enhance. Session-scoped, baked into a sibling `.edit` file
  on Set. Its cells carry no source tag; their descriptions say "baked into
  the file when you set it".
- **PALETTE** edits the scheme wallust extracts: tone, character, backend,
  colorspace, palette saturation, threshold, contrast-safe, and (video) the
  sampled frame second. Persisted to `ryowalls.json` immediately; cells
  carry the `ryowalls` source tag. TunePanel's colliding "Adjust" header
  dies: frame moves under a SAMPLING section head, saturation under COLOUR.

They stay two lanes rather than one because the two targets have different
commit semantics and different lifetimes, and a sheet that mixed
session-scoped and disk-persistent cells would need two kinds of "changed"
on one surface.

The **source** is not a lane and not a toolbar toggle: it is the page's
identity. The Fraunces title names it; clicking the title's count-caret
opens the module `Picker` (6 builtins + user libraries is 9+, catalogue
territory): filter field, rows invert under the pointer, current row dotted.
The picker's footer is an add-library `Field` (mono: `owner/repo@branch`)
and library rows carry a remove affordance on hover. The bespoke dropdown
dies.

### 2.3 Layout

Left column (span 5): the grid in BROWSE; a `Section`/`Cell` sheet in GRADE
and PALETTE. Right column (span 7): the preview stack, **pinned across all
three lanes**, because every control in every lane exists to repaint it.

The preview stack, top to bottom:

1. **The mock** in a module `Preview` frame, label `LIVE PREVIEW`, corner
   tag = the pick's resolution in mono. 16:9 inside the frame.
2. **The candidate strip**: the 16 extracted colours as one contiguous
   hairline-framed swatch strip, 22 tall. Chromatic, and allowed: data.
3. **The pending card** (the improvement, 2.6).
4. Pick metadata line: name/id in mono, source tag, low-res flag.

Bottom bar verbs, right: `SAVE COPY` | divider | `OPEN` | `SET WALLPAPER`
(primary; bone-filled while armed). Armed = a pick exists and differs from
what the desktop wears. Left status: `PREVIEWING · NOT SET` with the pulsing
dot, or `WALLPAPER SET · LIVE ON YOUR DESKTOP` after a set, or the current
operation (`DOWNLOADING`, `APPLYING EDITS`) while busy.

Blocks vs cells, stated: the grid is a block; the mock is a block; the
swatch strips are blocks; the pending card is a block; the Enhance surface
is a block; the commit bar is a block. Every slider, toggle, seg and chips
row in GRADE and PALETTE is a `Cell` with its span from `Spans.of()`:

- GRADE: LOOK section: one `chips` cell (7 looks, span 10, selection
  derived from matching values; editing any grade cell deselects). GRADE
  section: brightness/contrast/saturation/warmth as `slid` cells (span 6,
  value numeral shows signed integers, def `0`, struck default and the 2px
  changed bar per contract), vignette as `sw` (span 4). A `RESET EDITS`
  `Btn` sits in the section header line, enabled while any cell is changed.
- PALETTE: PRESETS: one `chips` cell (4 presets, macros: picking one sets
  keys, the lit state is derived). MOOD: tone `seg` 2 (span 4), character
  `seg` 4 (span 8). COLOUR: saturation `slid` with `AUTO` rendered as the
  value at 0, threshold `slid`, contrast-safe `sw`, backend `seg` 4,
  colorspace `seg` 4. SAMPLING (video picks only): frame `slid` (0..10s,
  0.5 steps). `RESET TO DEFAULT` `Btn` in the lane's last section head.

The Advanced drawer dies: backend/colorspace/threshold are ordinary cells in
COLOUR. A 12-cell sheet does not need a drawer; grouping by meaning is the
disclosure.

### 2.4 The surfaces

**The wall grid.** GridView, cells at the current 200px/0.62 rhythm, gap
`s2`. A tile: the thumbnail full-bleed (content), radius 2, hairline `line`
border. Hover: border `lineStrong` (no dark wash; the image is the
information). Selected: the gallery-tile grammar exactly: 1px `ink` border,
corner ink dot; no tick circle, no coloured frame. Resolution badge: bottom
left, a solid paper plate with mono/9 text (`1440P`, `4K`); a low-res pick
inverts the badge to bone (`720P · SOFT`), amendment 5. Video tiles: a small
paper plate with an ink triangle glyph (a triangle, not a circled play);
local clips loop on hover as today, remote clips never stream in the grid.
Local lane adds the selection checkbox: a 16px hairline square, bone-filled
with a black check when marked, and the marked tile gets a 1px bone border,
not a red wash. Right-click still opens the source page.

**MockDesktop.** Survives as the app's crown, redrawn in two ways. One: its
chrome (frame, empty state, busy veil) comes from `Preview`; the busy veil
is the label row swapping to the operation word, not a translucent scrim.
Two: **the mock paints the user's actual shell**: the bar is drawn by
`Silhouette.draw()` with the user's current bar skin (read from
`shell.json`), recoloured by the candidate scheme, instead of the hardcoded
generic pill. The terminal keeps its fastfetch card and the 8-colour
neofetch strip; cava keeps its motion (amendment 2). Everything inside the
canvas is candidate-scheme colour: that is the entire point of the surface,
it is a specimen. The pill's `radius: height/2` and the cava bars' rounded
caps are **correct drift**: they depict the shell, which is round. They
stay.

**The Enhance block** (GRADE lane). A block, not a cell: it has phases, a
progress bar, and a verdict. Anatomy: the primary `ENHANCE IMAGE / ENHANCE
CLIP` Btn (or `INSTALL ENHANCER` when the tool is missing, or the
no-Vulkan sentence when the GPU cannot); while running, the shared progress
spec with the phase word (`EXTRACTING FRAMES`) in caps; after, the verdict.
Every current verdict sentence survives verbatim: the px-vs-cap skip
explanations, the per-cause failure blame (`gpu`/`read`/generic), the
button that stays visible through `sharp`. That copy is UX capital.

**The source picker, local bulk delete, add-mp4 import, settings.** The
picker per 2.2. Bulk delete: `SELECT ALL`/`CLEAR` Btns in the toolbar,
`DELETE N` opens the destructive confirm plate (bone, 2px border, verb
`DELETE N FILES`). Add-mp4 keeps the FileDialog. Settings overlay: API key
(`Field`, mono), NSFW `sw` gated on the key, downloads folder row with an
`OPEN` Btn.

### 2.5 The drift, corrected

The 11 `radius: height/2` uses die by replacement, not by search-and-replace:
LookChip, PresetChip, the sliding-pill Segmented, the pill Toggle, the fit
and add chips, and the round play/tick badges are all deleted when the
module controls (`Chips`, `Seg`, `Sw`, `Slid`, `Btn`) take their places.
The two survivors are inside MockDesktop and are content (see above). The
never-rendered Fraunces face gets its one string: the source title. The Qt
pill scrollbar becomes `ScrollRail`. The Theme fork dies per section 1, and
with it the JetBrainsMono drift and the 120/240/360 motion table.

### 2.6 The improvement: the pending rice diff

The new system's dirty-state machine, pointed at the desktop. The Hub shows
`v != d` as a diff against files on disk; ryowalls shows the candidate
scheme against the scheme the desktop currently wears.

The **pending card** in the preview stack: clean state (pick == desktop):
hairline card, "This is your desktop." Dirty state: **the card inverts to
bone** (the screen's one editorial plate): `PREVIEWING · YOUR DESKTOP STILL
WEARS <name>`, and beneath it the diff: the current 16-colour strip with a
struck mono label, the candidate strip below in full, then up to three mono
rows in file syntax: `image  <old path> -> <new path>`, `palette  dark16 ->
harddark16` when tuned, `frame  1.0s -> 4.5s` when scrubbed. `N OF 16
COLOURS CHANGE` as the count tag. SET WALLPAPER is the SAVE of this machine;
on success the card flips back to hairline, which is the confirmation (no
toast needed, though the status line still reports).

Engine addition (the only one this app needs): `ryowalls current --json`,
returning the active wallpaper path and its 16 resolved colours from the
wallust state, so the singleton can hold `current` beside `selected`.

### 2.7 Art

Per the vector grammar, generated with recraft `line_art`, regraded by
`bin/art/regrade-svg.py`, verified at 0.00% chroma and 6-17% ink:

- **A torii gate**, 1:1: the app mark. A gate frames a view; that is what a
  wallpaper browser does. Replaces `logo.svg` (drawn at 30px in the head)
  and anchors the empty grid and no-pick states at 96px.

No other art. The wallpapers are the art.

### 2.8 What must not be lost

`Wallhaven.qml` survives untouched, and the UI must keep a surface for every
capability in it: six sources plus user libraries (add by
`owner/repo[@branch][/path]` or URL, remove, per-library image/live filter);
search, pagination, top-range, ratio fit vs the primary monitor; NSFW gated
on the API key; local listing with bulk select and disk delete behind a
confirm; live-wallpaper import, frame scrubbing with debounced desktop
repaint, and the fill/fit live mode; the full enhance pipeline (caps
re-probe on window focus, install-via-gpk path, phase file watching,
download-then-enhance, the outlived-pick toast rule, grid reload on
completion); grade preview through the rotating temp slot and the bake-on-set
`.edit` sibling; palette extraction for every pick including graded
previews; apply/download/openWeb; self-clearing status. The mock's economy
rules survive: thumb-then-full fade (retimed to `swap`), remote clips
pausing after 15s of looping.

---

## 3. ryovm

### 3.1 What it is for

Run and manage quickemu machines: keep a small yard of them, commission new
ones from the catalogue, a cloud image, or an ISO, and reach the running
ones. What the current UI makes harder than it should be: reading state at a
glance. The surface spends its loudness on chrome (gradients, hard shadows,
ember frames on everything), so the genuinely live signals (running, fault,
ssh-ready) have to shout in colour to compete, which is how the app ended up
carrying 2.25% chromatic pixels, 5-7x its references. Monochrome plus
inversion re-prices the whole board: a lit tile, a bone plate and a spinning
flap become loud again because nothing else is.

### 3.2 Information architecture

**Library / catalog / instant is wrong by one and hides a fourth.** Catalog
and Instant are the same job (get a new machine) through different engines,
and Load ISO is a third acquisition channel demoted to a modal dialog behind
a toolbar button. The lanes become two:

- **LIBRARY**: the yard. List left, machine stage right.
- **NEW**: commissioning. A `seg` 3 at the top of the lane picks the
  channel: **CATALOG / INSTANT / ISO**. Catalog and Instant keep their left
  grids; ISO's left column is the mark plus one explanatory sentence, and
  (engine verb, optional but cheap: `ryovm isos`, scanning ~/Downloads and
  the vm directory) a list of discovered ISOs that pre-fills the sheet.
  The ImportDialog dies as a modal; its fields become the ISO sheet in the
  hero: name `Field`, path `Field` (mono) with `BROWSE` (the zenity/kdialog
  fallback process survives), guest `seg` 3, `CREATE`.

Deep links map cleanly: `RYOVM_START_MODE=catalog|instant` selects NEW with
the channel preset; `onCreated` still lands in LIBRARY with the new machine
selected.

### 3.3 Layout

Head: eyebrow, no Fraunces title (the serif is on the stage), the
**departure board** right-aligned: the `NN MACHINES NN RUNNING` FlapWord,
ink on instrument plates. Toolbar: lane `Seg`, search `Field`, and (NEW
lane) the channel seg; the Load ISO button leaves the toolbar. The engine
banner and the KVM gate keep their jobs (a missing engine is a banner, only
the hardware fault gates the window) but are redrawn per 3.5.

Left column (span 5): the yard list, or the OS/cloud grid, or the ISO
explainer. Right column (span 7), LIBRARY lane, top to bottom:

1. **The stage**, pinned. It never scrolls: it is the feedback loop, the
   Hub's preview rule applied.
2. **The verb row**: Launch (+ mode seg + disposable sw + the honest
   per-mode caption) when stopped; Stop / Console / SSH when running. The
   captions survive word for word.
3. **The sheet**: a Flickable of `Section`s. Order: REACH IT (running
   only, first, no longer below the fold), IDENTITY, RESOURCES, SEAL, USB,
   SNAPSHOTS, TEMPLATE, DANGER, LOG (3.6), and the engraved machine plate
   as the colophon.

Blocks vs cells, stated: the stage, the reach panel, the snapshot list, the
usb rows, the log, the machine plate, and every download surface are blocks.
Cells: cores (`step`, 1..32, value `AUTO` until pinned, def `auto`), memory
(`step`, GB), disk size (`step`, 8GB steps, with a `GROW TO N GB` Btn
enabled only above the current cap), display mode (`seg` 3), ssh login
(`Field`, mono, the "guest account ssh signs in with" desc), rename
(`Field` + Btn), snapshot name (`Field` + Btn). In the cloud sheet:
disposable (`sw` cell whose value line reads `BURN`/`KEEP`), the toolset as
a true `multi` (12 members, ✓/+ chips, exactly the taxonomy's set control),
extra packages (`Field`, mono, file truth). Defaults in settings: cores and
memory as `step` cells.

### 3.4 The vocabulary: keep or kill

Ruled item by item. The principle: the interaction physics stay, the colour
was carrying state that inversion, the word itself, and blinking now carry.

- **Split-flap: KEEP.** The mechanism is the brand: 70ms InQuad fold, the
  34ms pause, the one hard frame of the plate slapping the stop pin, the
  40ms cascade. All within the motion budget (`Tokens.flap` exists for it).
  Changes: plate gradients die; plates are flat `paperLift` faces
  (amendment 1) with `lineSoft` frames and the black seam. Ink is `ink`
  for a live word, `inkDim` for a dormant one, never green or ember: **the
  word carries the state** (RUNNING / STOPPED / BURNING), which is what a
  departure board is for. Reduced-motion: characters swap instantly.
- **Annunciator: KEEP.** Its own comment already states the correct theory
  (backlit label glowing through dark glass). Monochrome grammar: dark =
  transparent face, `lineSoft` border, `inkFaint` engraved label. Lit =
  `tint10` face, `lineStrong` border, label in `ink`, the 2px filament
  strip along the base in `ink`. Alarm = **the tile inverts to bone**,
  black label, and warns on the 1Hz square wave. Three states where colour
  used to fake five; SEALED simply lights, BURN inverts and blinks. A
  quiet panel is a healthy panel, unchanged.
- **GuardSwitch: KEEP.** Two distinct motions for destruction is
  interaction design, not decoration. The cover: `paperLift` face,
  hazard stripes as 45-degree ink hatching (the hazard-label reference is
  black and white; pattern replaces colour). The armed bed: the contract's
  own destructive plate, bone fill, `inkOnBone` verb, 2px border. The
  160ms cover flip sits inside `move`; the 3s slam-shut stays.
- **HankoSeal: KEEP, RED, RATIONED.** Amendment 3. One seal per screen, on
  the stage, only when it certifies: stamped over the OS mark when the
  machine is sealed, thudding once when a machine is born. Unsealed
  machines show no seal. The seal's circles are print, not chrome; the
  existing license stands.
- **BoardScrollBar: KEEP,** promoted to the module (section 1). It was the
  proof the app understood the system before the system existed.
- **BrutalPanel and every hard offset shadow: KILL.** The contract is
  explicit: the 8px brutalist shadow belongs to the website. The stage,
  the cards and the modals become flat hairline-framed print. What
  replaces the depth: the ticket keeps its perforation column (punched
  paper holes, printed absence), the flap board keeps its physicality, and
  inversion carries emphasis. The drama moves from shadow to state.
- **RegMark, the perforation, the engraved machine plate, corner screws:
  KEEP.** Print motifs, already ink-only or trivially so; screws are dots.
- **The keycap gradients (FlapCell plates, OsIcon monogram, VmCard badge):
  KILL.** Gradients are banned; flat faces per the rulings above.

### 3.5 The surfaces

**The yard list.** Rows 64 tall (the current 68 minus its shadow), hairline
frame, transparent fill. Anatomy: the OS mark (colour, amendment 4) at 26px
on a hairline tile when monogrammed; name in Grotesk 14 (`ink` when running,
`inkDim` when stopped); the spec line in mono 11 `inkFaint`
(`4c · 8G · window · 12 GB`); the state FlapWord right-aligned, 3 cells,
registered like a board column. Selected: `tint10` fill, 1px `ink` border,
corner dot (the gallery grammar). Running: the flap says RUN and the name
brightens; no signal rail, no border colour. The populate cascade survives
(it is the roll-call; entrance animation is banned for pages, and this is a
list transition on data arrival, the one place it stays because the flaps
are already doing it; if it fights the no-entrance rule in review, the flaps
cascading alone carry it and the opacity slide dies).

**The stage.** Flat, hairline-framed, `line` brightening to `lineStrong`
while running (no ember frame). Left stub: the OS mark at 64, the hanko when
sealed, the power FlapWord (7 cells), `RYOVM · PASS` in tag/9. Perforation
column. Manifest: the machine name in Fraunces (the window's serif), the
`LINUX GUEST · QEMU/KVM CARRIER` line in tag/9 ls 1.8, the IATA field grid
(8px caps labels over mono 14 values, hairlines only), then the annunciator
matrix: KVM UEFI TPM DISK NET SSH SPICE SEALED BURN, uniform 54px tiles,
per-3.4 grammar. RegMark top right in `inkFaint`.

**Reach it.** First section while running. The ssh command in a mono `Field`
(read-only face, the full honest form with user@), `OPEN` and `COPY` Btns;
the answering/not-answering sentence (`ink` when ready, plain when booting;
no green); the login-as `Field`; the console row with its viewer-missing
honesty; the release-keys KeyHints as mono keycap tags; the headless "this
panel is the machine's only door" line. All current copy survives.

**Snapshots.** Name `Field` plus SAVE; rows with name/date, RESTORE behind a
GuardSwitch, DELETE as the two-tap confirm. The NO DISK explainer row keeps
its dark annunciator and its sentence. Seal and Template keep their
sentences and verbs; restore-seal stays under a guard.

**The OS catalogue.** Tiles at the current 150px rhythm, hairline, logo at
52 (colour), name Grotesk 12; selected = gallery grammar (ink border,
`tint10`, corner dot; the ember tick square dies). Popular/All split
survives, drawn as `Section` headers with dot-and-leader. The create sheet:
OS mark at 72 with the name in Fraunces 22 on a flat framed hero, release
and edition as `Chips` (they exceed 4 often; chips wrap), the honest
"quickemu downloads the official image" sentence, `CREATE MACHINE` primary.
Download state: the shared progress spec, phase word in caps, Cancel;
indeterminate fallback per section 1 (blinking dot plus the mono log line,
no sweep).

**The cloud lane.** Left: the curated grid, same tile spec. Right sheet:
the disposable `sw` cell, the toolset `multi`, the extra-packages `Field`,
the heavy-tools steer sentence (kept verbatim, it routes users to
templates), `CREATE · BURN` primary. The `~2.5 GB · logs in as ryoku /
ryoku` line stays mono: it is file truth.

**The ISO sheet.** Per 3.2. The guest seg doubles as the logo slug,
unchanged.

**The fault strip.** Above the bottom bar. Hairline frame; an inverted
FAULT annunciator tile (bone, blinking while fresh), the first stderr line
in `ink`, `DETAIL` expanding the full stderr as a mono block, `DISMISS`.
Sticky until dismissed or superseded, as today. No red field, no red
border; the inverted tile is louder than the old ember wash ever was.

**The gate and the banner.** KVM off: the full-window gate keeps its two
sentences, led by the app mark, not a red cpu icon. Engine missing: the
banner becomes a hairline row with a lit (not inverted: it is a limitation,
not a fault) `ENGINE` annunciator, the sentence, and `INSTALL ENGINE`.

**Settings overlay.** Engine status row (mono version string), default
cores/memory `step` cells, machines path row with OPEN, the catalogue
provenance rows in mono. Same overlay spec as ryowalls.

### 3.6 The improvement: the yard log

The Hub got a console; ryovm gets the flight recorder. Today every verb's
receipt flashes in the status bar for 4.5 seconds and is gone, and a fault
overwrites the previous one; the machine's history exists nowhere. The
singleton already funnels every receipt and fault through two functions
(`info()`, `raiseFault()`); the log is those functions growing memory.

`Vm` gains `events`: `{time, vm, kind, text, detail}` appended by
info/raiseFault/launch/stop/seal/snapshot/create, capped at 200, session
scoped. The UI: a LOG section at the foot of the machine sheet, filtered to
the selected machine: mono 11 rows, `HH:MM:SS` in `inkFaint`, the receipt in
`inkDim`, faults marked with an inverted tag and expandable to their full
stderr. The bottom bar keeps showing the latest line; the log is where it
stops evaporating. This is the pending-write diff's sibling: file truth,
mono, grouped, and it makes "what just happened to this machine" a question
the instrument can answer.

### 3.7 Art

- **A coiled dragon**, 1:1: contained power, the app mark. Replaces
  `logo.svg`, anchors the empty library, the KVM gate, and the ISO lane's
  left column. Same pipeline and verification as 2.7.

The OS logos and the hanko carry the only other non-ink pixels in the app.

### 3.8 What must not be lost

`Vm.qml` survives untouched; the UI must keep a surface for all of it: the
caps gate split (KVM off gates, engine missing merely bans launch, the
library works engineless); the 5s poll with its anti-rebuild guards; the
queued verb runner with config coalescing (rapid stepper clicks must not
eat a Launch); create/instant streaming with real Cancel and half-image
cleanup; sticky faults with full stderr; the narrated ssh handoff script
(the boot-wait heartbeat, the cloud-init tools-wait with Ctrl+C drop-in,
the "password you never set" postmortem) verbatim, it is the best copy in
the distro; copy-ssh; USB assignment with the launch-time honesty line;
seal/restore/template/spawn; rename via pendingSelect; grow and reclaim;
deep links; the quit handshake during downloads; the disk-cached no-network
logo resolution and the Popular split; the per-mode launch captions and
every "stop the machine to X" gate sentence.

---

## 4. Port order and verification

Order: the shared pieces first (`Field`, `ScrollRail`, `IconBtn`, the
skeleton), then **ryowalls** (smaller, and its GRADE/PALETTE sheets are the
first real test of Cell/Section outside the Hub), then ryovm.

Per app, the Shell rule: list the surfaces (2.4 / 3.5), port the surfaces
into the grid as blocks, then let the cells fill in around them, then
verify. A surface present in the old app and missing in the new one is a
regression, same as a setting.

Checks, not vibes:

1. **Surface count.** Every surface named in 2.4 and 3.5 exists and is
   reachable. ryowalls ~18, ryovm ~28.
2. **Wire probes.** ryowalls: flip a PALETTE cell, read `ryowalls.json`;
   set a wallpaper, read `ryoku-wallust.json` and confirm the desktop; the
   pending card clears itself. ryovm: pin cores, read the `.conf`; launch,
   watch the flap and the poll; kill the engine mid-create, see the fault
   strip and the log entry.
3. **Chroma budget.** Rasterise each window in a settled state with no
   thumbnails loaded and no logos cached: chromatic pixels 0.00%. With
   content loaded, all chroma must sit inside content rects (thumbnails,
   mock canvas, swatch strips, logos, one hanko).
4. **Token audit.** No hex, family, radius, duration or spacing literal
   outside `Tokens.qml` in either app; `grep radius:` yields only
   `Tokens.radius`, dots, the hanko, and MockDesktop's two content pills.
5. **Motion audit.** No duration above `swap` except the 1Hz square blinks
   and the 600/600 heartbeat; reduced-motion zeroes everything, flaps
   included.
6. **Copy audit.** The sentences named "survives verbatim" in 2.4, 2.8,
   3.5 and 3.8 are present character for character.
