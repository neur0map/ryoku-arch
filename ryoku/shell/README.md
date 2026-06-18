# ryoku/shell/

The Ryoku desktop shell: the bar, panels, launcher, and screenshot tool that run
on top of the Hyprland config in `ryoku/hyprland`. The installer deploys all of
it to `~/.config` (see `installation/backend/lib/deploy.sh`).

## Layout

- `ipc/` The control plane: one Go program, `ryoku-shell`. As `ryoku-shell daemon`
  it supervises the Quickshell components, starts the clipboard and wallpaper
  helpers, and listens on a single Unix socket. As `ryoku-shell <command>` it is a
  thin client that forwards a command to that socket; Hyprland keybinds use it.
- `quickshell/` The UI, hand-written Quickshell (QML): `pill` (the morphing bar),
  `sidebar`, `topbar`, `launcher`, and `ryoshot` (screenshot and annotation).
  These render the shell; they hold no daemon logic.
- `wallust/` Palette generation from the current wallpaper (the kitty palette and
  the Hyprland colors).
- `kde/`, `brave-theme/` Per-app config.
- `systemd/` The user session target.

The Hyprland config that hosts this shell lives at `ryoku/hyprland`; its
`scripts/` holds the clipboard and wallpaper thumbnailers the UI calls directly.
Its autostart also runs `ryoku-idle start`, which enables dim/lock/display-off/
suspend timeouts only on detected laptops.

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

## Dependencies

Beyond Hyprland, quickshell, and `go` (to build `ryoku-shell`), the shell calls at
runtime: `awww` (wallpaper daemon), `wallust` (palette), `cliphist` and
`wl-clipboard`, `imagemagick` (clipboard and wallpaper thumbnails), `hyprpicker`,
`hypridle` and `brightnessctl` (laptop idle/dim), `upower` (battery state),
`wireplumber` (`wpctl`) and `playerctl` (media keys), `jq`, and `glib2` (`gio`).
The keybinds open `kitty` (terminal) and `nautilus` (files). Fonts: JetBrains
Mono Nerd and Noto; cursor: Bibata. The lock is qylock, from `ryoku/`.

## Develop it live

Run the shell straight from this checkout on a running Hyprland session, no
install required:

    ryoku/shell/dev-run.sh       # build ryoku-shell, then run it with RYOKU_SHELL_DIR set
    ryoku/shell/dev-binds.sh on  # optional: bind the shell keys for this session
    ryoku/shell/dev-stop.sh      # stop it (restore your keys with: hyprctl reload)

The daemon launches each component with `qs -p`, so your own `~/.config` is never
touched, and quickshell hot-reloads QML edits, so changes show as you save.

## Install

The installer deploys this tree to `~/.config` and the prebuilt `ryoku-shell` to
`/usr/local/bin`: `installation/iso/build.sh` builds the daemon into the image and
`installation/backend/lib/deploy.sh` lays down the configs. The lock screen is
qylock, shipped by `ryoku/lockscreen`; the shell does not replace it.
