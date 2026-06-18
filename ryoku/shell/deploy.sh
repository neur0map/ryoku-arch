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
# Hyprland auto-reloads its config on change, so a naive rm+cp of ~/.config/hypr
# briefly leaves hyprland.lua missing and trips emergency mode. We pause
# auto-reload for the swap; live mode issues one clean reload at the end, staged
# mode leaves auto-reload paused so the swap never reaches the running session.
set -euo pipefail

reload=1
[[ "${1:-}" == "--no-reload" ]] && reload=0

here="$(cd "$(dirname "$0")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
bindir="$HOME/.local/bin"
say() { printf '  %s\n' "$*"; }

hypr_live=0
if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
  hypr_live=1
fi

# Build the daemon/client and put it on PATH.
say "building ryoku-shell"
(cd "$here/ipc" && go build -o ryoku-shell .)
mkdir -p "$bindir"
install -m755 "$here/ipc/ryoku-shell" "$bindir/ryoku-shell"
say "installed $bindir/ryoku-shell"
install -m755 "$here/../../system/hardware/power/ryoku-hw-laptop" "$bindir/ryoku-hw-laptop"
install -m755 "$here/../../system/hardware/power/ryoku-idle" "$bindir/ryoku-idle"
say "installed laptop idle helpers"

# Quickshell components: a deployed daemon runs `qs -c <name>`, reading
# ~/.config/quickshell/<name>.
say "installing quickshell components -> $cfg/quickshell"
rm -rf "$cfg/quickshell"
mkdir -p "$cfg/quickshell"
cp -a "$here/quickshell/." "$cfg/quickshell/"

# Pause Hyprland's config auto-reload so the hypr swap below never exposes a
# missing hyprland.lua (which would trip emergency mode).
if (( hypr_live )); then
  hyprctl keyword misc:disable_autoreload true >/dev/null 2>&1 || true
fi

# Hyprland config replaces the base. Back up an existing one first.
if [[ -d $cfg/hypr ]]; then
  bak="$cfg/hypr.bak-$(date +%Y%m%d%H%M%S)"
  cp -a "$cfg/hypr" "$bak"
  say "backed up existing hypr -> $bak"
fi
rm -rf "$cfg/hypr"
mkdir -p "$cfg/hypr"
cp -a "$here/../hyprland/." "$cfg/hypr/"

# Palette generation, per-app config, and the user session target.
mkdir -p "$cfg/wallust";   cp -a "$here/wallust/." "$cfg/wallust/"
cp -a "$here/../apps/fish/config.fish" "$cfg/fish/config.fish"
cp -a "$here/kde/kdeglobals" "$cfg/kdeglobals"
mkdir -p "$cfg/systemd/user"; cp -a "$here/systemd/user/." "$cfg/systemd/user/"
command -v systemctl >/dev/null 2>&1 && systemctl --user daemon-reload 2>/dev/null || true

if (( hypr_live && reload )); then
  # Apply now in one clean reload (this also restores auto-reload).
  hyprctl reload >/dev/null 2>&1 || true
  say "deployed and reloaded Hyprland."
else
  # Staged: leave auto-reload paused so the running session keeps its current
  # config until the next login, which loads the new one and fires the autostart.
  say "staged. log out and back in to activate (autostart launches the daemon)."
fi
