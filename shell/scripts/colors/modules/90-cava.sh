#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="cava"

PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
COVER_COLORS_FILE="$STATE_DIR/user/generated/cover-colors.json"
COVER_COLOR_SCRIPT="$SCRIPT_DIR/../cava/extract_cover_colors.py"
CAVA_CONFIG_DIR="$XDG_CONFIG_HOME/cava"
CAVA_CONFIG="$CAVA_CONFIG_DIR/config"
CAVA_COLOR_BACKUP="$STATE_DIR/user/generated/cava-color-section.bak"

MARKER_BEGIN="# BEGIN ryoku-generated-colors"
MARKER_END="# END ryoku-generated-colors"
LEGACY_MARKER_BEGIN="# BEGIN i""nir-generated-colors"
LEGACY_MARKER_END="# END i""nir-generated-colors"

cava_cfg() {
  local key="$1"
  local fallback="$2"

  config_json ".appearance.cava.${key} // \"${fallback}\"" "$fallback"
}

palette_color() {
  local key="$1"

  command -v jq >/dev/null 2>&1 || return 0
  jq -r ".$key // empty" "$PALETTE_FILE" 2>/dev/null || true
}

cover_color() {
  local idx="$1"

  [[ -f $COVER_COLORS_FILE ]] || return 1
  jq -r ".[$idx] // empty" "$COVER_COLORS_FILE" 2>/dev/null || true
}

