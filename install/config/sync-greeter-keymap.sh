#!/bin/bash

# Make the SDDM greeter authenticate with the same keyboard layout the password
# was set with. archinstall only configures the console keymap (vconsole
# KEYMAP), which the LUKS disk-unlock prompt and the TTYs use; the graphical
# greeter reads the X11/XKB layout, which is left at the "us" default. A non-US
# user therefore sets and unlocks their disk and logs in on a TTY fine, but the
# qylock greeter rejects the very same password because it reads the keys under
# "us". Derive and write the matching X11 keymap so greeter, TTY, and disk-unlock
# all agree. Runs before detect-keyboard-layout.sh so Hyprland inherits it too.
set -euo pipefail

if command -v ryoku-keymap-sync >/dev/null 2>&1; then
  ryoku-keymap-sync || echo "Warning: could not sync the greeter keyboard layout; check ryoku-keymap-sync." >&2
elif [[ -x ${RYOKU_PATH:-}/bin/ryoku-keymap-sync ]]; then
  "$RYOKU_PATH/bin/ryoku-keymap-sync" || echo "Warning: could not sync the greeter keyboard layout; check ryoku-keymap-sync." >&2
fi
