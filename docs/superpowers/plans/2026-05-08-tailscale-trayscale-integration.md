# Tailscale and Trayscale Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `RyokuTailscale` singleton, a sidebar Tailscale status card with an "Open Trayscale" action, and rework `SecPulseIndicator` so the topbar reflects combined OpenVPN + Tailscale state with a two-line tooltip.

**Architecture:** New singleton polls `tailscale status --json` (gated on the existing SecPulse module key + sidebar OVPN tab open). Two consumers bind to it: a peer status card in the OVPN sidebar tab, and the existing topbar `SecPulseIndicator` extended with combined state. No umbrella service, no new bar module key, no migration. Mirrors the `RyokuOpenVpn` shape verbatim and the `ShellUpdateIndicator` peer pattern for the topbar widget.

**Tech Stack:** Quickshell QML 6, jq, bash. Tests are static asserts in `tests/sidebar-tailscale.sh` (new) and `tests/bar-secpulse.sh` (extended), plus the existing `shell/scripts/qml-check.fish`.

**Spec:** `docs/superpowers/specs/2026-05-08-tailscale-trayscale-integration-design.md`

---

## File Structure

```
shell/services/RyokuTailscale.qml                                     NEW   singleton ~120 lines
shell/services/qmldir                                                 EDIT  one register line
shell/modules/sidebarRight/BottomWidgetGroup.qml                      EDIT  one parallel Binding
shell/modules/sidebarRight/CompactSidebarRightContent.qml             EDIT  one parallel Binding
shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml            NEW   sidebar card ~110 lines
shell/modules/sidebarRight/openvpn/OpenVpnTab.qml                     EDIT  insert stub + card at top
shell/modules/bar/SecPulseIndicator.qml                               EDIT  extend state, two-line tooltip
install/ryoku-aur.packages                                            EDIT  add trayscale line
tests/sidebar-tailscale.sh                                            NEW   static asserts
tests/bar-secpulse.sh                                                 EDIT  add two assertions
```

Each file has one responsibility. The two new QML files are small and focused. Two existing files (`SecPulseIndicator.qml`, `OpenVpnTab.qml`) gain Tailscale awareness without growing past readable size.

---

## Task 1: Re-add `trayscale` to AUR package list

The package was removed during the secPulse purge (commit `7ffa2715`) but the install script `install/config/tailscale.sh` still expects trayscale on disk for the new "Open Trayscale" button to work for fresh installs. This is the lowest-risk change and lays groundwork for the TDD scaffold.

**Files:**
- Modify: `install/ryoku-aur.packages`

- [ ] **Step 1: Inspect the current package list around the alphabetic insertion point**

```bash
grep -n -E "^t" install/ryoku-aur.packages | head -10
```

Expected: a list of `t*` packages with line numbers (no `trayscale` present).

- [ ] **Step 2: Add `trayscale` to the package list**

Edit `install/ryoku-aur.packages` and add `trayscale` on its own line, alphabetically with the other `t*` entries. The exact location depends on the surrounding entries; insert it so the `t*` block stays in alphabetic order (e.g. between `topgrade` and `ttf-cascadia-code` if those are present, or near the end of the `t` block otherwise).

- [ ] **Step 3: Verify the file parses**

```bash
grep -E "^trayscale$" install/ryoku-aur.packages
```

Expected: prints `trayscale` once. If it prints zero or more than one, fix.

- [ ] **Step 4: Commit**

```bash
git add install/ryoku-aur.packages
git commit -m "chore(install): re-add trayscale to AUR package list"
```

---

## Task 2: Create `RyokuTailscale` singleton + register in `qmldir` + first assertion (TDD pair)

This is the foundation. The singleton is the only file in the plan that contains real logic; both downstream consumers are bindings into it. Write the test scaffold with one assertion (singleton file exists), watch it fail, write the singleton + qmldir entry, watch it pass.

**Files:**
- Create: `tests/sidebar-tailscale.sh`
- Create: `shell/services/RyokuTailscale.qml`
- Modify: `shell/services/qmldir`

- [ ] **Step 1: Create the test scaffold with the first assertion**

Create `tests/sidebar-tailscale.sh` with EXACTLY this content:

```bash
#!/bin/bash

# Static asserts for the Tailscale + Trayscale integration. Mirrors the
# style of tests/sidebar-openvpn.sh and tests/bar-secpulse.sh. Spec:
# docs/superpowers/specs/2026-05-08-tailscale-trayscale-integration-design.md.

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

# 1. Service singleton + qmldir registration.
assert_file       "shell/services/RyokuTailscale.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuTailscale 1.0 RyokuTailscale.qml"
assert_contains   "shell/services/RyokuTailscale.qml" "tailscale status --json"
assert_contains   "shell/services/RyokuTailscale.qml" "BackendState"
assert_contains   "shell/services/RyokuTailscale.qml" "Self.HostName"
assert_contains   "shell/services/RyokuTailscale.qml" "function openTrayscale"
assert_matches    "shell/services/RyokuTailscale.qml" 'property bool tabOpen'

# 1b. AUR package list ships trayscale so fresh installs have the GUI
#     the openTrayscale() action launches.
assert_matches    "install/ryoku-aur.packages" '^trayscale$'

echo "ok: sidebar-tailscale static asserts"
```

- [ ] **Step 2: Make the test executable, run it, expect FAIL**

```bash
chmod +x tests/sidebar-tailscale.sh
bash tests/sidebar-tailscale.sh
```

Expected: non-zero exit, stderr `FAIL: shell/services/RyokuTailscale.qml should exist`.

- [ ] **Step 3: Create `shell/services/RyokuTailscale.qml`**

Create `shell/services/RyokuTailscale.qml` with EXACTLY this content:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * Ryoku Tailscale service: polls `tailscale status --json` periodically
 * and exposes typed properties for the sidebar status card and the topbar
 * SecPulse indicator. Polling is gated: the 30s status poll only runs
 * while the SecPulse bar indicator is enabled or the sidebar OpenVPN tab
 * is open. A `presenceProc` one-shot at startup sets `installed`.
 *
 * Action: `openTrayscale()` launches the Trayscale GTK4 GUI via
 * Quickshell.execDetached. Trayscale ships with the install
 * (install/ryoku-aur.packages and install/config/tailscale.sh enables
 * tailscaled.service at install time).
 */
