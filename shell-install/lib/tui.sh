#!/bin/bash

# gum-rendered front of house: the support verdict, the snapshot offer, the
# confirm, and the closing card. gum sizes and closes its own borders, so the
# boxes are always well formed. Without gum (a fresh box, before it is
# installed) everything falls back to plain ui.sh lines, no hand-drawn boxes.

TUI_ACCENT="#F25623"
TUI_OK="#8AB573"
TUI_ERR="#C75450"
TUI_DIM="#AEAB94"

tui_has() { command -v gum >/dev/null 2>&1; }

# tui_box COLOR LINE... -> a rounded, padded card (gum), else indented lines.
tui_box() {
  local color="$1"
  shift
  if tui_has; then
    gum style --border rounded --border-foreground "$color" \
      --padding "1 2" --margin "1 0" -- "$@"
  else
    local line
    printf '\n'
    for line in "$@"; do printf '   %s\n' "$line"; done
  fi
}

# tui_label TEXT -> a dim caption above a card.
tui_label() {
  if tui_has; then
    gum style --foreground "$TUI_DIM" --margin "1 0 0 1" -- "$*"
  else
    rsi_header "$*"
  fi
}

# tui_confirm PROMPT -> 0 on yes. gum's dialog when present, else the ui.sh
# tty-aware reader. --yes auto-affirms either way.
tui_confirm() {
  [[ ${RSI_ASSUME_YES:-0} == 1 ]] && return 0
  if tui_has; then
    gum confirm "$1"
  else
    rsi_confirm "$1"
  fi
}

# tui_spin TITLE CMD... -> run CMD under a spinner (gum), else announce and run.
tui_spin() {
  local title="$1"
  shift
  if tui_has; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    rsi_step "$title"
    "$@"
  fi
}

# The support verdict: the first thing every user sees after the banner. Loads
# the distro adapter on a supported family; on anything else it states the
# reason and exits without touching the system.
tui_verdict() {
  local id family
  id="$(rsi_os_id)"
  family="$(rsi_detect_family)"

  if [[ $family == unsupported ]]; then
    tui_label "system check"
    tui_box "$TUI_ERR" \
      "✗  $id  ·  not an Arch-family distro" \
      "" \
      "The Ryoku shell installer supports the Arch family today" \
      "(Arch, CachyOS, EndeavourOS, Manjaro, Garuda, Artix, ...)." \
      "Other distros are planned: see shell-install/distros/TEMPLATE.sh." \
      "" \
      "Nothing was changed."
    exit 1
  fi

  tui_label "system check"
  tui_box "$TUI_OK" "✓  $id  ·  Arch family  ·  supported"
  rsi_load_adapter
}

# Install gum itself so the rest of the run is rendered with it. Runs after the
# sudo prompt; a fresh box reaches here with plain output and graduates to gum.
tui_ensure_gum() {
  rsi_dry && return 0
  tui_has && return 0
  rsi_step "installing gum (the installer interface)"
  sudo pacman -S --needed --noconfirm gum >/dev/null 2>&1 \
    || rsi_warn "could not install gum; continuing with plain output"
}

# Recommend, and offer to take, a system snapshot before any package or driver
# lands. Honours an existing snapper config or timeshift; otherwise it just
# advises a manual backup. Always non-fatal.
tui_snapshot() {
  rsi_dry && return 0
  local tool=""
  if command -v snapper >/dev/null 2>&1 && sudo snapper list-configs 2>/dev/null | grep -q '^[a-zA-Z]'; then
    tool=snapper
  elif command -v timeshift >/dev/null 2>&1; then
    tool=timeshift
  fi

  tui_label "snapshot"
  if [[ -z $tool ]]; then
    tui_box "$TUI_DIM" \
      "A backup or system snapshot before installing is recommended:" \
      "Ryoku installs system packages and GPU/firmware drivers." \
      "No snapper config or timeshift was found to take one for you."
    return 0
  fi

  tui_box "$TUI_ACCENT" \
    "Recommended: a $tool snapshot before installing, so the system" \
    "packages and drivers can be rolled back if anything goes wrong."
  tui_confirm "Take a $tool snapshot now?" || { rsi_step "skipping snapshot"; return 0; }

  case "$tool" in
    snapper) tui_spin "creating snapper snapshot" \
      sudo snapper create --description "before ryoku shell install" ;;
    timeshift) tui_spin "creating timeshift snapshot" \
      sudo timeshift --create --comments "before ryoku shell install" --scripted ;;
  esac || rsi_warn "snapshot failed (non-fatal); continuing"
}

# tui_done LINE... -> the closing success card.
tui_done() {
  tui_box "$TUI_OK" "✓  Ryoku shell installed" "$@"
}
