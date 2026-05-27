#!/bin/bash

# ryoku-update-core.sh: the single source of truth for the Ryoku update flow.
#
# Channel model (resolve/validate/persist + channel-to-branch mapping), the
# shared wrapped-git helper, and permission/ownership self-healing. Every part
# of the update pipeline (ryoku-update, ryoku-update-git, ryoku-update-perform,
# ryoku-doctor, and the shell About helper) sources this so channel and path
# logic exists in exactly one place.
#
# Source it AFTER lib/runtime-env.sh: it relies on RYOKU_PATH and
# RYOKU_STATE_PATH already being exported.

# Guard against double-sourcing.
[[ -n ${RYOKU_UPDATE_CORE_SOURCED:-} ]] && return 0
RYOKU_UPDATE_CORE_SOURCED=1

# The channels Ryoku ships. Today each maps 1:1 to a git branch; the mapping is
# centralized so a future stable/beta split only changes one function.
RYOKU_CHANNELS=(main unstable-dev)
RYOKU_DEFAULT_CHANNEL="main"

ryoku_channel_is_valid() {
  local candidate="${1:-}" known
  for known in "${RYOKU_CHANNELS[@]}"; do
    [[ $candidate == "$known" ]] && return 0
  done
  return 1
}

# Echo the channel if valid, else the default. Never fails.
ryoku_channel_normalize() {
  if ryoku_channel_is_valid "${1:-}"; then
    printf '%s\n' "$1"
  else
    printf '%s\n' "$RYOKU_DEFAULT_CHANNEL"
  fi
}

# Map a channel to the git branch it tracks (1:1 for now).
ryoku_channel_to_branch() {
  case "${1:-}" in
  unstable-dev) printf '%s\n' "unstable-dev" ;;
  *) printf '%s\n' "main" ;;
  esac
}

# Path to the shell's config.json (holds shellUpdates.channel). Honors an
# explicit RYOKU_SHELL_CONFIG_DIR, then the ryoku-shell config, then the legacy
# illogical-impulse path so older installs keep resolving.
ryoku_shell_config_file() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

  if [[ -n ${RYOKU_SHELL_CONFIG_DIR:-} ]]; then
    printf '%s\n' "$RYOKU_SHELL_CONFIG_DIR/config.json"
    return
  fi

  if [[ -f $config_home/ryoku-shell/config.json ]]; then
    printf '%s\n' "$config_home/ryoku-shell/config.json"
    return
  fi

  # Legacy location is only honored for reads when it actually exists. Fresh
  # writes must land on the canonical ryoku-shell path (the shell stopped
  # reading illogical-impulse), so fall through to it when nothing exists.
  if [[ -f $config_home/illogical-impulse/config.json ]]; then
    printf '%s\n' "$config_home/illogical-impulse/config.json"
    return
  fi

  printf '%s\n' "$config_home/ryoku-shell/config.json"
}

# Wrapped git that never prompts for credentials and always targets the repo.
ryoku_git() {
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/true git -C "$RYOKU_PATH" "$@"
}

# Resolve the active update channel. Precedence (highest first):
#   1. explicit argument ($1) or RYOKU_UPDATE_BRANCH env override
#   2. shell config.json shellUpdates.channel
#   3. $RYOKU_STATE_PATH/channel state file
#   4. the currently checked-out git branch (if it is a known channel)
#   5. the default channel (main)
# Always prints a valid channel; warns to stderr on an invalid configured value.
ryoku_resolve_channel() {
  local override="${1:-${RYOKU_UPDATE_BRANCH:-}}"
  local configured=""
  local config_file=""
  local state_file="$RYOKU_STATE_PATH/channel"
  local state_channel=""
  local checkout_branch=""

  if [[ -n $override ]]; then
    configured="$override"
  else
    config_file="$(ryoku_shell_config_file)"
    if [[ -f $config_file ]] && command -v jq >/dev/null 2>&1; then
      configured="$(jq -r '.shellUpdates.channel // empty' "$config_file" 2>/dev/null || true)"
    fi

    if [[ -z $configured && -r $state_file ]]; then
      state_channel="$(<"$state_file")"
      ryoku_channel_is_valid "$state_channel" && configured="$state_channel"
    fi

    if [[ -z $configured && -d ${RYOKU_PATH:-}/.git ]]; then
      checkout_branch="$(ryoku_git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
      ryoku_channel_is_valid "$checkout_branch" && configured="$checkout_branch"
    fi
  fi

  if [[ -z $configured ]]; then
    printf '%s\n' "$RYOKU_DEFAULT_CHANNEL"
  elif ryoku_channel_is_valid "$configured"; then
    printf '%s\n' "$configured"
  else
    echo -e "\e[33mIgnoring invalid Ryoku update channel '$configured'; using ${RYOKU_DEFAULT_CHANNEL}.\e[0m" >&2
    printf '%s\n' "$RYOKU_DEFAULT_CHANNEL"
  fi
}

