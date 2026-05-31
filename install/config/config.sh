#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

copy_default_file_if_missing() {
  local source_file="$1"
  local target_file="$2"

  [[ -f $source_file ]] || return 0
  [[ -e $target_file ]] && return 0

  mkdir -p "$(dirname "$target_file")"
  cp -a "$source_file" "$target_file"
}

install_default_configs() {
  local source_file relative_path

  [[ -d $RYOKU_PATH/config ]] || return 0
  mkdir -p "$HOME/.config"

  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$RYOKU_PATH/config/"}"
    copy_default_file_if_missing "$source_file" "$HOME/.config/$relative_path"
  done < <(find "$RYOKU_PATH/config" -type f -print0)
}

seed_default_wallpapers() {
  local source_dir target_dir source_file rel target

  source_dir="$RYOKU_PATH/wallpapers"
  target_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"

  [[ -d $source_dir ]] || return 0

  mkdir -p "$target_dir"

  while IFS= read -r -d '' source_file; do
    rel="${source_file#$source_dir/}"
    target="$target_dir/$rel"
    mkdir -p "$(dirname "$target")"
    [[ -e $target ]] || cp -a "$source_file" "$target"
  done < <(find "$source_dir" -type f -print0)
}

remove_retired_wallpaper_assets() {
  local target_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"
  local cache_file="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/wallpaper-selector/colors.json"
  local tmp

  rm -f "$target_dir/qs-niri.jpg"

  [[ -f $cache_file ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  tmp="$(mktemp "${cache_file}.XXXXXX")" || return 0
  if jq 'del(."qs-niri.jpg")' "$cache_file" >"$tmp"; then
    mv "$tmp" "$cache_file"
  else
    rm -f "$tmp"
  fi
}

# Pick a random default wallpaper so a fresh desktop is not blank. The shell's
# WallpaperService reads path.txt on first boot and applies it (and derives the
# colour scheme from it), so writing the state here is enough - no compositor is
# running yet during install. Respects an existing user choice.
set_random_default_wallpaper() {
  local wp_dir state_wp chosen
  wp_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"
  state_wp="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-shell/wallpaper"
  [[ -d $wp_dir ]] || return 0
  [[ -s "$state_wp/path.txt" ]] && return 0

  chosen="$(find "$wp_dir" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null \
    | shuf -n1)"
  [[ -n $chosen ]] || return 0

  mkdir -p "$state_wp"
  printf '%s\n' "$chosen" >"$state_wp/path.txt"
  printf 'image\n' >"$state_wp/type.txt"
  mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/current"
  ln -sf "$chosen" "${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/current/background" 2>/dev/null || true
}

install_default_configs
seed_default_wallpapers
set_random_default_wallpaper
remove_retired_wallpaper_assets
copy_default_file_if_missing "$RYOKU_PATH/default/bashrc" "$HOME/.bashrc"
