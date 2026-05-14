#!/bin/bash
# Shared terminal dashboard helpers for ryoku-update.
# This script is meant to be sourced.

# shellcheck shell=bash

RYOKU_UPDATE_DASHBOARD_ACTIVE="${RYOKU_UPDATE_DASHBOARD_ACTIVE:-0}"
RYOKU_UPDATE_DASHBOARD_FINISHED="${RYOKU_UPDATE_DASHBOARD_FINISHED:-0}"
RYOKU_UPDATE_DASHBOARD_CURRENT_STEP="${RYOKU_UPDATE_DASHBOARD_CURRENT_STEP:-0}"
RYOKU_UPDATE_DASHBOARD_TOTAL="${RYOKU_UPDATE_DASHBOARD_TOTAL:-0}"
RYOKU_UPDATE_DASHBOARD_ROWS="${RYOKU_UPDATE_DASHBOARD_ROWS:-0}"
RYOKU_UPDATE_DASHBOARD_COLS="${RYOKU_UPDATE_DASHBOARD_COLS:-80}"
RYOKU_UPDATE_DASHBOARD_TOP_LINES="${RYOKU_UPDATE_DASHBOARD_TOP_LINES:-0}"
RYOKU_UPDATE_DASHBOARD_LOG_TOP="${RYOKU_UPDATE_DASHBOARD_LOG_TOP:-0}"
RYOKU_UPDATE_DASHBOARD_LOGO_LINES="${RYOKU_UPDATE_DASHBOARD_LOGO_LINES:-0}"
RYOKU_UPDATE_DASHBOARD_STAGE_TOP="${RYOKU_UPDATE_DASHBOARD_STAGE_TOP:-0}"
RYOKU_UPDATE_DASHBOARD_STARTED="${RYOKU_UPDATE_DASHBOARD_STARTED:-$SECONDS}"
RYOKU_UPDATE_DASHBOARD_RESULT="${RYOKU_UPDATE_DASHBOARD_RESULT:-running}"
RYOKU_UPDATE_DISCORD_URL="${RYOKU_UPDATE_DISCORD_URL:-https://discord.gg/8KjBmUEyKA}"
RYOKU_UPDATE_SUBREDDIT_URL="${RYOKU_UPDATE_SUBREDDIT_URL:-https://www.reddit.com/r/RyokuArch/}"

declare -ga RYOKU_UPDATE_DASHBOARD_LABELS=()
declare -ga RYOKU_UPDATE_DASHBOARD_STATUS=()

ryoku_update_status_file() {
  local state_home="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}"
  printf '%s\n' "${RYOKU_UPDATE_STATUS:-$state_home/quickshell/user/update-status}"
}

ryoku_update_report_progress() {
  local step="$1" total="$2" message="$3" status_file

  status_file="$(ryoku_update_status_file)"
  mkdir -p "$(dirname "$status_file")" 2>/dev/null || true
  printf 'progress:%s:%s:%s\n' "$step" "$total" "$message" >"$status_file" 2>/dev/null || true
}

