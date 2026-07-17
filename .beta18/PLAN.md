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

Schema rows still need written descriptions. Only ShellSettingsPage has them.
The inventory's notes are engineering observations and must not be shipped as
user copy.
