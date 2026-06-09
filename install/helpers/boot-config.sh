#!/bin/bash

# Gate system-level boot mutations (mkinitcpio.conf.d, modprobe.d, bootloader
# entries, kernel swaps). Enabled by default so the OS/ISO install is unchanged.
# The standalone shell install sets RYOKU_BOOT_CONFIG=0 so it never rewrites a
# foreign system's boot path; driver packages and per-user Hyprland env still
# apply. `shell-install/install --with-boot-config` flips it back on for users
# who want exact ISO parity and accept the risk.
ryoku_boot_config_enabled() { [[ ${RYOKU_BOOT_CONFIG:-1} == 1 ]]; }
