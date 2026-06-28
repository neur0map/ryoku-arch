#!/usr/bin/env bash
# Deploy the Ryoku shell from this repo into the live config. One way: the repo
# is the source, the shell configs replace the matching ones under ~/.config,
# including the Hyprland config. Builds ryoku-shell and puts it on PATH.
#
#   deploy.sh              build + install, then apply live (hyprctl reload).
#   deploy.sh --no-reload  build + install + stage the files, but DO NOT touch
#                          the running session. The new config takes effect on
#                          the next login. Useful so a live swap can't disrupt
#                          the current session.
#
# Hyprland auto-reloads its config on change. The hypr swap below builds the new
# config in a staging dir and renames it into place (near-atomic), so hyprland.lua
# is never missing mid-swap and emergency mode can't trip; auto-reload is paused
# too as a belt. Live mode reloads once at the end; staged mode leaves the swap
# for the next login.
set -euo pipefail

reload=1
[[ "${1:-}" == "--no-reload" ]] && reload=0

here="$(cd "$(dirname "$0")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
bindir="$HOME/.local/bin"
say() { printf '  %s\n' "$*"; }

restart_shell() {
  local shell=$bindir/ryoku-shell
  local log="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-shell.log"

  [[ -x $shell ]] || return 0
  "$shell" quit >/dev/null 2>&1 || true
  for _ in {1..20}; do
    "$shell" ping >/dev/null 2>&1 || break
    sleep 0.1
  done

  # quit should stop the surfaces, but a crashed daemon orphans them and the
  # leftover qs keeps its single-instance lock, so the fresh pill cant come up and
  # the new daemon dies with it. clear any strays before i start again.
  pkill -f 'qs -c pill' >/dev/null 2>&1 || true
  pkill -f 'qs -c sidebar' >/dev/null 2>&1 || true
  pkill -f 'qs -c visualizer' >/dev/null 2>&1 || true
  sleep 0.2

  mkdir -p "$(dirname -- "$log")"
  if command -v setsid >/dev/null 2>&1; then
    setsid "$shell" daemon >"$log" 2>&1 < /dev/null &
  else
    nohup "$shell" daemon >"$log" 2>&1 < /dev/null &
  fi
  say "restarted ryoku-shell daemon -> $log"
}

hypr_live=0
if command -v hyprctl >/dev/null 2>&1; then
  # When deploy runs outside the Hyprland session (ssh, an agent, the curl
  # recovery), HYPRLAND_INSTANCE_SIGNATURE is unset and hyprctl cannot find the
  # compositor, so the autoreload pause below would be skipped and the rm+cp
  # config swap could trip the live session into emergency mode. Recover the
  # signature from the runtime dir so the pause still happens when a session is up.
  if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    for _inst in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/; do
      [ -d "$_inst" ] || continue
      _sig="$(basename "$_inst")"
      export HYPRLAND_INSTANCE_SIGNATURE="$_sig"
      break
    done
  fi
  if hyprctl version >/dev/null 2>&1; then hypr_live=1; fi
fi

# Build the daemon/client and put it on PATH.
say "building ryoku-shell"
(cd "$here/ipc" && go build -o ryoku-shell .)
mkdir -p "$bindir"
install -m755 "$here/ipc/ryoku-shell" "$bindir/ryoku-shell"
say "installed $bindir/ryoku-shell"

# Build the Ryoku Hub backend (a separate Go binary; the hub's quickshell config
# shells out to it for the keybind legend and its TOML config).
say "building ryoku-hub"
(cd "$here/../hub/backend" && go build -o ryoku-hub .)
install -m755 "$here/../hub/backend/ryoku-hub" "$bindir/ryoku-hub"
say "installed $bindir/ryoku-hub"
say "building ryoku CLI"
(cd "$here/../cli" && go build -o ryoku .)
install -m755 "$here/../cli/ryoku" "$bindir/ryoku"
install -m755 "$here/../../system/hardware/power/ryoku-hw-laptop" "$bindir/ryoku-hw-laptop"
install -m755 "$here/../../system/hardware/power/ryoku-idle" "$bindir/ryoku-idle"
install -m755 "$here/../../system/hardware/leds/ryoku-leds" "$bindir/ryoku-leds"
install -m755 "$here/../../system/hardware/audio/ryoku-mic" "$bindir/ryoku-mic"
install -m755 "$here/../../system/hardware/display/ryoku-monitor" "$bindir/ryoku-monitor"
for s in "$here/../../system/extras"/ryoku-*; do
  install -m755 "$s" "$bindir/${s##*/}"
done
install -m755 "$here/quickshell/plugins/ryoku-plugins-place" "$bindir/ryoku-plugins-place"
say "installed Ryoku CLI and hardware helpers"

# Record the checkout this deploy came from and the commit it laid down, so the
# deployed `ryoku` binary (on PATH, far from the repo) can track the update
# channel in `ryoku status`: it compares this commit (what is now running)
# against origin/main. One way, like every step: the repo is the source.
repo_root="$(cd "$here/../.." && pwd)"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku"
mkdir -p "$state_dir"
printf '%s\n' "$repo_root" > "$state_dir/repo"
git -C "$repo_root" rev-parse HEAD > "$state_dir/deployed" 2>/dev/null || rm -f "$state_dir/deployed"
say "recorded update-channel checkout -> $state_dir/repo"

