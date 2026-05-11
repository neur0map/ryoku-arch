# SecPulse OpenVPN Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `secPulse` bar module that shows live OpenVPN state as a single icon in the right island, toggleable from Settings, Bar, Modules.

**Architecture:** Single QML widget binds directly to the existing `RyokuOpenVpn` singleton. No new service, no schema, no migration. Coexists with the existing System Tray module. Follows the `ShellUpdateIndicator.qml` peer pattern (MouseArea root, Rectangle pill, single MaterialSymbol icon).

**Tech Stack:** Quickshell QML 6, jq, bash. Test layer is static asserts in `tests/bar-secpulse.sh` plus the existing `shell/scripts/qml-check.fish`.

**Spec:** `docs/superpowers/specs/2026-05-08-secpulse-ovpn-indicator-design.md`

---

## File Structure

```
shell/modules/bar/SecPulseIndicator.qml      NEW  bar widget, ~70 lines
shell/modules/bar/BarContent.qml             EDIT 1 block insert in right island
shell/modules/settings/BarConfig.qml         EDIT 1 SettingsSwitch in modules row
shell/services/RyokuOpenVpn.qml              EDIT line 34 only, repoint config key
shell/defaults/config.json                   EDIT 1 key under bar.modules
tests/bar-secpulse.sh                        NEW  static assertions, 5 checks
tests/topbar-removal-regression.sh           EDIT loosen one assertion
```

Each file has one responsibility, kept small. No file in this plan grows past 200 lines.

---

## Task 1: Loosen the topbar-removal regression to permit `bar.modules.secPulse`

The regression test currently bans both `bar.secPulse` (legacy block) and `bar.modules.secPulse` (new module toggle) from `shell/defaults/config.json`. We want to keep the first ban and drop the second so the new module key is allowed. This must land before any other change touches defaults.

**Files:**
- Modify: `tests/topbar-removal-regression.sh:31-35`

- [ ] **Step 1: Read current assertion 4**

```bash
sed -n '31,35p' tests/topbar-removal-regression.sh
```

Expected output:

```
# 4. SecPulse config keys are gone from defaults.
jq -e '(.bar.modules | has("secPulse") | not) and (.bar | has("secPulse") | not)' \
    shell/defaults/config.json >/dev/null \
    || fail "shell/defaults/config.json must not contain bar.modules.secPulse or bar.secPulse"
ok "secPulse keys stripped from defaults"
```

- [ ] **Step 2: Replace the assertion**

Edit `tests/topbar-removal-regression.sh`. Replace those five lines with:

```bash
# 4. Legacy bar.secPulse schema block stays gone from defaults. The
#    bar.modules.secPulse boolean toggle is allowed (re-introduced as a
#    focused OpenVPN-status module; see specs/2026-05-08-secpulse-ovpn-indicator-design.md).
jq -e '(.bar | has("secPulse") | not)' \
    shell/defaults/config.json >/dev/null \
    || fail "shell/defaults/config.json must not contain the legacy bar.secPulse block"
ok "legacy bar.secPulse block stripped from defaults"
```

- [ ] **Step 3: Run the regression test**

```bash
bash tests/topbar-removal-regression.sh
```

Expected: all `ok:` lines print, exit 0. The shape did not change because the legacy block is still absent.

- [ ] **Step 4: Commit**

```bash
git add tests/topbar-removal-regression.sh
git commit -m "test(topbar): permit bar.modules.secPulse module toggle, keep legacy block ban"
```

---

## Task 2: Add the `bar.modules.secPulse` default + first failing assertion (TDD pair)

Write the new test scaffold with one assertion that demands the default exists, watch it fail, add the default, watch it pass.

**Files:**
- Create: `tests/bar-secpulse.sh`
- Modify: `shell/defaults/config.json` (add key under `.bar.modules`)

- [ ] **Step 1: Create the test scaffold with one assertion**

Create `tests/bar-secpulse.sh` with the following content:

```bash
#!/bin/bash

# Static asserts for the SecPulse bar module. Mirrors the style of
# tests/sidebar-openvpn.sh. SecPulse is a focused OpenVPN-state
# indicator; see docs/superpowers/specs/2026-05-08-secpulse-ovpn-indicator-design.md.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  assert_file "$path"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_matches() {
  local path="$1"
  local re="$2"
  assert_file "$path"
  grep -qE "$re" "$ROOT_DIR/$path" || fail "$path should match regex: $re"
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  assert_file "$path"
  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

# 1. Module default lives in shell defaults so users get the toggle on a
#    fresh config and existing configs fall through to the runtime ?? true.
assert_json_expr  "shell/defaults/config.json" '.bar.modules.secPulse == true' \
  "shell defaults should set bar.modules.secPulse to true"

echo "ok: bar-secpulse static asserts"
```

- [ ] **Step 2: Make the test executable, run it, expect FAIL**

```bash
chmod +x tests/bar-secpulse.sh
bash tests/bar-secpulse.sh
```

Expected exit code: non-zero. Expected stderr:

```
FAIL: shell defaults should set bar.modules.secPulse to true
```

- [ ] **Step 3: Add the key to `shell/defaults/config.json`**

Locate the `bar.modules` block (alphabetic order is loose; the existing keys include `sysTray`, `taskbar`, `weather`). Insert `secPulse` next to `sysTray`:

Open `shell/defaults/config.json` and inside the `"modules"` object under `"bar"`, add:

```json
"secPulse": true,
```

For example, the relevant block becomes (existing keys unchanged, new line added):

```json
"modules": {
  "activeWindow": true,
  "battery": false,
  "clock": true,
  "leftSidebarButton": true,
  "media": true,
  "resources": true,
  "rightSidebarButton": true,
  "secPulse": true,
  "sysTray": true,
  "taskbar": false,
  "utilButtons": true,
  "weather": true,
  "kanjiClock": true,
  "dateLabel": true,
  "weatherIcon": true,
  "workspaces": true
}
```

- [ ] **Step 4: Validate JSON parses, run both tests**

```bash
jq . shell/defaults/config.json >/dev/null && echo "JSON valid"
bash tests/bar-secpulse.sh
bash tests/topbar-removal-regression.sh
```

Expected: `JSON valid`, then `ok: bar-secpulse static asserts`, then the regression test prints all `ok:` lines and exits 0.

- [ ] **Step 5: Commit**

```bash
git add tests/bar-secpulse.sh shell/defaults/config.json
git commit -m "feat(bar): default bar.modules.secPulse to true with regression test"
```

---

## Task 3: Repoint `RyokuOpenVpn.barIndicatorEnabled` to the live config key

`shell/services/RyokuOpenVpn.qml:34` currently reads the dead `bar.secPulse.showOpenVpn` key (the schema for which was deleted in commit `cb0d3907`). Repoint it to the new `bar.modules.secPulse` so the polling-active gate becomes meaningful again.

**Files:**
- Modify: `tests/bar-secpulse.sh` (add second assertion)
- Modify: `shell/services/RyokuOpenVpn.qml:34`

- [ ] **Step 1: Add the failing assertion**

Append above the final `echo` line in `tests/bar-secpulse.sh`:

```bash
# 2. The OVPN service's bar-indicator gate reads the live module key,
#    not the deleted bar.secPulse.showOpenVpn schema.
assert_contains   "shell/services/RyokuOpenVpn.qml" \
  "Config.options?.bar?.modules?.secPulse ?? true"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/bar-secpulse.sh
```

Expected stderr:

```
FAIL: shell/services/RyokuOpenVpn.qml should contain: Config.options?.bar?.modules?.secPulse ?? true
```

- [ ] **Step 3: Repoint the gate**

Edit `shell/services/RyokuOpenVpn.qml`. On line 34, change:

```qml
    property bool barIndicatorEnabled: Config.options?.bar?.secPulse?.showOpenVpn ?? true
```

to:

```qml
    property bool barIndicatorEnabled: Config.options?.bar?.modules?.secPulse ?? true
```

- [ ] **Step 4: Run the test + qml-check, expect PASS**

```bash
bash tests/bar-secpulse.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: bar-secpulse static asserts` and qml-check exits 0.

