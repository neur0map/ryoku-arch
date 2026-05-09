# Network Monitor: listeners, connections, latency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Network Monitor sidebar tab with three new sections: a latency strip (gateway + VPN exit ping), a listener overview with click-to-open-browser + click-to-kill, and an established outbound connections list with click-to-copy.

**Architecture:** Service-singleton owns three new properties (`latency`, `listeners`, `connections`) plus a VPN-gateway cache, all polled only when the sidebar AND the netmon tab are open. Three new sibling QML components (`LatencyStrip`, `ListenerSection`, `ConnectionsSection`) extracted out of `NetMonTab.qml` and wired in as children. Actions (`killListener`, `xdg-open`) are one-shot Processes; no helper scripts added.

**Tech Stack:** Quickshell QML 6, `ss` (iproute2), `ping` (iputils), `kill`, `xdg-open`. Tests are static asserts in `tests/sidebar-netmon.sh`.

**Spec:** `docs/superpowers/specs/2026-05-09-netmon-listeners-connections-latency-design.md`

---

## File Structure

```
shell/services/RyokuNetMon.qml                                 EDIT  +~190 lines (3 properties, parsers, ping, kill, vpn-cache)
shell/modules/sidebarRight/netmon/NetMonTab.qml                EDIT  +~12 lines (mount 3 new components)
shell/modules/sidebarRight/netmon/LatencyStrip.qml             NEW   ~80 lines
shell/modules/sidebarRight/netmon/ListenerSection.qml          NEW   ~140 lines
shell/modules/sidebarRight/netmon/ConnectionsSection.qml       NEW   ~110 lines
tests/sidebar-netmon.sh                                        EDIT  +8 assertion blocks (#8 through #15)
```

---

## Task 1: Service - listeners property + 3s shared Timer

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #8)
- Modify: `shell/services/RyokuNetMon.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-netmon static asserts"` line, with a blank-line separator from block #7:

```bash
# 8. Listener overview - service property + ss -tlnpH poll + parser.
assert_matches    "shell/services/RyokuNetMon.qml" 'property var listeners'
assert_contains   "shell/services/RyokuNetMon.qml" "ss -tlnpH"
assert_contains   "shell/services/RyokuNetMon.qml" "_parseListeners"
assert_contains   "shell/services/RyokuNetMon.qml" "id: ssTimer"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
bash tests/sidebar-netmon.sh
```

Expected stderr first line: `FAIL: shell/services/RyokuNetMon.qml should match regex: property var listeners`.

- [ ] **Step 3: Add the listeners property + Process + Timer + parser to `shell/services/RyokuNetMon.qml`**

Add these declarations immediately after the existing `_vnstatByIface` property block (search for `_vnstatByIface` and insert before the existing `Process { id: vnstatProbe }`):

```qml
    // ── listeners (own TCP LISTEN sockets) ───────────────────────
    property var listeners: []

    Process {
        id: ssListenersProc
        command: ["ss", "-tlnpH"]
        stdout: StdioCollector {
            onStreamFinished: { root._parseListeners(this.text || "") }
        }
    }

    Timer {
        id: ssTimer
        running: GlobalStates.sidebarRightOpen && root.tabOpen
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            ssListenersProc.running = true
        }
    }

    function _parseListeners(text: string): void {
        const out = []
        for (const line of text.split("\n")) {
            const trimmed = line.trim()
            if (trimmed.length === 0) continue
            // ss -tlnpH columns: STATE Recv-Q Send-Q Local Peer Process
            const tokens = trimmed.split(/\s+/)
            if (tokens.length < 5) continue
            const local = tokens[3]
            const procToken = tokens[tokens.length - 1]
            const procMatch = procToken.match(/users:\(\("([^"]+)",pid=(\d+),/)
            if (!procMatch) continue   // user-owned filter: drop rows without PID visibility
            const colonIdx = local.lastIndexOf(":")
            if (colonIdx < 0) continue
            let address = local.slice(0, colonIdx)
            const port = parseInt(local.slice(colonIdx + 1), 10) || 0
            // Strip surrounding [] for ipv6 display
            if (address.startsWith("[") && address.endsWith("]")) address = address.slice(1, -1)
            out.push({
                port: port,
                address: address,
                pid: parseInt(procMatch[2], 10) || 0,
                process: procMatch[1],
                family: address.includes(":") ? "tcp6" : "tcp"
            })
        }
        root.listeners = out
    }
```