ryoku_update_tput_number() {
  local cap="$1" fallback="$2" value

  value="$(tput "$cap" 2>/dev/null || true)"
  if [[ $value =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$fallback"
  fi
}

ryoku_update_color() {
  local code="$1" text="$2"

  if [[ -n ${NO_COLOR:-} ]]; then
    printf '%s' "$text"
  else
    printf '\033[%sm%s\033[0m' "$code" "$text"
  fi
}

ryoku_update_repeat() {
  local char="$1" count="$2" output="" i

  for ((i = 0; i < count; i++)); do
    output+="$char"
  done

  printf '%s' "$output"
}

ryoku_update_dashboard_repo_root() {
  local source_path="${BASH_SOURCE[0]}"
  local source_dir

  source_dir="$(cd -- "$(dirname -- "$source_path")" && pwd 2>/dev/null || true)"
  if [[ -n $source_dir && -d "$source_dir/.." ]]; then
    (cd -- "$source_dir/.." && pwd)
  else
    printf '%s\n' "${RYOKU_PATH:-$PWD}"
  fi
}

ryoku_update_brand_logo() {
  local logo_file="${RYOKU_UPDATE_BRAND_LOGO_FILE:-$(ryoku_update_dashboard_repo_root)/assets/brand/logo.txt}"

  if [[ -r $logo_file ]]; then
    cat "$logo_file"
  else
    printf '%s\n' "RYOKU"
  fi
}

ryoku_update_dashboard_logo_height() {
  if (( RYOKU_UPDATE_DASHBOARD_COLS >= 58 )); then
    ryoku_update_brand_logo | wc -l | tr -d '[:space:]'
  else
    printf '%s\n' 1
  fi
}

ryoku_update_dashboard_draw_brand() {
  (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 1 )) || return 0

  local row=1 line

  if (( RYOKU_UPDATE_DASHBOARD_LOGO_LINES > 1 )); then
    while IFS= read -r line; do
      ryoku_update_dashboard_line "$row" "$(ryoku_update_color "35;1" "$line")"
      ((row++))
      (( row > RYOKU_UPDATE_DASHBOARD_LOGO_LINES )) && break
    done < <(ryoku_update_brand_logo)
  else
    ryoku_update_dashboard_line 1 "$(ryoku_update_color "35;1" "RYOKU")"
  fi
}

ryoku_update_print_brand_header() {
  local line

  if (( RYOKU_UPDATE_DASHBOARD_COLS >= 58 )); then
    while IFS= read -r line; do
      printf '%s\n' "$(ryoku_update_color "35;1" "$line")"
    done < <(ryoku_update_brand_logo)
  else
    printf '%s\n' "$(ryoku_update_color "35;1" "RYOKU")"
  fi
}

ryoku_update_print_success_footer() {
  printf '\n%s\n' "$(ryoku_update_color "32;1" "Thanks for updating Ryoku.")"
  printf '%s\n' "$(ryoku_update_color "90" "Join the Ryoku community:")"
  printf '%s\n' "Discord: $RYOKU_UPDATE_DISCORD_URL"
  printf '%s\n' "Subreddit: $RYOKU_UPDATE_SUBREDDIT_URL"
}

ryoku_update_dashboard_should_start() {
  case "${RYOKU_UPDATE_DASHBOARD:-auto}" in
    0|false|off|no)
      return 1
      ;;
  esac

  [[ -t 1 ]] || return 1
  [[ ${TERM:-} == "dumb" ]] && return 1
  [[ ${CI:-} == "true" ]] && return 1

  local rows
  rows="$(ryoku_update_tput_number lines 0)"
  (( rows >= 18 ))
}

ryoku_update_stage_symbol() {
  local status="$1"

  case "$status" in
    done) printf '✓' ;;
    running) printf '●' ;;
    failed) printf '✗' ;;
    skipped) printf '◌' ;;
    *) printf '○' ;;
  esac
}

ryoku_update_stage_color() {
  local status="$1"

  case "$status" in
    done) printf '32' ;;
    running) printf '35;1' ;;
    failed) printf '31;1' ;;
    skipped) printf '33' ;;
    *) printf '90' ;;
  esac
}

ryoku_update_dashboard_line() {
  local row="$1" text="${2:-}"

  printf '\033[%d;1H\033[2K' "$row"
  printf '%s' "$text"
}

ryoku_update_install_dashboard_gum_shim() {
  gum() {
    if [[ ${RYOKU_UPDATE_DASHBOARD_ACTIVE:-0} == "1" && ${1:-} == "confirm" ]]; then
      shift

      local default="no" prompt="" arg

      while (( $# > 0 )); do
        arg="$1"
        case "$arg" in
          --default=yes|--default=true|--default)
            default="yes"
            shift
            ;;
          --default=no|--default=false)
            default="no"
            shift
            ;;
          --affirmative|--negative|--padding)
            shift
            (( $# > 0 )) && shift
            ;;
          --show-help=*)
            shift
            ;;
          --*)
            shift
            ;;
          *)
            prompt="$arg"
            shift
            ;;
        esac
      done

      [[ -n $prompt ]] || prompt="Continue?"
      ryoku_update_confirm "$prompt" "$default"
      return
    fi

    command gum "$@"
  }

  export -f gum ryoku_update_confirm
}

