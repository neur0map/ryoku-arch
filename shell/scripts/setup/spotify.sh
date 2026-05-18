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

  setup_progress 2 "$TOTAL" "Granting Spicetify write access to /opt/spotify"
  sudo chmod a+wr /opt/spotify
  sudo chmod a+wr /opt/spotify/Apps -R

  setup_progress 3 "$TOTAL" "Applying Spicetify backup"
  prefs="$(find_spotify_prefs)"
  if [[ -n $prefs ]]; then
    echo "prefs already exists at $prefs"
    spicetify config prefs_path "$prefs" >/dev/null 2>&1 || true
  fi

  if ! spicetify backup apply; then
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
    spicetify backup apply
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