- [ ] **Step 4: Run tests + qml-check + sanity-run the parser logic**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
ss -tlnpH | head -5
```

The first two exit 0. The `ss` output gives a sense of the rows the parser will see at runtime.

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-netmon.sh shell/services/RyokuNetMon.qml
git status --short
git commit -m "feat(netmon): poll TCP listeners every 3s when tab is open"
```

Verify exactly two files staged before committing.

---

## Task 2: Service - connections property + parser (hooks into existing Timer)

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #9)
- Modify: `shell/services/RyokuNetMon.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo` line, blank-line separator from block #8:

```bash
# 9. Established outbound connections - service property + parser.
assert_matches    "shell/services/RyokuNetMon.qml" 'property var connections'
assert_contains   "shell/services/RyokuNetMon.qml" "state established"
assert_contains   "shell/services/RyokuNetMon.qml" "_parseConnections"
```

- [ ] **Step 2: Run, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Add the connections property + Process + parser, and hook into the existing Timer**

Add these declarations immediately after the `ssListenersProc` Process block (the one created in Task 1):

```qml
    // ── connections (established TCP) ────────────────────────────
    property var connections: []

    Process {
        id: ssConnectionsProc
        command: ["ss", "-tnpH", "state", "established"]
        stdout: StdioCollector {
            onStreamFinished: { root._parseConnections(this.text || "") }
        }
    }
```

Then locate the existing `ssTimer` block (just added in Task 1) and modify its `onTriggered` to also fire the new Process:

```qml
        onTriggered: {
            ssListenersProc.running = true
            ssConnectionsProc.running = true
        }
```

Add the parser function near `_parseListeners`:

```qml
    function _parseConnections(text: string): void {
        const out = []
        for (const line of text.split("\n")) {
            const trimmed = line.trim()
            if (trimmed.length === 0) continue
            // ss -tnpH state established columns: STATE Recv-Q Send-Q Local Peer Process
            const tokens = trimmed.split(/\s+/)
            if (tokens.length < 5) continue
            const local = tokens[3]
            const peer = tokens[4]
            const procToken = tokens[tokens.length - 1]
            const procMatch = procToken.match(/users:\(\("([^"]+)",pid=(\d+),/)
            if (!procMatch) continue
            const peerColon = peer.lastIndexOf(":")
            if (peerColon < 0) continue
            let remoteAddress = peer.slice(0, peerColon)
            const remotePort = parseInt(peer.slice(peerColon + 1), 10) || 0
            if (remoteAddress.startsWith("[") && remoteAddress.endsWith("]")) remoteAddress = remoteAddress.slice(1, -1)
            const localColon = local.lastIndexOf(":")
            const localPort = localColon >= 0 ? (parseInt(local.slice(localColon + 1), 10) || 0) : 0
            out.push({
                localPort: localPort,
                remoteAddress: remoteAddress,
                remotePort: remotePort,
                pid: parseInt(procMatch[2], 10) || 0,
                process: procMatch[1]
            })
        }
        root.connections = out
    }
```

- [ ] **Step 4: Tests + qml-check + sanity-run**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
ss -tnpH state established | head -5
```

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-netmon.sh shell/services/RyokuNetMon.qml
git commit -m "feat(netmon): poll established TCP connections in the same 3s tick"
```

---

## Task 3: Service - latency property + per-target ping + VPN gateway cache

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #10)
- Modify: `shell/services/RyokuNetMon.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo` line, blank-line separator from block #9:

```bash
# 10. Latency strip - per-target pings, VPN gateway cache, default-gateway tracking.
assert_matches    "shell/services/RyokuNetMon.qml" 'property var latency'
assert_matches    "shell/services/RyokuNetMon.qml" 'property var _vpnGatewayCache'
assert_contains   "shell/services/RyokuNetMon.qml" "ping -c 1 -W 1"
assert_contains   "shell/services/RyokuNetMon.qml" "ip -j route show dev"
assert_contains   "shell/services/RyokuNetMon.qml" "_refreshLatency"
assert_contains   "shell/services/RyokuNetMon.qml" "_probeVpnGateway"
assert_contains   "shell/services/RyokuNetMon.qml" "_absorbPing"
```

