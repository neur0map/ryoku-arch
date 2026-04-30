#!/bin/bash

ryoku_wallpaper_dirs_print0() {
  printf '%s\0' "$RYOKU_WALLPAPER_DIR"
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
