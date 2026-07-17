# beta-18 handoff

Branch `beta-18`, 19 commits on top of `404c0d5a`. Everything below is committed.
Nothing is on `unstable-dev` or `main`.

## What the job is

Replace the UI of **ryoku hub**, **ryowalls** and **ryovm** with one design.
Not ryomotion. No setting may be lost or hidden. Docs come with it.

## Read in this order

1. `.beta18/DESIGN.md` (605 lines). The contract for the Hub. Palette with
   measured contrast ratios, type scale, space scale, the control taxonomy, the
   cell, page anatomy, Profile and Credits, art direction, and a reviewer
   checklist. Written to be implemented literally.
2. `.beta18/APPS.md` (599 lines). The same for ryowalls and ryovm, with six
   numbered amendments to the contract up front.
3. `.beta18/PLAN.md`. What broke and why. Read the Shell-port failure before
   porting anything.
4. `.beta18/inventory.json`. Every setting and every surface in the Hub as it
   exists today. This is the contract for losing nothing.

Both DESIGN.md and APPS.md were written by a fable-5 agent given the measured
facts and told to override where it disagreed. It did, in useful places.

## The design, in six lines

Paper `#000000` plus grain at 5.5%. Ink `#cdc4ba`, a warm bone, not white:
white glows and kills the matte. The ramp is contrast-solved, nothing under
4.6:1. Radius 2. Fraunces for display, Space Grotesk for anything a human reads
as language including numerals, Space Mono for what a config file would hold.
**No colour in app chrome.** Emphasis is inversion: the surface flips to bone and
its ink flips to black. The accent lives in the compositor frame, not in content.

## Where everything is

| | |
|---|---|
| The module | `ryoku/ui/` (`Ryoku.Ui`), 19 components |
| Tokens, Spans, Silhouette | `ryoku/ui/Singletons/` |
| Schemas, 30 pages, 479 controls | `ryoku/hub/quickshell/schema/*.js` |
| Schema renderers | `ryoku/hub/quickshell/{SchemaPage,SettingsSheet}.qml` |
| Tests | `tests/ui/wire-probe.sh`, `tests/ui/barcode.sh` |
| Mockups, QML + renders + video | `.beta18/mockups/` |
| Art and the references | `.beta18/art/` |
| Shipped art | `ryoku/ui/art/{justice,graces,helm}.svg` |

### The mockups, in the order they were iterated

`.beta18/mockups/`. Each `*.qml` runs standalone:

    QML_IMPORT_PATH=$HOME/.local/lib/qt6/qml qs -p .beta18/mockups/B6.qml

- `A.qml` specimen layout, art centred. Rejected: its top chip bar was a
  relocated sidebar, not a redesign.
- `B.qml` desktop layout, rail plus a settings table. The conservative one.
- `C.qml` the sheet: no rail, no tabs, no pages, filter as the only navigation.
  The most reference-faithful and it does not scale past one screen.
- `B2.qml` B at a normal scale with Space Grotesk and real animation.
- `B3.qml` the UX closes: edit, preview redraws, state counts, save. **This is
  the one the user pointed at.**
- `B4.qml` bento grid, preview rebuilt with callouts on the drawing.
- `B5.qml` semantic sections, Flow packing, spans derived, preview pinned.
- `B6.qml` **the latest and the reference.** All ten bar skins as a drawn
  gallery, the pending-write diff in real config syntax, contrast fixed.
- `composed-hub.qml` the module assembled into a full page against the real
  `shell.json`. Closest thing to the target that exists.

`B6-shot.png` and `b6.mp4` show it moving. The videos are real pointer input, not
scripted fakes.

## What is done

- **`Ryoku.Ui`**: Tokens, Spans, Silhouette; the eight controls (Sw, Step, Slid,
  Seg, Chips, Multi, PickBar+Picker, Gallery); Cell, Section, Grain, Btn;
  ActionBar, Preview, Field, IconBtn, ScrollRail, Barcode. All render.
- **The import-path fix.** `daemon.go` injects `QML_IMPORT_PATH` only into
  configs it supervises, so `qs -c hub` from a keybind resolved no shared module
  at all. Proven with a standalone `qs -p` (exit 255, "not installed"). Fixed in
  `hyprland/modules/env.lua`. An installed system reads `/usr/lib/qt6/qml` and
  never hit it, so it was dev-only and silent. **If an import fails in dev and
  works on an installed box, this is why.**
- **30 schemas**, 515 settings to 479 controls. The difference is hand-wired set
  members collapsing: `islandModules` was 7 toggles and is one `multi`.
- **Copy**: 453 of 479 written, 178 labels replaced. 26 left blank on purpose
  (GpuPage 11, DisplaysPage 6, RashinPage 6) where the source did not say what
  the setting does. An invented description reads as authoritative and is worse
  than none.
- **`tests/ui/wire-probe.sh`**: proves the adapter still writes what the UI set.
  Green: frameBorder 57 to 88, barStyle nacre to delos, islandModules changed.
- **`tests/ui/barcode.sh`**: proves the dossier's Code 39 scans.
- **`docs/ui-ux.md`** rewritten. It claimed "wallust overrides only the accent",
  which was never true.
- Deploy and packaging wired: `deploy.sh` and the `ryoku-desktop` PKGBUILD
  install `Ryoku.Ui` to `/usr/lib/qt6/qml/Ryoku/Ui`.

## What is NOT done

