# Noctalia Settings Ryoku Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the default `Super+Alt+Space` settings experience with Noctalia's centered settings panel, preserving Noctalia's visual frontend and layout while adapting only the backend bindings to Ryoku. Keep the current Brain Shell settings menu available as a legacy fallback until explicitly removed.

**Architecture:** Vendor Noctalia upstream as an attributed source snapshot, generate a Ryoku runtime namespace from the Noctalia settings/UI/widget modules, and route all system integration through Ryoku adapter services. The new panel is opened through Ryoku IPC and existing keybindings. Unsupported Noctalia pages remain visible and searchable, but disabled. Wi-Fi and Bluetooth are active v1 pages backed by Ryoku-compatible providers.

**Tech Stack:** Quickshell QML, QtQuick, Quickshell service APIs where available, Ryoku IPC Bash scripts, Hyprland bindings, `iwd`/`iwctl`, optional `nmcli`, `bluetoothctl`/BlueZ, Bash static regression tests.

---

## File Structure

- Add: `config/quickshell/ryoku/vendor/noctalia-shell/UPSTREAM.md`
  - Records the upstream repository, pinned commit, source date, purpose, local adaptation rules, and update procedure.
- Add: `config/quickshell/ryoku/vendor/noctalia-shell/LICENSE`
  - Exact Noctalia MIT license copy.
- Add: `config/quickshell/ryoku/vendor/noctalia-shell/upstream/`
  - Byte-for-byte Noctalia snapshot copied from commit `9f8dd48c8df5ab1f7f87ddf9842627e1e5682186`, excluding `.git`.
- Add: `config/quickshell/ryoku/Noctalia/`
  - Runtime-adapted Noctalia QML namespace used by Ryoku. Imports are rewritten to `qs.Noctalia.*`; backend-facing services are replaced with Ryoku adapters.
- Add: `config/quickshell/ryoku/Noctalia/Services/Ryoku/`
  - Ryoku adapter helpers for feature availability, command execution, IPC routing, file paths, and command capability detection.
- Add: `config/quickshell/ryoku/Noctalia/Services/Networking/`
  - Ryoku Wi-Fi and Bluetooth services, including `iwd` first and optional `nmcli` provider files.
- Add or modify: `config/quickshell/ryoku/Noctalia/**/qmldir`
  - Registers copied Noctalia components and Ryoku adapter singletons required by `qs.Noctalia.*` imports.
- Modify: `config/quickshell/ryoku/shell.qml`
  - Instantiates the Noctalia settings window and routes IPC methods to either the new centered panel or the legacy Brain Shell menu.
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`
  - Splits old settings state into an explicit legacy settings-menu state.
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml`
  - Keeps the old `SettingsMenuPopup` mounted only for the legacy fallback state.
- Modify: `bin/ryoku-ipc`
  - Keeps `shell toggle settings-menu` as the new Noctalia panel route, adds `legacy-settings-menu`, and adds direct subtab commands for Wi-Fi, Bluetooth, and other settings tabs.
- Modify: `default/hypr/bindings/utilities.conf`
  - Keeps `Super+Alt+Space` bound to the new settings panel and moves Wi-Fi/Bluetooth shortcuts from TUI launchers to centered settings subtabs.
- Modify: `tests/ryoku-ipc.sh`
  - Covers default, legacy, and subtab IPC routing.
- Add: `tests/quickshell-noctalia-settings.sh`
  - Static regression coverage for vendoring, namespace rewrite, panel geometry, disabled page handling, no full Noctalia shell bootstrap, and IPC integration.
- Add: `tests/quickshell-noctalia-network-providers.sh`
  - Static regression coverage for `iwd`, optional `nmcli`, Bluetooth, and secret-handling constraints.
- Modify: `tests/quickshell-topbar-settings-menus.sh`
  - Reclassifies the old Brain Shell settings menu as the legacy fallback instead of the default settings experience.
- Modify: `README.md`
  - Credits Noctalia settings UI and describes the new Ryoku settings entry points.
- Add or modify: `CREDITS.md`
  - Adds Noctalia attribution if the file exists; create it if missing.
- Add or modify: `NOTICE`
  - Adds Noctalia MIT notice if the file exists; create it if missing.

---

## Implementation Rules

- Preserve Noctalia's frontend layout and visual components. Runtime edits are limited to import paths, adapter service injection, disabled-state guards, command wiring, and screen-safe geometry caps.
- Do not instantiate Noctalia `ShellRoot`, bar, dock, desktop widgets, notification daemon, setup wizard, plugin loader, updater, telemetry, or autonomous config migration code.
- Do not remove the current Brain Shell `SettingsMenuPopup.qml`. It remains available through `legacy-settings-menu`.
- Do not add NetworkManager as a hard dependency. Prefer Ryoku's existing `iwd` setup. Use `nmcli` only when present.
- Do not pass Wi-Fi passwords on a command line. Passwords must go through stdin, a Quickshell process input channel, or an equivalent non-argv channel.
- Keep disabled pages visible and searchable. A disabled page must render the Noctalia page shell with disabled controls and a concise unavailable state inside the page.
- Use two-space indentation in new shell/QML files.

---

### Task 1: Add Static Tests For The New Settings Contract

**Files:**
- Add: `tests/quickshell-noctalia-settings.sh`
- Add: `tests/quickshell-noctalia-network-providers.sh`
- Modify: `tests/ryoku-ipc.sh`
- Modify: `tests/quickshell-topbar-settings-menus.sh`

- [ ] **Step 1: Add the Noctalia settings static test**

Create `tests/quickshell-noctalia-settings.sh`:

```bash
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

vendor="config/quickshell/ryoku/vendor/noctalia-shell"
runtime="config/quickshell/ryoku/Noctalia"
shell_qml="config/quickshell/ryoku/shell.qml"

[[ -f $vendor/UPSTREAM.md ]] || fail "Noctalia vendor metadata should exist"
[[ -f $vendor/LICENSE ]] || fail "Noctalia MIT license should be copied"
grep -q 'https://github.com/noctalia-dev/noctalia-shell' "$vendor/UPSTREAM.md" \
  || fail "UPSTREAM should record the Noctalia repository"
grep -q '9f8dd48c8df5ab1f7f87ddf9842627e1e5682186' "$vendor/UPSTREAM.md" \
  || fail "UPSTREAM should pin the reviewed Noctalia commit"
grep -q 'MIT License' "$vendor/LICENSE" \
  || fail "Noctalia license should be MIT"

[[ -f $vendor/upstream/Modules/Panels/Settings/SettingsPanelWindow.qml ]] \
  || fail "Upstream Noctalia settings window should be vendored"
[[ -f $vendor/upstream/Modules/Panels/Settings/SettingsContent.qml ]] \
  || fail "Upstream Noctalia settings content should be vendored"
[[ -f $vendor/upstream/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml ]] \
  || fail "Upstream Noctalia Wi-Fi subtab should be vendored"
[[ -f $vendor/upstream/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml ]] \
  || fail "Upstream Noctalia Bluetooth subtab should be vendored"

[[ -f $runtime/Modules/Panels/Settings/SettingsPanelWindow.qml ]] \
  || fail "Runtime Noctalia settings window should exist"
[[ -f $runtime/Modules/Panels/Settings/SettingsContent.qml ]] \
  || fail "Runtime Noctalia settings content should exist"
[[ -f $runtime/Services/UI/RyokuSettingsPanelService.qml ]] \
  || fail "Ryoku settings panel service should exist"
[[ -f $runtime/Services/Ryoku/RyokuFeatureAvailability.qml ]] \
  || fail "Ryoku feature availability service should exist"

grep -q 'import qs.Noctalia.Commons' "$runtime/Modules/Panels/Settings/SettingsPanelWindow.qml" \
  || fail "Runtime settings window should import the Noctalia runtime namespace"
! rg -n '^import qs\.(Commons|Widgets|Services|Modules|Assets)' "$runtime" \
  || fail "Runtime Noctalia files should not import the upstream root namespace"
rg -n 'import qs.Noctalia' "$runtime" >/dev/null \
  || fail "Runtime Noctalia files should use qs.Noctalia imports"

grep -q 'SettingsPanelWindow' "$shell_qml" \
  || fail "Ryoku shell should instantiate the Noctalia settings window"
grep -q 'toggleLegacySettingsMenu' "$shell_qml" \
  || fail "Ryoku shell should keep a legacy settings-menu route"
grep -q 'openSettingsRoute' "$shell_qml" \
  || fail "Ryoku shell should route settings subtabs through IPC"
! rg -n 'ShellRoot|PluginRegistry\.init|TelemetryService|UpdateService|SetupWizard|shouldOpenSetupWizard' "$shell_qml" "$runtime" \
  || fail "Ryoku should not bootstrap the full Noctalia shell"

grep -Eq 'implicitWidth:[[:space:]]+840|panelWidth:[[:space:]]+840|width:[[:space:]]+840' "$runtime/Modules/Panels/Settings/SettingsPanelWindow.qml" \
  || fail "Settings panel should preserve Noctalia's 840px visual width"
grep -Eq 'implicitHeight:[[:space:]]+910|panelHeight:[[:space:]]+910|height:[[:space:]]+910' "$runtime/Modules/Panels/Settings/SettingsPanelWindow.qml" \
  || fail "Settings panel should preserve Noctalia's 910px visual height"
grep -Eq 'Math\.min|availableGeometry|screen\.width|screen\.height' "$runtime/Modules/Panels/Settings/SettingsPanelWindow.qml" \
  || fail "Settings panel should cap size to available screen geometry"

for tab in General UserInterface ColorScheme Wallpaper Bar Dock DesktopWidgets ControlCenter Launcher Notifications OSD LockScreen SessionMenu Idle Audio Display Connections Location System Plugins Hooks About; do
  grep -q "SettingsPanel.Tab.$tab" "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
    || fail "Settings tab $tab should remain present"
done

grep -q 'featureAvailable' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Settings content should consult feature availability"
grep -q 'enabled:.*featureAvailable' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Unavailable settings controls should be disabled"
grep -q 'searchable' "$runtime/Modules/Panels/Settings/SettingsContent.qml" \
  || fail "Unavailable settings pages should remain searchable"

grep -q 'ryoku/noctalia-settings/settings.json' "$runtime/Commons/Settings.qml" \
  || fail "Runtime settings should use a Ryoku-owned settings path"
grep -q 'ryoku/noctalia-settings/state.json' "$runtime/Services/UI/RyokuSettingsPanelService.qml" \
  || fail "Panel state should use a Ryoku-owned state path"

grep -q 'legacy-settings-menu' bin/ryoku-ipc \
  || fail "ryoku-ipc should expose the legacy settings-menu route"
grep -q 'settings-menu wifi' bin/ryoku-ipc \
  || fail "ryoku-ipc should expose a Wi-Fi settings route"
grep -q 'settings-menu bluetooth' bin/ryoku-ipc \
  || fail "ryoku-ipc should expose a Bluetooth settings route"

grep -q 'SUPER ALT, SPACE' default/hypr/bindings/utilities.conf \
  || fail "Super+Alt+Space binding should remain declared"
grep -q 'ryoku-ipc shell toggle settings-menu' default/hypr/bindings/utilities.conf \
  || fail "Super+Alt+Space should open the new settings panel"
grep -q 'settings-menu wifi' default/hypr/bindings/utilities.conf \
  || fail "Wi-Fi shortcut should open the settings Wi-Fi subtab"
grep -q 'settings-menu bluetooth' default/hypr/bindings/utilities.conf \
  || fail "Bluetooth shortcut should open the settings Bluetooth subtab"
```

Make it executable:

```bash
chmod +x tests/quickshell-noctalia-settings.sh
```

- [ ] **Step 2: Add the network-provider static test**

Create `tests/quickshell-noctalia-network-providers.sh`:

```bash
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

runtime="config/quickshell/ryoku/Noctalia"
network_dir="$runtime/Services/Networking"

[[ -f $network_dir/RyokuNetworkService.qml ]] \
  || fail "Ryoku network service should exist"
[[ -f $network_dir/IwdProvider.qml ]] \
  || fail "Ryoku network service should include an iwd provider"
[[ -f $network_dir/NmcliProvider.qml ]] \
  || fail "Ryoku network service should include an optional nmcli provider"
[[ -f $network_dir/RyokuBluetoothService.qml ]] \
  || fail "Ryoku Bluetooth service should exist"

grep -q 'iwctl' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should use iwctl"
grep -q 'station.*scan' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should support scanning"
grep -q 'station.*get-networks' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should support listing networks"
grep -q 'passphrase' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should support secured network connections"
grep -Eq 'stdin|write|input|process\.stdin' "$network_dir/IwdProvider.qml" \
  || fail "Wi-Fi secrets should be supplied through process input, not argv"
! rg -n 'iwctl.*(password|passphrase|psk|secret).*argv|command:.*(password|passphrase|psk|secret)' "$network_dir" \
  || fail "Wi-Fi passwords should not be placed in command arguments"

grep -q 'nmcli' "$network_dir/NmcliProvider.qml" \
  || fail "optional NetworkManager provider should use nmcli"
grep -Eq 'ryoku-cmd-present|commandExists|which|hasCommand' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should detect available providers"
grep -Eq 'iwd|IwdProvider' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should prefer iwd for Ryoku"
grep -Eq 'nmcli|NmcliProvider' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should fall back to nmcli only when present"

grep -q 'bluetoothctl' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should use bluetoothctl"
grep -q 'scan on' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support scanning"
grep -q 'pair' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support pairing"
grep -q 'connect' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support connecting"
grep -q 'trust' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support trusted devices"

grep -q 'RyokuNetworkService' "$runtime/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml" \
  || fail "Wi-Fi subtab should use the Ryoku network service"
grep -q 'RyokuBluetoothService' "$runtime/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml" \
  || fail "Bluetooth subtab should use the Ryoku Bluetooth service"
```

Make it executable:

```bash
chmod +x tests/quickshell-noctalia-network-providers.sh
```

- [ ] **Step 3: Extend IPC tests**

In `tests/ryoku-ipc.sh`, add assertions that exercise these command forms:

```bash
assert_has_route "shell toggle settings-menu"
assert_has_route "shell toggle legacy-settings-menu"
assert_has_route "shell settings-menu wifi"
assert_has_route "shell settings-menu bluetooth"
assert_has_route "shell settings-menu color-scheme"
assert_has_route "shell settings-menu wallpaper"
assert_has_route "shell settings-menu display"
assert_has_route "shell settings-menu audio"
```

If `tests/ryoku-ipc.sh` does not have an `assert_has_route` helper, add a local helper that invokes the script help or dry route listing already used by the test. Keep the helper side-effect free.

- [ ] **Step 4: Reclassify the current topbar settings menu as legacy**

In `tests/quickshell-topbar-settings-menus.sh`, update assertions that describe the old menu as the default. The test should still verify:

```bash
grep -q 'legacySettingsMenuOpen' config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml \
  || fail "Brain Shell settings popup should be guarded by legacy settings-menu state"
grep -q 'legacySettingsMenuOpen' config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml \
  || fail "Legacy settings popup should be mounted through the legacy popup state"
```

Remove or rewrite any assertion that requires `SettingsMenuPopup.qml` to be opened by the default `settings-menu` route.

- [ ] **Step 5: Run the new and modified tests and confirm they fail**

Run:

```bash
tests/quickshell-noctalia-settings.sh
tests/quickshell-noctalia-network-providers.sh
tests/ryoku-ipc.sh
tests/quickshell-topbar-settings-menus.sh
```

Expected result: the first two tests fail because no vendor/runtime tree exists yet; IPC and topbar tests fail on the new routes/state split.

- [ ] **Step 6: Commit the failing test contract**

Run:

```bash
git add tests/quickshell-noctalia-settings.sh tests/quickshell-noctalia-network-providers.sh tests/ryoku-ipc.sh tests/quickshell-topbar-settings-menus.sh
git commit -m "test: specify noctalia settings integration"
```

---

### Task 2: Vendor Noctalia With Attribution

**Files:**
- Add: `config/quickshell/ryoku/vendor/noctalia-shell/UPSTREAM.md`
- Add: `config/quickshell/ryoku/vendor/noctalia-shell/LICENSE`
- Add: `config/quickshell/ryoku/vendor/noctalia-shell/upstream/`
- Modify: `README.md`
- Add or modify: `CREDITS.md`
- Add or modify: `NOTICE`

- [ ] **Step 1: Prepare the pinned upstream snapshot**

Ensure `/tmp/noctalia-shell` contains the reviewed commit:

```bash
if [[ ! -d /tmp/noctalia-shell/.git ]]; then
  git clone https://github.com/noctalia-dev/noctalia-shell /tmp/noctalia-shell
fi
git -C /tmp/noctalia-shell fetch origin 9f8dd48c8df5ab1f7f87ddf9842627e1e5682186
git -C /tmp/noctalia-shell checkout 9f8dd48c8df5ab1f7f87ddf9842627e1e5682186
```

- [ ] **Step 2: Copy the upstream source snapshot**

Create the vendor directory and copy the source excluding `.git`:

```bash
mkdir -p config/quickshell/ryoku/vendor/noctalia-shell/upstream
rsync -a --delete --exclude .git /tmp/noctalia-shell/ config/quickshell/ryoku/vendor/noctalia-shell/upstream/
cp /tmp/noctalia-shell/LICENSE config/quickshell/ryoku/vendor/noctalia-shell/LICENSE
```

If `rsync` is not installed, use `cp -a` after emptying only `config/quickshell/ryoku/vendor/noctalia-shell/upstream` with explicit approval when needed.

- [ ] **Step 3: Add `UPSTREAM.md`**

Create `config/quickshell/ryoku/vendor/noctalia-shell/UPSTREAM.md`:

```markdown
# Noctalia Shell Upstream Snapshot

Repository: https://github.com/noctalia-dev/noctalia-shell
Pinned commit: 9f8dd48c8df5ab1f7f87ddf9842627e1e5682186
License: MIT
Imported for: Ryoku centered settings panel UI, layout, widgets, and settings-page structure.

## Local Integration

- `upstream/` is a source snapshot for attribution and drift review.
- Runtime QML used by Ryoku lives in `../../Noctalia/`.
- Runtime changes are limited to import namespace rewrites, Ryoku backend adapters, disabled-feature guards, settings paths, and screen-safe geometry caps.
- Ryoku must not instantiate Noctalia `ShellRoot`, bar, dock, desktop widgets, setup wizard, plugin loader, updater, telemetry, or autonomous migrations.

## Update Procedure

1. Review upstream settings, widgets, services, and license changes.
2. Replace `upstream/` with the new pinned snapshot.
3. Rebuild the runtime namespace from the settings-related modules only.
4. Re-apply Ryoku adapter changes.
5. Run `tests/quickshell-noctalia-settings.sh` and `tests/quickshell-noctalia-network-providers.sh`.
6. Update this file with the new commit.
```

