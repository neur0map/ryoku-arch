#!/bin/bash

# Preflight: refuse root, detect the distro, report what already exists on the
# system, and gate the run behind explicit consent that shows the full plan
# (including what is deliberately never touched).

rsi_preflight_root() {
  (( EUID == 0 )) && rsi_die "do not run as root. Run as your normal user; the installer uses sudo only for the wayland session entry."
  return 0
}

# Paths the installer may touch, used for the conflict report.
rsi_conflict_targets() {
  printf '%s\n' \
    "$RSI_RYOKU_PATH" \
    "$RSI_SHELL_PATH" \
    "$RSI_QUICKSHELL_DIR" \
    "$RSI_CONFIG_HOME/hypr" \
    "$RSI_CONFIG_HOME/ryoku" \
    "$RSI_CONFIG_HOME/ryoku-shell" \
    "$RSI_SESSION_FILE"
}

rsi_conflict_report() {
  rsi_step "scanning for existing files the installer would touch"
  local t found=0
  while IFS= read -r t; do
    if [[ -e $t || -L $t ]]; then
      rsi_warn "exists, will be backed up: $t"
      found=1
    fi
  done < <(rsi_conflict_targets)
  if command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1; then
    rsi_dim "  note: quickshell already installed. Ryoku runs as 'qs -c ryoku-shell' and will not disturb your existing quickshell configs."
  fi
  (( found == 0 )) && rsi_ok "no conflicting files found"
}

rsi_plan() {
  cat <<EOF

This experimental installer will, in your user scope:
  - install the shell-critical packages listed in packages/shell.deps
  - deploy the Ryoku payload to $RSI_RYOKU_PATH
  - deploy the shell to $RSI_SHELL_PATH and $RSI_QUICKSHELL_DIR
  - build the native QML plugins (cmake/ninja)
  - link ryoku-* commands into $RSI_BIN_HOME
  - seed missing configs into $RSI_CONFIG_HOME (existing files are preserved)
  - add a "Ryoku" wayland session at $RSI_SESSION_FILE (the only sudo write)
  - enable the hypridle and ryoku-resume-listener user services

It will NOT touch any of these:
  - your bootloader, kernel, or initramfs
  - your filesystem, btrfs, or snapshots
  - your display manager (it adds a session beside your existing ones)
  - plymouth / boot splash
  - /etc/pacman.conf, sudoers, udev rules, or other global system config

Everything it changes is backed up under $RSI_BACKUP_ROOT and recorded in
$RSI_MANIFEST, so 'shell-install/uninstall' reverses it.
EOF
}

rsi_preflight() {
  rsi_banner
  rsi_preflight_root
  rsi_load_adapter
  rsi_ok "detected $RSI_FAMILY family"
  rsi_conflict_report
  rsi_plan

  if rsi_dry; then
    rsi_say ""
    rsi_ok "dry run: nothing was changed"
    return 0
  fi

  rsi_say ""
  rsi_confirm "Proceed with the experimental shell install?" || rsi_die "aborted by user"
}
