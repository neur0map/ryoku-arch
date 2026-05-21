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
Settings UI -> Config.setNestedValue() or a narrow IPC/command adapter -> shared service/tokens -> shell-wide consumers
```

Rules:

- Do not implement global visuals as local properties on the settings window.
- Add user-facing config keys in both `shell/modules/common/Config.qml` and `shell/defaults/config.json`.
- Put visual interpretation in `shell/modules/common/Appearance.qml` for Material ii or `shell/modules/waffle/looks/Looks.qml` for Waffle.
- Make bar, panels, sidebars, overview, launchers, popups, and settings consume the same tokens.
- Settings pages under `shell/modules/settings/`, `shell/ryokuSettings.qml`, `shell/settings.qml`, and `shell/waffleSettings.qml` should mutate config and explain options. They should not become one-off style engines.
- For system behavior, prefer a named `ryoku-*` command with a small QML service or IPC adapter. Do not put package, sudo, systemd, network, hardware, or migration logic directly in a settings component.
- Verify a settings change by toggling it and checking at least one non-settings shell surface or system command result.

The migrated core is part of the product. Before adding shell UI for a feature, check whether an existing `ryoku-*` command already owns it. Common core domains include packages, updates, snapshots, rollback, migrations, Niri config, keybinds, themes, wallpaper, fonts, cursor, hardware toggles, power profiles, services, firewall, hosts, VPN, DNS, webapps, and app installs.

# Ryoku Development Environment

Use `unstable-dev` for new work. Keep `main` untouched unless explicitly asked to release or merge.

Development tree:

```bash
cd "$HOME/prowl/ryoku-arch"
git checkout unstable-dev
git status --short
```

Runtime preview for shell-only edits:

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
rsync -a --delete "$DEV/shell/" "$RUNT/"
systemctl --user restart ryoku-shell.service
```

Installed repo:

```bash
git -C "$HOME/.local/share/ryoku" status -sb
```

Do not manually copy experiments into `$HOME/.local/share/ryoku`. That checkout is the installed update tree. If it drifts, updates and channel switching break.

Before committing settings or IPC work, run the narrow checks that match the touched area. Prefer existing tests under `tests/` and shell checks for changed scripts. If a local hook fails on unrelated existing warnings, report that clearly instead of hiding it.

