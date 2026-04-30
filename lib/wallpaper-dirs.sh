#!/bin/bash

ryoku_wallpaper_legacy_user_dir() {
  local theme_name=""

  theme_name="$(cat "$RYOKU_CONFIG_PATH/current/theme.name" 2>/dev/null || true)"
  printf '%s\n' "$RYOKU_CONFIG_PATH/backgrounds/$theme_name"
}

ryoku_wallpaper_dirs_print0() {
  local legacy_user_dir

  legacy_user_dir="$(ryoku_wallpaper_legacy_user_dir)"
  printf '%s\0' "$RYOKU_WALLPAPER_DIR"
  if [[ $legacy_user_dir != $RYOKU_WALLPAPER_DIR ]]; then
    printf '%s\0' "$legacy_user_dir"
  fi
  printf '%s\0' "$RYOKU_CONFIG_PATH/current/theme/backgrounds"
}

ryoku_wallpaper_dirs_stale() {
  local list="$1"
  local dir found

  [[ -f $list ]] || return 0

  while IFS= read -r -d '' dir; do
    [[ -d $dir ]] || continue
    if [[ $dir -nt $list ]]; then
      return 0
    fi
    while IFS= read -r -d '' found; do
      [[ -n $found ]] && return 0
    done < <(find -L "$dir" -maxdepth 1 -type f -newer "$list" -print0 2>/dev/null)
  done < <(ryoku_wallpaper_dirs_print0)

  return 1
}
