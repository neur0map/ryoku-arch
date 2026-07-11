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
  pkill -f 'qs -c launcher' >/dev/null 2>&1 || true
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
# Build the Ryoku Rashin backend (the optional agent OS daemon; a separate Go
# binary that serves the dashboard and bridges the Hermes agent over ACP).
say "building ryoku-rashin"
(cd "$here/../rashin/backend" && go build -o ryoku-rashin .)
install -m755 "$here/../rashin/backend/ryoku-rashin" "$bindir/ryoku-rashin"
# `rashin` is the terminal-lane command: the same binary under a second name
# (busybox pattern), argv0 routes a bare argument to the terminal ask.
ln -sf ryoku-rashin "$bindir/rashin"
say "installed $bindir/ryoku-rashin (and the rashin command)"
# Pre-index the checkout for the Rashin vault: dev-machine equivalent of the
# snapshot the package ships to /usr/share/ryoku/rashin.
"$bindir/ryoku-rashin" repo-index "$here/../.." \
  "${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/rashin-repo.md"
say "indexed ryoku repo for rashin"
# Rashin's systemd user unit: the dev deploy points ExecStart at ~/.local/bin
# (the package ships /usr/bin); reload so systemctl sees the fresh unit.
mkdir -p "$cfg/systemd/user"
sed "s|^ExecStart=.*|ExecStart=$bindir/ryoku-rashin serve --if-enabled|" \
  "$here/../rashin/systemd/ryoku-rashin.service" > "$cfg/systemd/user/ryoku-rashin.service"
systemctl --user daemon-reload 2>/dev/null || true
say "installed rashin systemd user unit"
say "building ryoku CLI"
(cd "$here/../cli" && go build -o ryoku .)
install -m755 "$here/../cli/ryoku" "$bindir/ryoku"
install -m755 "$here/../../system/hardware/power/ryoku-hw-laptop" "$bindir/ryoku-hw-laptop"
install -m755 "$here/../../system/hardware/power/ryoku-idle" "$bindir/ryoku-idle"
install -m755 "$here/../../system/hardware/leds/ryoku-leds" "$bindir/ryoku-leds"
install -m755 "$here/../../system/hardware/audio/ryoku-mic" "$bindir/ryoku-mic"
install -m755 "$here/../../system/hardware/display/ryoku-monitor" "$bindir/ryoku-monitor"
install -m755 "$here/../../system/hardware/gpu/ryoku-gpu" "$bindir/ryoku-gpu"
install -m755 "$here/../../system/hardware/gpu/ryoku-gpu-detect" "$bindir/ryoku-gpu-detect"
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

# First-party GUI apps: each ryoku/apps/<name>/quickshell ships as qs -c <name>,
# launched from a keybind and a .desktop entry. Drop in a new app dir and it ships.
appshare="${XDG_DATA_HOME:-$HOME/.local/share}"
for appdir in "$here"/../apps/*/; do
  [[ -d "${appdir}quickshell" ]] || continue
  appname="$(basename "$appdir")"
  mkdir -p "$cfg/quickshell/$appname"
  cp -a "${appdir}quickshell/." "$cfg/quickshell/$appname/"
  for b in "${appdir}bin/"*; do [[ -f "$b" ]] && install -m755 "$b" "$bindir/$(basename "$b")"; done
  # an app may carry Go helper(s): a subdir with a go.mod builds to a bin named
  # for the module (ryovm/fetch -> ryovm-fetch). keeps "drop in an app dir" true.
  for gomod in "${appdir}"*/go.mod; do
    [[ -f "$gomod" ]] || continue
    helperdir="$(dirname "$gomod")"
    helper="$(sed -n -E 's/^module[[:space:]]+//p' "$gomod" | head -1)"
    [[ -n "$helper" ]] || continue
    say "building $helper"
    (cd "$helperdir" && go build -o "$helper" .) && install -m755 "$helperdir/$helper" "$bindir/$helper"
  done
  for d in "${appdir}"*.desktop; do [[ -f "$d" ]] && install -Dm644 "$d" "$appshare/applications/$(basename "$d")"; done
  icon="${appdir}quickshell/logo.svg"; [[ -f "$icon" ]] || icon="$here/../assets/brand/logo-mark.svg"
  install -Dm644 "$icon" "$appshare/icons/hicolor/scalable/apps/$appname.svg"
  say "installed app $appname -> $cfg/quickshell/$appname"
