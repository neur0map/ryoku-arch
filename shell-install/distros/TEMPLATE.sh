#!/bin/bash

# Distro adapter template. Copy to <family>.sh, register the family's distro
# IDs in detect.sh (rsi_detect_family), and implement the three contract
# functions below. Nothing outside shell-install/distros/ should need to
# change to add a distro, so the OS/ISO installer is never affected.
#
# The logical dependency names passed in come from packages/shell.deps. Map
# each to your distro's real package(s). Skip packages already installed and
# record installed ones with `rsi_record pkg NAME` so --purge-packages works.

# ryoku_distro_prereqs
#   Ensure the package manager and any helper (AUR, COPR, ...) are ready.
ryoku_distro_prereqs() {
  rsi_die "ryoku_distro_prereqs not implemented for this distro"
}

# ryoku_distro_map LOGICAL -> echo "class real [real...]"
#   class is a hint your ryoku_distro_install understands (e.g. repo/aur).
ryoku_distro_map() {
  printf ''
}

# ryoku_distro_install LOGICAL...
#   Resolve each logical name, install the missing real packages, honour
#   rsi_dry (print, change nothing) and record installed packages.
ryoku_distro_install() {
  rsi_die "ryoku_distro_install not implemented for this distro"
}
