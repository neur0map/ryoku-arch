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


# Ryoku shell: one product, canonical layers

Ryoku is a single shell and dotfile config of its own. Code under `shell/` was
adapted from several upstream projects (see `CREDITS.md` for attribution) but
NONE of them are tracked upstream: it is all Ryoku now, evolved as
one cohesive product. Do not reason about `shell/dashboard/` or `shell/settingsgui/`
as separate shells; they are integrated Ryoku components.

The ONLY vendored external kept faithful to upstream is `vendor/qylock/` (the
lockscreen and SDDM theme). `skwd-wall` and `hyprmod` are AUR packages, not
vendored. Leave those three alone; everything else under `shell/` is Ryoku-owned
and may be reorganized freely.

Canonical layers (use these; do not add parallel surfaces elsewhere):

- Config: the typed `Ryoku.Config` / `GlobalConfig` layer in
  `shell/plugin/src/Ryoku/Config/`, persisted to `~/.config/ryoku/shell.json`.
  New user-facing config keys go HERE (the Vicinae launcher toggle is the
  reference example). Do NOT add new keys to the legacy dashboard store
  (`~/.config/ryoku/dashboard/*`, `shell/dashboard/config/Config.qml`) or settings-gui store
  (`~/.config/ryoku/settings-gui/settings.json`). Those hold the existing desktop config;
  consolidating how its defaults ("the rice") ship is tracked in
  `docs/ryoku-config-architecture.md`.
- Settings UI: the settings-gui `SettingsContent`
  (`shell/settingsgui/Modules/Panels/Settings/Tabs/`), opened by `ryoku-shell settings`.
  New settings UI is a tab or sub-tab there, bound to `GlobalConfig`. The Ryoku
  dashboard "Settings" tab (`shell/dashboard/modules/widgets/dashboard/controls/SettingsTab.qml`)
  is a parallel surface being retired: do NOT add settings to it.
- IPC: Ryoku's own `ryoku-shell ipc <target> <fn>` (run `ryoku-shell ipc show`
  for the live registry). Keybinds live only in `config/hypr/hyprland.conf`
  (Ryoku-owned); per the config contract it reaches existing installs only via a
  `[global]` migration, and user overrides go in `config/hypr/custom.conf`.

Licensing: `shell/dashboard/` is AGPL-3.0 (keep its `ATTRIBUTION.md` and AGPL header
obligations); `shell/settingsgui/` is MIT. Unifying identity does not relicense
borrowed code: keep attribution intact.

# Ryoku Settings and System Architecture

When working on Ryoku settings, treat settings as a control surface, not as the owner of behavior or visual truth.

The user's files are the source of truth. Settings is a control surface over them,
never their owner:

- A hand edit to a config file is honored. The typed config round-trips keys it does
  not model (`ConfigObject::loadFromJson`/`toJsonObject` keep unknown keys), so editing
  `~/.config/ryoku/shell.json` by hand never loses data on the next save.
- The Settings UI must not overwrite a value the user set. A save writes the user's
  current state plus their untouched keys, never a fresh model that drops them.
- The rice and `shell/rice/config-overrides.json` only *seed*: forced over upstream
  defaults on a fresh install, fill-if-missing on update (`merge_config_overrides`).
  They never revert a value an existing user already chose.
- To push a changed default onto existing users, ship a `[global]` migration. That is
  the only mechanism allowed to touch live user config (see
  `docs/ryoku-config-architecture.md`).

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

`main` and `unstable-dev` are the workspaces for the full product (ISO + shell):
develop the shell and the system together here so the shell and the ISO cannot
drift. Standalone shell installs (`shell-install/`) pull a channel branch
directly; there is no separate generated branch. See `docs/ryoku-shell-branch.md`
for the product vs provisioning boundary. (The old `rebirth` workflow is retired.)

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
git switch unstable-dev   # bleeding-edge dev line (promote to main for release)
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

<!-- prowl-agent -->
## Prowl Agent (code intelligence)

This rice is indexed by **prowl-agent** (MCP server: `prowl-agent serve`).
**Prefer prowl-agent queries before reading files manually.** They return cited,
bounded context; open raw files only after a query points you to them.

Tools: `overview`, `clusters`, `find_symbol`, `find_references`, `find_callers`, `find_callees`, `file_relations`, `blast_radius`, `entrypoints_for`, `tests_for`, `similar_code`, `smart_search`, `architecture_violations`, `repo_hotspots`, `doctor`, `status`.

### Ricing playbook

- **New session / unfamiliar rice:** call `overview` first, then `clusters` to grab a whole subsystem.
- **Fuzzy / natural-language question:** use `smart_search` (or `similar_code`); pass `detail: compact` to list files before pulling snippets.
- **Before changing a color/font/var:** `find_symbol` it, then `find_references` to see every usage; check `architecture_violations` for hardcoded duplicates.
- **Before editing or deleting a file or script:** run `blast_radius` to see what breaks, and `find_callers` to see what invokes it.
- **Adding a keybind:** run `doctor` first to avoid `duplicate_keybind` conflicts.
- **Tracing startup:** `entrypoints_for` a file to find the WM/session entry and autostart chain.
- **Before committing:** run `doctor` and resolve errors (cycles, dangling refs, broken commands).
<!-- /prowl-agent -->