done

# Nautilus stash actions (a nautilus-python extension). Installs ship it system-wide
# from the ryoku-desktop package; the dev loop drops it in the user extensions dir.
install -Dm644 "$here/../apps/nautilus/ryoku-stash-menu.py" \
  "$appshare/nautilus-python/extensions/ryoku-stash-menu.py"
say "installed nautilus stash menu -> $appshare/nautilus-python/extensions"

# Pause Hyprland's config auto-reload so the hypr swap below never exposes a
# missing hyprland.lua (which would trip emergency mode).
if (( hypr_live )); then
  hyprctl keyword misc:disable_autoreload true >/dev/null 2>&1 || true
fi

# Hyprland config replaces the base, but the user's own files and the per-machine
# generated drop-ins must survive a redeploy, exactly the way a packaged
# `ryoku materialize` preserves every unshipped file (docs/updates.md). Two
# classes survive: (1) anything the repo tree does NOT ship (monitors_user.lua,
# settings.lua, theme.lua, and anything else the user dropped
# in) is user-owned and carried across untouched; (2) the seed drop-ins the repo
# ships a default for but the machine owns after first boot (ryoku-monitor writes
# monitors.lua, ryoku-gpu writes gpu.lua, the user owns keyboard.lua and user.lua) keep their
# live copy over the shipped default. Shipped files (modules/*, scripts/*, ...)
# stay Ryoku-owned: the repo copy wins, matching materialize clobbering them.
seeds=(monitors.lua gpu.lua keyboard.lua user.lua)
# Build the new config in a staging dir on the same filesystem, then rename it
# into place. A slow rm+cp of ~/.config/hypr leaves a long window where
# hyprland.lua is missing; anything that reloads then (a manual reload or a fresh
# login both bypass the autoreload pause) trips Hyprland into emergency mode and a
# stale "cannot open hyprland.lua". A rename swap closes that window.
rm -rf "$cfg"/hypr.staging.*
staging="$cfg/hypr.staging.$$"
mkdir -p "$staging"
cp -a "$here/../hyprland/." "$staging/"
# Carry the user's own files and the per-machine seeds across, mirroring
# materialize: any file the freshly-staged repo tree does not contain is
# user-owned and kept; the seeds keep their live copy over the shipped default.
if [[ -d $cfg/hypr ]]; then
  while IFS= read -r -d '' f; do
    rel=${f#"$cfg/hypr/"}
    [[ -e "$staging/$rel" ]] && continue   # shipped -> Ryoku-owned, repo copy wins
    mkdir -p "$staging/$(dirname "$rel")"
    cp -a "$f" "$staging/$rel"
  done < <(find "$cfg/hypr" -type f -print0)
  for f in "${seeds[@]}"; do
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
mkdir -p "$cfg/fish/conf.d"; cp -a "$here/../apps/fish/conf.d/." "$cfg/fish/conf.d/"
mkdir -p "$cfg/qt6ct"; cp -a "$here/qt6ct/qt6ct.conf" "$cfg/qt6ct/qt6ct.conf"
mkdir -p "$cfg/pipewire"; cp -a "$here/../apps/pipewire/." "$cfg/pipewire/"
mkdir -p "$cfg/systemd/user"; cp -a "$here/systemd/user/." "$cfg/systemd/user/"
# pip (PEP 668 --user) + the default-app map: Ryoku-owned, so a dev box tracks
# them the way the package materializes them for an installed one.
mkdir -p "$cfg/pip"; cp -a "$here/../apps/pip/pip.conf" "$cfg/pip/pip.conf"
cp -a "$here/../apps/mimeapps.list" "$cfg/mimeapps.list"
# Refresh the icon cache only when the theme has an index.theme; the user-overlay
# hicolor dir usually has none, and gtk-update-icon-cache -f on an index-less dir
# writes an EMPTY cache that Qt then trusts, hiding every icon in it. With no
# cache, Qt/GTK scan the dir directly (correct), so drop any stale one instead.
_iconroot="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
if [[ -f "$_iconroot/index.theme" ]] && command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -qtf "$_iconroot" 2>/dev/null || true
else
  rm -f "$_iconroot/icon-theme.cache" 2>/dev/null || true
fi
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