- [ ] **Step 2: Run, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Add latency state + ping pattern + VPN gateway cache**

Add these declarations immediately after the connections section (after `_parseConnections` from Task 2):

```qml
    // ── latency strip (gateway + VPN exit) ───────────────────────
    property var latency: []
    property var _vpnGatewayCache: ({})    // { ifname: gateway }
    property string _defaultGateway: ""    // populated by _parsePoll

    Timer {
        id: latencyTimer
        running: GlobalStates.sidebarRightOpen && root.tabOpen
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: root._refreshLatency()
    }

    function _refreshLatency(): void {
        const targets = []
        const defaultDev = root.defaultRouteIface
        const defaultIsVpn = /^(tun|wg|tailscale)/.test(defaultDev)
        if (root._defaultGateway) {
            targets.push({
                target: root._defaultGateway,
                label: defaultIsVpn ? "vpn" : "gw"
            })
        }
        if (!defaultIsVpn) {
            for (const i of root.interfaces) {
                if (i.isVpnTunnel && (i.state === "UP" || i.ipv4.length > 0)) {
                    const gw = root._vpnGatewayCache[i.name]
                    if (gw) targets.push({ target: gw, label: "vpn" })
                    break
                }
            }
        }
        // Prune stale entries (targets no longer in list).
        const targetIps = targets.map(t => t.target)
        root.latency = root.latency.filter(l => targetIps.includes(l.target))
        // Issue pings; each updates its entry on return.
        for (const t of targets) {
            Qt.createQmlObject(`
                import Quickshell.Io; Process {
                    command: ["sh", "-c", "ping -c 1 -W 1 -n ` + t.target + ` 2>/dev/null"]
                    stdout: StdioCollector { onStreamFinished: root._absorbPing("` + t.target + `", "` + t.label + `", this.text) }
                    onExited: destroy()
                    Component.onCompleted: running = true
                }`, root)
        }
    }

    function _absorbPing(ip: string, label: string, output: string): void {
        const match = output.match(/time=([\d.]+)\s*ms/)
        const ok = match !== null
        const rttMs = ok ? parseFloat(match[1]) : 0
        const result = { target: ip, label: label, rttMs: rttMs, ok: ok }
        root.latency = root.latency.filter(l => l.target !== ip).concat([result])
    }

    function _probeVpnGateway(ifname: string): void {
        Qt.createQmlObject(`
            import Quickshell.Io; Process {
                command: ["sh", "-c", "ip -j route show dev ` + ifname + ` 2>/dev/null"]
                stdout: StdioCollector { onStreamFinished: root._absorbVpnGateway("` + ifname + `", this.text) }
                onExited: destroy()
                Component.onCompleted: running = true
            }`, root)
    }

    function _absorbVpnGateway(ifname: string, jsonText: string): void {
        try {
            const arr = JSON.parse(jsonText || "[]")
            if (!Array.isArray(arr)) return
            for (const r of arr) {
                if (r.gateway) {
                    const cache = Object.assign({}, root._vpnGatewayCache)
                    cache[ifname] = r.gateway
                    root._vpnGatewayCache = cache
                    return
                }
            }
        } catch (e) {
            // ignore - stays uncached, no VPN pill until next probe
        }
    }
```

- [ ] **Step 4: Wire `_parsePoll` to populate `_defaultGateway` AND probe new VPN ifaces**

Locate the existing `_parsePoll` function. Find this line:

```qml
        root.defaultRouteIface = (routes.length > 0 && routes[0].dev) ? routes[0].dev : ""
```

Add a new line immediately after:

```qml
        root._defaultGateway = (routes.length > 0 && routes[0].gateway) ? routes[0].gateway : ""
```

Then find the line at the very end of the function:

```qml
        root.interfaces = out
```

Add this block immediately after it (BEFORE the DNS-leak detection that follows):

