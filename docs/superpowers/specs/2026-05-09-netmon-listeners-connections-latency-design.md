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

| Property                     | Source command                                          | Interval |
|------------------------------|---------------------------------------------------------|----------|
| `latency`                    | `ping -c 1 -W 1 -n <ip>` per target (one Process per target) | 5 s      |
| `listeners` + `connections`  | shared single call `ss -tnpH '( state established or state listening )'`, parsed and split client-side | 3 s      |

A single `ssProc` Process runs once per 3 s tick and emits both listening and established TCP sockets. The widget-side parser splits rows by `State` field (`LISTEN` vs `ESTAB`) into the two property arrays. This collapses two would-be polls into one and shares a timer.

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

// Split-tunnel case: VPN is up but is NOT the default route. We need the VPN
// iface's specific gateway via a separate `ip -j route show dev <iface>` probe.
// Fires only in this case (no second probe in single-pill scenarios).
if (!defaultIsVpn) {
    for (const i of root.interfaces) {
        if (i.isVpnTunnel && (i.state === "UP" || i.ipv4.length > 0)) {
            // service queues a one-shot `ip -j route show dev <i.name>` probe
            // and pushes the resulting gateway as a `vpn` target on completion
            root._probeVpnGateway(i.name)
            break
        }
    }
}
```

**Result:**

| Scenario                              | Pills shown                                |
|---------------------------------------|--------------------------------------------|
| No VPN                                | `gw 12 ms`                                 |
| VPN is default route (full-tunnel)    | `vpn 84 ms`                                |
| VPN active, split-tunnel              | `gw 12 ms`  `vpn 84 ms`                    |
| Tailscale (no kernel gateway)         | `gw 12 ms` only - VPN pill skipped         |

**Action helpers (one-shot, not polled):**

```qml
function killListener(pid: int): void {
    // SIGTERM via /usr/bin/kill; next listener poll will reflect.
    killProc.command = ["kill", String(pid)]
    killProc.running = true
}
```

Browser-open is invoked from the widget directly:

```qml
Quickshell.execDetached(["xdg-open", "http://localhost:" + port])
```

No service-side wrapper for browser-open since there's no state to track.

### UI: extracted components

`NetMonTab.qml` is currently 379 lines and three more sections would push it past 600. Natural extraction point - split out three sibling components co-located in `shell/modules/sidebarRight/netmon/`:

```
shell/modules/sidebarRight/netmon/
├── NetMonTab.qml              (slimmed composition root, ~280 lines)
├── LatencyStrip.qml           (NEW, ~80 lines)
├── ListenerSection.qml        (NEW, ~140 lines)
└── ConnectionsSection.qml     (NEW, ~110 lines)
```

`NetMonTab.qml` keeps the egress card, DNS-leak banner, proxychain card, active-connections header + cards. The three new components are mounted under Active connections in the same `ScrollView` ColumnLayout.

The `qmldir` for the netmon module remains a non-Singleton folder import (no qmldir file currently exists for this directory; the module is implicitly declared via the path). The new components are picked up by their filename inside `NetMonTab.qml` via plain QML composition - no explicit registration needed.

## UI shape

### Latency strip

Sits **inside the egress card**, below the public-IP row and above the existing DNS-leak banner. One row of pills, each pill renders:

```
[ gw  12 ms ]  [ vpn  84 ms ]
```

- Pill background: 15% transparent on the pill's color (green/yellow/red) over `Appearance.colors.colLayer2`.
- Color thresholds: `<50 ms` green (`Appearance.colors.colPrimary` or theme accent), `<200 ms` yellow (`#fabd2f` fallback), `≥200 ms` or timeout red (`Appearance.m3colors.m3error`).
- Empty-state: when both pings fail, show one neutral pill `latency: unavailable`.
- VPN pill hidden when no VPN tunnel is up or has no gateway.

### Listener overview

Section header `Listeners (N)` with a small filter icon. Below, a column of listener rows:

```
[3000]  python3              0.0.0.0           [ × ]
[4444]  nc                   0.0.0.0           [ × ]
[8080]  java                 127.0.0.1         [ × ]
```

- Port pill (left): clickable → `xdg-open http://localhost:<port>`. Pill background uses the accent color at 12% opacity. Cursor `PointingHandCursor`.
- Process name (middle): plain text, monospace font.
- Bound address (right of process): subtext color, monospace. `0.0.0.0`/`::` rendered as-is (signals "exposed to network"); `127.0.0.1`/`::1` rendered as-is (loopback-only).
- Close icon (right): MaterialSymbol `close`. Clickable → `RyokuNetMon.killListener(pid)`. On click, the row dims to 50% opacity for ~3 s (the next poll will remove it). If still present after 3 s, opacity restores to 1 (kill failed silently).
- Empty state: muted text `No listening ports`.

### Established outbound connections

Section header `Outbound (N)`. Below, a column of connection rows:

```
ssh → 10.10.42.1:22
firefox → 142.250.80.36:443
```

- Process name (left): plain text.
- Arrow + remote `IP:port` (right): monospace, accent color on hover. Clicking copies `<IP>` (just the IP, no port) to clipboard with the same "Copied!" transient as the per-iface IP rows.
- Empty state: muted text `No outbound connections`.
- Filter: only rows where we have a PID (= user-owned). System-process connections (e.g., NetworkManager DHCP) are hidden.

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
assert_contains   "shell/services/RyokuNetMon.qml" "function killListener"
assert_contains   "shell/services/RyokuNetMon.qml" "ss -tnpH"
assert_contains   "shell/services/RyokuNetMon.qml" "state established or state listening"
assert_contains   "shell/services/RyokuNetMon.qml" "ping -c 1"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "xdg-open"
assert_contains   "shell/modules/sidebarRight/netmon/ListenerSection.qml" "RyokuNetMon.killListener"
assert_contains   "shell/modules/sidebarRight/netmon/ConnectionsSection.qml" "Quickshell.clipboardText"
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