Singleton {
    id: root

    // ── public state ──────────────────────────────────────────────
    property bool installed: false       // tailscale binary present
    property bool connected: false       // BackendState=Running && Self.Online
    property bool transitioning: false   // BackendState in {Starting, NoState}
    property string hostname: ""
    property string tailIp: ""           // first IPv4 from Self.TailscaleIPs
    property string relay: ""            // Self.Relay (DERP region code)
    property string exitNode: ""         // first peer with ExitNode=true

    // ── activation gates (parents flip these) ─────────────────────
    property bool barIndicatorEnabled: Config.options?.bar?.modules?.secPulse ?? true
    property bool tabOpen: false         // BottomWidgetGroup/CompactSidebarRightContent set this
    readonly property bool _gateActive: barIndicatorEnabled || tabOpen

    // ── presence: one-shot at startup ─────────────────────────────
    Process {
        id: presenceProc
        command: ["sh", "-c", "command -v tailscale >/dev/null 2>&1 && echo y || echo n"]
        stdout: StdioCollector {
            onStreamFinished: { root.installed = (this.text.trim() === "y") }
        }
    }
    Component.onCompleted: presenceProc.running = true

    // ── status poll: 30s, gated on _gateActive ────────────────────
    Process {
        id: statusProc
        command: ["sh", "-c",
            "command -v tailscale >/dev/null 2>&1 && tailscale status --json 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                if (raw.length === 0) {
                    root.connected = false
                    root.transitioning = false
                    root.hostname = ""
                    root.tailIp = ""
                    root.relay = ""
                    root.exitNode = ""
                    return
                }
                try {
                    const data = JSON.parse(raw)
                    const self = data?.Self ?? {}
                    const state = data?.BackendState ?? ""
                    root.connected = (state === "Running") && (self.Online === true)
                    root.transitioning = (state === "Starting") || (state === "NoState")
                    root.hostname = self.HostName ?? ""
                    root.tailIp = (self.TailscaleIPs && self.TailscaleIPs.length > 0)
                                  ? self.TailscaleIPs[0] : ""
                    root.relay = self.Relay ?? ""
                    let exit = ""
                    const peers = data?.Peer ?? {}
                    for (const k in peers) {
                        if (peers[k]?.ExitNode === true) {
                            exit = peers[k]?.HostName ?? ""
                            break
                        }
                    }
                    root.exitNode = exit
                } catch (e) {
                    root.connected = false
                    root.transitioning = false
                }
            }
        }
    }
    Timer {
        running: root._gateActive
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: statusProc.running = true
    }

    // ── public action ─────────────────────────────────────────────
    function openTrayscale(): void {
        Quickshell.execDetached(["trayscale"])
    }
}
```

- [ ] **Step 4: Register the singleton in `shell/services/qmldir`**

Open `shell/services/qmldir` and add a new line (alphabetic insertion) between the existing `singleton Ryoku...` entries. Search for `singleton RyokuOpenVpn` first to find its position, and insert the Tailscale entry adjacent to it:

```
singleton RyokuTailscale 1.0 RyokuTailscale.qml
```

The qmldir is a flat list of singleton declarations; preserve all existing entries byte-for-byte and only add this one line.

- [ ] **Step 5: Run the test + qml-check, expect PASS**

```bash
bash tests/sidebar-tailscale.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-tailscale static asserts`. qml-check exits 0 (the new singleton parses).

If qml-check reports an unresolved property or import, double-check that imports match `shell/services/RyokuOpenVpn.qml`'s exactly (`pragma Singleton`, `pragma ComponentBehavior: Bound`, `import Quickshell`, `import Quickshell.Io`, `import QtQuick`, `import qs.modules.common`).

- [ ] **Step 6: Commit**

```bash
git add tests/sidebar-tailscale.sh shell/services/RyokuTailscale.qml shell/services/qmldir
git commit -m "feat(services): add RyokuTailscale singleton bound to tailscale status JSON"
```

---

## Task 3: Wire `tabOpen` Bindings in both sidebar layouts

The OVPN sidebar tab is hosted by two parent shapes: `BottomWidgetGroup.qml` (regular sidebar) and `CompactSidebarRightContent.qml` (compact sidebar). Each already has a `Binding { target: RyokuOpenVpn; property: "tabOpen"; ... }` block. Add a sibling for `RyokuTailscale.tabOpen` driven by the same condition (Tailscale card lives inside the OVPN tab, so the gate is identical).

**Files:**
- Modify: `tests/sidebar-tailscale.sh` (add second assertion)
- Modify: `shell/modules/sidebarRight/BottomWidgetGroup.qml`
- Modify: `shell/modules/sidebarRight/CompactSidebarRightContent.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo "ok: sidebar-tailscale static asserts"` line in `tests/sidebar-tailscale.sh`. Add a blank line between the existing block and the new block:

```bash
# 2. Both sidebar layouts drive RyokuTailscale.tabOpen in parallel with
#    the existing RyokuOpenVpn.tabOpen Binding.
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "target: RyokuTailscale"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "target: RyokuTailscale"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-tailscale.sh
```

Expected stderr first line:

```
FAIL: shell/modules/sidebarRight/BottomWidgetGroup.qml should contain: target: RyokuTailscale
```

- [ ] **Step 3: Add the Binding to `BottomWidgetGroup.qml`**

Edit `shell/modules/sidebarRight/BottomWidgetGroup.qml`. Locate the existing `Binding` for `RyokuOpenVpn.tabOpen` (around lines 121-125):

```qml
    Binding {
        target: RyokuOpenVpn
        property: "tabOpen"
        value: root.currentTabType === "openvpn" && !root.collapsed
    }
```

Add an identical-looking sibling Binding immediately after it:

```qml
    Binding {
        target: RyokuTailscale
        property: "tabOpen"
        value: root.currentTabType === "openvpn" && !root.collapsed
    }
```

The two Bindings live as siblings; both are top-level under the `Item { ... }` root. Do not modify the existing OVPN Binding.

- [ ] **Step 4: Add the Binding to `CompactSidebarRightContent.qml`**

Edit `shell/modules/sidebarRight/CompactSidebarRightContent.qml`. Locate the existing `Binding` for `RyokuOpenVpn.tabOpen` (around lines 703-707):

```qml
    Binding {
        target: RyokuOpenVpn
        property: "tabOpen"
        value: root.sections[root.activeSection]?.id === "openvpn"
    }
```

Add an identical-looking sibling Binding immediately after it:

```qml
    Binding {
        target: RyokuTailscale
        property: "tabOpen"
        value: root.sections[root.activeSection]?.id === "openvpn"
    }