# Write the channel to the shell's config.json without clobbering other keys.
ryoku_write_shell_channel() {
  local channel="$1"
  local config_file
  local tmp_file=""

  config_file="$(ryoku_shell_config_file)"
  mkdir -p "$(dirname "$config_file")" 2>/dev/null || return 0

  if command -v python3 >/dev/null 2>&1; then
    tmp_file="$(mktemp)"
    if python3 - "$config_file" "$channel" >"$tmp_file" <<'PY'
import json
import sys

path, channel = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    data = {}

shell_updates = data.get("shellUpdates")
if not isinstance(shell_updates, dict):
    shell_updates = {}
data["shellUpdates"] = shell_updates
shell_updates["channel"] = channel

json.dump(data, sys.stdout, indent=2)
sys.stdout.write("\n")
PY
    then
      mv -- "$tmp_file" "$config_file"
    else
      rm -f "$tmp_file"
    fi
  elif [[ ! -f $config_file ]]; then
    printf '{"shellUpdates":{"channel":"%s"}}\n' "$channel" >"$config_file"
  fi
}

# Persist the channel to every place that reads it: the state file (canonical)
# and the shell config. Centralizing this prevents the desync between sources
# that made channel switching unreliable.
ryoku_persist_channel() {
  local channel
  channel="$(ryoku_channel_normalize "${1:-}")"

  mkdir -p "$RYOKU_STATE_PATH" 2>/dev/null || return 0
  printf '%s\n' "$channel" >"$RYOKU_STATE_PATH/channel" 2>/dev/null || true
  ryoku_write_shell_channel "$channel"
}

# Tell git the repo is trusted even if ownership looks "dubious" (e.g. after a
# prior sudo run left root-owned objects). Covers the active path plus the
# default and legacy locations so every tool agrees.
ryoku_git_mark_safe_directory() {
  local dir
  for dir in "${RYOKU_PATH:-}" "${RYOKU_PATH_DEFAULT:-}" "${RYOKU_LEGACY_PATH:-}"; do
    [[ -n $dir && -d $dir/.git ]] || continue
    git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$dir" && continue
    git config --global --add safe.directory "$dir" 2>/dev/null || true
  done
}

# If the repo has files owned by another user (typically root, from a sudo run),
# hand ownership back to the invoking user so later git/file writes stop hitting
# permission errors. Best-effort: silent if we cannot sudo.
ryoku_repo_fix_ownership() {
  local repo="${1:-$RYOKU_PATH}"
  local target_user="${SUDO_USER:-$USER}"
  local owner=""

  [[ -n $repo && -d $repo ]] || return 0
  ((EUID == 0)) && return 0

  owner="$(stat -c '%U' "$repo" 2>/dev/null || true)"
  [[ -n $owner && $owner != "$target_user" ]] || return 0

  command -v sudo >/dev/null 2>&1 || return 0
  sudo -n true >/dev/null 2>&1 || { [[ -t 0 ]] && sudo -v || return 0; }

  echo -e "\e[33mRepairing Ryoku repo ownership ($owner -> $target_user) at $repo\e[0m"
  sudo chown -R "$target_user" "$repo" 2>/dev/null || true
}