- [ ] **Step 5: Commit**

```bash
git add tests/bar-secpulse.sh shell/services/RyokuOpenVpn.qml
git commit -m "fix(openvpn): repoint barIndicatorEnabled gate to bar.modules.secPulse"
```

---

## Task 4: Create `SecPulseIndicator.qml`

Author the bar widget. Mirrors `ShellUpdateIndicator.qml`'s shape exactly: MouseArea root, Rectangle pill, single MaterialSymbol icon, RotationAnimation on transitioning, StyledToolTip for hover. No new state.

**Files:**
- Modify: `tests/bar-secpulse.sh` (add third assertion)
- Create: `shell/modules/bar/SecPulseIndicator.qml`

- [ ] **Step 1: Add the failing assertion**

Append above the final `echo` line in `tests/bar-secpulse.sh`:

```bash
# 3. The widget exists and binds to the existing RyokuOpenVpn surface.
assert_file       "shell/modules/bar/SecPulseIndicator.qml"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuOpenVpn.activeProfile"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuOpenVpn.transitioning"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "GlobalStates.sidebarRightOpen = true"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "vpn_key"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "vpn_key_off"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/bar-secpulse.sh
```

Expected stderr first line:

```
FAIL: shell/modules/bar/SecPulseIndicator.qml should exist
```

- [ ] **Step 3: Create the widget**

Create `shell/modules/bar/SecPulseIndicator.qml` with exactly this content:

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * SecPulse: at-a-glance OpenVPN connection state for the topbar.
 * Click opens the right sidebar (lands on the user's last tab,
 * which is the OpenVPN tab if they were just there).
 * Always visible when bar.modules.secPulse is on; four states drive the icon.
 */
