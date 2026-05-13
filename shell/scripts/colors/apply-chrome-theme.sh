#!/bin/bash
#
# apply-chrome-theme.sh - Apply Ryoku dark/light browser theme preferences.
#
# Usage:
#   apply-chrome-theme.sh
#   apply-chrome-theme.sh "#ff6b35"
#
# Chromium-based browsers show "managed by your organization" whenever enterprise
# policy files are present, so Ryoku only edits user profile preferences here.
# Browser forks with Omarchy's live color flags still get the generated accent.

set -euo pipefail

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
CHROMIUM_THEME_FILE="$STATE_DIR/user/generated/chromium.theme"
LOG_FILE="$STATE_DIR/user/generated/chrome_theme.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"

mkdir -p "$STATE_DIR/user/generated" 2>/dev/null
: > "$LOG_FILE" 2>/dev/null

log() {
  echo "[chrome] $*" >> "$LOG_FILE"
}

hex_to_rgb() {
  local hex="$1"

  hex="${hex#\#}"
  printf "%d,%d,%d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

rgb_to_hex() {
  local rgb="$1"
  local r g b

  IFS=',' read -r r g b <<<"$rgb"
  [[ $r =~ ^[0-9]+$ && $g =~ ^[0-9]+$ && $b =~ ^[0-9]+$ ]] || return 1
  (( r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255 )) || return 1
  printf '#%02X%02X%02X\n' "$r" "$g" "$b"
}

is_omarchy() {
  local bin_path

  bin_path="$(command -v "$1" 2>/dev/null || true)"
  if [[ -n $bin_path ]] && command -v pacman >/dev/null 2>&1; then
    pacman -Qo "$bin_path" 2>/dev/null | grep -qi "omarchy" && return 0
  fi

  return 1
}

resolve_color() {
  local requested="${1:-}"
  local rgb_color hex_color seed_file colors_json c

  if [[ -n $requested && $requested =~ ^#[A-Fa-f0-9]{6}$ ]]; then
    echo "$requested"
    return 0
  fi

  if [[ -f $CHROMIUM_THEME_FILE ]]; then
    rgb_color="$(tr -d '[:space:]' <"$CHROMIUM_THEME_FILE")"
    if [[ $rgb_color =~ ^[0-9]{1,3},[0-9]{1,3},[0-9]{1,3}$ ]]; then
      hex_color="$(rgb_to_hex "$rgb_color" 2>/dev/null || true)"
      if [[ -n $hex_color ]]; then
        echo "$hex_color"
        return 0
      fi
    fi
  fi

  seed_file="$STATE_DIR/user/generated/color.txt"
  if [[ -f $seed_file ]]; then
    c="$(tr -d '\n' <"$seed_file")"
    if [[ -n $c && $c =~ ^#[A-Fa-f0-9]{6}$ ]]; then
      echo "$c"
      return 0
    fi
  fi

  colors_json="$STATE_DIR/user/generated/palette.json"
  [[ -f $colors_json ]] || colors_json="$STATE_DIR/user/generated/colors.json"
  if [[ -f $colors_json ]] && command -v jq >/dev/null 2>&1; then
    c="$(jq -r '.surface_container_low // .surface // .background // .primary // empty' "$colors_json" 2>/dev/null || true)"
    if [[ -n $c ]]; then
      echo "$c"
      return 0
    fi
  fi

  return 0
}

resolve_color_scheme() {
  local meta_file="$STATE_DIR/user/generated/theme-meta.json"
  local mode scss_file val

  if [[ -f $meta_file ]] && command -v jq >/dev/null 2>&1; then
    mode="$(jq -r '.mode // empty' "$meta_file" 2>/dev/null || true)"
    if [[ $mode == "dark" || $mode == "light" ]]; then
      echo "$mode"
      return 0
    fi
  fi

  scss_file="$STATE_DIR/user/generated/material_colors.scss"
  if [[ -f $scss_file ]]; then
    val="$(grep '^\$darkmode:' "$scss_file" 2>/dev/null | sed 's/.*: *\(.*\);/\1/' | tr -d ' ' || true)"
    if [[ $val == "True" || $val == "true" ]]; then
      echo "dark"
      return 0
    fi
  fi

  echo "light"
}

BROWSERS=()

register_browser() {
  local bin_name="$1"
  local prefs_dir="$2"

  if command -v "$bin_name" >/dev/null 2>&1; then
    BROWSERS+=("$bin_name|$prefs_dir")
  fi
}

register_browser google-chrome-stable "$HOME/.config/google-chrome"
register_browser google-chrome "$HOME/.config/google-chrome"
register_browser chromium "$HOME/.config/chromium"
register_browser chromium-browser "$HOME/.config/chromium"
register_browser brave "$HOME/.config/BraveSoftware/Brave-Browser"
register_browser brave-browser "$HOME/.config/BraveSoftware/Brave-Browser"
register_browser helium "$HOME/.config/net.imput.helium"

dedup_browsers() {
  local -A seen
  local deduped=()
  local entry prefs_dir

  for entry in "${BROWSERS[@]}"; do
    prefs_dir="${entry#*|}"
    if [[ -z ${seen[$prefs_dir]:-} ]]; then
      seen[$prefs_dir]=1
      deduped+=("$entry")
    fi
  done

  BROWSERS=("${deduped[@]}")
}

fix_preferences() {
  local prefs_dir="$1"
  local name="$2"
  local color_scheme="$3"
  local prefs_file="$prefs_dir/Default/Preferences"
  local tmp_file="${prefs_file}.ryoku-tmp"

  command -v jq >/dev/null 2>&1 || {
    log "$name: jq missing; skipping browser preferences"
    return 0
  }

  if [[ ! -f $prefs_file ]]; then
    mkdir -p "$prefs_dir/Default" 2>/dev/null
    echo '{}' >"$prefs_file"
    log "$name: created Preferences file"
  fi

  if jq --argjson color_scheme "$color_scheme" '
    .extensions.theme.id = "" |
    .extensions.theme.use_system = false |
    .extensions.theme.use_custom = false |
    .browser.theme.color_scheme = $color_scheme |
    .browser.theme.color_scheme2 = $color_scheme
  ' "$prefs_file" >"$tmp_file" 2>/dev/null && [[ -s $tmp_file ]]; then
    mv "$tmp_file" "$prefs_file"
    log "$name: preferences set (color_scheme=$color_scheme)"
  else
    rm -f "$tmp_file"
    log "$name: failed to update preferences"
  fi
}

resolve_variant() {
  local config_file
  local variant
  local chrome_variant

  config_file="$(ryoku_shell_config_file)"
  if [[ -f $config_file ]] && command -v jq >/dev/null 2>&1; then
    variant="$(jq -r '.appearance.palette.type // "auto"' "$config_file" 2>/dev/null || true)"
    if [[ -n $variant && $variant != "null" && $variant != "auto" ]]; then
      chrome_variant="$(echo "$variant" | sed 's/scheme-//' | tr '-' '_')"
      case $chrome_variant in
      tonal_spot | neutral | vibrant | expressive)
        echo "$chrome_variant"
        ;;
      *)
        echo "neutral"
        ;;
      esac
      return 0
    fi
  fi

  echo "tonal_spot"
}

apply_to_browser() {
  local bin_name="$1"
  local prefs_dir="$2"
  local theme_color="$3"
  local mode="$4"
  local variant="$5"
  local color_scheme=1
  local rgb_color

  if [[ $mode == "dark" ]]; then
    color_scheme=2
  fi

  fix_preferences "$prefs_dir" "$bin_name" "$color_scheme"

  if is_omarchy "$bin_name"; then
    rgb_color="$(hex_to_rgb "$theme_color")"
    "$bin_name" --no-startup-window \
      --set-user-color="$rgb_color" \
      --set-color-scheme="$mode" \
      --set-color-variant="$variant" >/dev/null 2>&1 & disown
    log "$bin_name: applied live accent $theme_color (mode=$mode, variant=$variant)"
  else
    log "$bin_name: applied profile mode only; restart may be required"
  fi
}

main() {
  local theme_color
  local mode
  local variant
  local entry bin_name prefs_dir

  theme_color="$(resolve_color "${1:-}")"
  if [[ -z $theme_color ]]; then
    log "Could not determine browser theme color. Skipping."
    return 1
  fi

  mode="$(resolve_color_scheme)"
  variant="$(resolve_variant)"

  log "Browser theme input: color=$theme_color, mode=$mode, variant=$variant"

  dedup_browsers
  if (( ${#BROWSERS[@]} == 0 )); then
    log "No Chromium-based browsers found. Skipping."
    return 0
  fi

  for entry in "${BROWSERS[@]}"; do
    IFS='|' read -r bin_name prefs_dir <<<"$entry"
    apply_to_browser "$bin_name" "$prefs_dir" "$theme_color" "$mode" "$variant"
  done
}

main "$@"
