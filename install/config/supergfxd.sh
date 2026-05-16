#!/bin/bash

# Enable the supergfxd daemon so supergfxctl can manage dGPU power state.
#
# supergfxctl is the asus-linux.org-canonical workaround for the s2idle
# resume failure that wedges the compositor on hybrid-GPU laptops after
# long lid-closed sleeps (symptom: black screen + cursor, screen on/off
# and lid cycle do not recover). On platforms without a supported
# vendor driver (anything outside ASUS asus-wmi today) the daemon's
# own platform probe refuses to start it, which is harmless and the
# source-of-truth for "should this be active?".
#
# The package is shipped universally via install/ryoku-aur.packages so
# every ryoku machine has the same baseline; this script just flips the
# service to enabled. We intentionally do not pin a default mode
# (Integrated / Hybrid / Vfio) here. First-run supergfxd picks one
# based on detected hardware and writes /etc/supergfxd.conf, and we
# defer to the user / hardware-specific scripts (e.g. asus-rog.sh) to
# override that if they want a different post-install default.

if ! ryoku-cmd-present systemctl; then
  exit 0
fi

if systemctl list-unit-files supergfxd.service >/dev/null 2>&1; then
  sudo systemctl enable supergfxd.service
fi