- [ ] **Step 4: Add repository-level attribution**

Update `README.md` with a concise credit:

```markdown
Ryoku's centered settings panel UI is adapted from Noctalia Shell, MIT licensed, with Ryoku-specific backend adapters. See `config/quickshell/ryoku/vendor/noctalia-shell/UPSTREAM.md`.
```

Create or update `CREDITS.md`:

```markdown
# Credits

## Noctalia Shell

Ryoku's centered settings panel UI, layout, widgets, and settings-page structure are adapted from Noctalia Shell.

- Repository: https://github.com/noctalia-dev/noctalia-shell
- License: MIT
- Pinned snapshot: `9f8dd48c8df5ab1f7f87ddf9842627e1e5682186`
```

Create or update `NOTICE`:

```text
Noctalia Shell
Copyright (c) 2025 noctalia-dev
Licensed under the MIT License.
Source: https://github.com/noctalia-dev/noctalia-shell
Pinned commit: 9f8dd48c8df5ab1f7f87ddf9842627e1e5682186
```

- [ ] **Step 5: Run attribution tests**

Run:

```bash
tests/quickshell-noctalia-settings.sh
```

Expected result: vendor metadata assertions pass; runtime assertions still fail.

- [ ] **Step 6: Commit vendor snapshot and attribution**

Run:

```bash
git add config/quickshell/ryoku/vendor/noctalia-shell README.md CREDITS.md NOTICE
git commit -m "vendor: add noctalia settings source snapshot"
```

---

### Task 3: Build The Ryoku Noctalia Runtime Namespace

**Files:**
- Add: `config/quickshell/ryoku/Noctalia/`

- [ ] **Step 1: Copy only settings-required runtime modules**

Create the runtime namespace from the vendored snapshot:

```bash
mkdir -p config/quickshell/ryoku/Noctalia
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Assets config/quickshell/ryoku/Noctalia/
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Commons config/quickshell/ryoku/Noctalia/
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Widgets config/quickshell/ryoku/Noctalia/
mkdir -p config/quickshell/ryoku/Noctalia/Modules/Panels
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Modules/Panels/Settings config/quickshell/ryoku/Noctalia/Modules/Panels/
mkdir -p config/quickshell/ryoku/Noctalia/Services
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Services/UI config/quickshell/ryoku/Noctalia/Services/
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Services/Utils config/quickshell/ryoku/Noctalia/Services/
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Services/Theming config/quickshell/ryoku/Noctalia/Services/
cp -a config/quickshell/ryoku/vendor/noctalia-shell/upstream/Services/Networking config/quickshell/ryoku/Noctalia/Services/
```

Do not copy Noctalia root shell files, bars, dock modules outside the settings dependency chain, desktop widgets, setup wizard, or plugin loader.

- [ ] **Step 2: Rewrite QML imports to the Ryoku runtime namespace**

For all QML files under `config/quickshell/ryoku/Noctalia`, rewrite:

```text
import qs.Commons
import qs.Widgets
import qs.Services
import qs.Modules
import qs.Assets
```

to:

```text
import qs.Noctalia.Commons
import qs.Noctalia.Widgets
import qs.Noctalia.Services
import qs.Noctalia.Modules
import qs.Noctalia.Assets
```

Also rewrite deeper imports, for example:

```text
import qs.Modules.Panels.Settings
```

to:

```text
import qs.Noctalia.Modules.Panels.Settings
```

- [ ] **Step 3: Replace Noctalia settings persistence paths**

In `config/quickshell/ryoku/Noctalia/Commons/Settings.qml`, change Noctalia-owned paths to Ryoku-owned paths:

```qml
property string settingsPath: `${Paths.state}/ryoku/noctalia-settings/settings.json`
```

If the upstream file uses a different path shape, keep the same storage mechanism but make the resolved filename contain:

```text
ryoku/noctalia-settings/settings.json
```

- [ ] **Step 4: Add runtime import guard tests**

Run:

```bash
tests/quickshell-noctalia-settings.sh
```

Expected result: namespace/vendor assertions pass; panel service, feature availability, shell integration, and backend adapter assertions still fail.

- [ ] **Step 5: Commit the runtime namespace**

Run:

```bash
git add config/quickshell/ryoku/Noctalia
git commit -m "feat: add noctalia settings runtime namespace"
```

---

### Task 4: Add Ryoku Settings Panel Service And Centered Window Integration

**Files:**
- Add: `config/quickshell/ryoku/Noctalia/Services/UI/RyokuSettingsPanelService.qml`
- Modify: `config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/SettingsPanelWindow.qml`
- Modify: `config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/SettingsContent.qml`
- Modify: `config/quickshell/ryoku/shell.qml`

- [ ] **Step 1: Add `RyokuSettingsPanelService.qml`**

Create `config/quickshell/ryoku/Noctalia/Services/UI/RyokuSettingsPanelService.qml` as a Ryoku-owned equivalent of Noctalia's `SettingsPanelService`. Preserve the upstream window-facing API so the copied `SettingsPanelWindow.qml` only needs service-name and import edits:

```qml
pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool isWindowOpen: false
  property var settingsWindow: null
  property int requestedTab: 0
  property int requestedSubTab: -1
  property string requestedRoute: ""
  property var requestedEntry: null
  readonly property string statePath: `${Quickshell.env("HOME")}/.local/state/ryoku/noctalia-settings/state.json`

  signal windowOpened
  signal windowClosed

  function openToEntry(entry) {
    requestedEntry = entry
    if (settingsWindow) {
      settingsWindow.visible = true
      isWindowOpen = true
      windowOpened()
      settingsWindow.navigateToEntry(entry)
    }
  }

  function openToTab(tab, subTab) {
    const tabId = tab !== undefined ? tab : 0
    const subTabId = subTab !== undefined ? subTab : -1
    requestedTab = tabId
    requestedSubTab = subTabId
    if (settingsWindow) {
      settingsWindow.visible = true
      isWindowOpen = true
      windowOpened()
      settingsWindow.navigateTo(tabId, subTabId)
    }
  }

  function openWindow(tab) {
    openToTab(tab !== undefined ? tab : 0, -1)
  }

  function openRoute(route) {
    requestedRoute = route || "general"
    if (settingsWindow) {
      settingsWindow.visible = true
      isWindowOpen = true
      windowOpened()
      settingsWindow.navigateToRoute(requestedRoute)
    }
  }

  function closeWindow() {
    if (settingsWindow) {
      settingsWindow.visible = false
    }
    isWindowOpen = false
    windowClosed()
  }

  function toggle(tab, subTab) {
    if (isWindowOpen) {
      closeWindow()
    } else {
      openToTab(tab, subTab)
    }
  }

  function close() {
    closeWindow()
  }
}
```

Register the singleton in `config/quickshell/ryoku/Noctalia/Services/UI/qmldir`:

```text
singleton RyokuSettingsPanelService 1.0 RyokuSettingsPanelService.qml
```

- [ ] **Step 2: Switch `SettingsPanelWindow.qml` to the Ryoku service**

In `SettingsPanelWindow.qml`, replace the upstream service import/use with `RyokuSettingsPanelService`:

```qml
import qs.Noctalia.Services.UI
```

Keep the upstream initial visibility line:

```qml
visible: false
```

Keep `visible: false` as Noctalia does and let `RyokuSettingsPanelService` control `settingsWindow.visible`. In `Component.onCompleted`, register the window:

```qml
RyokuSettingsPanelService.settingsWindow = root
```

The close button and escape handling must call:

```qml
RyokuSettingsPanelService.close()
```

The panel must preserve Noctalia dimensions and add screen caps:

```qml
readonly property int panelWidth: 840
readonly property int panelHeight: 910
width: Math.min(panelWidth, screen ? screen.width - 24 : panelWidth)
height: Math.min(panelHeight, screen ? screen.height - 24 : panelHeight)
```

Keep Noctalia's floating centered placement logic. If upstream uses a helper window type that centers itself, keep that helper and only cap `width`/`height`.

Add a route navigation helper that mirrors Noctalia's existing `navigateTo` and `navigateToEntry` flow:

```qml
function navigateToRoute(route) {
  if (isInitialized) {
    settingsContent.openRoute(route)
  } else {
    settingsContent.requestedRoute = route
    settingsContent.initialize()
    Qt.callLater(() => settingsContent.openRoute(route))
    isInitialized = true
  }
}
```

- [ ] **Step 3: Route requested tabs into `SettingsContent.qml`**

In `SettingsContent.qml`, add `property string requestedRoute: ""` and route IPC strings through a small mapping function:

```qml
function routeToTab(route) {
  switch (route) {
  case "wifi":
  case "bluetooth":
  case "connections":
    return SettingsPanel.Tab.Connections
  case "color-scheme":
    return SettingsPanel.Tab.ColorScheme
  case "wallpaper":
    return SettingsPanel.Tab.Wallpaper
  case "display":
    return SettingsPanel.Tab.Display
  case "audio":
    return SettingsPanel.Tab.Audio
  default:
    return SettingsPanel.Tab.General
  }
}

function routeToSubTab(route) {
  switch (route) {
  case "wifi":
    return 0
  case "bluetooth":
    return 1
  default:
    return -1
  }
}

function openRoute(route) {
  requestedRoute = route || "general"
  navigateToTab(routeToTab(requestedRoute), routeToSubTab(requestedRoute))
}
```

This uses Noctalia's existing `navigateToTab(tabId, subTabIndex)` flow so the copied loader, scroll, and subtab logic remain intact.

- [ ] **Step 4: Instantiate the Noctalia settings panel in `shell.qml`**

Add the runtime import near the existing Brain Shell imports:

```qml
import qs.Noctalia.Modules.Panels.Settings as NoctaliaSettings
import qs.Noctalia.Services.UI as NoctaliaUI
```

Instantiate the panel once at shell root scope:

```qml
NoctaliaSettings.SettingsPanelWindow {
  id: noctaliaSettingsPanel
}
```

Add IPC-facing functions on the existing IPC object or shell root:

```qml
function toggleSettingsMenu() {
  NoctaliaUI.RyokuSettingsPanelService.toggle(0, -1)
}

function openSettingsMenu() {
  NoctaliaUI.RyokuSettingsPanelService.openWindow(0)
}

function openSettingsRoute(route) {
  NoctaliaUI.RyokuSettingsPanelService.openRoute(route)
}

function closeSettingsMenu() {
  NoctaliaUI.RyokuSettingsPanelService.close()
}
```

Use the actual IPC handler pattern in `shell.qml`; do not add a parallel IPC server.

- [ ] **Step 5: Verify shell integration**

Run:

```bash
tests/quickshell-noctalia-settings.sh
```

Expected result: window/service/shell assertions pass; feature availability and network assertions still fail.

- [ ] **Step 6: Commit centered panel integration**

Run:

```bash
git add config/quickshell/ryoku/Noctalia config/quickshell/ryoku/shell.qml
git commit -m "feat: wire noctalia settings panel into ryoku shell"
```

---

### Task 5: Split Default And Legacy Settings IPC

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml`
- Modify: `config/quickshell/ryoku/shell.qml`
- Modify: `bin/ryoku-ipc`
- Modify: `default/hypr/bindings/utilities.conf`

- [ ] **Step 1: Add explicit legacy popup state**

In `Popups.qml`, add:

```qml
property bool legacySettingsMenuOpen: false
```

Keep the existing old settings state if other code still references it, but make default settings IPC stop using it.

- [ ] **Step 2: Bind the old Brain Shell popup to legacy state**

In `PopupLayer.qml`, change the old `SettingsMenuPopup` visibility/open binding from the default settings state to:

```qml
Popups.legacySettingsMenuOpen
```

If the component expects an `open` property, pass the legacy state through the same property name used today.

- [ ] **Step 3: Add legacy IPC functions in `shell.qml`**

Add:

```qml
function toggleLegacySettingsMenu() {
  BS.Popups.legacySettingsMenuOpen = !BS.Popups.legacySettingsMenuOpen
}

