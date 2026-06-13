echo "Repair Hyprland screen sharing (Discord/OBS/Meet). Ship a clean xdph.conf and drop a"
echo "stale custom share-picker pin left behind when hyprland-preview-share-picker was"
echo "removed, which made the portal launch a missing picker and broke screen-share source"
echo "selection. Also enable Wayland PipeWire capture for Electron apps on the next login."

# shellcheck disable=SC1091
source "$RYOKU_PATH/lib/hypr-config.sh"

xdph_conf="$HOME/.config/hypr/xdph.conf"

# 1) Drop a dangling custom_picker_binary that points at the now-removed preview picker,
#    so the portal falls back to the installed default (hyprland-share-picker).
if [[ -f $xdph_conf ]] \
  && grep -q 'custom_picker_binary' "$xdph_conf" \
  && ! command -v hyprland-preview-share-picker >/dev/null 2>&1; then
  sed -i '/custom_picker_binary[[:space:]]*=[[:space:]]*hyprland-preview-share-picker/d' "$xdph_conf"
  echo "  removed stale custom_picker_binary pin from xdph.conf"
fi

# 2) Ship the default xdph.conf (allow_token_by_default) when the user has none.
if [[ ! -f $xdph_conf ]] && command -v ryoku-refresh-config >/dev/null 2>&1; then
  ryoku-refresh-config hypr/xdph.conf
fi

# 3) Enable Wayland PipeWire capture for Electron apps (screen sharing) on next login.
hypr_entry="$(hypr_entrypoint)"
if [[ -f $hypr_entry ]]; then
  hypr_set_env "$hypr_entry" ELECTRON_OZONE_PLATFORM_HINT auto
fi

# 4) Restart the portal so the xdph.conf change applies without a full re-login.
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal.service >/dev/null 2>&1 || true
fi
