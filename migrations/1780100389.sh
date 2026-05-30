#!/usr/bin/env bash
# Migration 0008: add the Super+G gaming-overlay keybind to existing Hyprland configs.
#
# Existing installs have a user-owned ~/.config/hypr/hyprland.conf that predates
# the gaming overlay. Newly shipped defaults include:
#   $gameBar = sh -lc '$HOME/.local/bin/ryoku-shell ipc gaming toggle'
#   bind = SUPER, G, exec, $gameBar
# This migration injects both lines if they are missing, matching the layout
# the default config ships with.
#
# It is idempotent: running it twice makes no further changes.

set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

if [[ ! -f "$CONF" ]]; then
  echo "0008: no hyprland.conf at $CONF; nothing to do."
  exit 0
fi

# --- variable line -------------------------------------------------------
if ! grep -q '^\$gameBar = ' "$CONF"; then
  # Insert after the $clipboard variable if present, matching the default
  # config layout. We anchor on $clipboard because the default ships it.
  if grep -q "^\$clipboard = " "$CONF"; then
    awk '
      { print }
      /^\$clipboard = / && !done {
        print "$gameBar = sh -lc '\''$HOME/.local/bin/ryoku-shell ipc gaming toggle'\''"
        done = 1
      }
    ' "$CONF" > "${CONF}.tmp" && mv "${CONF}.tmp" "$CONF"
  fi
fi

# --- bind line -----------------------------------------------------------
if ! grep -q '^bind = SUPER, G, exec, \$gameBar$' "$CONF"; then
  if grep -q '^bind = SUPER, V, exec, \$clipboard$' "$CONF"; then
    awk '
      { print }
      /^bind = SUPER, V, exec, \$clipboard$/ && !done {
        print "bind = SUPER, G, exec, $gameBar"
        done = 1
      }
    ' "$CONF" > "${CONF}.tmp" && mv "${CONF}.tmp" "$CONF"
  fi
fi

# --- append-if-anchor-missing fallback -----------------------------------
# Heavily customised configs may lack the $clipboard var / SUPER, V bind that
# the anchored inserts above key off. In that case the lines never landed, so
# append them here. The grep -qF guards keep this idempotent across re-runs.
if ! grep -qF '$gameBar = sh -lc '\''$HOME/.local/bin/ryoku-shell ipc gaming toggle'\''' "$CONF"; then
  printf '%s\n' '$gameBar = sh -lc '\''$HOME/.local/bin/ryoku-shell ipc gaming toggle'\''' >> "$CONF"
fi

if ! grep -qF 'bind = SUPER, G, exec, $gameBar' "$CONF"; then
  printf '%s\n' 'bind = SUPER, G, exec, $gameBar' >> "$CONF"
fi

echo "0008: gaming keybind ensured."
