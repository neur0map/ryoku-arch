#!/bin/bash
# Setup Spotify and Spicetify.
#
# @meta name: Setup Spotify + Spicetify
# @meta description: Install Spotify and configure Spicetify
# @meta icon: music_note
# @meta keywords: spotify music spicetify aur flatpak

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh"

CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell/config.json"

find_spotify_prefs() {
  find "$HOME" -path '*/spotify/prefs' -print -quit 2>/dev/null
}

await_or_force_close_spotify() {
  local waited=0

  echo
  echo "Sign in to Spotify so it can write its prefs file."
  echo "Quit Spotify normally to continue, or press Enter here to force-quit it."
  echo

  while ! pgrep -x spotify >/dev/null 2>&1; do
    sleep 1
    waited=$((waited + 1))
    if (( waited >= 30 )); then
      echo "Spotify did not start; continuing anyway." >&2
      return 0
    fi
  done

  while pgrep -x spotify >/dev/null 2>&1; do
    if read -r -t 2 _; then
      echo "Force-closing Spotify..."
      pkill -x spotify || true
      for _ in 1 2 3 4 5; do
        pgrep -x spotify >/dev/null 2>&1 || break
        sleep 1
      done
      pgrep -x spotify >/dev/null 2>&1 && pkill -9 -x spotify || true
      break
    fi
  done

  echo "Spotify closed; resuming setup."
}

theme_enabled_in_config() {
  [[ -f $CONFIG_PATH ]] || return 1
  setup_cmd_present jq || return 1

  [[ $(jq -r '.appearance.wallpaperTheming.enableSpicetify // false' "$CONFIG_PATH" 2>/dev/null) == "true" ]]
}

setup_init "spotify" "Setup Spotify + Spicetify"

if is_arch_like; then
  TOTAL=5

  setup_progress 1 "$TOTAL" "Installing Spotify and Spicetify CLI"
  install_arch -- spotify spicetify-cli

  find_spotify_dir() {
    local dir

    for dir in /opt/spotify "$HOME/.local/share/spotify-launcher/install/usr/share/spotify"; do
      [[ -d $dir/Apps ]] && printf '%s\n' "$dir" && return 0
    done

    return 1
  }

  setup_progress 2 "$TOTAL" "Configuring Spicetify paths"
  spotify_dir="$(find_spotify_dir || true)"
  if [[ -z $spotify_dir ]]; then
    setup_fail "Could not find the Spotify install directory."
    setup_finish_pause
    exit 1
  fi

  echo "Spotify install directory: $spotify_dir"
  spicetify config spotify_path "$spotify_dir" >/dev/null 2>&1 || true
  sudo chmod a+wr "$spotify_dir"
  sudo chmod a+wr "$spotify_dir/Apps" -R

  setup_progress 3 "$TOTAL" "Applying Spicetify backup"
  prefs="$(find_spotify_prefs)"
  if [[ -n $prefs ]]; then
    echo "prefs already exists at $prefs"
    spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
  fi

  spicetify_apply_with_recovery() {
    local config_path=""
    local config_dir=""

    spicetify backup apply && return 0
    spicetify restore backup apply && return 0

    config_path="$(spicetify -c 2>/dev/null || true)"
    if [[ -n $config_path ]]; then
      config_dir="$(dirname "$config_path")"
      if [[ -d $config_dir ]]; then
        echo "Clearing stale backup state..."
        rm -rf "$config_dir/Backup" 2>/dev/null || true
        sed -i '/^\[Backup\]/,/^\[/{/^\[Backup\]/!{/^\[/!d}}' "$config_dir/config-xpui.ini" 2>/dev/null || true
      fi
    fi

    spicetify backup apply
  }

  if ! spicetify_apply_with_recovery; then
    echo
    echo "backup apply failed, likely because Spotify has not generated prefs yet."
    echo "Launching Spotify so it can create prefs..."
    if ! setsid -f spotify >/dev/null 2>&1 </dev/null; then
      nohup spotify >/dev/null 2>&1 </dev/null &
    fi
    setup_notify "Sign in to Spotify, then quit it or press Enter in the terminal to force-quit" "media-playback-start"
    await_or_force_close_spotify

    prefs="$(find_spotify_prefs)"
    if [[ -z $prefs ]]; then
      setup_fail "Could not locate spotify/prefs after first run; aborting."
      setup_finish_pause
      exit 1
    fi

    echo "Found prefs at $prefs"
    spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
    spicetify_apply_with_recovery
  fi

  setup_progress 4 "$TOTAL" "Installing Spicetify Marketplace"
  if curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh; then
    echo "Marketplace installed."
  else
    echo "warning: Marketplace installer failed; rerun it later if needed." >&2
  fi

  if theme_enabled_in_config; then
    setup_progress 5 "$TOTAL" "Applying Ryoku Spicetify theme"
    theme_script="$SCRIPT_DIR/../colors/apply-spicetify-theme.sh"
    if [[ -x $theme_script ]]; then
      if "$theme_script"; then
        echo "Ryoku theme applied."
      else
        echo "warning: theme script returned non-zero; rerun it manually if Spotify looks unstyled." >&2
      fi
    else
      echo "warning: $theme_script not found or not executable; skipping theme." >&2
    fi
  else
    setup_progress 5 "$TOTAL" "Skipping Ryoku theme because Spotify theming is disabled"
    echo "Enable appearance.wallpaperTheming.enableSpicetify in Settings to apply the Ryoku theme."
  fi

  setup_done "Spotify + Spicetify ready."
else
  TOTAL=2

  setup_progress 1 "$TOTAL" "Installing Spotify via Flatpak"
  install_flatpak com.spotify.Client

  setup_progress 2 "$TOTAL" "Skipping Spicetify because Flatpak Spotify is unsupported"
  setup_done "Spotify installed via Flatpak. Spicetify was skipped."
fi

setup_finish_pause
