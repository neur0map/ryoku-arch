#!/bin/bash

# Deploy stage. Lays down the Ryoku payload, builds and deploys the shell,
# links the commands, seeds configs, registers a wayland session, and enables
# the user services. Every created path and every backup is recorded in the
# manifest so uninstall can reverse it.

# rsi_run CMD... -> run a command, or print it in dry-run.
rsi_run() {
  if rsi_dry; then
    rsi_dim "  would run: $*"
    return 0
  fi
  "$@"
}

# Deploy the repo payload to the canonical RYOKU_PATH so the deployed ryoku-*
# commands and lib/runtime-env.sh resolve. Back up any prior install.
rsi_deploy_payload() {
  rsi_step "deploying Ryoku payload to $RSI_RYOKU_PATH"
  rsi_backup "$RSI_RYOKU_PATH"
  rsi_run mkdir -p "$RSI_RYOKU_PATH"
  if rsi_dry; then
    rsi_dim "  would rsync $RSI_REPO/ -> $RSI_RYOKU_PATH/ (minus installer/iso/docs/vcs)"
  else
    rsync -a --delete \
      --exclude='.git' \
      --exclude='.github' \
      --exclude='shell-install' \
      --exclude='iso' \
      --exclude='legacy' \
      --exclude='distro' \
      --exclude='tests' \
      --exclude='docs' \
      --exclude='videowalls' \
      --exclude='showcase.png' \
      "$RSI_REPO/." "$RSI_RYOKU_PATH/"
  fi
  rsi_record dir "$RSI_RYOKU_PATH"
}

# Build the native QML plugins and deploy the runtime shell tree, mirroring
# the supported build in install/config/shell.sh (reused, not reimplemented).
rsi_deploy_shell() {
  rsi_step "building and deploying the shell"
  local vendor="$RSI_RYOKU_PATH/shell"
  rsi_backup "$RSI_SHELL_PATH"

  if rsi_dry; then
    rsi_dim "  would sync $vendor -> $RSI_SHELL_PATH, run setup, deploy to $RSI_QUICKSHELL_DIR"
    rsi_record dir "$RSI_SHELL_PATH"
    rsi_record dir "$RSI_QUICKSHELL_DIR"
    return 0
  fi

  mkdir -p "$(dirname "$RSI_SHELL_PATH")"
  rsync -a --delete --delete-excluded \
    --exclude='AGENTS.md' --exclude='README.md' --exclude='CHANGELOG.md' \
    --exclude='CONTRIBUTING.md' --exclude='SECURITY.md' --exclude='.github' \
    --exclude='docs' --exclude='build' --exclude='CMakeCache.txt' --exclude='CMakeFiles' \
    "$vendor/." "$RSI_SHELL_PATH/"
  rm -rf "$RSI_SHELL_PATH/build" "$RSI_SHELL_PATH/CMakeCache.txt" "$RSI_SHELL_PATH/CMakeFiles"
  chmod +x "$RSI_SHELL_PATH/setup" 2>/dev/null || true
  find "$RSI_SHELL_PATH/scripts" -type f -exec chmod +x {} + 2>/dev/null || true

  local log="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku-shell-setup.log"
  mkdir -p "$(dirname "$log")"
  (
    cd "$RSI_SHELL_PATH"
    env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST \
      RYOKU_CORE_UPDATE_CHILD=1 \
      RYOKU_SHELL_RUNTIME_DIR="$RSI_QUICKSHELL_DIR" \
      IS_UPDATE=true \
      bash ./setup install -y --skip-deps --skip-setups --skip-sysupdate
  ) >"$log" 2>&1 || rsi_warn "shell setup returned non-zero; see $log"
  rsi_record dir "$RSI_SHELL_PATH"

  mkdir -p "$(dirname "$RSI_QUICKSHELL_DIR")"
  if [[ -d $RSI_QUICKSHELL_DIR ]]; then
    rsync -a --delete "$RSI_SHELL_PATH/" "$RSI_QUICKSHELL_DIR/"
  else
    cp -a "$RSI_SHELL_PATH/." "$RSI_QUICKSHELL_DIR/"
  fi
  printf '%s\n' "$RSI_RYOKU_PATH" >"$RSI_QUICKSHELL_DIR/.ryoku-source-path"
  find "$RSI_QUICKSHELL_DIR/scripts" -type f -exec chmod +x {} + 2>/dev/null || true
  rsi_record dir "$RSI_QUICKSHELL_DIR"
}

# Link the launcher and ryoku-* commands into ~/.local/bin (user scope only).
# The ~/.local/lib bridge lets commands invoked via the symlink find
# lib/runtime-env.sh through their relative ../lib path.
rsi_link_commands() {
  rsi_step "linking commands into $RSI_BIN_HOME"
  rsi_run mkdir -p "$RSI_BIN_HOME"

  local launcher="$RSI_RYOKU_PATH/shell/scripts/ryoku-shell"
  if [[ -e $launcher ]] || rsi_dry; then
    rsi_backup "$RSI_BIN_HOME/ryoku-shell"
    rsi_run ln -sfn "$launcher" "$RSI_BIN_HOME/ryoku-shell"
    rsi_record link "$RSI_BIN_HOME/ryoku-shell"
  fi

  if [[ -d $RSI_RYOKU_PATH/bin ]]; then
    local f base
    for f in "$RSI_RYOKU_PATH"/bin/ryoku-*; do
      [[ -f $f ]] || continue
      base="$(basename "$f")"
      rsi_run ln -sfn "$f" "$RSI_BIN_HOME/$base"
      rsi_record link "$RSI_BIN_HOME/$base"
    done
  fi

  local libdir
  libdir="$(dirname "$RSI_BIN_HOME")/lib"
  rsi_run mkdir -p "$libdir"
  rsi_run ln -sfn "$RSI_RYOKU_PATH/lib/runtime-env.sh" "$libdir/runtime-env.sh"
  rsi_record link "$libdir/runtime-env.sh"
}

