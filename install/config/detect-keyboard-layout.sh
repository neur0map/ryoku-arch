#!/bin/bash

# Copy the keyboard layout selected during install into the user-owned keyboard.conf.
set -euo pipefail

conf="/etc/vconsole.conf"
hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
# Hyprland loads hyprland.lua over hyprland.conf when present; match the layout file.
if [[ -f $hypr_dir/keyboard.lua ]]; then kbd_conf="$hypr_dir/keyboard.lua"; else kbd_conf="$hypr_dir/keyboard.conf"; fi

[[ -f $kbd_conf ]] || exit 0

set_hypr_input() {
  local key="$1"
  local value="$2"

  if [[ $kbd_conf == *.lua ]]; then
    # hl.config({ input = { kb_layout = "us", ... } })
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$kbd_conf"; then
      sed -i -E "s|^([[:space:]]*)${key}[[:space:]]*=.*|\1${key} = \"${value}\",|" "$kbd_conf"
    elif grep -qE '^[[:space:]]*input[[:space:]]*=[[:space:]]*\{' "$kbd_conf"; then
      sed -i "/^[[:space:]]*input[[:space:]]*=[[:space:]]*{/a\\        ${key} = \"${value}\"," "$kbd_conf"
    fi
  else
    if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$kbd_conf"; then
      sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|    ${key} = ${value}|" "$kbd_conf"
    elif grep -q '^[[:space:]]*input[[:space:]]*{' "$kbd_conf"; then
      sed -i "/^[[:space:]]*input[[:space:]]*{/a\\    ${key} = ${value}" "$kbd_conf"
    fi
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
