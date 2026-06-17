# shell/

The Ryoku desktop shell: the bar, panels, launcher, and the Hyprland
glue around them. `ryoku/` ships the plain desktop; this tree is the full shell
that sits on top of it.

This is a starting base. It is in the repo, de-branded, and reorganized, but not
yet wired into the installer. The pieces are here to build on.

## Layout

- `ipc/` The control plane: one Go program, `ryoku-shell`. As `ryoku-shell daemon`
  it supervises the Quickshell components, starts the clipboard and wallpaper
  helpers, and listens on a single Unix socket. As `ryoku-shell <command>` it is a
  thin client that forwards a command to that socket; Hyprland keybinds use it.
- `quickshell/` The UI, hand-written Quickshell (QML): `pill` (the morphing bar),
  `sidebar`, `topbar`, `launcher`, and `ryoshot` (screenshot and annotation).
  These render the shell; they hold no daemon logic.
- `hypr/` The Hyprland config in Lua (`hyprland.lua` plus `modules/`), and the few
  leaf scripts the UI still calls directly (`scripts/`: clipboard and wallpaper
  thumbnailers, the imagemagick policy).
- `wallust/` Palette generation from the current wallpaper (terminal, ghostty,
  Hyprland colors, fastfetch).
- `fish/`, `fastfetch/`, `ghostty/`, `kde/`, `brave-theme/` Per-app config.
- `systemd/` The user session target.

## The IPC

Everything that controls the shell goes through `ryoku-shell`, so there is one
socket and one place that knows how to talk to the components:

| Command | Effect |
|---|---|
| `ryoku-shell daemon` | start the shell: supervise `pill`, bring up clipboard history and the wallpaper, then serve the socket |
| `launcher`, `clipboard`, `link`, `wallpaper-picker`, `mixer`, `calendar`, `power`, `battery`, `media`, `peek`, `hide` | toggle a pill surface on the active monitor |
| `sidebar` | toggle the sidebar |
| `lock` | lock the screen with qylock (the shell ships no lock of its own) |
| `wallpaper [next\|init\|set <path>]` | change the wallpaper and retheme |
| `reload`, `status`, `ping`, `quit` | manage the daemon |

The daemon resolves the active monitor itself, so the client and the keybinds stay
dumb. Build it with `go build` in `ipc/`; the binary belongs on `PATH` as
`ryoku-shell`.

## Develop it live

Run the shell straight from this checkout on a running Hyprland session, no
install required:

    shell/dev-run.sh        # build ryoku-shell, then run it with RYOKU_SHELL_DIR set
    shell/dev-binds.sh on   # optional: bind the shell keys for this session
    shell/dev-stop.sh       # stop it (restore your keys with: hyprctl reload)

The daemon launches each component with `qs -p`, so your own `~/.config` is never
touched, and quickshell hot-reloads QML edits, so changes show as you save.

## Not wired yet

Installing the configs to `~/.config` and building `ryoku-shell` into the image is
the deployment step, not part of this pass. The lock screen is qylock, shipped by
`ryoku/`; the shell does not replace it.