# Seed configs. ~/.config/hypr must be owned by Ryoku for its session to work,
# so it is backed up then deployed (reversible transition). Everything else is
# delegated to the OS installer's config.sh, which does file-level
# copy-if-missing (it never overwrites a file the user already has) plus
# wallpaper and channel seeding, keeping parity with a real Ryoku seed.
rsi_seed_configs() {
  rsi_step "seeding configs into $RSI_CONFIG_HOME"
  local src="$RSI_RYOKU_PATH/config"
  if ! rsi_dry && [[ ! -d $src ]]; then
    rsi_warn "no config payload at $src"
    return 0
  fi

  local hypr="$RSI_CONFIG_HOME/hypr"
  rsi_backup "$hypr"
  if rsi_dry; then
    rsi_dim "  would deploy Ryoku hypr config to $hypr (backing up any existing)"
  else
    mkdir -p "$hypr"
    rsync -a "$src/hypr/" "$hypr/"
  fi
  rsi_record dir "$hypr"

  local config_sh="$RSI_RYOKU_PATH/install/config/config.sh"
  if rsi_dry; then
    rsi_dim "  would run config.sh (file-level copy-if-missing + wallpaper seed)"
  elif [[ -f $config_sh ]]; then
    bash "$config_sh" || rsi_warn "config seed reported a problem; continuing"
  else
    rsi_warn "no config.sh at $config_sh; skipping default config seed"
  fi

  # Record the Ryoku-namespaced config dirs so uninstall removes them without
  # touching the user's own app configs (which were only ever filled in where
  # absent and are harmless to leave).
  local d
  for d in "$RSI_CONFIG_HOME/ryoku" "$RSI_CONFIG_HOME/ryoku-shell"; do
    if [[ -e $d ]] || rsi_dry; then
      rsi_record dir "$d"
    fi
  done
}

# Register a distinctly-named Ryoku wayland session beside the user's existing
# sessions. Clone the installed Hyprland session entry so Exec matches the
# packaged launcher (the hyprland package owns start-hyprland), then rebrand
# the visible name. The only path written with sudo.
rsi_install_session() {
  rsi_step "registering the Ryoku wayland session"
  rsi_backup "$RSI_SESSION_FILE"

  local src="" cand
  for cand in /usr/share/wayland-sessions/hyprland.desktop \
              /usr/share/wayland-sessions/Hyprland.desktop; do
    [[ -f $cand ]] && { src="$cand"; break; }
  done

  if rsi_dry; then
    rsi_dim "  would register $RSI_SESSION_FILE (from ${src:-built-in template})"
    rsi_record session "$RSI_SESSION_FILE"
    return 0
  fi

  sudo install -d "$(dirname "$RSI_SESSION_FILE")"
  if [[ -n $src ]]; then
    sudo sed -e 's/^Name=.*/Name=Ryoku/' \
             -e 's/^Comment=.*/Comment=Ryoku Hyprland desktop (experimental shell install)/' \
             "$src" | sudo tee "$RSI_SESSION_FILE" >/dev/null
  else
    rsi_warn "no installed Hyprland session found; writing a generic entry"
    printf '%s\n' \
      "[Desktop Entry]" "Name=Ryoku" \
      "Comment=Ryoku Hyprland desktop (experimental shell install)" \
      "Exec=Hyprland" "Type=Application" "DesktopNames=Hyprland" \
      | sudo tee "$RSI_SESSION_FILE" >/dev/null
  fi
  rsi_record session "$RSI_SESSION_FILE"
}

# Enable the shell and supporting user services. Best-effort: a unit that is
# absent or a user systemd that is unreachable must not abort the install.
rsi_enable_services() {
  rsi_step "enabling user services"
  if [[ -x $RSI_BIN_HOME/ryoku-shell ]]; then
    if rsi_dry; then
      rsi_dim "  would enable ryoku-shell.service"
    else
      env RYOKU_SHELL_RUNTIME_DIR="$RSI_QUICKSHELL_DIR" "$RSI_BIN_HOME/ryoku-shell" service enable >/dev/null 2>&1 \
        || rsi_warn "could not enable ryoku-shell.service now (it starts from Hyprland on first login)"
    fi
    rsi_record service ryoku-shell.service
  fi

  local unit
  for unit in hypridle.service ryoku-resume-listener.service; do
    if rsi_dry; then
      rsi_dim "  would enable $unit"
      rsi_record service "$unit"
      continue
    fi
    if systemctl --user enable "$unit" >/dev/null 2>&1; then
      rsi_record service "$unit"
    else
      rsi_warn "skipped $unit (unit not present or user systemd unavailable)"
    fi
  done

  rsi_dry || systemctl --user daemon-reload >/dev/null 2>&1 || true
}

rsi_deploy() {
  rsi_manifest_init
  rsi_deploy_payload
  rsi_deploy_shell
  rsi_link_commands
  rsi_seed_configs
  rsi_install_session
  rsi_enable_services
  rsi_ok "deploy complete"
}
