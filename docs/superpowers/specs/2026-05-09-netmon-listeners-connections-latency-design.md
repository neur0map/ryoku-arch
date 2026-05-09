# Network Monitor: listener overview, established connections, latency strip

## Goal

Extend the Network Monitor sidebar tab (`shell/modules/sidebarRight/netmon/`) with three new sections that bring CTF/pentest utility:

1. **Latency strip** - auto-pinged round-trip times to the default-route gateway and to the active VPN tunnel's gateway.
2. **Listener overview** - user-owned TCP listening sockets, with click-to-open-in-browser and click-to-kill actions.
3. **Established outbound connections** - TCP connections currently in the `ESTABLISHED` state, with click-to-copy on the remote address.

All three reuse the existing tab-open polling gate (no background work when the tab is hidden), follow established service-singleton + view-widget separation, and ship with no new helper scripts (uses `ss`, `ping`, `kill`, `xdg-open` directly).

## Non-goals

- Pinging arbitrary user-input targets (deferred - auto-only for v1).
- Killing privileged-port listeners (root-owned). The listener filter excludes anything we can't see a PID for, so these don't appear in the UI.
- UDP listener visibility (deferred - niche for typical CTF/pentest).
- TCP-connect fallback when ICMP is blocked. Arch's `ping` ships setuid; if a user has stripped that capability or is in a restrictive container, the latency pills show timeout/red.
- Server-side service plumbing (the new poll Processes invoke commands directly; no `ryoku-netmon-*` bash helpers added).
- Existing-card actions (the per-iface IPv4/IPv6 copy is already shipped; not changed here).

## Architecture

### Service-layer additions to `shell/services/RyokuNetMon.qml`

Three new property surfaces on the existing singleton, each driven by its own gated `Process` + `Timer` (running only when `GlobalStates.sidebarRightOpen && root.tabOpen`, same pattern as the main poll):

```qml
// New properties
property var latency: []         // [{target: "192.168.1.1", label: "gw", rttMs: 12.3, ok: true}, ...]
property var listeners: []       // [{port: 3000, address: "0.0.0.0", pid: 12345, process: "python3", family: "tcp"}, ...]
property var connections: []     // [{localPort: 50000, remoteAddress: "10.10.42.1", remotePort: 22, pid: 12346, process: "ssh"}, ...]
```

**Polling cadence:**

| Property      | Source command                                                            | Interval |
|---------------|---------------------------------------------------------------------------|----------|
| `latency`     | `ping -c 1 -W 1 -n <ip>` per target (one dynamic Process per target, destroyed `onExited`, same pattern as the existing `_refreshVnstat`) | 5 s      |
| `listeners`   | `ss -tlnpH` (one Process)                                                 | 3 s      |
| `connections` | `ss -tnpH state established` (one Process)                                | 3 s      |

Two separate `ss` invocations rather than a combined filter expression: the combined form `'( state established or state listening )'` requires shell tokenisation which complicates argv invocation, and two `ss` calls are negligibly cheap (microseconds). One `Timer` triggers both Processes per tick.

`ss` flags: `-t` TCP only, `-l` listening, `-n` no-resolve (we render numeric ports), `-p` include PID, `-H` no header line. Output rows are space-separated; the parser tokenises by whitespace, with the `users:(("name",pid=N,fd=M))` field always last when `-p` is set.

**Latency target derivation** (each 5 s tick computes the target list before issuing pings):

```js
const defaultDev = root.defaultRouteIface
const defaultIsVpn = /^(tun|wg|tailscale)/.test(defaultDev)
const targets = []

// Always: the default-route gateway. Label depends on whether the default
// route is itself a VPN tunnel (full-tunnel mode).
if (routes[0] && routes[0].gateway) {
    targets.push({
        target: routes[0].gateway,
        label: defaultIsVpn ? "vpn" : "gw"
    })
}

// Split-tunnel case: VPN is up but is NOT the default route. Use the cached
// per-iface gateway from `_vpnGatewayCache` (populated by an on-iface-change
// probe described below).
if (!defaultIsVpn) {
    for (const i of root.interfaces) {
        if (i.isVpnTunnel && (i.state === "UP" || i.ipv4.length > 0)) {
            const gw = root._vpnGatewayCache[i.name]
            if (gw) targets.push({ target: gw, label: "vpn" })
            break
        }
    }
}
```

