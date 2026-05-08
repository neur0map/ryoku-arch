#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"
RUNTIME_SHELL_PATH="${RYOKU_SHELL_RUNTIME_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell}"
REPLACEMENTS_FILE="$RYOKU_PATH/default/ryoku-shell/branding-replacements.tsv"
CONFIG_OVERRIDES_FILE="$RYOKU_PATH/default/ryoku-shell/config-overrides.json"

log() {
  printf 'Ryoku branding: %s\n' "$1"
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

apply_service_cleanup() {
  local service="$1"
  local cleanup_cmd="$RYOKU_PATH/bin/ryoku-shell-cleanup-orphans"
  local cleanup_line

  [[ -f $service ]] || return 0
  [[ -x $cleanup_cmd ]] || cleanup_cmd="$HOME/.local/share/ryoku/bin/ryoku-shell-cleanup-orphans"

  cleanup_line="ExecStopPost=-$cleanup_cmd --quiet"

  if grep -q '^ExecStopPost=' "$service"; then
    RYOKU_CLEANUP_LINE="$cleanup_line" perl -0pi -e \
      's/^ExecStopPost=.*$/$ENV{RYOKU_CLEANUP_LINE}/mg' "$service"
  else
    printf '\n%s\n' "$cleanup_line" >>"$service"
  fi
}

install_visible_assets() {
  local icon_dir="$HOME/.local/share/icons/hicolor/scalable/apps"

  install_asset "$RYOKU_PATH/logo-mark.svg" "$SHELL_PATH/assets/icons/ryoku.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$SHELL_PATH/assets/icons/desktop-symbolic.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$icon_dir/ryoku.svg"
  install_asset "$RYOKU_PATH/logo-mark.svg" "$icon_dir/ryoku-shell.svg"
}

restore_shell_panels_original_frame_state_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0

  perl -0pi -e '
    s/^import qs\.modules\.frame\n//mg;
    s/^\s*PanelLoader \{ identifier: "iiScreenFrame"; component: ScreenFrame \{\} \}\n//mg;
  ' "$file"
}

restore_shell_panels_original_frame_state() {
  restore_shell_panels_original_frame_state_to_file "$SHELL_PATH/ShellIiPanels.qml"
  restore_shell_panels_original_frame_state_to_file "$RUNTIME_SHELL_PATH/ShellIiPanels.qml"
}

apply_installed_labels() {
  local installed_service="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-shell.service"

  apply_replacements_to_file "assets/applications/ryoku-shell.desktop" \
    "${XDG_DATA_HOME:-$HOME/.local/share}/applications/ryoku-shell.desktop"
  apply_replacements_to_file "assets/systemd/ryoku-shell.service" \
    "$installed_service"
  apply_service_cleanup "$installed_service"

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
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell"
  local config_file="$config_dir/config.json"
  local temp_file

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
  mv "$temp_file" "$config_file"
}

