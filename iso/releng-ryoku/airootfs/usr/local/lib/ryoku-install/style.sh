#!/bin/bash
# Shared gum styling helpers for the Ryoku installer.
# Source from each stage; do not invoke directly.

ORANGE_256=202
ORANGE_TRUE='#F25623'
SUBDUED_256=248
GREEN_OK_256=35
RED_ERR_256=196

# Stage header. Usage: stage_header <stage_number> <total> <title>
stage_header() {
  local n="$1" total="$2" title="$3"
  clear
  gum style \
    --border double --foreground "$ORANGE_256" \
    --padding "1 2" --margin 1 --align center --width 56 \
    "Ryoku Installer" "" "Stage ${n}/${total}: ${title}"
  echo
}

# Info paragraph (subdued).
info() {
  gum style --foreground "$SUBDUED_256" "$@"
  echo
}

# Success message.
success() {
  gum style --foreground "$GREEN_OK_256" --bold "$@"
  echo
}

# Warning box (red on near-black).
warning() {
  gum style \
    --border thick --foreground "$RED_ERR_256" --background 232 \
    --padding "1 2" --margin 1 --align center --width 60 \
    "$@"
  echo
}

# Abort with a warning box and exit non-zero.
abort() {
  warning "Pre-flight failed" "" "$@"
  exit 1
}