ryoku_update_dashboard_draw() {
  (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 1 )) || return 0

  local elapsed line status label symbol color i

  elapsed=$((SECONDS - RYOKU_UPDATE_DASHBOARD_STARTED))

  printf '\0337'
  ryoku_update_dashboard_draw_brand
  ryoku_update_dashboard_line "$((RYOKU_UPDATE_DASHBOARD_LOGO_LINES + 1))" "$(ryoku_update_color "35;1" "Ryoku Update")  $(ryoku_update_color "90" "${elapsed}s elapsed")"
  ryoku_update_dashboard_line "$((RYOKU_UPDATE_DASHBOARD_LOGO_LINES + 2))" "$(ryoku_update_color "90" "Log: ${RYOKU_UPDATE_LOG:-/tmp/ryoku-update.log}")"
  ryoku_update_dashboard_line "$((RYOKU_UPDATE_DASHBOARD_LOGO_LINES + 3))" "$(ryoku_update_color "90" "$(ryoku_update_repeat "─" "$RYOKU_UPDATE_DASHBOARD_COLS")")"

  for ((i = 1; i <= RYOKU_UPDATE_DASHBOARD_TOTAL; i++)); do
    label="${RYOKU_UPDATE_DASHBOARD_LABELS[$i]:-Stage $i}"
    status="${RYOKU_UPDATE_DASHBOARD_STATUS[$i]:-pending}"
    symbol="$(ryoku_update_stage_symbol "$status")"
    color="$(ryoku_update_stage_color "$status")"
    line="$(ryoku_update_color "$color" "$symbol") $(ryoku_update_color "90" "[$i/$RYOKU_UPDATE_DASHBOARD_TOTAL]") $label"
    ryoku_update_dashboard_line "$((RYOKU_UPDATE_DASHBOARD_STAGE_TOP + i - 1))" "$line"
  done

  ryoku_update_dashboard_line "$((RYOKU_UPDATE_DASHBOARD_TOP_LINES - 1))" "$(ryoku_update_color "90" "$(ryoku_update_repeat "─" "$RYOKU_UPDATE_DASHBOARD_COLS")")"
  case "$RYOKU_UPDATE_DASHBOARD_RESULT" in
    success)
      ryoku_update_dashboard_line "$RYOKU_UPDATE_DASHBOARD_TOP_LINES" "$(ryoku_update_color "32;1" "Update complete. Thanks for updating Ryoku.")"
      ;;
    failed)
      ryoku_update_dashboard_line "$RYOKU_UPDATE_DASHBOARD_TOP_LINES" "$(ryoku_update_color "31;1" "Update failed") $(ryoku_update_color "90" "Run: ryoku-doctor")"
      ;;
    *)
      ryoku_update_dashboard_line "$RYOKU_UPDATE_DASHBOARD_TOP_LINES" "$(ryoku_update_color "90" "Live output scrolls below. Prompts stay interactive.")"
      ;;
  esac
  printf '\0338'
}

ryoku_update_dashboard_set_scroll_region() {
  (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 1 )) || return 0
  printf '\033[%d;%dr' "$RYOKU_UPDATE_DASHBOARD_LOG_TOP" "$RYOKU_UPDATE_DASHBOARD_ROWS"
  printf '\033[%d;1H' "$RYOKU_UPDATE_DASHBOARD_LOG_TOP"
}

ryoku_update_dashboard_start() {
  local total="$1" i
  shift

  RYOKU_UPDATE_DASHBOARD_TOTAL="$total"
  RYOKU_UPDATE_DASHBOARD_STARTED=$SECONDS
  RYOKU_UPDATE_DASHBOARD_RESULT="running"

  RYOKU_UPDATE_DASHBOARD_LABELS=()
  RYOKU_UPDATE_DASHBOARD_STATUS=()
  for ((i = 1; i <= total; i++)); do
    RYOKU_UPDATE_DASHBOARD_LABELS[$i]="${1:-Stage $i}"
    RYOKU_UPDATE_DASHBOARD_STATUS[$i]="pending"
    shift || true
  done

  if ryoku_update_dashboard_should_start; then
    RYOKU_UPDATE_DASHBOARD_ROWS="$(ryoku_update_tput_number lines 24)"
    RYOKU_UPDATE_DASHBOARD_COLS="$(ryoku_update_tput_number cols 80)"
    RYOKU_UPDATE_DASHBOARD_LOGO_LINES="$(ryoku_update_dashboard_logo_height)"
    RYOKU_UPDATE_DASHBOARD_STAGE_TOP=$((RYOKU_UPDATE_DASHBOARD_LOGO_LINES + 4))
    RYOKU_UPDATE_DASHBOARD_TOP_LINES=$((RYOKU_UPDATE_DASHBOARD_STAGE_TOP + total + 1))
    RYOKU_UPDATE_DASHBOARD_LOG_TOP=$((RYOKU_UPDATE_DASHBOARD_TOP_LINES + 1))

    if (( RYOKU_UPDATE_DASHBOARD_ROWS - RYOKU_UPDATE_DASHBOARD_LOG_TOP < 5 )); then
      RYOKU_UPDATE_DASHBOARD_ACTIVE=0
      export RYOKU_UPDATE_DASHBOARD_ACTIVE
      ryoku_update_print_brand_header
      printf '\n%s\n\n' "$(ryoku_update_color "35;1" "Ryoku Update")"
      return 0
    fi

    RYOKU_UPDATE_DASHBOARD_ACTIVE=1
    export RYOKU_UPDATE_DASHBOARD_ACTIVE
    ryoku_update_install_dashboard_gum_shim
    printf '\033[?25l\033[2J\033[H'
    ryoku_update_dashboard_draw
    ryoku_update_dashboard_set_scroll_region
  else
    RYOKU_UPDATE_DASHBOARD_ACTIVE=0
    export RYOKU_UPDATE_DASHBOARD_ACTIVE
    RYOKU_UPDATE_DASHBOARD_COLS="$(ryoku_update_tput_number cols 80)"
    ryoku_update_print_brand_header
    printf '\n%s\n\n' "$(ryoku_update_color "35;1" "Ryoku Update")"
  fi
}

