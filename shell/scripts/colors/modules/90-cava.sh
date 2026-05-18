#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/module-runtime.sh"
COLOR_MODULE_ID="cava"

PALETTE_FILE="$STATE_DIR/user/generated/palette.json"
CAVA_CONFIG_DIR="$XDG_CONFIG_HOME/cava"
CAVA_CONFIG="$CAVA_CONFIG_DIR/config"
CAVA_COLOR_BACKUP="$STATE_DIR/user/generated/cava-color-section.bak"

MARKER_BEGIN="# BEGIN ryoku-generated-colors"
MARKER_END="# END ryoku-generated-colors"
LEGACY_MARKER_BEGIN="# BEGIN i""nir-generated-colors"
LEGACY_MARKER_END="# END i""nir-generated-colors"

palette_color() {
  local key="$1"

  command -v jq >/dev/null 2>&1 || return 0
  jq -r ".$key // empty" "$PALETTE_FILE" 2>/dev/null || true
}

build_gradient() {
  local -a colors=()
  local c
  local key

  for key in primary_container secondary_container primary tertiary secondary tertiary_container primary_fixed_dim tertiary_fixed_dim; do
    c="$(palette_color "$key")"
    [[ -n $c ]] && colors+=("$c")
    (( ${#colors[@]} >= 8 )) && break
  done

  if (( ${#colors[@]} < 2 )); then
    log_module "Not enough palette colors for gradient (got ${#colors[@]})"
    return 1
  fi

  printf '%s\n' "${colors[@]}"
}

generate_color_section() {
  local -a gradient=()
  local c
  local bg
  local i

  while IFS= read -r c; do
    gradient+=("$c")
  done < <(build_gradient)

  (( ${#gradient[@]} >= 2 )) || return 1

  bg="$(palette_color "background")"
  [[ -n $bg ]] || bg="$(palette_color "surface")"

  printf '%s\n' "$MARKER_BEGIN"
  printf '[color]\n'
  [[ -n ${bg:-} ]] && printf "background = '%s'\n" "$bg"
  printf 'gradient = 1\n'

  i=1
  for c in "${gradient[@]}"; do
    printf "gradient_color_%d = '%s'\n" "$i" "$c"
    (( i++ ))
  done

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

  log_module "Applied theme colors to cava config"
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