apply_ryoku_owned_shell_defaults_to_file() {
  local file="$1"
  local temp_file

  [[ -f $file ]] || return 0

  if ryoku-cmd-missing jq; then
    return 0
  fi

  temp_file=$(mktemp)
  jq '
    def append_once($value):
      if index($value) then . else . + [$value] end;
    def widgets:
      ["dashboard", "calendar", "events", "todo", "notepad", "calculator", "sysmon", "timer"];
    .bar.cornerStyle = 4
    | .bar.modules.kanjiClock = (.bar.modules.kanjiClock // true)
    | .bar.modules.secPulse = (.bar.modules.secPulse // true)
    | .bar.modules.dateLabel = (.bar.modules.dateLabel // true)
    | .bar.modules.weatherIcon = (.bar.modules.weatherIcon // true)
    | .bar.dynamicIsland.enabled = (.bar.dynamicIsland.enabled // true)
    | .bar.dynamicIsland.states.voiceSearch = (.bar.dynamicIsland.states.voiceSearch // true)
    | .bar.dynamicIsland.states.recording = (.bar.dynamicIsland.states.recording // true)
    | .bar.dynamicIsland.states.timer = (.bar.dynamicIsland.states.timer // true)
    | .bar.dynamicIsland.states.screenshotToast = (.bar.dynamicIsland.states.screenshotToast // true)
    | .bar.dynamicIsland.states.music = (.bar.dynamicIsland.states.music // true)
    | .bar.dynamicIsland.statePrecedence = (.bar.dynamicIsland.statePrecedence // ["voiceSearch", "recording", "timer", "screenshotToast", "music"])
    | .bar.dynamicIsland.tools.enabled = (.bar.dynamicIsland.tools.enabled // true)
    | .bar.dynamicIsland.tools.keybind = (.bar.dynamicIsland.tools.keybind // "Mod+S")
    | .bar.dynamicIsland.tools.order = (.bar.dynamicIsland.tools.order // ["screenshot", "record", "lens", "colorPicker", "musicRecognize", "micToggle", "osk", "DIVIDER", "caffeine", "notepad", "screenCast", "darkMode", "powerProfile"])
    | .bar.dynamicIsland.tools.buttons.screenshot = (.bar.dynamicIsland.tools.buttons.screenshot // true)
    | .bar.dynamicIsland.tools.buttons.record = (.bar.dynamicIsland.tools.buttons.record // true)
    | .bar.dynamicIsland.tools.buttons.lens = (.bar.dynamicIsland.tools.buttons.lens // true)
    | .bar.dynamicIsland.tools.buttons.colorPicker = (.bar.dynamicIsland.tools.buttons.colorPicker // true)
    | .bar.dynamicIsland.tools.buttons.musicRecognize = (.bar.dynamicIsland.tools.buttons.musicRecognize // true)
    | .bar.dynamicIsland.tools.buttons.micToggle = (.bar.dynamicIsland.tools.buttons.micToggle // true)
    | .bar.dynamicIsland.tools.buttons.osk = (.bar.dynamicIsland.tools.buttons.osk // true)
    | .bar.dynamicIsland.tools.buttons.caffeine = (.bar.dynamicIsland.tools.buttons.caffeine // true)
    | .bar.dynamicIsland.tools.buttons.notepad = (.bar.dynamicIsland.tools.buttons.notepad // true)
    | .bar.dynamicIsland.tools.buttons.screenCast = (.bar.dynamicIsland.tools.buttons.screenCast // false)
    | .bar.dynamicIsland.tools.buttons.darkMode = (.bar.dynamicIsland.tools.buttons.darkMode // true)
    | .bar.dynamicIsland.tools.buttons.powerProfile = (.bar.dynamicIsland.tools.buttons.powerProfile // false)
    | .bar.dynamicIsland.tools.autoCloseAfterAction = (.bar.dynamicIsland.tools.autoCloseAfterAction // true)
    | .bar.dynamicIsland.tools.closeOnEsc = (.bar.dynamicIsland.tools.closeOnEsc // true)
    | .bar.dynamicIsland.musicPopupContinuous = (.bar.dynamicIsland.musicPopupContinuous // true)
    | .bar.kanjiClock.showDate = (.bar.kanjiClock.showDate // true)
    | .bar.kanjiClock.useKanjiDigits = (.bar.kanjiClock.useKanjiDigits // false)
    | .bar.secPulse.showVpn = (.bar.secPulse.showVpn // true)
    | .bar.secPulse.showOpenVpn = (.bar.secPulse.showOpenVpn // true)
    | .bar.secPulse.showPublicIp = (.bar.secPulse.showPublicIp // false)
    | .bar.secPulse.showListening = (.bar.secPulse.showListening // false)
    | .bar.secPulse.vpnClickCommand = (.bar.secPulse.vpnClickCommand // "xdg-open https://login.tailscale.com/admin/machines")
    | .sidebar.right.enabledWidgets =
      (((.sidebar.right.enabledWidgets // widgets) | if type == "array" then . else widgets end) | append_once("openvpn"))
  ' "$file" >"$temp_file"
  mv "$temp_file" "$file"
}

apply_ryoku_owned_runtime_config_to_file() {
  local file="$1"
  local temp_file

  [[ -f $file ]] || return 0

  if ryoku-cmd-missing jq; then
    return 0
  fi

  temp_file=$(mktemp)
  jq '
    def append_once($value):
      if index($value) then . else . + [$value] end;
    def put_default($path; $value):
      if getpath($path) == null then setpath($path; $value) else . end;
    def widgets:
      ["dashboard", "calendar", "events", "todo", "notepad", "calculator", "sysmon", "timer"];
    .bar.cornerStyle =
      (if (.bar.dynamicIsland == null and (.bar.cornerStyle == null or .bar.cornerStyle == 1)) then 4 elif .bar.cornerStyle == null then 4 else .bar.cornerStyle end)
    | put_default(["bar", "modules", "kanjiClock"]; true)
    | put_default(["bar", "modules", "secPulse"]; true)
    | put_default(["bar", "modules", "dateLabel"]; true)
    | put_default(["bar", "modules", "weatherIcon"]; true)
    | put_default(["bar", "dynamicIsland", "enabled"]; true)
    | put_default(["bar", "dynamicIsland", "states", "voiceSearch"]; true)
    | put_default(["bar", "dynamicIsland", "states", "recording"]; true)
    | put_default(["bar", "dynamicIsland", "states", "timer"]; true)
    | put_default(["bar", "dynamicIsland", "states", "screenshotToast"]; true)
    | put_default(["bar", "dynamicIsland", "states", "music"]; true)
    | put_default(["bar", "dynamicIsland", "statePrecedence"]; ["voiceSearch", "recording", "timer", "screenshotToast", "music"])
    | put_default(["bar", "dynamicIsland", "tools", "enabled"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "keybind"]; "Mod+S")
    | put_default(["bar", "dynamicIsland", "tools", "order"]; ["screenshot", "record", "lens", "colorPicker", "musicRecognize", "micToggle", "osk", "DIVIDER", "caffeine", "notepad", "screenCast", "darkMode", "powerProfile"])
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "screenshot"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "record"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "lens"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "colorPicker"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "musicRecognize"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "micToggle"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "osk"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "caffeine"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "notepad"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "screenCast"]; false)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "darkMode"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "buttons", "powerProfile"]; false)
    | put_default(["bar", "dynamicIsland", "tools", "autoCloseAfterAction"]; true)
    | put_default(["bar", "dynamicIsland", "tools", "closeOnEsc"]; true)
    | put_default(["bar", "dynamicIsland", "musicPopupContinuous"]; true)
    | put_default(["bar", "kanjiClock", "showDate"]; true)
    | put_default(["bar", "kanjiClock", "useKanjiDigits"]; false)
    | put_default(["bar", "secPulse", "showVpn"]; true)
    | put_default(["bar", "secPulse", "showOpenVpn"]; true)
    | put_default(["bar", "secPulse", "showPublicIp"]; false)
    | put_default(["bar", "secPulse", "showListening"]; false)
    | put_default(["bar", "secPulse", "vpnClickCommand"]; "xdg-open https://login.tailscale.com/admin/machines")
    | .sidebar.right.enabledWidgets =
      (((.sidebar.right.enabledWidgets // widgets) | if type == "array" then . else widgets end) | append_once("openvpn"))
  ' "$file" >"$temp_file"
  mv "$temp_file" "$file"
}

restore_ryoku_owned_shell_config() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku-shell"
  local config_file="$config_dir/config.json"
  local defaults_file

  for defaults_file in "$SHELL_PATH/defaults/config.json" "$RUNTIME_SHELL_PATH/defaults/config.json"; do
    apply_ryoku_owned_shell_defaults_to_file "$defaults_file"
  done

  apply_ryoku_owned_runtime_config_to_file "$config_file"
}

merge_default_config_overrides() {
  local defaults_file temp_file

  [[ -f $CONFIG_OVERRIDES_FILE ]] || return 0

  if ryoku-cmd-missing jq; then
    return 0
  fi

  for defaults_file in "$SHELL_PATH/defaults/config.json" "$RUNTIME_SHELL_PATH/defaults/config.json"; do
    [[ -f $defaults_file ]] || continue
    temp_file=$(mktemp)
    jq -s '.[0] * .[1]' "$defaults_file" "$CONFIG_OVERRIDES_FILE" >"$temp_file"
    mv "$temp_file" "$defaults_file"
  done
}

main() {
  if [[ ! -d $SHELL_PATH ]]; then
    log "checkout not found, branding will apply after shell install"
    return 0
  fi

  install_visible_assets
  restore_shell_panels_original_frame_state
  apply_installed_labels
  merge_default_config_overrides
  merge_config_overrides
  restore_ryoku_owned_shell_config

  log "applied"
}

main "$@"