**VPN gateway cache** (`_vpnGatewayCache: { ifname: gateway }`) is populated by a one-shot probe `ip -j route show dev <iface>` that runs whenever a new VPN tunnel iface appears in `root.interfaces` (detected by comparing the current and previous interfaces snapshot inside `_parsePoll`). Result is parsed for `gateway` field; entries are kept until the iface disappears, at which point the cache key is dropped. Cache also drops when `tabOpen` toggles to false to avoid stale entries on long sessions.

**Initial-state behaviour:** before the first ping returns, `latency` is `[]` and the strip renders no pills (no placeholder text). Once any ping returns, that target's pill appears. The strip's parent `RowLayout` collapses gracefully when empty.

**Result:**

| Scenario                              | Pills shown                                |
|---------------------------------------|--------------------------------------------|
| No VPN                                | `gw 12 ms`                                 |
| VPN is default route (full-tunnel)    | `vpn 84 ms`                                |
| VPN active, split-tunnel              | `gw 12 ms`  `vpn 84 ms`                    |
| Tailscale (no kernel gateway)         | `gw 12 ms` only, VPN pill skipped          |
| First 5 s after tab open              | empty (no pills until ping returns)        |

**Action helpers (one-shot, not polled):**

```qml
Process {
    id: killProc
    // command set per-call by killListener()
}

function killListener(pid: int): void {
    // SIGTERM via /usr/bin/kill; next listener poll (within 3 s) will reflect.
    // Concurrent calls are not expected (kill is sub-millisecond), but the
    // pattern of mutating the command-then-running an existing Process is
    // already used by the public-IP fetch in this same file.
    killProc.command = ["kill", String(pid)]
    killProc.running = true
}
```

Browser-open is invoked from `ListenerSection.qml` directly via the established codebase API:

```qml
Quickshell.execDetached(["xdg-open", "http://localhost:" + port])
```

(`Quickshell.execDetached` is the canonical detached-launch helper used by `shell/GlobalStates.qml`, `shell/killDialog.qml`, `shell/shell.qml`.) No service-side wrapper for browser-open since there's no state to track.

### UI: extracted components

`NetMonTab.qml` is currently 379 lines and three more sections would push it past 600. Natural extraction point - split out three sibling components co-located in `shell/modules/sidebarRight/netmon/`:

```
shell/modules/sidebarRight/netmon/
├── NetMonTab.qml              (slimmed composition root, ~280 lines)
├── LatencyStrip.qml           (NEW, ~80 lines)
├── ListenerSection.qml        (NEW, ~140 lines)
└── ConnectionsSection.qml     (NEW, ~110 lines)
```

`NetMonTab.qml` keeps the egress card (with the new `LatencyStrip` slotted inside it), DNS-leak banner, proxychain card, active-connections header + cards. `ListenerSection` and `ConnectionsSection` are mounted under Active connections in the same `ScrollView` ColumnLayout.

The netmon module folder has no `qmldir` file (sibling sidebar tabs `hosts/`, `openvpn/` follow the same pattern); QML resolves new components by filename within the module path. No explicit registration needed.

**Required imports per file:**

- `LatencyStrip.qml`: `qs.modules.common`, `qs.modules.common.widgets`, `qs.services`, `QtQuick`, `QtQuick.Layouts`.
- `ListenerSection.qml`: `qs.modules.common`, `qs.modules.common.widgets`, `qs.services`, `Quickshell` (for `execDetached`), `QtQuick`, `QtQuick.Layouts`.
- `ConnectionsSection.qml`: `qs.modules.common`, `qs.modules.common.widgets`, `qs.services`, `Quickshell` (for `clipboardText`), `QtQuick`, `QtQuick.Layouts`.

Each component is a top-level `Item` or `ColumnLayout` with `Layout.fillWidth: true` so it slots into a parent `ColumnLayout` row. Each accepts a `colAccent` property (passed in from `NetMonTab.qml`) so all three sections share a single theme-aware accent computation rather than re-deriving it. Inside `NetMonTab.qml`:

```qml
LatencyStrip { colAccent: root.colAccent }
ListenerSection { colAccent: root.colAccent }
ConnectionsSection { colAccent: root.colAccent }
```

## UI shape

### Latency strip

Sits **inside the egress card**, below the public-IP row and above the existing DNS-leak banner (when shown). One row of pills, each pill renders:

```
[ gw  12 ms ]  [ vpn  84 ms ]
```

- Pill shape: rounded `Rectangle` with `radius: implicitHeight / 2`, padded label `<label> <ms>`.
- Pill background: 15%-opacity tint of the threshold color over `Appearance.colors.colLayer2`. Border at full color, 1px.
- Color thresholds:
  - `< 50 ms` green: `Appearance.colors.colPrimary` (theme accent already used by VPN-tunnel borders).
  - `< 200 ms` yellow: `Appearance.m3colors.m3warning` if defined, else hex fallback `"#fabd2f"`.
  - `>= 200 ms` or timeout red: `Appearance.m3colors.m3error` if defined, else hex fallback `"#fb4934"`.
- Failure pill: when a ping returns non-zero or the parser fails to extract `time=`, the pill renders `<label> timeout` in red.
- Empty `latency` array (initial state, or both pings yet to complete) renders no pills, so the strip occupies no vertical space.
- VPN pill hidden when no VPN tunnel is up or no gateway is known (cache miss).

### Listener overview

Section header is a horizontal row: `MaterialSymbol "wifi_tethering"` icon + `"Listeners"` label (bold) + count pill `(N)`. Below, a column of listener rows:

```
[3000]  python3            0.0.0.0       [ × ]
[4444]  nc                 0.0.0.0       [ × ]
[8080]  java               127.0.0.1     [ × ]
```

- Port pill (left): clickable, opens `http://localhost:<port>` via `Quickshell.execDetached(["xdg-open", "http://localhost:" + port])`. Pill background `ColorUtils.transparentize(root.colAccent, 0.85)`. Cursor `PointingHandCursor`. Tooltip text `"Open in browser"`.
- Process name: plain text, default color.
- Bound address: monospace, color-coded for the security signal. `0.0.0.0` and `::` (any-address bind, exposed to LAN) render in `Appearance.m3colors.m3warning` or fallback `"#fabd2f"`. `127.0.0.1` and `::1` (loopback-only) render in `Appearance.colors.colSubtext`. Other addresses (e.g. `192.168.1.5`) render in `Appearance.colors.colSubtext`.
- Close icon (right): `MaterialSymbol "close"` inside a clickable square (32x32, hover-tinted). Calls `RyokuNetMon.killListener(pid)`. On click: row opacity drops to 0.5 for 3 s (handled by a per-row Timer), then restores. If the next poll has removed the row, the visual cue is moot; if the row remains, opacity restoration signals the kill failed.
- Empty state: muted text `"No listening ports"` when `RyokuNetMon.listeners.length === 0`.

### Established outbound connections

Section header is a horizontal row: `MaterialSymbol "arrow_outward"` icon + `"Outbound"` label (bold) + count pill `(N)`. Below, a column of connection rows:

```
ssh         10.10.42.1:22
firefox     142.250.80.36:443
```

- Process name (left): plain text, monospace.
- Remote `IP:port` (right): monospace, default color, accent color on hover. Right-aligned via a flex spacer. Click row anywhere copies the bare IP (no port) to clipboard via `Quickshell.clipboardText = remoteAddress`, with the same `"Copied!"` flash for 1.5 s as the per-iface IP rows.
- Empty state: muted text `"No outbound connections"` when `RyokuNetMon.connections.length === 0`.
- Filter: only rows where the parser extracted a `pid` (= user-owned). System-process connections without a visible PID are dropped at the service layer.

## Polling discipline

All three new sections share the existing tab-open gate. The `latency`, `listeners`, and `connections` properties are populated only when `GlobalStates.sidebarRightOpen && root.tabOpen`. When the tab is closed:

- All three Timers stop (`running: false`) - no `ss`, `ping`, or `kill` processes spawn.
- Properties retain their last values (no flash of empty state when the tab reopens).
- `killListener()` calls when tab is closed are no-ops; the helper relies on the next poll for visual confirmation, so the kill executes but the user never sees the result. This is acceptable since closing a tab mid-action is rare.