```

Note the value expression differs from BottomWidgetGroup (this is the compact layout's own tab-tracking shape); copy exactly the OVPN Binding's value expression.

- [ ] **Step 5: Run the test + qml-check**

```bash
bash tests/sidebar-tailscale.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-tailscale static asserts`. qml-check exits 0.

- [ ] **Step 6: Commit**

Stage ONLY the three files for this task:

```bash
git add tests/sidebar-tailscale.sh \
        shell/modules/sidebarRight/BottomWidgetGroup.qml \
        shell/modules/sidebarRight/CompactSidebarRightContent.qml
git commit -m "feat(sidebar): drive RyokuTailscale.tabOpen from both sidebar layouts"
```

Before staging, verify the diff for each sidebar file is exactly the new Binding block (no other changes). If pre-existing user modifications appear in `git diff -- <file>`, stop and report rather than including them.

---

## Task 4: Create `TailscaleStatusCard.qml`

A focused sidebar widget that mirrors `OpenVpnStatusCard.qml`'s shape: header row with icon + label + status pill, detail rows when connected, and a `DialogButton` action plus a card-wide MouseArea that both call `RyokuTailscale.openTrayscale()`.

**Files:**
- Modify: `tests/sidebar-tailscale.sh` (add third assertion)
- Create: `shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo "ok: sidebar-tailscale static asserts"` line in `tests/sidebar-tailscale.sh`, with a blank line before:

```bash
# 3. Sidebar status card exists and binds to RyokuTailscale state, with
#    an Open Trayscale action that calls openTrayscale().
assert_file       "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.connected"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.hostname"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.openTrayscale()"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" '"lan"'
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" 'buttonText: "Open Trayscale"'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-tailscale.sh
```

Expected stderr first line:

```
FAIL: shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml should exist
```

- [ ] **Step 3: Create the widget**

Create `shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml` with EXACTLY this content:

```qml
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/**
 * Tailscale status card for the OpenVPN sidebar tab. Peer pattern of
 * OpenVpnStatusCard. Binds to RyokuTailscale; click anywhere on the
 * card body or the Open Trayscale button launches the Trayscale GUI.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: cardCol.implicitHeight + 24
    color: Appearance.colors.colLayer2
    radius: Appearance.rounding.normal

    readonly property color colAccent:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
        : Appearance.m3colors.m3primary

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: RyokuTailscale.installed ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton
        onClicked: { if (RyokuTailscale.installed) RyokuTailscale.openTrayscale() }
        propagateComposedEvents: true
    }

    ColumnLayout {
        id: cardCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Header row.
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            MaterialSymbol {
                text: "lan"
                iconSize: Appearance.font.pixelSize.larger
                color: RyokuTailscale.connected ? root.colAccent : Appearance.colors.colSubtext
            }
            StyledText {
                text: "Tailscale"
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer2
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: RyokuTailscale.transitioning ? "starting..."
                    : RyokuTailscale.connected ? "connected"
                    : "off"
                font.pixelSize: Appearance.font.pixelSize.small
                color: RyokuTailscale.connected ? root.colAccent
                    : RyokuTailscale.transitioning ? root.colAccent
                    : Appearance.colors.colSubtext
            }
        }

        // Detail rows when connected.
        StyledText {
            visible: RyokuTailscale.connected && RyokuTailscale.hostname.length > 0
            text: RyokuTailscale.hostname
            color: Appearance.colors.colOnLayer2
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: RyokuTailscale.connected && RyokuTailscale.tailIp.length > 0
            text: RyokuTailscale.tailIp + (RyokuTailscale.relay.length > 0 ? (", via " + RyokuTailscale.relay) : "")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }
        StyledText {
            visible: RyokuTailscale.connected && RyokuTailscale.exitNode.length > 0
            text: "exit: " + RyokuTailscale.exitNode
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }

        // Action row.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 8

            DialogButton {
                enabled: RyokuTailscale.installed
                buttonText: "Open Trayscale"
                onClicked: RyokuTailscale.openTrayscale()
            }
        }
    }
}
```

- [ ] **Step 4: Run the test + qml-check**

```bash
bash tests/sidebar-tailscale.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-tailscale static asserts`. qml-check exits 0; the new file parses.

If qml-check reports unresolved imports, the most likely fix is removing one: the only ones the file actually uses are listed above. Do not invent new properties.

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-tailscale.sh shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml
git commit -m "feat(sidebar): add TailscaleStatusCard with Open Trayscale action"
```

---

## Task 5: Slot `TailscaleStatusCard` and not-installed stub into `OpenVpnTab.qml`

Insert two blocks at the very top of the OVPN tab's main `ColumnLayout` (above the existing `openvpn-not-installed` stub): a Tailscale-not-installed stub (visible if `tailscale` is missing) and the `TailscaleStatusCard` (visible if installed).

**Files:**
- Modify: `tests/sidebar-tailscale.sh` (add fourth assertion)
- Modify: `shell/modules/sidebarRight/openvpn/OpenVpnTab.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo "ok: sidebar-tailscale static asserts"` line, with a blank line before:

```bash
# 4. OpenVpnTab instantiates TailscaleStatusCard and renders a Tailscale
#    not-installed stub gated on RyokuTailscale.installed.
assert_contains   "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml" "TailscaleStatusCard {"
assert_contains   "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml" "RyokuTailscale.installed"
assert_contains   "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml" "Tailscale not installed"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-tailscale.sh
```

Expected stderr first line:

```
FAIL: shell/modules/sidebarRight/openvpn/OpenVpnTab.qml should contain: TailscaleStatusCard {
```

- [ ] **Step 3: Insert the two blocks**

Edit `shell/modules/sidebarRight/openvpn/OpenVpnTab.qml`. The current top of the main `ColumnLayout` (around lines 43-79) starts with the `openvpn-not-installed stub` Rectangle. Insert two new sibling blocks immediately ABOVE that existing stub.

Locate this section:

```qml
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // openvpn-not-installed stub
        Rectangle {
            visible: !RyokuOpenVpn.openvpnInstalled
```

Insert the two new blocks right after the `spacing: 12` line and before `// openvpn-not-installed stub`:

```qml
        // tailscale-not-installed stub
        Rectangle {
            visible: !RyokuTailscale.installed
            Layout.fillWidth: true
            Layout.preferredHeight: tsStubCol.implicitHeight + 24
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            ColumnLayout {
                id: tsStubCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: "warning_amber"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: "Tailscale not installed"
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer2
                    }
                }
                StyledText {
                    text: "Install with: pacman -S tailscale"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        // Tailscale status card (only when installed).
        TailscaleStatusCard {
            visible: RyokuTailscale.installed
        }

```

The blank line after the closing `}` keeps the separation consistent with the existing `// openvpn-not-installed stub` block that follows. Preserve all existing whitespace, indentation, and comments below.

The QML imports at the top of `OpenVpnTab.qml` already cover `qs.services` (which exposes `RyokuTailscale`) and `qs.modules.sidebarRight.openvpn` (which exposes `TailscaleStatusCard` since both files live in the same directory). No new import lines should be needed. If qml-check fails to resolve `TailscaleStatusCard`, verify the existing imports match.

- [ ] **Step 4: Run the test + qml-check**

```bash
bash tests/sidebar-tailscale.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-tailscale static asserts`. qml-check exits 0.

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-tailscale.sh shell/modules/sidebarRight/openvpn/OpenVpnTab.qml
git commit -m "feat(sidebar): slot Tailscale stub and status card above OVPN content"
```

---

## Task 6: Extend `SecPulseIndicator.qml` for combined OVPN + Tailscale state

Rework the topbar widget so its icon represents combined VPN state (any-connected, any-transitioning, both-missing) and its tooltip becomes two lines (OpenVPN + Tailscale).

**Files:**
- Modify: `tests/bar-secpulse.sh` (add new assertions)
- Modify: `shell/modules/bar/SecPulseIndicator.qml`

- [ ] **Step 1: Add failing assertions**

Insert above the FINAL `echo "ok: bar-secpulse static asserts"` line in `tests/bar-secpulse.sh`. Add a blank line between block #5 and the new block #6:

```bash
# 6. SecPulseIndicator now reads RyokuTailscale state and the tooltip
#    surfaces both OpenVPN and Tailscale status lines.
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuTailscale.connected"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "RyokuTailscale.transitioning"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "OpenVPN:"
assert_contains   "shell/modules/bar/SecPulseIndicator.qml" "Tailscale:"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/bar-secpulse.sh
```

Expected stderr first line:

```
FAIL: shell/modules/bar/SecPulseIndicator.qml should contain: RyokuTailscale.connected
```

- [ ] **Step 3: Read the current widget content for context**

```bash
cat shell/modules/bar/SecPulseIndicator.qml
```

The current file has:
- Imports (`QtQuick`, `Quickshell`, `qs`, `qs.services`, `qs.modules.common`, `qs.modules.common.widgets`)
- MouseArea root with hover/cursor/click bindings
- `accentColor` (per-skin ternary)
- `_connected` (OVPN-only), `_missing` (OVPN-only)
- Pill rectangle with hover-color
- MaterialSymbol icon driven by `_connected` / `RyokuOpenVpn.transitioning` / `_missing`
- StyledToolTip with single-VPN text logic

The rework keeps the structure (root, pill, icon, tooltip) and only changes:
- Replace `_connected` with `_anyConnected`, `_missing` with `_bothMissing`, add `_anyTransitioning`
- Reroute icon condition checks to the new derived properties
- Replace tooltip text with a two-line composer that builds OVPN line + Tailscale line

- [ ] **Step 4: Replace the widget content**

Replace the entire contents of `shell/modules/bar/SecPulseIndicator.qml` with EXACTLY this:

```qml
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * SecPulse: at-a-glance combined OpenVPN + Tailscale connection state for
 * the topbar. Click opens the right sidebar (lands on the user's last tab,
 * which is the OpenVPN tab if they were just there). Always visible when
 * bar.modules.secPulse is on; combined-state logic drives one icon and the
 * tooltip surfaces both VPN states on separate lines.
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

    readonly property bool _anyTransitioning: RyokuOpenVpn.transitioning || RyokuTailscale.transitioning
    readonly property bool _anyConnected: (RyokuOpenVpn.activeProfile.length > 0 && !RyokuOpenVpn.transitioning)
                                          || (RyokuTailscale.connected && !RyokuTailscale.transitioning)
    readonly property bool _bothMissing: !RyokuOpenVpn.openvpnInstalled && !RyokuTailscale.installed

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
        text: root._anyTransitioning ? "sync"
            : root._anyConnected ? "vpn_key"
            : "vpn_key_off"
        fill: root._anyConnected ? 1 : 0
        iconSize: Appearance.font.pixelSize.larger
        color: root._bothMissing ? Appearance.m3colors.m3error
            : (root._anyConnected || root._anyTransitioning) ? root.accentColor
            : Appearance.colors.colSubtext

        RotationAnimation on rotation {
            loops: Animation.Infinite
            running: root._anyTransitioning
            from: 0
            to: 360
            duration: 1200
        }
    }

    function _ovpnLine() {
        if (RyokuOpenVpn.transitioning) {
            if (RyokuOpenVpn.transitionTarget.length === 0) return "OpenVPN: Disconnecting..."
            if (RyokuOpenVpn.activeProfile.length > 0)
                return "OpenVPN: Switching " + RyokuOpenVpn.activeProfile + " to " + RyokuOpenVpn.transitionTarget + "..."
            return "OpenVPN: Connecting to " + RyokuOpenVpn.transitionTarget + "..."
        }
        if (RyokuOpenVpn.activeProfile.length > 0) {
            let line = "OpenVPN: " + RyokuOpenVpn.activeProfile
            if (RyokuOpenVpn.activeIp.length > 0) line += ", " + RyokuOpenVpn.activeIp
            if (RyokuOpenVpn.activeSince.length > 0) line += ", since " + RyokuOpenVpn.activeSince
            return line
        }
        if (!RyokuOpenVpn.openvpnInstalled) return "OpenVPN: not installed"
        return "OpenVPN: off"
    }

    function _tsLine() {
        if (RyokuTailscale.transitioning) return "Tailscale: starting..."
        if (RyokuTailscale.connected) {
            let line = "Tailscale: " + RyokuTailscale.hostname
            if (RyokuTailscale.tailIp.length > 0) line += ", " + RyokuTailscale.tailIp
            if (RyokuTailscale.relay.length > 0) line += ", via " + RyokuTailscale.relay
            if (RyokuTailscale.exitNode.length > 0) line += ", exit " + RyokuTailscale.exitNode
            return line
        }
        if (!RyokuTailscale.installed) return "Tailscale: not installed"
        return "Tailscale: off"
    }

    StyledToolTip {
        extraVisibleCondition: root.containsMouse
        text: root._ovpnLine() + "\n" + root._tsLine()
    }
}
```

- [ ] **Step 5: Run the test + qml-check**

```bash
bash tests/bar-secpulse.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: bar-secpulse static asserts`. qml-check exits 0.

- [ ] **Step 6: Run the broader test suite to ensure no regressions**

```bash
bash tests/sidebar-tailscale.sh
bash tests/sidebar-openvpn.sh
bash tests/topbar-removal-regression.sh
fish shell/scripts/qml-check.fish
echo "all green"
```

All should exit 0; the chain ends with `all green`.

- [ ] **Step 7: Commit**

```bash
git add tests/bar-secpulse.sh shell/modules/bar/SecPulseIndicator.qml
git commit -m "feat(bar): combine OVPN and Tailscale state in SecPulseIndicator with two-line tooltip"
```

---

## Task 7: Deploy to live runtime, restart shell, visual smoke test

Per `docs/ui-patterns.md`, dev → runtime sync is the safe preview path. After this task the new card is visible in the sidebar and the topbar tooltip carries both VPN states.

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

1. Open the right sidebar and switch to the OpenVPN tab. At the top, above the OVPN status card, there should be a new Tailscale card with a `lan` icon, the label "Tailscale", and a status pill reading "connected" / "off" / "starting...".
2. If `tailscaled` is running and authenticated, the card should show hostname, tailIp + ", via" + relay, and (if applicable) "exit: <node>".
3. Click the "Open Trayscale" button. Trayscale should launch as a separate window.
4. Click anywhere on the card body (not the button). Trayscale should also launch via the card-wide MouseArea.
5. Hover the topbar SecPulse icon. The tooltip should now show two lines:
   ```
   OpenVPN: <state line>
   Tailscale: <state line>
   ```
   For your current state: OpenVPN line shows the active profile + IP + since-time, Tailscale line shows hostname + tailIp + via relay.
6. Confirm the topbar icon itself reflects combined state. With both connected, it shows filled `vpn_key` in the accent color. If you `tailscale down` or stop OpenVPN, the icon stays filled+accent as long as ANY VPN is up. With BOTH off but installed, it shows outlined `vpn_key_off` in subtext color.
7. (Optional) Trigger a Tailscale transition: run `tailscale down && tailscale up` in a terminal. Watch the bar icon morph to `sync` and rotate while transitioning, then settle back to `vpn_key`.

If any visual check fails, identify which task introduced the regression and use `git revert` on that specific commit. Do not bundle reverts.

- [ ] **Step 4: Confirm polling gate is honest**

```bash
# Open OVPN sidebar tab so RyokuTailscale.tabOpen=true
# Then check: tailscale status --json should be polled every 30s
journalctl --user -u ryoku-shell.service --since "1 minute ago" --no-pager 2>/dev/null | grep -i "tailscale" | tail -5
```

No specific output is required, but the absence of error spam is what we want. The poll itself doesn't log; we're confirming nothing crashes around it.

---

## Task 8: Push to origin/main (after user confirms visual)

**Files:** none (push only)

- [ ] **Step 1: Confirm with user**

Wait for the user to confirm the visual smoke test passed. Do not push without explicit go-ahead.

- [ ] **Step 2: Push**

```bash
git push origin main
```

Expected: push succeeds; six commits land on `main` (Task 1 package, Task 2 service + qmldir, Task 3 sidebar Bindings, Task 4 status card, Task 5 OVPN tab wiring, Task 6 indicator rework). Other users running `ryoku-update` will pick up the new feature on their next update cycle. The `tailscale` package is already in `install/ryoku-base.packages`; `trayscale` lands on next AUR sync.

---

## Test runbook (full)

Canonical verification command after the plan is complete:

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
bash tests/sidebar-tailscale.sh \
  && bash tests/bar-secpulse.sh \
  && bash tests/sidebar-openvpn.sh \
  && bash tests/topbar-removal-regression.sh \
  && fish shell/scripts/qml-check.fish \
  && echo "all green"
```

Every test should print at least one `ok:` line and the chain ends with `all green`.
