#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-${RYOKU_INIR_PATH:-$HOME/.local/share/inir}}"
REPLACEMENTS_FILE="$RYOKU_PATH/default/ryoku-shell/branding-replacements.tsv"
CONFIG_OVERRIDES_FILE="$RYOKU_PATH/default/ryoku-shell/config-overrides.json"

log() {
  printf 'Ryoku shell branding: %s\n' "$1"
}

install_asset() {
  local source="$1"
  local target="$2"

  [[ -f $source ]] || return 0
  mkdir -p "$(dirname "$target")"
  install -m 0644 "$source" "$target"
}

apply_replacements_to_file() {
  local relative="$1"
  local file="$2"
  local target search replace

  [[ -f $file ]] || return 0
  [[ -f $REPLACEMENTS_FILE ]] || return 0

  while IFS=$'\t' read -r target search replace || [[ -n $target ]]; do
    [[ -n $target ]] || continue
    [[ ${target:0:1} == "#" ]] && continue
    [[ $target == "$relative" ]] || continue

    SEARCH="$search" REPLACE="$replace" perl -0pi -e 's/\Q$ENV{SEARCH}\E/$ENV{REPLACE}/g' "$file"
  done <"$REPLACEMENTS_FILE"
}

apply_replacements_to_root_file() {
  local relative="$1"
  local file="$2"
  local mode temp_file

  [[ -f $file ]] || return 0

  if [[ -w $file ]]; then
    apply_replacements_to_file "$relative" "$file"
    return 0
  fi

  ryoku-cmd-present sudo || return 0
  sudo -n true >/dev/null 2>&1 || return 0

  temp_file=$(mktemp)
  cp "$file" "$temp_file"
  apply_replacements_to_file "$relative" "$temp_file"
  mode=$(stat -c '%a' "$file")
  sudo install -m "$mode" "$temp_file" "$file"
  rm -f "$temp_file"
}

apply_replacements_to_tree() {
  local tree="$1"
  local target search replace

  [[ -d $tree ]] || return 0
  [[ -f $REPLACEMENTS_FILE ]] || return 0

  while IFS=$'\t' read -r target search replace || [[ -n $target ]]; do
    [[ -n $target ]] || continue
    [[ ${target:0:1} == "#" ]] && continue
    apply_replacements_to_file "$target" "$tree/$target"
  done <"$REPLACEMENTS_FILE"
}

install_visible_assets() {
  local background="$RYOKU_PATH/themes/ryoku/backgrounds/1-ryoku.png"
  local icon_dir="$HOME/.local/share/icons/hicolor/scalable/apps"

  install_asset "$RYOKU_PATH/logo-mark.svg" "$SHELL_PATH/assets/icons/ryoku.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$SHELL_PATH/assets/icons/desktop-symbolic.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$icon_dir/ryoku.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$icon_dir/inir.svg"
  install_asset "$background" "$SHELL_PATH/dots/sddm/pixel/assets/background.png"

  if [[ -d /usr/share/sddm/themes/ii-pixel ]]; then
    if [[ -w /usr/share/sddm/themes/ii-pixel ]]; then
      install_asset "$background" "/usr/share/sddm/themes/ii-pixel/assets/background.png"
    elif ryoku-cmd-present sudo && sudo -n true >/dev/null 2>&1; then
      sudo install -d -m 0755 /usr/share/sddm/themes/ii-pixel/assets
      sudo install -m 0644 "$background" /usr/share/sddm/themes/ii-pixel/assets/background.png
    fi
  fi
}

apply_installed_labels() {
  apply_replacements_to_file "assets/applications/inir.desktop" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/inir.desktop"
  apply_replacements_to_file "assets/systemd/inir.service" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/inir.service"

  if [[ -d /usr/share/sddm/themes/ii-pixel ]]; then
    apply_replacements_to_root_file "dots/sddm/pixel/metadata.desktop" \
      "/usr/share/sddm/themes/ii-pixel/metadata.desktop"
    apply_replacements_to_root_file "dots/sddm/pixel/theme.conf" \
      "/usr/share/sddm/themes/ii-pixel/theme.conf"
    apply_replacements_to_root_file "dots/sddm/pixel/Main.qml" \
      "/usr/share/sddm/themes/ii-pixel/Main.qml"
    apply_replacements_to_root_file "dots/sddm/pixel/VirtualKeyboard.qml" \
      "/usr/share/sddm/themes/ii-pixel/VirtualKeyboard.qml"
  fi
}

merge_config_overrides() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/inir"
  local config_file="$config_dir/config.json"
  local temp_file temp_file_with_wallpaper wallpaper_path

  [[ -f $CONFIG_OVERRIDES_FILE ]] || return 0

  if ryoku-cmd-missing jq; then
    log "jq missing, skipped shell config merge"
    return 0
  fi

  mkdir -p "$config_dir"
  if [[ ! -f $config_file ]]; then
    if [[ -f $SHELL_PATH/defaults/config.json ]]; then
      cp "$SHELL_PATH/defaults/config.json" "$config_file"
    else
      printf '{}\n' >"$config_file"
    fi
  fi

  temp_file=$(mktemp)
  jq -s '.[0] * .[1]' "$config_file" "$CONFIG_OVERRIDES_FILE" >"$temp_file"

  wallpaper_path="$RYOKU_CONFIG_PATH/current/background"
  if [[ ! -e $wallpaper_path && -f $RYOKU_PATH/themes/ryoku/backgrounds/1-ryoku.png ]]; then
    wallpaper_path="$RYOKU_PATH/themes/ryoku/backgrounds/1-ryoku.png"
  fi

  temp_file_with_wallpaper=$(mktemp)
  jq --arg path "$wallpaper_path" \
    '.background.wallpaperPath = $path
      | .background.thumbnailPath = ""
      | .background.backdrop.wallpaperPath = $path
      | .background.backdrop.thumbnailPath = ""' \
    "$temp_file" >"$temp_file_with_wallpaper"

  mv "$temp_file_with_wallpaper" "$config_file"
  rm -f "$temp_file"
}

main() {
  if [[ ! -d $SHELL_PATH ]]; then
    log "checkout not found, branding will apply after shell install"
    return 0
  fi

  install_visible_assets
  apply_replacements_to_tree "$SHELL_PATH"
  apply_installed_labels
  merge_config_overrides

  log "applied"
}

main "$@"