```qml
        // Populate / prune VPN-gateway cache for the latency strip.
        for (const iface of out) {
            if (iface.isVpnTunnel && (iface.state === "UP" || iface.ipv4.length > 0)
                && !root._vpnGatewayCache[iface.name]) {
                root._probeVpnGateway(iface.name)
            }
        }
        const currentIfaceNames = out.map(i => i.name)
        const cache = Object.assign({}, root._vpnGatewayCache)
        let cacheChanged = false
        for (const k of Object.keys(cache)) {
            if (!currentIfaceNames.includes(k)) {
                delete cache[k]
                cacheChanged = true
            }
        }
        if (cacheChanged) root._vpnGatewayCache = cache
```

- [ ] **Step 5: Tests + qml-check + sanity-run**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
ping -c 1 -W 1 -n 1.1.1.1 2>&1 | grep 'time='
ip -j route show dev wlan0 | jq '.[0]' 2>/dev/null || echo "no wlan0 route"
```

- [ ] **Step 6: Commit**

```bash
git add tests/sidebar-netmon.sh shell/services/RyokuNetMon.qml
git commit -m "feat(netmon): add latency strip data + VPN gateway cache"
```

---

## Task 4: Service - `killListener` action

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #11)
- Modify: `shell/services/RyokuNetMon.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo` line, blank-line separator from block #10:

```bash
# 11. Listener kill action (SIGTERM via kill).
assert_contains   "shell/services/RyokuNetMon.qml" "function killListener"
assert_contains   "shell/services/RyokuNetMon.qml" "id: killProc"
```

- [ ] **Step 2: Run, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Add the kill Process + function**

Add these declarations immediately after the `ssConnectionsProc` Process block:

```qml
    // ── kill action (SIGTERM by PID) ─────────────────────────────
    Process {
        id: killProc
        // command set per-call by killListener()
    }

    function killListener(pid: int): void {
        // SIGTERM via /usr/bin/kill; next listener poll (within 3 s) will reflect.
        killProc.command = ["kill", String(pid)]
        killProc.running = true
    }
```

- [ ] **Step 4: Tests + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-netmon.sh shell/services/RyokuNetMon.qml
git commit -m "feat(netmon): add killListener action for the listener overview"
```

---

## Task 5: `ListenerSection.qml` widget

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #12)
- Create: `shell/modules/sidebarRight/netmon/ListenerSection.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo` line, blank-line separator from block #11:

```bash
# 12. ListenerSection widget - port pill, kill button, color-coded address.
assert_file       "shell/modules/sidebarRight/netmon/ListenerSection.qml"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "RyokuNetMon.listeners"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "RyokuNetMon.killListener"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "Quickshell.execDetached"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "xdg-open"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "wifi_tethering"
```

- [ ] **Step 2: Run, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Create `shell/modules/sidebarRight/netmon/ListenerSection.qml`**

Write EXACTLY this content:

```qml
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

/*
 * Listener overview: own-process TCP LISTEN sockets. Click the port pill to
 * open http://localhost:<port> in the default browser; click the X icon to
 * SIGTERM the listener. Bound address is color-coded (yellow for 0.0.0.0/::,
 * subtext for loopback) so the security signal is visible at a glance.
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 6

    required property color colAccent

    readonly property color colWarn: Appearance.m3colors.m3warning ?? "#fabd2f"

    function isExposed(addr) {
        return addr === "0.0.0.0" || addr === "::"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MaterialSymbol {
            text: "wifi_tethering"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: "Listeners"
            color: Appearance.colors.colOnLayer1
            font.weight: Font.Bold
            font.pixelSize: Appearance.font.pixelSize.normal
        }
        StyledText {
            text: "(" + RyokuNetMon.listeners.length + ")"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.fillWidth: true }
    }

    StyledText {
        visible: RyokuNetMon.listeners.length === 0
        text: "No listening ports"
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
        Layout.leftMargin: 4
    }

    Repeater {
        model: RyokuNetMon.listeners
        delegate: Rectangle {
            id: row
            required property var modelData
            property bool dimming: false
            Layout.fillWidth: true
            Layout.preferredHeight: rowLayout.implicitHeight + 12
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small
            opacity: dimming ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Timer {
                id: dimResetTimer
                interval: 3000
                onTriggered: row.dimming = false
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10

                // Port pill: click opens http://localhost:<port>
                Rectangle {
                    implicitWidth: portText.implicitWidth + 16
                    implicitHeight: portText.implicitHeight + 6
                    radius: implicitHeight / 2
                    color: ColorUtils.transparentize(root.colAccent, 0.85)
                    border.width: 1
                    border.color: ColorUtils.transparentize(root.colAccent, 0.6)
                    StyledText {
                        id: portText
                        anchors.centerIn: parent
                        text: row.modelData.port
                        color: root.colAccent
                        font.weight: Font.Bold
                        font.family: Appearance.font.family.monospace ?? "monospace"
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", "http://localhost:" + row.modelData.port])
                    }
                }

                StyledText {
                    text: row.modelData.process
                    color: Appearance.colors.colOnLayer2
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                StyledText {
                    text: row.modelData.address
                    color: root.isExposed(row.modelData.address) ? root.colWarn : Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                // Kill button
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28
                    radius: Appearance.rounding.small
                    color: killMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    MouseArea {
                        id: killMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !row.dimming
                        onClicked: {
                            RyokuNetMon.killListener(row.modelData.pid)
                            row.dimming = true
                            dimResetTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Tests + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

If qml-check reports unresolved imports, double-check the imports match `shell/modules/sidebarRight/netmon/NetMonTab.qml`'s established pattern. Do NOT add new imports beyond what is in the canonical content.

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-netmon.sh shell/modules/sidebarRight/netmon/ListenerSection.qml
git commit -m "feat(netmon): add ListenerSection widget with click-to-open + click-to-kill"
```