# Build the Ryoku.Blobs QML plugin (the frame's blob renderer) and install the
# module onto the user's QML import path. ryoku-shell points QML2_IMPORT_PATH
# there for the quickshell processes it supervises. Needs cmake + ninja +
# qt6-shadertools (build-time only); skip cleanly when the toolchain is absent so
# a plain config deploy still succeeds (the module ships prebuilt on installs).
qmldir="$HOME/.local/lib/qt6/qml"
if command -v cmake >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1; then
  say "building Ryoku.Blobs plugin"
  "$here/plugin/build.sh" "$qmldir"
  say "installed Ryoku.Blobs -> $qmldir/Ryoku/Blobs"
else
  say "skipping Ryoku.Blobs plugin (cmake/ninja not found)"
fi

# Install the Ryoku.PluginKit QML module (the signature kit a plugin imports for
# its content) onto the same import path. Pure QML, so a plain copy, no toolchain.
say "installing Ryoku.PluginKit module"
"$here/quickshell/plugins/kit/install.sh" "$qmldir"
say "installed Ryoku.PluginKit -> $qmldir/Ryoku/PluginKit"

# Quickshell components: a deployed daemon runs `qs -c <name>`, reading
# ~/.config/quickshell/<name>.
say "installing quickshell components -> $cfg/quickshell"
rm -rf "$cfg/quickshell"
mkdir -p "$cfg/quickshell"
cp -a "$here/quickshell/." "$cfg/quickshell/"

# Ryoku Hub's quickshell config (qs -c hub), kept beside the shell's components.
mkdir -p "$cfg/quickshell/hub"
cp -a "$here/../hub/quickshell/." "$cfg/quickshell/hub/"

# Pause Hyprland's config auto-reload so the hypr swap below never exposes a
# missing hyprland.lua (which would trip emergency mode).
if (( hypr_live )); then
  hyprctl keyword misc:disable_autoreload true >/dev/null 2>&1 || true
fi

# Hyprland config replaces the base, but the user's own files and the per-machine
# generated drop-ins must survive a redeploy, exactly as `ryoku materialize`
# preserves them on a packaged install: ryoku-monitor writes monitors.lua,
# ryoku-gpu writes gpu.lua, the hub writes settings.lua, theme apply writes
# theme.lua, the user owns keyboard.lua (the keyboard layout), and may keep
# user.lua / monitors_user.lua.
preserve=(user.lua monitors_user.lua settings.lua theme.lua monitors.lua gpu.lua keyboard.lua)
# Build the new config in a staging dir on the same filesystem, then rename it
# into place. A slow rm+cp of ~/.config/hypr leaves a long window where
# hyprland.lua is missing; anything that reloads then (a manual reload or a fresh
# login both bypass the autoreload pause) trips Hyprland into emergency mode and a
# stale "cannot open hyprland.lua". A rename swap closes that window.
rm -rf "$cfg"/hypr.staging.*
staging="$cfg/hypr.staging.$$"
mkdir -p "$staging"
cp -a "$here/../hyprland/." "$staging/"
# Carry the user's own files and the per-machine generated drop-ins across, the
# way a packaged `ryoku materialize` preserves them on an update.
if [[ -d $cfg/hypr ]]; then
  for f in "${preserve[@]}"; do
    [[ -e "$cfg/hypr/$f" ]] && cp -a "$cfg/hypr/$f" "$staging/$f"
  done
fi
# cp -a carries the repo's older mtimes; bump the entry so an mtime-watching
# autoreload still registers the swapped-in config as new.
touch "$staging/hyprland.lua"
if [[ -d $cfg/hypr ]]; then
  bak="$cfg/hypr.bak-$(date +%Y%m%d%H%M%S)"
  mv "$cfg/hypr" "$bak"
  say "backed up existing hypr -> $bak"
fi
mv "$staging" "$cfg/hypr"

# Palette generation, per-app config, and the user session target.
mkdir -p "$cfg/wallust";   cp -a "$here/wallust/." "$cfg/wallust/"
cp -a "$here/../apps/fish/config.fish" "$cfg/fish/config.fish"
cp -a "$here/kde/kdeglobals" "$cfg/kdeglobals"
mkdir -p "$cfg/systemd/user"; cp -a "$here/systemd/user/." "$cfg/systemd/user/"
# Ryoku VM launcher: the wrapper on PATH plus its app-launcher entry (ryoku-hub
# does the real work). optdepends (qemu, libvirt, looking-glass) install on first
# "Enable passthrough" from Ryoku Settings > GPU, not here.
install -m755 "$here/../apps/ryoku-vm/ryoku-vm" "$bindir/ryoku-vm"
install -Dm644 "$here/../apps/ryoku-vm/ryoku-vm.desktop" \
  "${XDG_DATA_HOME:-$HOME/.local/share}/applications/ryoku-vm.desktop"
# the app-launcher icon (the brand mark) so the VM entry shows the logo, not a blank tile.
install -Dm644 "$here/../assets/brand/logo-mark.svg" \
  "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/ryoku-vm.svg"
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -qtf "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" 2>/dev/null || true
command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true

if (( hypr_live && reload )); then
  # Apply now in one clean reload (this also restores auto-reload), then restart
  # the shell daemon so a changed binary and changed QML both take effect.
  hyprctl reload >/dev/null 2>&1 || true
  restart_shell
  say "deployed and reloaded Hyprland."
else
  # Staged: leave auto-reload paused so the running session keeps its current
  # config until the next login, which loads the new one and fires the autostart.
  say "staged. log out and back in to activate (autostart launches the daemon)."
fi
