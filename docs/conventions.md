# Conventions

How code and configuration are written in this repo. When in doubt, match the
file next to the one you are editing.

## Hyprland is Lua

`ryoku/hyprland/` is authored in Lua, never as a raw `hyprland.conf`.

- `hyprland.lua` is the entry point and `require`s each module by name.
- `modules/` holds one concern per file: keybinds in `binds.lua`, motion in
  `animations.lua`, window rules in `window_rules.lua`, session startup in
  `autostart.lua`, and so on. A new concern is a new module plus one `require`.
- Use the `hl` API the modules already use (`hl.exec_cmd`, `hl.on`, the keyword
  setters). Do not shell out to `hyprctl` from Lua when an `hl` call exists.
- `keyboard.lua`, `gpu.lua`, `monitors.lua` are seeds the hardware helpers
  manage. Keep them generic; never hardcode one machine's monitors or layout.

## QML is one component per file

`ryoku/shell/quickshell/` is the UI. Each surface (`pill`, `sidebar`, `topbar`,
`launcher`, `ryoshot`) is its own directory, and each component is a single
`.qml` file. Compose components; do not merge unrelated UI into one file.

View and logic stay apart: QML renders and animates, `ryoku-shell` (Go, in
`ryoku/shell/ipc/`) decides. The UI asks the daemon over its socket; it does not
embed policy.

## System logic is a named helper

Anything with real shell logic is a `ryoku-<thing>` script in
`system/hardware/.../` installed to `/usr/local/bin` and invoked by name from
Lua autostart or keybinds: `ryoku-gpu`, `ryoku-monitor`, `ryoku-hw-laptop`,
`ryoku-idle`, `ryoku-fastfetch`, `ryoku-shell`. Do not inline multi-step shell
into Lua, and do not copy a helper's logic into a second place; if two callers
need it, it is one shared helper (as `ryoku-hw-laptop` is).

## Native config formats are expected

The Lua rule covers the *Hyprland* config only. Every third-party tool keeps its
own native format under its own directory: `kitty.conf`, `wallust.toml`,
`kdeglobals`, `yazi.toml`, `starship.toml`, `hypridle.conf`, `npmrc`, `pip.conf`.
That is correct, not a violation. Do not invent a Lua wrapper for a tool that
reads its own format.

## No duplication

Search before adding. There is one source for each config, script, value, and
fact. If a thing must exist in two places, extract it to one place and reference
it. Two copies will drift; treat a second copy as a bug.

## Comments

Comment the *why* when it is not obvious. Never narrate the *what*, never leave
commented-out code, never pad with filler. If a file reads as more explanation
than code, the code is too complicated; simplify it. The pre-commit hook rejects
filler comment lines.

## Naming

Helpers are `ryoku-<thing>`. Lua modules are named for their concern
(`binds.lua`). QML components are named for the component (`Pill.qml`). Names are
literal and lowercase-hyphenated for scripts.

## Commits and hooks

Run the hooks; never use `--no-verify`. Subjects are `[area] scope: imperative
summary`, where area is one of
`global | installation | system | ryoku | docs | test | tooling | release`
(shell changes use `[global]`). No em-dash, no authorship or attribution
trailer, no filler. Keep one logical change per commit. Details in
`docs/development.md`.