---

## Task 6: `ConnectionsSection.qml` widget

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #13)
- Create: `shell/modules/sidebarRight/netmon/ConnectionsSection.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo` line, blank-line separator from block #12:

```bash
# 13. ConnectionsSection widget - established outbound + click-to-copy.
assert_file       "shell/modules/sidebarRight/netmon/ConnectionsSection.qml"
assert_contains   "shell/modules/sidebarRight/netmon/ConnectionsSection.qml" "RyokuNetMon.connections"
assert_contains   "shell/modules/sidebarRight/netmon/ConnectionsSection.qml" "Quickshell.clipboardText"
assert_contains   "shell/modules/sidebarRight/netmon/ConnectionsSection.qml" "arrow_outward"
```

- [ ] **Step 2: Run, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Create `shell/modules/sidebarRight/netmon/ConnectionsSection.qml`**

Write EXACTLY this content:

```qml
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

/*
 * Established outbound connections: own-process TCP sockets in ESTAB state.
 * Click any row to copy the bare remote IP (no port) to the clipboard.
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 6

    required property color colAccent

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MaterialSymbol {
            text: "arrow_outward"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: "Outbound"
            color: Appearance.colors.colOnLayer1
            font.weight: Font.Bold
            font.pixelSize: Appearance.font.pixelSize.normal
        }
        StyledText {
            text: "(" + RyokuNetMon.connections.length + ")"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.fillWidth: true }
    }

    StyledText {
        visible: RyokuNetMon.connections.length === 0
        text: "No outbound connections"
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
        Layout.leftMargin: 4
    }

    Repeater {
        model: RyokuNetMon.connections
        delegate: Rectangle {
            id: row
            required property var modelData
            property bool justCopied: false
            Layout.fillWidth: true
            Layout.preferredHeight: rowLayout.implicitHeight + 10
            color: rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
            radius: Appearance.rounding.small
            Behavior on color { ColorAnimation { duration: 100 } }

            Timer {
                id: copyResetTimer
                interval: 1500
                onTriggered: row.justCopied = false
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10

                StyledText {
                    text: row.modelData.process
                    color: Appearance.colors.colOnLayer2
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.preferredWidth: 110
                    elide: Text.ElideRight
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: row.justCopied
                          ? "Copied!"
                          : (row.modelData.remoteAddress + ":" + row.modelData.remotePort)
                    color: row.justCopied ? root.colAccent : Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideMiddle
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !row.justCopied
                onClicked: {
                    Quickshell.clipboardText = row.modelData.remoteAddress
                    row.justCopied = true
                    copyResetTimer.restart()
                }
            }
        }
    }
}
```