## Edge cases + risks

| Case                                    | Behavior                                                      |
|-----------------------------------------|---------------------------------------------------------------|
| Privileged-port kill (root-owned)       | Filter hides them upstream; can't reach the X icon.           |
| Process exits between poll and click    | `kill` of invalid PID is a silent no-op; next poll removes the row. |
| Many listeners (e.g., docker NAT)       | Section lives in the parent ScrollView; no extra scroll.      |
| `ss` unavailable                        | Service degrades to empty arrays; sections show empty states. |
| `ping` not setuid (rare)                | Latency pings return error; pills show red `timeout`.         |
| Tailscale (no traditional gateway)      | Skip VPN pill; latency shows only `gw`.                       |
| Browser-open on non-HTTP port (e.g., 22)| `xdg-open http://localhost:22` opens the browser; user sees connection-refused. Acceptable UX - port pill click is "best-effort open". |
| Race: poll mid-truncation of stdout     | `ss` outputs are atomic line-by-line via stdio; no partial-line risk. |
| ipv6 listeners (`tcp6`, address `::`)   | Show as a separate row, address rendered as `::` or `::1`. Browser-open path uses `http://localhost:<port>` (works for v4+v6 dual-stack). |
| Listener on an unusual address (e.g., `192.168.1.5:8080`) | Rendered as-is; browser-open still uses `localhost:<port>` since clicking expresses "open my own listener". |

## Testing

Static asserts appended to `tests/sidebar-netmon.sh` (existing file). New block #8:

```bash
# 8. Listener overview, outbound connections, and latency strip surfaces.
assert_file       "shell/modules/sidebarRight/netmon/LatencyStrip.qml"
assert_file       "shell/modules/sidebarRight/netmon/ListenerSection.qml"
assert_file       "shell/modules/sidebarRight/netmon/ConnectionsSection.qml"
assert_matches    "shell/services/RyokuNetMon.qml" 'property var latency'
assert_matches    "shell/services/RyokuNetMon.qml" 'property var listeners'
assert_matches    "shell/services/RyokuNetMon.qml" 'property var connections'
assert_matches    "shell/services/RyokuNetMon.qml" 'property var _vpnGatewayCache'
assert_contains   "shell/services/RyokuNetMon.qml" "function killListener"
assert_contains   "shell/services/RyokuNetMon.qml" "ss -tlnpH"
assert_contains   "shell/services/RyokuNetMon.qml" "state established"
assert_contains   "shell/services/RyokuNetMon.qml" "ping -c 1 -W 1"
assert_contains   "shell/services/RyokuNetMon.qml" "ip -j route show dev"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "xdg-open"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "RyokuNetMon.killListener"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "Quickshell.execDetached"
assert_contains   "shell/modules/sidebarRight/netmon/ConnectionsSection.qml" "Quickshell.clipboardText"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "LatencyStrip"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "ListenerSection"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "ConnectionsSection"
```

No live-kill test (would require spawning a victim process from the test harness). Coverage relies on the existing `bash tests/sidebar-netmon.sh && fish shell/scripts/qml-check.fish` chain plus the visual smoke test during deployment.

## Out of scope (deferred)

- User-configurable ping targets with persistence in `config.json` (separate spec when needed).
- Bandwidth sparkline (visual flair, no info gain).
- DNS lookup tool (separate utility, distinct from monitoring).
- Quick proxychains test (covered by a separate proxychains-editor spec if pursued).
- Killing connections (vs killing listeners) - connections are mostly external; killing them is rarely useful and adds noise to the UI.
- "Open in terminal" or "Show full process tree" affordances on listener/connection rows.

## Naming

The three new components keep the `*Section.qml` / `*Strip.qml` naming convention to match the file role:

- `LatencyStrip.qml` - horizontal pill row, embedded inside another card.
- `ListenerSection.qml` - full-width section with header + body.
- `ConnectionsSection.qml` - same shape as ListenerSection.

The shared `Section.qml` extraction is **not** part of this spec - both ListenerSection and ConnectionsSection have enough divergent body shape that a generic header+body wrapper would save little. Revisit if a third section follows a similar shape later.
