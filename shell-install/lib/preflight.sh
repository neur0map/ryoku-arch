#!/bin/bash

# Two gates that run before anything is changed:
#   rsi_safety  hard checks that STOP the install if the machine is not safe to
#               proceed on. Universal across Arch machines (any bootloader,
#               filesystem, or desktop), but refuses clearly-unsafe conditions.
#   rsi_review  conflict report + the full plan + the consent prompt.

RSI_MIN_FREE_KB=$((3 * 1024 * 1024)) # 3 GiB headroom for the Qt6 + shell build

rsi_check_network() {
  local host=archlinux.org
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 6 -o /dev/null "https://$host" 2>/dev/null && return 0
  fi
  if command -v ping >/dev/null 2>&1; then
    ping -c1 -W3 "$host" >/dev/null 2>&1 && return 0
  fi
  if command -v timeout >/dev/null 2>&1; then
    timeout 6 bash -c "exec 3<>/dev/tcp/$host/443" 2>/dev/null && return 0
  fi
  return 1
}

# Hard safety gate. Every failure here stops the install before any change.
rsi_safety() {
  rsi_header "Safety checks"

  if (( EUID == 0 )); then
    rsi_die "running as root. Run as your normal user; sudo is used only where needed."
  fi
  rsi_ok "not running as root"

  # Must be an Arch-family system; the only adapter today is arch. This both
  # loads the adapter and stops on anything else.
  rsi_load_adapter
  rsi_ok "Arch-family system ($(rsi_os_id))"

  command -v pacman >/dev/null 2>&1 || rsi_die "pacman not found; this does not look like an Arch system."
  rsi_ok "pacman present"

  command -v sudo >/dev/null 2>&1 || rsi_die "sudo not found; it is required for package installs and the session entry."
  rsi_ok "sudo present"

  if [[ -e /var/lib/pacman/db.lck ]]; then
    rsi_die "pacman is locked (/var/lib/pacman/db.lck). Another package operation is running; wait for it to finish, then retry."
  fi
  rsi_ok "pacman database is not locked"

  local free_kb
  free_kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -n $free_kb ]] && (( free_kb < RSI_MIN_FREE_KB )); then
    rsi_die "low disk space in $HOME ($(( free_kb / 1024 )) MiB free). Building Qt6 and the shell needs about 3 GiB. Free up space and retry."
  fi
  rsi_ok "enough free disk in $HOME"

  if rsi_check_network; then
    rsi_ok "network reachable"
  else
    rsi_die "no network connectivity. pacman and the AUR need internet to install the shell dependencies."
  fi

  # Non-fatal advisories: the install still proceeds.
  [[ $(uname -m) == x86_64 ]] || rsi_warn "this is not an x86_64 machine ($(uname -m)); Ryoku targets x86_64 and is untested here."
  if ! systemctl is-enabled display-manager.service >/dev/null 2>&1 \
     && ! systemctl is-active display-manager.service >/dev/null 2>&1; then
    rsi_warn "no display manager detected; you will need a way to start the Ryoku wayland session (a display manager, or your own uwsm/tty launch)."
  fi
}

# Paths the installer may touch, used for the conflict report and the upfront
# backup.
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
  if (( found == 0 )); then
    rsi_ok "no conflicting files found"
  fi
}

rsi_plan() {
  rsi_header "What will happen"
  rsi_say "In your user scope, this will:"
  rsi_will "run a full system update (pacman -Syu), required so new apps match your libraries"
  if [[ ${RSI_MINIMAL:-0} == 1 ]]; then
    rsi_will "install only the shell-critical packages (minimal mode)"
  else
    rsi_will "install the Ryoku app + dependency set (apps the keybinds and commands need)"
  fi
  rsi_will "skip packages you already have (--needed), leaving your existing apps untouched"
  rsi_will "deploy the Ryoku payload to $RSI_RYOKU_PATH"
  rsi_will "build the native QML plugins and deploy the shell"
  rsi_will "link ryoku-* commands into $RSI_BIN_HOME"
  rsi_will "seed missing configs (your existing files are preserved)"
  rsi_will "add a \"Ryoku\" wayland session beside your existing ones (the only sudo write)"
  rsi_will "enable the ryoku-shell and hypridle user services"
  rsi_say ""
  rsi_say "It will NOT touch:"
  rsi_wont "your bootloader, kernel, or initramfs"
  rsi_wont "your filesystem, btrfs, or snapshots"
  rsi_wont "your display manager"
  rsi_wont "plymouth / boot splash"
  rsi_wont "/etc/pacman.conf, sudoers, udev, or other global system config"
  rsi_say ""
  rsi_dim "Everything changed is backed up under $RSI_BACKUP_ROOT and recorded in"
  rsi_dim "$RSI_MANIFEST, so 'shell-install/uninstall' reverses it."
}

# Prompt for sudo upfront so package installs never silently skip or stall, and
# keep the timestamp warm through long AUR builds. The keepalive is torn down
# by the EXIT trap in the entrypoint.
RSI_SUDO_PID=""
rsi_sudo_prime() {
  rsi_dry && return 0
  rsi_header "Administrator access"
  rsi_step "Ryoku needs sudo to install packages and register the login session."
  if ! sudo -v; then
    rsi_die "sudo authentication failed. Run as a user with sudo privileges and retry."
  fi
  rsi_ok "sudo authorized"
  ( while true; do sudo -n true 2>/dev/null || exit 0; sleep 50; done ) &
  RSI_SUDO_PID=$!
}

rsi_sudo_done() {
  [[ -n ${RSI_SUDO_PID:-} ]] && kill "$RSI_SUDO_PID" 2>/dev/null
  return 0
}

rsi_review() {
  rsi_header "Existing setup"
  rsi_conflict_report
  rsi_plan

  if rsi_dry; then
    rsi_say ""
    rsi_dim "dry run: previewing every step below; nothing will change."
    return 0
  fi

  rsi_say ""
  rsi_confirm "Proceed with the experimental shell install?" || rsi_die "aborted by user"
}