MouseArea {
    id: root

    implicitWidth: pill.width
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    readonly property color accentColor:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    readonly property bool _connected: RyokuOpenVpn.activeProfile.length > 0 && !RyokuOpenVpn.transitioning
    readonly property bool _missing: !RyokuOpenVpn.openvpnInstalled

    onClicked: { GlobalStates.sidebarRightOpen = true }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: icon.implicitWidth + 12
        height: icon.implicitHeight + 8
        radius: height / 2
        color: root.containsMouse
            ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer1Hover
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer1Hover)
            : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    MaterialSymbol {
        id: icon
        anchors.centerIn: pill
        text: RyokuOpenVpn.transitioning ? "sync"
            : root._connected ? "vpn_key"
            : "vpn_key_off"
        fill: root._connected ? 1 : 0
        iconSize: Appearance.font.pixelSize.larger
        color: root._missing ? Appearance.m3colors.m3error
            : (root._connected || RyokuOpenVpn.transitioning) ? root.accentColor
            : Appearance.colors.colSubtext

        RotationAnimation on rotation {
            loops: Animation.Infinite
            running: RyokuOpenVpn.transitioning
            from: 0
            to: 360
            duration: 1200
        }
    }

    StyledToolTip {
        extraVisibleCondition: root.containsMouse
        text: {
            if (RyokuOpenVpn.transitioning) {
                if (RyokuOpenVpn.transitionTarget.length === 0) return "Disconnecting..."
                if (RyokuOpenVpn.activeProfile.length > 0)
                    return "Switching " + RyokuOpenVpn.activeProfile + " to " + RyokuOpenVpn.transitionTarget + "..."
                return "Connecting to " + RyokuOpenVpn.transitionTarget + "..."
            }
            if (root._connected) {
                let line = RyokuOpenVpn.activeProfile
                if (RyokuOpenVpn.activeIp.length > 0) line += ", " + RyokuOpenVpn.activeIp
                if (RyokuOpenVpn.activeSince.length > 0) line += ", since " + RyokuOpenVpn.activeSince
                return line
            }
            if (root._missing) return "OpenVPN not installed"
            return "VPN: not connected"
        }
    }
}
```

- [ ] **Step 4: Run the test + qml-check**

```bash
bash tests/bar-secpulse.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: bar-secpulse static asserts`. qml-check parses the file successfully.

If qml-check reports an unresolved import or an unknown property, fix it inline (most likely fix is removing an unused `import` line; do not add new properties or restructure).

- [ ] **Step 5: Commit**

```bash
git add tests/bar-secpulse.sh shell/modules/bar/SecPulseIndicator.qml
git commit -m "feat(bar): add SecPulseIndicator widget bound to RyokuOpenVpn state"
```

---

## Task 5: Wire `SecPulseIndicator` into `BarContent.qml`

Slot the widget after the existing `SysTray { … }` block and before `TimerIndicator`. Visibility is gated solely on `bar.modules.secPulse`. No `useShortenedForm` gate; the icon stays useful at every bar width.

**Files:**
- Modify: `tests/bar-secpulse.sh` (add fourth assertion)
- Modify: `shell/modules/bar/BarContent.qml:672-682`

- [ ] **Step 1: Add the failing assertion**

Append above the final `echo` line in `tests/bar-secpulse.sh`:

```bash
# 4. BarContent instantiates SecPulseIndicator and gates it on the module key.
assert_contains   "shell/modules/bar/BarContent.qml" "SecPulseIndicator {"
assert_contains   "shell/modules/bar/BarContent.qml" "bar?.modules?.secPulse"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/bar-secpulse.sh
```

Expected stderr first line:

```
FAIL: shell/modules/bar/BarContent.qml should contain: SecPulseIndicator {
```

- [ ] **Step 3: Insert the slot**

Edit `shell/modules/bar/BarContent.qml`. Locate the existing `SysTray` block (currently lines 672-677). Insert the SecPulseIndicator block immediately after the `SysTray { ... }` closing brace and before `// Timer indicator`. The diff is purely additive:

Before:

```qml
            SysTray {
                visible: (Config.options?.bar?.modules?.sysTray ?? true) && root.useShortenedForm === 0
                Layout.fillWidth: false
                Layout.fillHeight: true
                invertSide: Config.options?.bar?.bottom ?? false
            }

            // Timer indicator
            TimerIndicator {
                Layout.alignment: Qt.AlignVCenter
            }
```

After:

```qml
            SysTray {
                visible: (Config.options?.bar?.modules?.sysTray ?? true) && root.useShortenedForm === 0
                Layout.fillWidth: false
                Layout.fillHeight: true
                invertSide: Config.options?.bar?.bottom ?? false
            }

            SecPulseIndicator {
                visible: Config.options?.bar?.modules?.secPulse ?? true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Timer indicator
            TimerIndicator {
                Layout.alignment: Qt.AlignVCenter
            }
```

- [ ] **Step 4: Run the test + qml-check**

```bash
bash tests/bar-secpulse.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: bar-secpulse static asserts`. qml-check exits 0.

- [ ] **Step 5: Commit**

```bash
git add tests/bar-secpulse.sh shell/modules/bar/BarContent.qml
git commit -m "feat(bar): slot SecPulseIndicator into right island after SysTray"
```

---

## Task 6: Add the SecPulse toggle to `BarConfig.qml`

Replace the flex `Item` filler in the existing modules row (next to System tray) with a `SettingsSwitch` bound to `bar.modules.secPulse`. The two switches now share the row uniformly.

**Files:**
- Modify: `tests/bar-secpulse.sh` (add fifth assertion)
- Modify: `shell/modules/settings/BarConfig.qml:398-407`

- [ ] **Step 1: Add the failing assertion**

Append above the final `echo` line in `tests/bar-secpulse.sh`:

```bash
# 5. BarConfig exposes a SettingsSwitch bound to the new module key.
assert_contains   "shell/modules/settings/BarConfig.qml" "bar.modules.secPulse"
assert_contains   "shell/modules/settings/BarConfig.qml" 'Translation.tr("SecPulse")'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/bar-secpulse.sh
```

Expected stderr first line:

```
FAIL: shell/modules/settings/BarConfig.qml should contain: bar.modules.secPulse
```

- [ ] **Step 3: Replace the filler**

Edit `shell/modules/settings/BarConfig.qml`. Locate the existing System tray row (currently lines 398-407):

Before:

```qml
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "shelf_auto_hide"
                    text: Translation.tr("System tray")
                    checked: Config.options?.bar?.modules?.sysTray ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.sysTray", checked)
                }
                Item { Layout.fillWidth: true }
            }
```

After:

```qml
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "shelf_auto_hide"
                    text: Translation.tr("System tray")
                    checked: Config.options?.bar?.modules?.sysTray ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.sysTray", checked)
                }
                SettingsSwitch {
                    buttonIcon: "vpn_key"
                    text: Translation.tr("SecPulse")
                    checked: Config.options?.bar?.modules?.secPulse ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.secPulse", checked)
                }
            }
```

- [ ] **Step 4: Run all tests + qml-check**

```bash
bash tests/bar-secpulse.sh
bash tests/topbar-removal-regression.sh
bash tests/sidebar-openvpn.sh
fish shell/scripts/qml-check.fish
```

Expected: every test prints its `ok:` line and exits 0; qml-check parses every file successfully.

- [ ] **Step 5: Commit**

```bash
git add tests/bar-secpulse.sh shell/modules/settings/BarConfig.qml
git commit -m "feat(settings): expose SecPulse module toggle in Bar settings row"
```

---

## Task 7: Deploy to live runtime, restart shell, visual smoke test

Per `docs/ui-patterns.md`, dev → runtime sync is the safe preview path. Do not write to `~/.local/share/ryoku/shell/...`. After this task the new widget is visible on the user's bar.

**Files:** none (no commits)

- [ ] **Step 1: Sync dev shell to the runtime tree**

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
rsync -a --delete "$DEV/shell/" "$RUNT/"
```

Expected: command exits 0, no stderr.

- [ ] **Step 2: Restart the user shell**

```bash
systemctl --user restart ryoku-shell.service
sleep 2
systemctl --user is-active ryoku-shell.service
```

Expected: `is-active` prints `active`.

- [ ] **Step 3: Visual smoke test (manual)**

1. Look at the right island. There should be a single `vpn_key` icon between the system tray (if any SNI items are registered) and the timer indicator.
2. Hover the icon. The tooltip text should match the current state per the table in the spec.
3. Open Settings, Bar, Modules. Confirm two switches in the row: System tray and SecPulse, both on.
4. Toggle SecPulse off. The icon disappears from the bar within one frame. Toggle it back on.
5. If a profile is currently active, the icon shows filled `vpn_key` in the accent color and the tooltip shows the profile name and IP. If not, it shows outlined `vpn_key_off` in subtext color with tooltip "VPN: not connected".
6. (Optional) Trigger a transition by clicking Connect on a profile in the OpenVPN sidebar tab and watch the icon animate to `sync` and rotate while transitioning.

If any visual check fails, revert by `git restore` on the offending file, fix, re-run from Task 5 or Task 6 as appropriate.

- [ ] **Step 4: Confirm polling gate works**

```bash
journalctl --user -u ryoku-shell.service -n 200 --no-pager 2>/dev/null | grep -iE "openvpn|secpulse" | tail -10
```

Expected: nothing alarming. The 5 second status poll should be present in process listings only when the indicator is visible.

```bash
ps -ef | grep -E "systemctl.*openvpn-client" | grep -v grep | head
```

(No output is fine; this just confirms no runaway shells.)

---

## Task 8: Push (after user confirms visual)

**Files:** none (push only)

- [ ] **Step 1: Confirm with user before pushing**

Wait for the user to confirm the bar widget looks right. Do not push without explicit go-ahead.

- [ ] **Step 2: Push to origin/main**

```bash
git push origin main
```

Expected: push succeeds; six commits land on `main`. Other users running `ryoku-update` will pick up the new module on their next update; the runtime fallback (`?? true`) handles their existing config files without a migration.

---

## Test runbook (full)

When the plan is complete, the canonical verification command is:

```bash
bash tests/bar-secpulse.sh \
  && bash tests/topbar-removal-regression.sh \
  && bash tests/sidebar-openvpn.sh \
  && fish shell/scripts/qml-check.fish \
  && echo "all green"
```

Every test should print at least one `ok:` line and the chain ends with `all green`.
