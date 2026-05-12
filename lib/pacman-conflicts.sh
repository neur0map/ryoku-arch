#!/bin/bash

ryoku_pacman_latest_update_log() {
  local env_log="${RYOKU_UPDATE_LOG:-}"
  local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  local candidate newest=""
  local mtime newest_mtime=0
  local candidates=(
    "$state_home/quickshell/user/update.log"
    "$state_home/ryoku/update.log"
    "/tmp/ryoku-update.log"
    "/tmp/omarchy-update.log"
  )

  if [[ -n $env_log && -r $env_log ]]; then
    printf '%s\n' "$env_log"
    return 0
  fi

  for candidate in "${candidates[@]}"; do
    [[ -r $candidate ]] || continue

    mtime=$(stat -c %Y "$candidate" 2>/dev/null || printf '0')
    if [[ -z $newest ]] || (( mtime > newest_mtime )); then
      newest="$candidate"
      newest_mtime="$mtime"
    fi
  done

  [[ -n $newest ]] || return 1
  printf '%s\n' "$newest"
}

ryoku_pacman_map_conflict_path() {
  local path="$1"
  local node_modules_dir="${RYOKU_SYSTEM_NODE_MODULES_DIR:-}"

  if [[ -n $node_modules_dir && $path == /usr/lib/node_modules/* ]]; then
    printf '%s/%s\n' "$node_modules_dir" "${path#/usr/lib/node_modules/}"
  else
    printf '%s\n' "$path"
  fi
}

ryoku_pacman_conflicts_from_log() {
  local log="$1"
  local line package path

  [[ -r $log ]] || return 1

  while IFS= read -r line; do
    line="${line//$'\r'/}"
    if [[ $line =~ ^([^:]+):[[:space:]]+(/.*)[[:space:]]exists[[:space:]]in[[:space:]]filesystem$ ]]; then
      package="${BASH_REMATCH[1]}"
      path="${BASH_REMATCH[2]}"
      printf '%s\t%s\n' "$package" "$path"
    fi
  done < "$log"
}

ryoku_pacman_safe_label() {
  local label="$1"

  label="${label//\//_}"
  label="${label// /_}"
  printf '%s\n' "$label"
}

ryoku_pacman_repair_conflict_path() {
  local package="$1"
  local path="$2"
  local backup_root="${RYOKU_PACMAN_CONFLICT_BACKUP_DIR:-/var/lib/ryoku/pacman-conflict-backups}"
  local label backup_path

  label="$(ryoku_pacman_safe_label "$package")"
  backup_path="$backup_root/${label}-$(date +%Y%m%d%H%M%S)/${path#/}"

  if [[ ! -e $path ]]; then
    echo "Known conflict path is already clear: $path"
    return 2
  fi

  if pacman -Qo "$path" >/dev/null 2>&1; then
    echo "Path is owned by pacman, leaving it in place: $path"
    return 2
  fi

  echo "Moving unowned package-manager conflict: $path -> $backup_path"
  sudo mkdir -p "$(dirname "$backup_path")"
  sudo mv "$path" "$backup_path"
}

ryoku_pacman_repair_conflicts_from_log() {
  local log="$1"
  local package raw_path path repair_status
  local found=0
  local fixes=0
  local clear=0
  local unresolved=0

  while IFS=$'\t' read -r package raw_path; do
    [[ -n ${package:-} && -n ${raw_path:-} ]] || continue

    found=1
    path="$(ryoku_pacman_map_conflict_path "$raw_path")"

    if ryoku_pacman_repair_conflict_path "$package" "$path"; then
      ((fixes++)) || true
    else
      repair_status=$?
      if (( repair_status == 2 )); then
        ((clear++)) || true
      else
        ((unresolved++)) || true
      fi
    fi
  done < <(ryoku_pacman_conflicts_from_log "$log")

  (( fixes > 0 )) && return 0
  (( found == 0 )) && return 1
  (( unresolved == 0 && clear > 0 )) && return 2
  return 1
}
