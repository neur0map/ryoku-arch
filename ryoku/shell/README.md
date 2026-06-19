# ryoku/shell/

The Ryoku desktop shell: the bar, panels, launcher, and screenshot tool that run
on top of the Hyprland config in `ryoku/hyprland`. The installer deploys all of
it to `~/.config` (see `installation/backend/lib/deploy.sh`).

## Layout

- `ipc/` The control plane: one Go program, `ryoku-shell`. As `ryoku-shell daemon`
  it supervises the Quickshell components, starts the clipboard and wallpaper
  helpers, and listens on a single Unix socket. As `ryoku-shell <command>` it is a
  thin client that forwards a command to that socket; Hyprland keybinds use it.
- `quickshell/` The UI, hand-written Quickshell (QML): `pill` (the morphing top
  island; it also draws the screen frame and hosts the edge popouts under
  `pill/popouts/`, the mixer and power), `sidebar`, `topbar`, and `launcher`, plus
  `ryoshot` (screenshot and annotation). These render the shell; they hold no
  daemon logic.
- `plugin/` `Ryoku.Blobs`, the C++/QML SDF metaball module the frame renders
  with: the border, the pill, and the popouts melt into one blob field. `build.sh`
  builds it with cmake onto a QML import path, and it ships prebuilt. See
  docs/frame.md.
- `wallust/` Palette generation from the current wallpaper (the kitty palette and
  the Hyprland colors).
- `kde/` The Qt/KDE platform theme (`kdeglobals`). GTK apps are themed by the
  Hyprland autostart (`gsettings color-scheme`), not a shipped file.
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

Beyond Hyprland, quickshell, `go` (to build `ryoku-shell`), and cmake + ninja +
qt6-shadertools (to build the `Ryoku.Blobs` plugin), the shell calls at
runtime: `awww` (wallpaper daemon), `wallust` (palette), `openrgb` (keyboard and
LED color), `cliphist` and `wl-clipboard`, `imagemagick` (clipboard and
wallpaper thumbnails), `hyprpicker`, `hypridle` and `brightnessctl` (laptop
idle/dim), `upower` (battery state), `wireplumber` (`wpctl`), `pipewire-pulse`
(`pactl` voice-call state), `cava` (music visualizer), `playerctl` (media keys),
`jq`, `glib2` (`gio`), `curl` (weather and LocalSend), and `python`/`openssl`/
`libnotify`/`xdg-utils` (the LocalSend file stash and opening stashed files).
The Super+D screen toolkit reuses `grim`/`slurp`, `hyprpicker`, `curl`/`jq`, and
`mpv`, and adds `tesseract` (OCR) and `zbar` (QR scan). The Super+U utilities
panel adds `gpu-screen-recorder`/`wf-recorder` (screen recording) and
`hyprsunset` (night light).
The keybinds open `kitty` (terminal) and `nautilus` (files). Fonts: JetBrains
Mono Nerd and Noto; cursor: Bibata. The lock is qylock, from `ryoku/`.

## Develop it live

Run the shell straight from this checkout on a running Hyprland session, no
install required:

    ryoku/shell/dev-run.sh       # build ryoku-shell, then run it with RYOKU_SHELL_DIR set
    ryoku/shell/dev-binds.sh on  # optional: bind the shell keys for this session
    ryoku/shell/dev-stop.sh      # stop it (restore your keys with: hyprctl reload)
    ryoku update                # pull a clean repo, deploy ~/.config, restart the shell

The daemon launches each component with `qs -p`, so your own `~/.config` is never
touched, and quickshell hot-reloads QML edits, so changes show as you save.
For live-mirror updates, `ryoku update` resolves the repo (`RYOKU_REPO`, the
current git tree, or `~/Work/ryoku-arch`), refuses uncommitted changes, runs
`git pull --ff-only`, copies `ryoku/shell`, `ryoku/hyprland`, and shell-adjacent
configs into `~/.config`, installs helpers into `~/.local/bin`, then reloads
Hyprland and restarts `ryoku-shell`.

## Install

The installer deploys this tree to `~/.config` and the prebuilt `ryoku-shell` to
`/usr/local/bin`: `installation/iso/build.sh` builds the daemon and prebuilds the
`Ryoku.Blobs` plugin into the image, and `installation/backend/lib/deploy.sh` lays
down the configs and installs the plugin onto the QML import path (`ryoku-shell`
points `QML2_IMPORT_PATH` there for the components it supervises). The lock screen
is qylock, shipped by `ryoku/lockscreen`; the shell does not replace it.
