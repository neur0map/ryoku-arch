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

# Copy-if-missing for app configs (never touch what the user already has),
# except ~/.config/hypr which Ryoku must own for its session to work: that
# one is backed up then deployed (reversible transition).
rsi_seed_configs() {
  rsi_step "seeding configs into $RSI_CONFIG_HOME"
  local src="$RSI_RYOKU_PATH/config"
  [[ -d $src ]] || { rsi_warn "no config payload at $src"; return 0; }

  local entry name dst
  for entry in "$src"/*; do
    [[ -e $entry ]] || continue
    name="$(basename "$entry")"
    dst="$RSI_CONFIG_HOME/$name"

    if [[ $name == hypr ]]; then
      rsi_backup "$dst"
      rsi_run mkdir -p "$dst"
      if rsi_dry; then
        rsi_dim "  would deploy Ryoku hypr config to $dst"
      else
        rsync -a "$entry/" "$dst/"
      fi
      rsi_record dir "$dst"
      continue
    fi

    if [[ -e $dst ]]; then
      rsi_dim "  keeping existing $dst"
      continue
    fi
    if rsi_dry; then
      rsi_dim "  would copy $name -> $dst"
    else
      cp -a "$entry" "$dst"
    fi
    rsi_record file "$dst"
  done
}

# Register a distinctly-named Ryoku wayland session beside the user's existing
# sessions. The only path written with sudo.
rsi_install_session() {
  rsi_step "registering the Ryoku wayland session"
  rsi_backup "$RSI_SESSION_FILE"
  local content="[Desktop Entry]
Name=Ryoku
Comment=Ryoku Hyprland desktop (experimental shell install)
Exec=Hyprland
Type=Application
DesktopNames=Hyprland"
  if rsi_dry; then
    rsi_dim "  would sudo-write $RSI_SESSION_FILE"
  else
    sudo install -d "$(dirname "$RSI_SESSION_FILE")"
    printf '%s\n' "$content" | sudo tee "$RSI_SESSION_FILE" >/dev/null
  fi
  rsi_record session "$RSI_SESSION_FILE"
}

# Enable the shell and idle user services if their units are present.
rsi_enable_services() {
  rsi_step "enabling user services"
  if [[ -x $RSI_BIN_HOME/ryoku-shell ]]; then
    rsi_run env RYOKU_SHELL_RUNTIME_DIR="$RSI_QUICKSHELL_DIR" "$RSI_BIN_HOME/ryoku-shell" service enable
    rsi_record service ryoku-shell.service
  fi
  if systemctl --user list-unit-files hypridle.service >/dev/null 2>&1; then
    rsi_run systemctl --user enable hypridle.service
    rsi_record service hypridle.service
  fi
  rsi_run systemctl --user daemon-reload
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