function closeLegacySettingsMenu() {
  BS.Popups.legacySettingsMenuOpen = false
}
```

Use the actual Brain Shell namespace alias currently present in `shell.qml`.

- [ ] **Step 4: Update `bin/ryoku-ipc` routing**

Update shell routes so:

```text
ryoku-ipc shell toggle settings-menu
```

calls the new Noctalia panel toggle, and:

```text
ryoku-ipc shell toggle legacy-settings-menu
```

calls the Brain Shell legacy popup toggle.

Add route forms:

```text
ryoku-ipc shell settings-menu wifi
ryoku-ipc shell settings-menu bluetooth
ryoku-ipc shell settings-menu connections
ryoku-ipc shell settings-menu color-scheme
ryoku-ipc shell settings-menu wallpaper
ryoku-ipc shell settings-menu display
ryoku-ipc shell settings-menu audio
ryoku-ipc shell settings-menu general
```

Each route should send the route string to `openSettingsRoute(route)` through the existing Quickshell IPC command mechanism.

Keep current route names that the system uses for `share` and `hardware`; route those to `legacy-settings-menu` in v1 because Noctalia has no exact pages for them.

- [ ] **Step 5: Update Hyprland bindings**

In `default/hypr/bindings/utilities.conf`, keep:

```text
SUPER ALT, SPACE
```

bound to:

```bash
ryoku-ipc shell toggle settings-menu
```

Change Wi-Fi and Bluetooth utility bindings from TUI launchers to:

```bash
ryoku-ipc shell settings-menu wifi
ryoku-ipc shell settings-menu bluetooth
```

Keep the old TUI launcher scripts installed as debug/fallback commands.

- [ ] **Step 6: Run IPC and topbar tests**

Run:

```bash
tests/ryoku-ipc.sh
tests/quickshell-topbar-settings-menus.sh
tests/quickshell-noctalia-settings.sh
```

Expected result: IPC/topbar legacy assertions pass. Feature availability and network assertions may still fail.

- [ ] **Step 7: Commit IPC split**

Run:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml config/quickshell/ryoku/shell.qml bin/ryoku-ipc default/hypr/bindings/utilities.conf tests/ryoku-ipc.sh tests/quickshell-topbar-settings-menus.sh
git commit -m "feat: route settings ipc to noctalia panel"
```

---

### Task 6: Add Feature Availability And Disabled Page Guards

**Files:**
- Add: `config/quickshell/ryoku/Noctalia/Services/Ryoku/RyokuCommand.qml`
- Add: `config/quickshell/ryoku/Noctalia/Services/Ryoku/RyokuFeatureAvailability.qml`
- Modify: `config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/SettingsContent.qml`
- Modify: Noctalia runtime tab files under `config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/Tabs/`
- Add or modify: `config/quickshell/ryoku/Noctalia/Services/Ryoku/qmldir`

- [ ] **Step 1: Add command capability helper**

Create `RyokuCommand.qml` with a small command-existence API that uses the existing Ryoku command helpers when possible:

```qml
pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property var commandCache: ({})
  property string pendingCommand: ""

  function hasCommand(name) {
    if (commandCache[name] !== undefined) {
      return commandCache[name]
    }

    pendingCommand = name
    checkProc.command = ["ryoku-cmd-present", name]
    checkProc.running = false
    checkProc.running = true
    return false
  }

  property var checkProc: Process {
    command: []
    running: false
    onExited: function(exitCode, exitStatus) {
      if (root.pendingCommand !== "") {
        root.commandCache[root.pendingCommand] = exitCode === 0
        root.pendingCommand = ""
      }
    }
  }
}
```

Register the singleton in `config/quickshell/ryoku/Noctalia/Services/Ryoku/qmldir`:

```text
singleton RyokuCommand 1.0 RyokuCommand.qml
```

- [ ] **Step 2: Add feature availability singleton**

Create `RyokuFeatureAvailability.qml`:

```qml
pragma Singleton

import QtQuick
import qs.Noctalia.Services.Ryoku

Singleton {
  id: service

  readonly property var enabledRoutes: ({
    "general": true,
    "user-interface": true,
    "color-scheme": true,
    "wallpaper": true,
    "connections": true,
    "wifi": true,
    "bluetooth": true,
    "audio": true,
    "display": true,
    "session-menu": true,
    "lock-screen": true,
    "about": true
  })

  readonly property var disabledRoutes: ({
    "bar": true,
    "dock": true,
    "desktop-widgets": true,
    "control-center": true,
    "launcher": true,
    "notifications": true,
    "osd": true,
    "idle": true,
    "location": true,
    "system": true,
    "plugins": true,
    "hooks": true
  })

  function featureAvailable(route) {
    return enabledRoutes[route] === true
  }

  function disabledReason(route) {
    if (disabledRoutes[route] === true) {
      return "This Noctalia settings page is not wired to Ryoku yet."
    }
    return ""
  }
}
```

- [ ] **Step 3: Keep every page visible and searchable**

In `SettingsContent.qml`, keep the upstream full tab model. Add route metadata without removing any entries:

```qml
property bool searchable: true
property bool featureAvailable: RyokuFeatureAvailability.featureAvailable(route)
property string disabledReason: RyokuFeatureAvailability.disabledReason(route)
```

If the upstream tab model is JavaScript object based, add these fields to every object. If it is a `ListModel`, add equivalent roles.

- [ ] **Step 4: Disable unavailable page controls**

For each disabled page component, preserve the Noctalia page layout and set the page body or control root to:

```qml
enabled: root.featureAvailable
opacity: root.featureAvailable ? 1 : 0.45
```

Add a small unavailable message inside the page body:

```qml
NLabel {
  visible: !root.featureAvailable
  text: root.disabledReason
}
```

Use Noctalia's existing text/box components, not a new Ryoku-styled component.

- [ ] **Step 5: Run disabled-state tests**

Run:

```bash
tests/quickshell-noctalia-settings.sh
```

Expected result: feature availability assertions pass. Network provider assertions may still fail.

- [ ] **Step 6: Commit feature availability**

Run:

```bash
git add config/quickshell/ryoku/Noctalia
git commit -m "feat: keep unsupported noctalia settings disabled"
```

---

### Task 7: Adapt Wi-Fi To Ryoku Providers