saturate_hex() {
  local hex="$1"
  local factor="${2:-1.4}"

  [[ $hex =~ ^#[0-9A-Fa-f]{6}$ ]] || {
    printf '%s\n' "$hex"
    return 0
  }

  python3 -c "
import colorsys
h = '${hex}'.lstrip('#')
r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
sat = min(1.0, sat * ${factor})
val = min(1.0, val * 1.1)
r2, g2, b2 = colorsys.hsv_to_rgb(hue, sat, val)
print('#%02x%02x%02x' % (int(r2 * 255), int(g2 * 255), int(b2 * 255)))
" 2>/dev/null || printf '%s\n' "$hex"
}

maybe_extract_cover_colors() {
  local count="$1"
  local cover_path
  local python_bin

  cover_path="${CAVA_COVER_IMAGE:-}"
  [[ -n $cover_path ]] || cover_path="$(cava_cfg coverPath "")"
  [[ -n $cover_path ]] || return 0

  if [[ $cover_path == file://* ]]; then
    cover_path="${cover_path#file://}"
  fi

  [[ -f $cover_path ]] || return 0
  [[ -f $COVER_COLOR_SCRIPT ]] || return 0

  python_bin="$(venv_python)"
  if ! "$python_bin" "$COVER_COLOR_SCRIPT" "$cover_path" "$count" "$COVER_COLORS_FILE" >/dev/null 2>&1; then
    log_module "Failed to extract cover colors from $cover_path"
  fi
}

build_gradient_theme() {
  local count="$1"
  local -a colors=()
  local c
  local key

  for key in primary_container secondary_container primary tertiary secondary tertiary_container primary_fixed_dim tertiary_fixed_dim; do
    c="$(palette_color "$key")"
    [[ -n $c ]] && colors+=("$c")
    (( ${#colors[@]} >= count )) && break
  done

  if (( ${#colors[@]} < 2 )); then
    log_module "Not enough palette colors for gradient (got ${#colors[@]})"
    return 1
  fi

  printf '%s\n' "${colors[@]}"
}

build_gradient_vibrant() {
  local count="$1"
  local -a colors=()
  local c
  local key

  for key in primary tertiary secondary error primary_fixed tertiary_fixed primary_container secondary_container; do
    c="$(palette_color "$key")"
    if [[ -n $c ]]; then
      colors+=("$(saturate_hex "$c" 1.6)")
    fi
    (( ${#colors[@]} >= count )) && break
  done

  if (( ${#colors[@]} < 2 )); then
    log_module "Not enough palette colors for vibrant gradient (got ${#colors[@]})"
    return 1
  fi

  printf '%s\n' "${colors[@]}"
}

build_gradient_cover() {
  local count="$1"
  local -a colors=()
  local c
  local i

  maybe_extract_cover_colors "$count"

  if [[ ! -f $COVER_COLORS_FILE ]]; then
    log_module "No cover colors file, falling back to theme colors"
    build_gradient_theme "$count"
    return
  fi

  for (( i = 0; i < count; i++ )); do
    c="$(cover_color "$i")"
    [[ -n $c ]] && colors+=("$c")
  done

  if (( ${#colors[@]} < 2 )); then
    log_module "Not enough cover colors (${#colors[@]}), falling back to theme colors"
    build_gradient_theme "$count"
    return
  fi

  printf '%s\n' "${colors[@]}"
}

generate_color_section() {
  local -a gradient=()
  local color_source
  local gradient_count
  local fg_override
  local bg_override
  local sensitivity
  local bars
  local framerate
  local bar_width
  local bar_spacing
  local stereo
  local channels="stereo"
  local c
  local bg
  local i

  color_source="$(cava_cfg colorSource "theme")"
  gradient_count="$(cava_cfg gradientCount "8")"
  fg_override="$(cava_cfg foreground "")"
  bg_override="$(cava_cfg background "")"
  sensitivity="$(cava_cfg sensitivity "100")"
  bars="$(cava_cfg bars "0")"
  framerate="$(cava_cfg framerate "60")"
  bar_width="$(cava_cfg barWidth "2")"
  bar_spacing="$(cava_cfg barSpacing "1")"
  stereo="$(cava_cfg stereo "true")"

  [[ $gradient_count =~ ^[0-9]+$ ]] || gradient_count=8
  [[ $sensitivity =~ ^[0-9]+$ ]] || sensitivity=100
  [[ $bars =~ ^[0-9]+$ ]] || bars=0
  [[ $framerate =~ ^[0-9]+$ ]] || framerate=60
  [[ $bar_width =~ ^[0-9]+$ ]] || bar_width=2
  [[ $bar_spacing =~ ^[0-9]+$ ]] || bar_spacing=1

  (( gradient_count < 2 )) && gradient_count=2
  (( gradient_count > 8 )) && gradient_count=8

  case "$color_source" in
    vibrant)
      while IFS= read -r c; do
        gradient+=("$c")
      done < <(build_gradient_vibrant "$gradient_count")
      ;;
    cover)
      while IFS= read -r c; do
        gradient+=("$c")
      done < <(build_gradient_cover "$gradient_count")
      ;;
    *)
      while IFS= read -r c; do
        gradient+=("$c")
      done < <(build_gradient_theme "$gradient_count")
      ;;
  esac

  (( ${#gradient[@]} >= 2 )) || return 1

  bg="$bg_override"
  if [[ -z $bg ]]; then
    bg="$(palette_color "background")"
    [[ -n $bg ]] || bg="$(palette_color "surface")"
  fi

  [[ $stereo == "false" ]] && channels="mono"

  printf '%s\n' "$MARKER_BEGIN"
  printf '[general]\n'
  printf 'framerate = %d\n' "$framerate"
  printf 'sensitivity = %d\n' "$sensitivity"
  (( bars > 0 )) && printf 'bars = %d\n' "$bars"
  printf 'bar_width = %d\n' "$bar_width"
  printf 'bar_spacing = %d\n' "$bar_spacing"
  printf '\n'
  printf '[output]\n'
  printf 'channels = %s\n' "$channels"
  printf '\n'
  printf '[color]\n'
  [[ -n ${bg:-} ]] && printf "background = '%s'\n" "$bg"

  if [[ -n $fg_override ]]; then
    printf "foreground = '%s'\n" "$fg_override"
  else
    printf 'gradient = 1\n'
    i=1
    for c in "${gradient[@]}"; do
      printf "gradient_color_%d = '%s'\n" "$i" "$c"
      (( i++ ))
    done
  fi

  printf '%s\n' "$MARKER_END"
}

replace_marked_block() {
  local color_block="$1"
  local begin="${2:-$MARKER_BEGIN}"
  local end="${3:-$MARKER_END}"
  local tmp

  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" -v block="$color_block" '
    $0 == begin { skip=1; next }
    skip && $0 == end { skip=0; print block; next }
    !skip { print }
  ' "$CAVA_CONFIG" > "$tmp"
  mv "$tmp" "$CAVA_CONFIG"
}

replace_color_section() {
  local color_block="$1"
  local tmp

  mkdir -p "$(dirname "$CAVA_COLOR_BACKUP")"
  rm -f "$CAVA_COLOR_BACKUP"
  tmp="$(mktemp)"
  awk -v block="$color_block" -v backup="$CAVA_COLOR_BACKUP" '
    /^\[color\]/ { in_color=1; print $0 > backup; print block; next }
    in_color && /^\[/ { in_color=0 }
    in_color { print $0 > backup; next }
    !in_color { print }
  ' "$CAVA_CONFIG" > "$tmp"
  mv "$tmp" "$CAVA_CONFIG"
}

apply_cava_colors() {
  [[ -f $PALETTE_FILE ]] || { log_module "palette.json not found, skipping"; return 0; }
  command -v jq >/dev/null 2>&1 || { log_module "jq not installed, skipping"; return 0; }
  command -v cava >/dev/null 2>&1 || { log_module "cava not installed, skipping"; return 0; }

  local color_block
  color_block="$(generate_color_section)" || { log_module "Failed to generate colors"; return 0; }

  mkdir -p "$CAVA_CONFIG_DIR"

  if [[ ! -f $CAVA_CONFIG ]]; then
    printf '%s\n' "$color_block" > "$CAVA_CONFIG"
    log_module "Created cava config with theme colors"
    return 0
  fi

  if grep -qF "$MARKER_BEGIN" "$CAVA_CONFIG"; then
    replace_marked_block "$color_block"
  elif grep -qF "$LEGACY_MARKER_BEGIN" "$CAVA_CONFIG"; then
    replace_marked_block "$color_block" "$LEGACY_MARKER_BEGIN" "$LEGACY_MARKER_END"
  elif grep -q '^\[color\]' "$CAVA_CONFIG"; then
    replace_color_section "$color_block"
  else
    printf '\n%s\n' "$color_block" >> "$CAVA_CONFIG"
  fi

  log_module "Applied theme colors to cava config (source=$(cava_cfg colorSource "theme"))"
}

strip_cava_colors() {
  [[ -f $CAVA_CONFIG ]] || return 0
  if grep -qF "$MARKER_BEGIN" "$CAVA_CONFIG"; then
    if [[ -s $CAVA_COLOR_BACKUP ]]; then
      replace_marked_block "$(cat "$CAVA_COLOR_BACKUP")"
      rm -f "$CAVA_COLOR_BACKUP"
      log_module "Restored original cava color section"
    else
      strip_marked_block "$MARKER_BEGIN" "$MARKER_END"
      log_module "Stripped Ryoku colors from cava config"
    fi
  fi

  if grep -qF "$LEGACY_MARKER_BEGIN" "$CAVA_CONFIG"; then
    strip_marked_block "$LEGACY_MARKER_BEGIN" "$LEGACY_MARKER_END"
    log_module "Stripped legacy colors from cava config"
  fi
}

strip_marked_block() {
  local begin="$1"
  local end="$2"
  local tmp

  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip=1; next }
    skip && $0 == end { skip=0; next }
    !skip { print }
  ' "$CAVA_CONFIG" > "$tmp"
  mv "$tmp" "$CAVA_CONFIG"
}

main() {
  local enabled

  enabled="$(config_bool '.appearance.wallpaperTheming.enableCava' false)"
  if [[ $enabled == "true" ]]; then
    apply_cava_colors
  else
    strip_cava_colors
  fi
}

main "$@"
