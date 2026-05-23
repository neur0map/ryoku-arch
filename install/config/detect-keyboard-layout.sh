#!/bin/bash

# Copy the keyboard layout selected during install into the Hyprland config.
set -euo pipefail

conf="/etc/vconsole.conf"
hypr_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

[[ -f $hypr_conf ]] || exit 0

set_hypr_input() {
  local key="$1"
  local value="$2"

  if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$hypr_conf"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|  ${key} = ${value}|" "$hypr_conf"
  elif grep -q '^[[:space:]]*input[[:space:]]*{' "$hypr_conf"; then
    sed -i "/^[[:space:]]*input[[:space:]]*{/a\\  ${key} = ${value}" "$hypr_conf"
  fi
}

if grep -q '^XKBLAYOUT=' "$conf"; then
  layout=$(grep '^XKBLAYOUT=' "$conf" | cut -d= -f2 | tr -d '"')
  [[ -n $layout ]] && set_hypr_input kb_layout "$layout"
fi

if grep -q '^XKBVARIANT=' "$conf"; then
  variant=$(grep '^XKBVARIANT=' "$conf" | cut -d= -f2 | tr -d '"')
  [[ -n $variant ]] && set_hypr_input kb_variant "$variant"
fi
