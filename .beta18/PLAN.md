# beta-18 rework, state and order of work

Branch `beta-18` only. Working notes, not shipped docs.

## Done

- **`ryoku/ui/` = `Ryoku.Ui`.** Tokens, Spans, and the eight controls (Sw, Step,
  Slid, Seg, Chips, Multi, PickBar+Picker, Gallery pending), plus Cell, Section,
  Grain, Btn. Installs via `ryoku/ui/install.sh`, wired into `deploy.sh` and the
  `ryoku-desktop` PKGBUILD (`/usr/lib/qt6/qml/Ryoku/Ui`). Smoke-tested: renders,
  zero warnings.
- **The import-path trap.** `daemon.go` injects `QML_IMPORT_PATH` only into the
  configs it supervises, so `qs -c hub` from a keybind could not resolve
  `Ryoku.*` at all. Proven with a standalone `qs -p` (exit 255, "not
  installed"), fixed in `hyprland/modules/env.lua`. An installed system reads
  `/usr/lib/qt6/qml` and never hit it, which is why it stayed hidden.
- **`inventory.json`.** 515 settings across 36 files, extracted per file. This
  is the contract: a setting in here and not on screen after the rework is a
  regression. 49 have no discoverable config key; those need eyes.
- **`DESIGN.md`.** The contract. Written to be implemented literally.
- **`art-grammar.txt`.** Validated: lead with the medium, never say "marble"
  (it forces a 3d render), measure the output rather than eyeball it.

## The numbers that decide the work

Of the Hub's enums: 79 have 1-4 options, 10 have 5-8, 23 have 10+. That is why
the taxonomy is seg / chips / pick and not one Dropdown. `islandModules` is a
set, not a choice. The ten bar skins are a gallery: no label distinguishes
"engraved bracket cells" from "three islands with concave dips".

**204 of the 515 settings are `custom` controls.** That is the real work. Each
one is either a control the taxonomy already covers (port it) or a genuine
one-off (keep it, and say why in the cell).

## Order

1. `Gallery.qml` into the module (the ten skins already draw; lift them out of
   the mock).
2. **Shell page** as the vertical slice: 66 settings, 5 tabs, three config
   files, live preview. If the pattern survives Shell it survives anything.
   Verify against the backend, not just on screen: change a value, confirm the
   key lands in `~/.config/ryoku/shell.json`.
3. **Profile and Credits.** These are the payoff, not settings pages. Spec is
   DESIGN.md sections 9. Profile exports itself; that is the feature.
4. The remaining pages, heaviest first: HyprStore (95), Animations (67),
   Appearance (58), Widgets (40), Input (32).
5. `docs/ui-ux.md` rewrite. It currently describes a system the code left: it
   claims wallust overrides only the accent, and the shell floats its surfaces
   too. Fix the doc to match the code, not the reverse.
6. ryowalls, then ryovm. Not ryomotion.

## Verification, not vibes

- Every page ports with a check: the setting count on screen matches
  `inventory.json` for that file.
- Backend: edit in the UI, then read the JSON on disk. A setting that renders
  but does not persist is worse than one that is missing.
- Contrast: nothing below 4.6:1. The old ramp shipped descriptions at 2.6:1.

## Traps already paid for

- A nested `Repeater` shadows `index`. `setV(index, ...)` inside one mutates
  the wrong row. It presented as a stuck preview, not as an error.
- A full-row `MouseArea` swallows its children's clicks even with
  `acceptedButtons: Qt.NoButton`. Use `HoverHandler`.
- `ListModel.get()` is not a binding dependency. A binding that reads it once
  freezes; tie it to a revision counter.
- `font.pixelSize` is an int. `8.5` is a load error, not a rounding.
- QML ids cannot start with a capital.
- The repo rejects em-dashes, authorship trailers and generated-content
  attribution at commit time. Subjects need an impact label.

## What the schemas settled

All 30 pages are schemas now: 515 settings, 482 controls (the difference is
hand-wired set members collapsing into `multi`). The taxonomy covers 514 of
515. The one holdout is AddonsPage's plugin field, whose kind is declared by a
plugin manifest at runtime and cannot be known statically; it stays dynamic.

The 204 `custom` controls were a false alarm. They are bespoke *implementations*
of ordinary kinds: 53 bools, 40 reals, 32 strings, 24 ints. Nothing about them
needed a bespoke control, they just never had a shared one.

**The real remaining work is the 605 non-setting surfaces**, not the settings.
Previews, live consoles, the monitor drag-arrange, the bezier editor, keybind
capture, store cards, wizards, scan buttons, loading and empty states. Those are
in `inventory.json` under `nonSettingSurfaces`, per file. A page is not ported
when its schema renders; it is ported when its surfaces come with it.

Descriptions are written: 453 of 479, and 178 labels replaced where the old one
was a raw config key. 26 remain, concentrated in GpuPage (11), DisplaysPage (6)
and RashinPage (6), where the setting's purpose was not clear from the source.
Those want eyes, not another pass: an invented description is worse than none.

## What the Shell port proved, by breaking

I ported Shell by cutting the view and keeping the state. The settings all
survived. The action bar did not, because the action bar was in the view.
save(), revert() and resetDefaults() stayed in the file with nothing calling
them; the live preview still wrote through the throttle so edits looked applied;
and Component.onDestruction still restored committedVals on leave. Edit a
setting, leave the page, lose it. That is data loss and I shipped it, then
backed it out in 33095045 / its revert.

It shipped because I checked that the settings survived and never checked that
the surfaces did. The inventory told me Shell had 26 non-setting surfaces. I
read the number as context. It was a list.

**There is no "schema-shaped page".** page-classes.json used to claim six of
them; that claim is what caused the bug. Every one of the 30 pages has
surfaces: 479 settings against 508 surfaces, and not a single page has zero.
WifiTab is 1 setting and 31 surfaces. Shell is 53 and 26. Even Performance
seeds its config and reloads the compositor.

So the schema is half a page, never a whole one. The correct order for any page:

1. List its surfaces from inventory.json. That is the work; the schema is not.
2. Port the surfaces first, into the sheet's grid as full-width blocks. A
   preview, a console, a drag-arrange, an action bar: these are not settings and
   do not go in a cell.
3. Then let SchemaPage draw the rows around them.
4. Then check: every surface present, every key in the schema, wire-probe green
   for that page's keys. A page is ported when all four hold, not when it
   renders.

The action bar is the first surface to build, because it is the one whose
absence silently destroys work rather than merely looking wrong. It is built:
Ryoku.Ui/ActionBar.qml, both states verified. It also splits the two verbs the
old pages ran together, revert discards unsaved edits and reset writes factory
values, which is itself an edit and leaves the page dirty.

Preview is built too: the frame, the label, the corner tag and the off state.
What goes inside stays the page's, because only the page knows what it draws.
Shell, Widgets, Appearance and ryowalls each grew their own preview block with
its own gradient and its own badge, which is four products' worth of chrome for
one idea.

Still to build, in the order they hurt: the update console, the monitor
drag-arrange, keybind capture, the bezier editor, store cards, scan lists, file
pickers, empty and loading states. inventory.json lists them per page. The
previews themselves (Viz, Clock, Weather, Calendar, MockDesktop) now only need
their canvas lifted into a Preview.

## What rendering all 30 pages actually proved

SchemaPage draws every schema with no errors, and that is not the same as every
page being ported. Rendering WindowRulesPage through it produces a raw filename
for a title, overlapping labels, and multi chips whose options are inventory
prose. The component is fine. The premise does not hold for that page, because
WindowRulesPage is a rule editor, not a settings page.

Classified in page-classes.json:

page-classes.json now records what is actually there: settings and surfaces per
page, no verdict. The verdict was the mistake.

## The apps

APPS.md is the design for ryowalls and ryovm. It is a contract like DESIGN.md,
not a sketch. The decisions worth knowing before reading it:

- Both apps are one skeleton. The arbitrary `parent.width * 0.44` against `0.46`
  becomes a 5/12 : 7/12 split of the same grid the Hub uses. Both local
  Theme.qml forks are deleted.
- Three components get promoted into Ryoku.Ui because both apps force them:
  Field, IconBtn, and ScrollRail, which is ryovm's BoardScrollBar. That one was
  the proof the app understood the system before the system existed.
- ryowalls: browse/adjust/tune becomes BROWSE / GRADE / PALETTE. The collision
  where TunePanel had a section headed "Adjust" while Adjust was a top-level mode
  dies by naming the target: you grade the image, you tune the scheme.
- ryovm: library/catalog/instant becomes LIBRARY / NEW with a channel seg, and
  the ImportDialog modal dissolves into the ISO sheet.
- The split-flap, the annunciator and the guard switch all stay and lose their
  colour. State moves to the word, to lit against dark, to a blink, and to
  inversion: an alarm tile inverts.
- **The hanko keeps its vermillion.** This breaks the no-colour rule on purpose
  and the amendment is written down: it is ryovm's sun, one per screen, stage
  only, and only when it certifies. Grey per-card seals die.
- MockDesktop gets upgraded rather than ported: it paints the user's actual bar
  skin through Silhouette.draw(), the same source the Hub's gallery draws from.
- Each app gets one thing it never had. ryowalls gets a pending rice diff, the
  Hub's dirty-state grammar applied to a wallpaper, with SET as its SAVE. ryovm
  gets a yard log, a per-machine flight recorder grown from info()/raiseFault().