- **No Hub page is ported.** A port was attempted and reverted (see below).
- **Profile and Credits** are designed with art and are not built. The user said
  twice these matter most: the Profile is the showoff piece, not an overview.
- **ryowalls and ryovm** are designed and not built.
A `hub-port` workflow (chrome plus 30 page ports plus an audit) was started and
then stopped before it wrote anything, so the tree is clean. Its script is at
`.claude/projects/.../workflows/scripts/hub-port-*.js` if the approach is worth
reusing: one agent per page, each told to list the page's surfaces from
inventory.json first and treat them as a checklist, with an adversarial audit
that greps for surviving colour and for pages that lost their action bar.

## The mistake to not repeat

I ported Shell by cutting the view and keeping the state. Every setting
survived. The action bar did not, because the action bar was in the view.
`save()`, `revert()` and `resetDefaults()` stayed in the file with nothing
calling them; the live preview still wrote through the throttle so edits looked
applied; and `Component.onDestruction` restored `committedVals` on leave. Edit a
setting, leave the page, lose it, with no Save to commit it first. That is data
loss and it shipped. Reverted in `c8e78f51`.

It shipped because I checked that the settings survived and never checked that
the surfaces did. The inventory said Shell had 26 non-setting surfaces. I read
the number as context. It was a list.

**There is no schema-shaped page.** An earlier `page-classes.json` claimed six of
them and that claim caused the bug. All 30 pages have surfaces: **479 settings
against 508 surfaces, and not one page has zero.** WifiTab is 1 setting and 31
surfaces. AppearancePage's Rices tab is an entire delegated sub-page.

### So port in this order

1. List the page's surfaces from `inventory.json`. That is the work. The schema
   is not.
2. Build the surfaces first, as full-width blocks in the section grid. A
   preview, a console, a drag-arrange, an action bar: not settings, not cells.
3. Let the rows flow around them.
4. Check four things: every surface present, every key present,
   `tests/ui/wire-probe.sh` green for that page's keys, nothing under 4.6:1.

**The ActionBar goes in first.** It is the one surface whose absence destroys
work rather than merely looking wrong.

## Art

`.beta18/art-grammar.txt` has the recipe. Short version:

- Model: `fal-ai/recraft/v3/text-to-image`, style `vector_illustration/line_art`.
  Key at `~/.config/fal/key`. It returns **SVG**, which is the point.
- **flux is the wrong model.** It renders. Ask it for a marble bust and it builds
  and lights a 3d sculpture whatever style words follow; lead with the medium and
  it draws manga, which is still anime. The user rejected both.
- Regrade with `bin/art/regrade-svg.py`. It buckets fills by luminance. Do NOT
  hand-map colours: every generation picks its own greys (one file's linework
  came back `rgb(57,58,58)`, another `rgb(0,0,0)`), so a string map silently
  misses one and the figure renders half invisible. That looked like a bad
  generation and was a bad mapping.
- The light fill is not just the background, it is painted inside every outlined
  shape. Map it to paper, never to `none`, or the outlines fill in solid.
- Verify by measuring, not by looking: 0.00% chromatic pixels, ink fraction near
  6 to 17%. Above ~20% midtone means it is being rendered, not drawn.

Shipped: `ryoku/ui/art/{justice,graces,helm}.svg`. Rejects and experiments are in
`.beta18/art/` (`r_*` raw, `p_*` pre-grade, `q_*` graded).

`.beta18/art/ref-*.png` are the three references the user chose. They are the
source of truth for the language, and they are all monochrome: 0.00 to 0.46%
chromatic pixels, measured. The Berserk pin sits at 69% near-black, 12.5%
near-white, 18% mid. Match that.

## House rules, enforced by hooks

- Subjects need an impact label: `[global] [installation] [system] [ryoku]
  [docs] [test] [tooling] [release]`.
- **No em-dashes**, anywhere, code or prose. Rejected at commit.
- **No authorship trailers, no generated-content attribution.** Rejected.
- **No filler comments.** `bin/ryoku-dev-scan-slop` rejects self-narration and
  chat residue. Comments are 2 to 6 lines, the why only. The story goes in the
  commit body.
- No PR. The user asked for the branch only.

## Open decisions the user should settle

1. **The hanko keeps its vermillion** (APPS.md amendment 3), which deliberately
   breaks the no-colour rule: one per screen, stage only, only when it
   certifies. Confirm or kill it.
2. **26 settings have no description.** They need eyes on the source, not
   another generation pass.
3. I retired DESIGN.md's Pillow duotone grade. It exists to force raster art
   onto a palette and the art is vector, already on it.

## Traps already paid for

- A nested `Repeater` shadows `index`. `setV(index, ...)` inside one mutates the
  wrong row. It presents as a frozen preview, not an error.
- A full-row `MouseArea` swallows its children's clicks even with
  `acceptedButtons: Qt.NoButton`. Use `HoverHandler`.
- `ListModel.get()` is not a binding dependency. A binding that reads it once
  freezes. Tie it to a revision counter.
- `font.pixelSize` is an int. `8.5` is a load error.
- QML ids cannot start with a capital.
- `TapHandler` has no `onReleased`. Use `onPressedChanged`.
- A tiled window ignores `minimumSize` and clips. It cost an hour on the
  barcode: the encoder was right, the render was clipped, and a Code 39 without
  its stop bars still looks exactly like a barcode.

## The rule under all of it

A thing that looks right is not evidence. The Shell port looked right and ate
saves. The barcode looked broken and was fine. Measure it, read it back off
disk, or scan it.
