# Style

- Two spaces for indentation, no tabs
- Use bash 5 conditionals: use `[[ ]]` for string/file tests and `(( ))` for numeric tests
- In `[[ ]]`, don't quote variables, but do quote string literals when comparing values (e.g., `[[ $branch == "dev" ]]`)
- Prefer `(( ))` over numeric operators inside `[[ ]]` (e.g., `(( count < 50 ))`, not `[[ $count -lt 50 ]]`)
- For strings/paths with spaces, quote them instead of escaping spaces with `\ ` (e.g., `"$APP_DIR/Disk Usage.desktop"`, not `$APP_DIR/Disk\ Usage.desktop`)
- Shebangs must use `#!/bin/bash` consistently (never `#!/usr/bin/env bash`)

# Command Naming

Ryoku commands use the `ryoku-` prefix. Legacy old-prefix wrappers remain only as compatibility bridges while migrations are still draining. Prefixes indicate purpose:

- `cmd-` - check if commands exist, misc utility commands
- `pkg-` - package management helpers
- `hw-` - hardware detection (return exit codes for use in conditionals)
- `refresh-` - copy default config to user's `~/.config/`
- `restart-` - restart a component
- `launch-` - open applications
- `install-` - install optional software
- `setup-` - interactive setup wizards
- `toggle-` - toggle features on/off
- `theme-` - theme management
- `update-` - update components

# Helper Commands

Use these instead of raw shell commands:

- `ryoku-cmd-missing` / `ryoku-cmd-present` - check for commands
- `ryoku-pkg-missing` / `ryoku-pkg-present` - check for packages
- `ryoku-pkg-add` - install packages (handles both pacman and AUR)
- `ryoku-hw-asus-rog` - detect ASUS ROG hardware (and similar `hw-*` commands)

# Config Structure

- `config/` - default configs copied to `~/.config/`
- `default/themed/*.tpl` - templates with `{{ variable }}` placeholders for theme colors
- `themes/*/colors.toml` - theme color definitions (accent, background, foreground, color0-15)

# Refresh Pattern

To copy a default config to user config with automatic backup:

```bash
ryoku-refresh-config hypr/hyprlock.conf
```

This copies `~/.local/share/ryoku/config/hypr/hyprlock.conf` to `~/.config/hypr/hyprlock.conf`.

# Migrations

To create a new migration, run `ryoku-dev-add-migration --no-edit`. This creates a migration file named after the unix timestamp of the last commit.

Migration format:
- No shebang line
- Start with an `echo` describing what the migration does
- Use `$RYOKU_PATH` to reference the Ryoku directory

Example:
```bash
echo "Disable fingerprint in hyprlock if fingerprint auth is not configured"

if ryoku-cmd-missing fprintd-list || ! fprintd-list "$USER" 2>/dev/null | grep -q "finger"; then
  sed -i 's/fingerprint:enabled = .*/fingerprint:enabled = false/' ~/.config/hypr/hyprlock.conf
fi
```


# Ryoku Settings and System Architecture

When working on Ryoku settings, treat settings as a control surface, not as the owner of behavior or visual truth.

Required flow:

```text
Settings UI -> GlobalConfig property or narrow IPC/command adapter -> shared tokens/services -> shell-wide consumers
```

Rules:

- Do not implement global visuals as local properties on a settings or control-center page.
- Add user-facing config keys in the typed config layer under `shell/plugin/src/Ryoku/Config/`.
- Persist settings through `GlobalConfig.saveConfig()` after changing `GlobalConfig` properties.
- Put shared visual interpretation in the config/tokens layer and consume it through `import Ryoku.Config`.
- Make the bar, popouts, sidebars, dashboard, launcher, lock-adjacent surfaces, and control center consume the same tokens and services.
- Settings and control-center pages under `shell/modules/controlcenter/`, `shell/modules/dashboard/`, `shell/modules/sidebar/`, and related shell modules should mutate config and expose choices. They should not become one-off style engines.
- For system behavior, prefer a named `ryoku-*` command with a small QML service or IPC adapter. Do not put package, sudo, systemd, network, hardware, or migration logic directly in a QML component.
- Verify a settings change by toggling it and checking at least one non-settings shell surface or system command result.

The migrated core is part of the product. Before adding shell UI for a feature, check whether an existing `ryoku-*` command already owns it. Common core domains include packages, updates, snapshots, rollback, migrations, Hyprland config, keybinds, themes, wallpaper, fonts, cursor, hardware toggles, power profiles, services, firewall, hosts, VPN, DNS, webapps, and app installs.

# Ryoku Workstation Environment

Use `rebirth` for Hyprland workstation work. Keep `main` untouched unless explicitly asked to release or merge.

Primary paths on this workstation:

```bash
DEV="$HOME/prowl/ryoku-arch"
INSTALL="$HOME/.local/share/ryoku"
SHELL_PATH="$HOME/.local/share/ryoku-shell"
RUNTIME="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
```

Development tree:

```bash
cd "$HOME/prowl/ryoku-arch"
git checkout rebirth
git status --short
```

Runtime preview for shell-only edits:

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNTIME="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
RYOKU_DEV_PATH="$DEV" "$DEV/shell/setup" install -y -q --skip-deps --skip-setups --skip-sysupdate --skip-build
systemctl --user restart ryoku-shell.service
```

Installed repo and live shell state:

```bash
git -C "$HOME/.local/share/ryoku" status -sb
env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST qs list --all
systemctl --user status ryoku-shell.service --no-pager
ryoku-doctor shell
```

Do not manually copy experiments into `$HOME/.local/share/ryoku`. That checkout is the installed update tree. If the user explicitly asks for live mirror parity, patch only the scoped files there, check `git -C "$HOME/.local/share/ryoku" status -sb`, and verify the same behavior in the development tree and installed tree.

Before committing settings, shell, IPC, or documentation work, run the narrow checks that match the touched area. Prefer existing tests under `tests/` and shell checks for changed scripts. If a local hook fails on unrelated existing warnings, report that clearly instead of hiding it.