- [ ] **Step 4: Tests + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-netmon.sh shell/modules/sidebarRight/netmon/ConnectionsSection.qml
git commit -m "feat(netmon): add ConnectionsSection widget with click-to-copy on remote IP"
```

---

## Task 7: `LatencyStrip.qml` widget

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #14)
- Create: `shell/modules/sidebarRight/netmon/LatencyStrip.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo` line, blank-line separator from block #13:

```bash
# 14. LatencyStrip widget - threshold-colored ping pills.
assert_file       "shell/modules/sidebarRight/netmon/LatencyStrip.qml"
assert_contains   "shell/modules/sidebarRight/netmon/LatencyStrip.qml" "RyokuNetMon.latency"
assert_contains   "shell/modules/sidebarRight/netmon/LatencyStrip.qml" "rttMs"
```

- [ ] **Step 2: Run, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Create `shell/modules/sidebarRight/netmon/LatencyStrip.qml`**

Write EXACTLY this content:

```qml
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Latency strip: small horizontal pill row showing ping round-trip times to
 * the default-route gateway and (when present) the active VPN tunnel's
 * gateway. Color-coded by threshold: green <50ms, yellow <200ms, red >=200ms
 * or timeout. Empty array yields zero pills (strip occupies no space).
 */
RowLayout {
    id: root
    Layout.fillWidth: true
    spacing: 6
    visible: RyokuNetMon.latency.length > 0

    required property color colAccent

    readonly property color colGood: root.colAccent
    readonly property color colWarn: Appearance.m3colors.m3warning ?? "#fabd2f"
    readonly property color colBad:  Appearance.m3colors.m3error ?? "#fb4934"

    function pillColor(rttMs, ok) {
        if (!ok) return root.colBad
        if (rttMs < 50) return root.colGood
        if (rttMs < 200) return root.colWarn
        return root.colBad
    }

    function pillText(item) {
        if (!item.ok) return item.label + " timeout"
        return item.label + " " + Math.round(item.rttMs) + " ms"
    }

    Repeater {
        model: RyokuNetMon.latency
        delegate: Rectangle {
            required property var modelData
            implicitWidth: pillLabel.implicitWidth + 18
            implicitHeight: pillLabel.implicitHeight + 6
            radius: implicitHeight / 2
            readonly property color pillCol: root.pillColor(modelData.rttMs, modelData.ok)
            color: ColorUtils.transparentize(pillCol, 0.85)
            border.width: 1
            border.color: pillCol
            StyledText {
                id: pillLabel
                anchors.centerIn: parent
                text: root.pillText(modelData)
                color: parent.pillCol
                font.weight: Font.Bold
                font.family: Appearance.font.family.monospace ?? "monospace"
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }
}
```

- [ ] **Step 4: Tests + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-netmon.sh shell/modules/sidebarRight/netmon/LatencyStrip.qml
git commit -m "feat(netmon): add LatencyStrip widget with threshold-colored pills"
```

---

## Task 8: Wire all three components into `NetMonTab.qml`

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add block #15)
- Modify: `shell/modules/sidebarRight/netmon/NetMonTab.qml`

- [ ] **Step 1: Add the failing assertion**

Insert above the FINAL `echo` line, blank-line separator from block #14:

```bash
# 15. NetMonTab mounts the three new components.
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "LatencyStrip"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "ListenerSection"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "ConnectionsSection"
```

- [ ] **Step 2: Run, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Slot LatencyStrip into the egress card**

Open `shell/modules/sidebarRight/netmon/NetMonTab.qml`. Locate the egress card's inner `ColumnLayout id: egressCol`. Find this section near the end of `egressCol`'s direct children, immediately BEFORE the existing DNS-leak banner Rectangle (`Rectangle { visible: RyokuNetMon.dnsLeak; ... }`).

Add this NEW component instance immediately above the DNS-leak banner Rectangle, still inside `egressCol`:

```qml
                LatencyStrip { colAccent: root.colAccent }
```

- [ ] **Step 4: Slot ListenerSection + ConnectionsSection at the end of the scrollable column**

Locate the existing scrollable area inner `ColumnLayout` (the one containing the `Repeater { model: root.activeIfaces ... }`). Add these two new components immediately AFTER the closing `}` of the Repeater, but still inside the inner ColumnLayout:

```qml
                ListenerSection { colAccent: root.colAccent }
                ConnectionsSection { colAccent: root.colAccent }
```

- [ ] **Step 5: Verify diff is purely additive**

```bash
git diff -- shell/modules/sidebarRight/netmon/NetMonTab.qml
```

Expected: 3 additive lines (the three component instances). NO other changes. If you see pre-existing user modifications, STOP and report `BLOCKED`.

- [ ] **Step 6: Tests + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

- [ ] **Step 7: Commit**

```bash
git add tests/sidebar-netmon.sh shell/modules/sidebarRight/netmon/NetMonTab.qml
git commit -m "feat(netmon): mount LatencyStrip, ListenerSection, ConnectionsSection in NetMonTab"
```

---

## Task 9: Deploy to runtime + visual smoke test

Per `docs/ui-patterns.md`, dev-to-runtime sync via rsync.

**Files:** none (no commits)

- [ ] **Step 1: Sync dev shell to runtime**

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
rsync -a --delete "$DEV/shell/" "$RUNT/"
```

(No new bin helpers in this batch, so nothing to install to `~/.local/share/ryoku/bin/`.)

- [ ] **Step 2: Restart the user shell**

```bash
systemctl --user restart ryoku-shell.service
sleep 3
systemctl --user is-active ryoku-shell.service
```

Expected: `active`. If `activating` or `failed`, run:

```bash
journalctl --user -u ryoku-shell.service --since="60 seconds ago" --no-pager | tail -50
```

and identify the QML error. Most likely culprit: a typo in one of the new component imports or a property the parent isn't passing.

- [ ] **Step 3: Visual smoke test (manual)**

1. Open right sidebar. Click the Network tab.
2. **Latency strip:** within ~5 s, a `gw N ms` pill appears below the public-IP row, color-coded green/yellow/red. With no VPN, only one pill. With Tailscale stopped (no VPN gateway), still only `gw`.
3. **Listener section:** open a terminal, run `python3 -m http.server 9999`. Within ~3 s, a row appears: `[9999] python3  0.0.0.0  [×]`. The address `0.0.0.0` should render in yellow (exposed signal). Click `[9999]` → default browser opens to `http://localhost:9999/` and shows the directory listing.
4. **Kill action:** click the `×` icon. The row dims to ~50% opacity. Within 3 s, the python server's terminal exits and the row disappears entirely.
5. **Loopback bind test:** `python3 -m http.server --bind 127.0.0.1 9998`. Address renders in subtext color, not yellow. Click `[9998]` opens the browser as before.
6. **Connections section:** with Firefox/curl active, you should see rows like `firefox  142.250.x.x:443`. Click any row → text flips to `Copied!` for 1.5 s. Verify clipboard with `wl-paste` (should be the bare IP, no port).
7. **Tab gating:** switch to a different sidebar tab. Run `pgrep -f 'ss -tlnpH'` and `pgrep -f 'ping -c 1'` - both should report nothing (Timers stopped).
8. **VPN behavior:** if you bring up a real VPN (`tailscale up`, OpenVPN), within 5 s a second `vpn N ms` pill appears in the latency strip. Tear down → pill disappears within ~5 s.
9. **Empty states:** with no listeners, "No listening ports" subtext shows. Same for connections.

If any check fails, identify which task introduced the regression with `git bisect` or by reading recent commits, then `git revert` that specific commit.

---

## Task 10: Push to origin/main

**Files:** none (push only)

- [ ] **Step 1: Wait for explicit user confirmation that smoke test passed**

Do not push without the user confirming.

- [ ] **Step 2: Push**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
git push origin main
```

Expected: 8 commits land on `main` (Tasks 1-8). Downstream `ryoku-update` consumers get the new sections on their next pull. No new install dependencies, no new helpers, no migrations needed (this batch piggy-backs on the netmon tab that already shipped).

---

## Test runbook (full)

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
bash tests/sidebar-netmon.sh \
  && bash tests/sidebar-hosts.sh \
  && bash tests/sidebar-tailscale.sh \
  && bash tests/sidebar-openvpn.sh \
  && bash tests/bar-secpulse.sh \
  && bash tests/topbar-removal-regression.sh \
  && fish shell/scripts/qml-check.fish \
  && echo "all green"
```