**Files:**
- Add: `config/quickshell/ryoku/Noctalia/Services/Networking/RyokuNetworkService.qml`
- Add: `config/quickshell/ryoku/Noctalia/Services/Networking/IwdProvider.qml`
- Add: `config/quickshell/ryoku/Noctalia/Services/Networking/NmcliProvider.qml`
- Modify: `config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml`

- [ ] **Step 1: Define the provider interface**

Both providers must expose:

```qml
property bool available
property bool scanning
property var networks
property string activeSsid
property string error

function refresh()
function scan()
function connect(ssid, security, passphrase)
function disconnect()
```

The service must expose the same interface and delegate to the active provider.

- [ ] **Step 2: Implement provider selection**

In `RyokuNetworkService.qml`, select providers in this order:

```qml
readonly property string providerName: IwdProvider.available ? "iwd" : (NmcliProvider.available ? "nmcli" : "none")
readonly property var provider: IwdProvider.available ? IwdProvider : (NmcliProvider.available ? NmcliProvider : null)
```

Expose:

```qml
readonly property bool available: provider !== null
readonly property bool usingIwd: providerName === "iwd"
readonly property bool usingNmcli: providerName === "nmcli"
```

- [ ] **Step 3: Implement `IwdProvider.qml`**

Use `iwctl` commands:

```text
iwctl station <device> scan
iwctl station <device> get-networks
iwctl station <device> connect <ssid>
```

Detect the station device with:

```text
iwctl device list
```

For secured networks, send passphrase through process input. The implementation must not build a command array containing the passphrase. The code must contain an explicit guard that prevents logging the secret:

```qml
function connect(ssid, security, passphrase) {
  const args = ["iwctl", "station", stationDevice, "connect", ssid]
  connectProcess.command = args
  connectProcess.input = passphrase + "\n"
  connectProcess.running = true
}
```

Adapt `input` to the exact process helper used in the Noctalia runtime. The key invariant is that `passphrase` is never part of `args`, `command`, debug logs, or error text.

- [ ] **Step 4: Implement `NmcliProvider.qml` as optional fallback**

Use `nmcli` only when present:

```text
nmcli -t -f ACTIVE,SSID,SECURITY,SIGNAL dev wifi list --rescan yes
nmcli dev wifi connect <ssid>
```

For passphrases, use `nmcli --ask` with process input if supported by the local process helper. If reliable stdin interaction is not available, disable secured-network connection for `nmcli` and show an unavailable reason in the Wi-Fi subtab. Do not pass `password <passphrase>` in argv.

- [ ] **Step 5: Wire `WifiSubTab.qml` to `RyokuNetworkService`**

Replace the upstream network service import/use with:

```qml
import qs.Noctalia.Services.Networking
```

Use:

```qml
RyokuNetworkService.networks
RyokuNetworkService.activeSsid
RyokuNetworkService.scan()
RyokuNetworkService.connect(ssid, security, passphrase)
RyokuNetworkService.disconnect()
```

Preserve Noctalia's Wi-Fi page visual structure, list delegates, toggles, and password dialog layout.

- [ ] **Step 6: Keep the old TUI commands as fallback only**

Do not delete `ryoku-launch-wifi`, `ryoku-launch-bluetooth`, `impala`, or the existing TUI-related scripts/packages. They remain callable outside the new settings UI.

- [ ] **Step 7: Run Wi-Fi tests**

Run:

```bash
tests/quickshell-noctalia-network-providers.sh
tests/quickshell-noctalia-settings.sh
```

Expected result: Wi-Fi provider assertions pass. Bluetooth assertions may still fail.

- [ ] **Step 8: Commit Wi-Fi adapter**

Run:

```bash
git add config/quickshell/ryoku/Noctalia/Services/Networking config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml
git commit -m "feat: adapt noctalia wifi settings to ryoku"
```

---

### Task 8: Adapt Bluetooth To Ryoku

**Files:**
- Add: `config/quickshell/ryoku/Noctalia/Services/Networking/RyokuBluetoothService.qml`
- Modify: `config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml`
- Modify: package or setup files only if the dependency audit proves a missing required BlueZ package

- [ ] **Step 1: Audit Bluetooth dependency declaration**

Search package/setup files:

```bash
rg -n 'bluez|bluetoothctl|bluetooth.service' install default config bin
```

If `bluetoothctl` is not provided by an already installed package declaration, add the minimal package that provides it to the appropriate Ryoku package list. Keep `bluetooth.service` enablement unchanged if it already exists.

- [ ] **Step 2: Implement `RyokuBluetoothService.qml`**

Expose:

```qml
property bool available
property bool powered
property bool scanning
property var devices
property string error

function refresh()
function setPowered(enabled)
function scan()
function pair(address)
function trust(address)
function connect(address)
function disconnect(address)
function remove(address)
```

Use `bluetoothctl` commands:

```text
bluetoothctl show
bluetoothctl devices
bluetoothctl scan on
bluetoothctl scan off
bluetoothctl power on
bluetoothctl power off
bluetoothctl pair <address>
bluetoothctl trust <address>
bluetoothctl connect <address>
bluetoothctl disconnect <address>
bluetoothctl remove <address>
```

Parse device lines into stable objects:

```qml
{
  address,
  name,
  paired,
  trusted,
  connected
}
```

- [ ] **Step 3: Wire `BluetoothSubTab.qml` to the Ryoku service**

Replace the upstream Bluetooth service import/use with:

```qml
import qs.Noctalia.Services.Networking
```

Use:

```qml
RyokuBluetoothService.devices
RyokuBluetoothService.powered
RyokuBluetoothService.scan()
RyokuBluetoothService.pair(address)
RyokuBluetoothService.trust(address)
RyokuBluetoothService.connect(address)
RyokuBluetoothService.disconnect(address)
RyokuBluetoothService.remove(address)
```

Preserve Noctalia's Bluetooth page visual structure, device list delegates, scan controls, pairing controls, and connection controls.

- [ ] **Step 4: Run Bluetooth tests**

Run:

```bash
tests/quickshell-noctalia-network-providers.sh
tests/quickshell-noctalia-settings.sh
```

Expected result: network-provider assertions pass.

- [ ] **Step 5: Commit Bluetooth adapter**

Run:

```bash
git add config/quickshell/ryoku/Noctalia install default tests/quickshell-noctalia-network-providers.sh
git commit -m "feat: adapt noctalia bluetooth settings to ryoku"
```

---

### Task 9: Wire Simple Ryoku Settings Pages

**Files:**
- Modify: runtime tabs under `config/quickshell/ryoku/Noctalia/Modules/Panels/Settings/Tabs/`
- Add: `config/quickshell/ryoku/Noctalia/Services/Ryoku/RyokuThemeActions.qml`
- Add: `config/quickshell/ryoku/Noctalia/Services/Ryoku/RyokuWallpaperActions.qml`
- Add: `config/quickshell/ryoku/Noctalia/Services/Ryoku/RyokuSessionActions.qml`

- [ ] **Step 1: Color scheme**

Wire Noctalia's color scheme page to existing Ryoku theme commands:

```text
ryoku-theme-refresh
ryoku-ipc shell toggle themes
```

Keep Noctalia's page layout and controls. Controls that require Matugen or templates that Ryoku does not expose remain disabled and visible.

- [ ] **Step 2: Wallpaper**

Wire Noctalia's wallpaper page actions to existing Ryoku wallpaper IPC where the action exists:

```text
ryoku-ipc shell toggle wallpaper
ryoku-ipc wallpaper wallhaven
ryoku-ipc wallpaper cache rebuild
```

Unavailable Noctalia wallpaper controls remain visible and disabled.

- [ ] **Step 3: Audio**

Wire volume and mute controls to the same backend currently used by Ryoku quick settings. If the existing shell has a volume service, reuse it. If it is only IPC-backed, call the existing Ryoku volume IPC commands. Keep advanced per-app mixer controls disabled until Ryoku exposes the data.

- [ ] **Step 4: Display**

Expose read-only monitor status from the existing Hyprland/Quickshell monitor data. Keep layout/orientation/scale mutation controls disabled unless Ryoku already has safe commands for those settings.

- [ ] **Step 5: Session, lock screen, and idle**

Wire safe existing actions only:

```text
lock
logout
reboot
poweroff
```

Do not wire Noctalia idle daemon settings unless Ryoku already owns equivalent config.

- [ ] **Step 6: Run settings tests**

Run:

```bash
tests/quickshell-noctalia-settings.sh
```

Expected result: tests continue to pass; any newly enabled route must remain visible/searchable and must not remove disabled pages.

- [ ] **Step 7: Commit simple page adapters**

Run:

```bash
git add config/quickshell/ryoku/Noctalia
git commit -m "feat: adapt noctalia settings pages to ryoku"
```

---

### Task 10: Runtime Smoke Verification

**Files:**
- No required edits unless verification exposes a defect.

- [ ] **Step 1: Restart Quickshell**

Run:

```bash
bin/ryoku-restart-shell
```

Expected result: Quickshell restarts without QML import errors.

- [ ] **Step 2: Open the default centered settings panel**

Run:

```bash
ryoku-ipc shell toggle settings-menu
```

Expected result: the Noctalia-styled panel opens centered on screen, not attached to the topbar.

- [ ] **Step 3: Capture a screenshot**

Run:

```bash
grim /tmp/ryoku-noctalia-settings.png
```

Verify the screenshot manually:

- Panel is centered.
- Visual layout matches Noctalia's left navigation and right content panel.
- `Color scheme`, `Connections`, and disabled pages are visible in the navigation.
- Unsupported pages are greyed out, not removed.
- The legacy Brain Shell menu is not open.

- [ ] **Step 4: Verify Wi-Fi and Bluetooth entry routes**

Run:

```bash
ryoku-ipc shell settings-menu wifi
ryoku-ipc shell settings-menu bluetooth
```

Expected result: the same centered panel opens with the relevant Connections subtab active.

- [ ] **Step 5: Verify legacy fallback**

Run:

```bash
ryoku-ipc shell toggle legacy-settings-menu
```

Expected result: the old Brain Shell settings popup still opens as a fallback.

- [ ] **Step 6: Check logs**

Run:

```bash
journalctl -b --user -u quickshell --no-pager -n 200
```

Expected result: no QML import failures, no singleton load failures, no command errors caused by opening the settings panel.

---

### Task 11: Final Test Sweep And Cleanup

**Files:**
- No required edits unless verification exposes a defect.

- [ ] **Step 1: Run static tests**

Run:

```bash
tests/quickshell-noctalia-settings.sh
tests/quickshell-noctalia-network-providers.sh
tests/ryoku-ipc.sh
tests/quickshell-topbar-settings-menus.sh
```

Expected result: all pass.

- [ ] **Step 2: Run formatting and diff checks**

Run:

```bash
git diff --check
git status --short
```

Expected result: no whitespace errors. `git status --short` only shows intentional files if there are uncommitted final fixes.

- [ ] **Step 3: Fix any common-sense gaps before completion**

Review the final diff specifically for:

- Any deleted Noctalia settings tab.
- Any removed Brain Shell fallback file.
- Any `Super+Alt+Space` route still targeting the old popup.
- Any Wi-Fi password passed in argv or logged.
- Any full Noctalia shell bootstrap import.
- Any uncredited Noctalia source copy.
- Any disabled page hidden from navigation or search.
- Any package change that adds NetworkManager as a hard dependency.

- [ ] **Step 4: Commit final fixes**

If final fixes were needed, run:

```bash
git add <changed-files>
git commit -m "fix: close noctalia settings integration gaps"
```

---

## Completion Criteria

- `Super+Alt+Space` opens a centered Noctalia-style settings panel.
- The panel preserves Noctalia's left navigation, content layout, dimensions, widgets, and visual hierarchy.
- The old Brain Shell settings menu remains available through `ryoku-ipc shell toggle legacy-settings-menu`.
- Wi-Fi and Bluetooth are visible and functional from the Noctalia Connections page using Ryoku-compatible providers.
- Unsupported Noctalia pages remain visible/searchable and are greyed out.
- Existing TUI Wi-Fi/Bluetooth launchers are not deleted.
- No full Noctalia shell bootstrap runs inside Ryoku.
- No Wi-Fi secret appears in command arguments or logs.
- Noctalia source, license, and attribution are present.
- Static tests pass, runtime smoke verification passes, and the Quickshell log is clean.