ryoku_update_dashboard_mark_stage() {
  local step="$1" status="$2"

  RYOKU_UPDATE_DASHBOARD_STATUS[$step]="$status"
  RYOKU_UPDATE_DASHBOARD_CURRENT_STEP="$step"
  ryoku_update_dashboard_draw
  ryoku_update_dashboard_set_scroll_region
}

ryoku_update_dashboard_log_stage() {
  local step="$1" total="$2" label="$3"

  if (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 1 )); then
    printf '\n%s\n\n' "$(ryoku_update_color "35;1" "[$step/$total] $label")"
  else
    printf '\n%s\n\n' "$(ryoku_update_color "35;1" "[$step/$total] $label")"
  fi
}

ryoku_update_run_stage() {
  local step="$1" total="$2" label="$3" rc
  shift 3

  ryoku_update_report_progress "$step" "$total" "$label"
  ryoku_update_dashboard_mark_stage "$step" "running"
  ryoku_update_dashboard_log_stage "$step" "$total" "$label"

  if "$@"; then
    rc=0
    ryoku_update_dashboard_mark_stage "$step" "done"
    if (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 0 )); then
      printf '%s\n' "$(ryoku_update_color "32" "✓ $label complete")"
    fi
  else
    rc=$?
    ryoku_update_dashboard_mark_stage "$step" "failed"
    ryoku_update_dashboard_finish "failed" "$rc"
    if (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 0 )); then
      printf '%s\n' "$(ryoku_update_color "31;1" "✗ $label failed")"
    fi
  fi

  return "$rc"
}

ryoku_update_dashboard_finish() {
  local result="${1:-success}" exit_code="${2:-1}" status_file

  (( RYOKU_UPDATE_DASHBOARD_FINISHED == 0 )) || return 0
  RYOKU_UPDATE_DASHBOARD_FINISHED=1
  RYOKU_UPDATE_DASHBOARD_RESULT="$result"

  status_file="$(ryoku_update_status_file)"
  mkdir -p "$(dirname "$status_file")" 2>/dev/null || true

  if [[ $result == "success" ]]; then
    printf 'success\n' >"$status_file" 2>/dev/null || true
  elif [[ $result == "failed" ]]; then
    printf 'failed:%s\n' "$exit_code" >"$status_file" 2>/dev/null || true
  fi

  if (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 1 )); then
    ryoku_update_dashboard_draw
    printf '\033[r\033[?25h\033[%d;1H\n' "$RYOKU_UPDATE_DASHBOARD_ROWS"
    if [[ $result == "success" ]]; then
      ryoku_update_print_success_footer
    fi
  else
    if [[ $result == "success" ]]; then
      printf '\n%s\n' "$(ryoku_update_color "32;1" "Ryoku update complete")"
      ryoku_update_print_success_footer
    else
      printf '\n%s\n' "$(ryoku_update_color "31;1" "Ryoku update failed")"
    fi
  fi

  RYOKU_UPDATE_DASHBOARD_ACTIVE=0
  export RYOKU_UPDATE_DASHBOARD_ACTIVE
}

ryoku_update_confirm() {
  local prompt="$1" default="${2:-no}" answer hint

  if (( RYOKU_UPDATE_DASHBOARD_ACTIVE == 1 )); then
    if [[ $default == "yes" ]]; then
      hint="[Y/n]"
    else
      hint="[y/N]"
    fi

    printf '%s %s ' "$prompt" "$hint"
    read -r answer || return 1
    if [[ $default == "yes" ]]; then
      [[ ! $answer =~ ^[Nn]$ ]]
    else
      [[ $answer =~ ^[Yy]$ ]]
    fi
    return
  fi

  if command -v gum >/dev/null 2>&1; then
    if [[ $default == "yes" ]]; then
      gum confirm --default=yes "$prompt"
    else
      gum confirm --default=no "$prompt"
    fi
    return
  fi

  if [[ $default == "yes" ]]; then
    hint="[Y/n]"
  else
    hint="[y/N]"
  fi

  printf '%s %s ' "$prompt" "$hint"
  read -r answer || return 1
  if [[ $default == "yes" ]]; then
    [[ ! $answer =~ ^[Nn]$ ]]
  else
    [[ $answer =~ ^[Yy]$ ]]
  fi
}
