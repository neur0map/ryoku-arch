# Network Monitor Sidebar Tab

Date: 2026-05-08
Status: Approved (pending implementation plan)

## Summary

Add a `Network` tab to the right sidebar that shows live per-interface status with a security-workstation lens: which interface carries default route, public egress IP, active VPN tunnels, DNS leak warnings, parsed proxychains config, and per-interface live RX/TX rate. Polling is gated so the tab is silent when not visible. Cards-per-active-connection layout. No topbar widget.

## Motivation

The user runs Try Hack Me, Hack The Box, and other lab VPNs from this workstation. The information that matters for that workflow:

1. Which tunnel am I currently routed through, and what does the lab see as my egress IP?
2. Are my DNS queries leaking out the LAN side while my VPN tunnel is up?
3. Is my proxychain configured and what is the chain order?
4. What is each interface actually pushing right now?

Existing options (`bmon`, `bwm-ng`, `iftop`) are TUI-only with no structured output suitable for QML. `vnstat` is JSON-friendly but historical, not live. `bandwhich` requires sudo per invocation. The cleanest path for live data is parse `ip -j` plus `/proc/net/dev` directly, layered with optional integrations: `vnstat` for historical context, NetworkManager DBus for instant state-transition signals.

## Non-goals

1. No connect/disconnect controls. NetworkManager applet plus the existing OpenVPN sidebar tab and Trayscale cover those.
2. No active DNS leak probing. Sending probe queries to detect leaks is itself a leak. We compare configured per-link resolvers against the active default resolver and surface a warning.
3. No proxychain edit affordance. Read-only display. Editing belongs in the user's editor against `proxychains.conf`.
4. No per-process bandwidth (bandwhich, nethogs). Sudo-on-every-invocation is wrong for a passive sidebar.
5. No mtr or traceroute Test buttons. mtr is one Alt-Tab away.
6. No Tor or nyx integration. Separate concern, separate feature.
7. No lab-CIDR auto-labels (THM, HTB, OffSec). Those CIDRs change without notice. The user controls OpenVPN profile names already; that name is shown on each card and is stable.
8. No topbar widget. Per the user's pattern.
9. No `bar.modules.*` toggle. Tab visibility is governed by `sidebar.right.enabledWidgets` like every other sidebar tab.

## Architecture

```
shell/
  services/
    RyokuNetMon.qml                                 NEW   singleton, polling + DBus subscription
    qmldir                                          EDIT  register the singleton
  modules/
    sidebarRight/
      BottomWidgetGroup.qml                         EDIT  import + Component + allTabs + tabOpen Binding + fallback
      CompactSidebarRightContent.qml                EDIT  same for compact layout
      netmon/
        NetMonTab.qml                               NEW   widget
  defaults/
    config.json                                     EDIT  add netmon to sidebar.right.enabledWidgets
  modules/
    common/Config.qml                               EDIT  same drift site
    settings/InterfaceConfig.qml                    EDIT  same drift site (Settings UI defaults array)
migrations/
  <unix-ts>.sh                                      NEW   idempotent append for existing user configs
tests/
  sidebar-netmon.sh                                 NEW   static asserts
```

### Boundaries

| Unit | Responsibility | Depends on |
|---|---|---|
| `RyokuNetMon.qml` | Poll kernel network state every 2s when sidebar+tab are visible. Compute live RX/TX rate from byte deltas. Detect VPN tunnels, DNS leaks. Optionally read vnstat history. Parse proxychains.conf. Expose typed properties to consumers. | `Quickshell.Io.Process`, `Quickshell.Io.FileView` |
| `NetMonTab.qml` | Render the egress strip, optional proxychain card, active-connection cards, scroll list | `RyokuNetMon`, common widgets |
| `BottomWidgetGroup.qml`, `CompactSidebarRightContent.qml` | Wire tab into both sidebar layouts, drive `tabOpen` | `RyokuNetMon`, `NetMonTab.qml` |
| Migration | Append `netmon` to existing user `enabledWidgets` arrays, idempotent, never seeds when key is missing entirely | `jq`, `~/.config/ryoku-shell/config.json` |

### Path conventions (per docs/ui-patterns.md tree map)

| Tree | Path | This feature writes there | Why |
|---|---|---|---|
| Dev | `~/prowl/ryoku-arch/shell/...` | Yes | Git source of truth |
| Installed repo | `~/.local/share/ryoku/shell/...` | Only `ryoku-update` | Git pull target |
| SHELL_PATH | `~/.local/share/ryoku-shell/...` | Only install/update flow | Generated from installed repo |
| Runtime | `~/.config/quickshell/ryoku-shell/...` | Only install/update flow or rsync preview | What Quickshell loads |
| User config | `~/.config/ryoku-shell/config.json` | Migration only, idempotent append | Hybrid per ui-patterns line 171 |

No system-state writes. The service runs entirely in user-space, reading from `/proc/net/dev`, `ip`, `nmcli`, `resolvectl`, optional `vnstat`, and DBus.

## Service surface

```qml
property var interfaces: []
// each entry: {
//   name: "wlan0",
//   type: "wifi" | "ether" | "vpn" | "loopback" | "bridge" | "unknown",
//   state: "UP" | "DOWN" | "UNKNOWN",
//   ipv4: "192.168.110.88",        // first IPv4, "" if none
//   ipv6: "fe80::2be4:...",        // first IPv6 link-local or global
//   gateway: "192.168.110.1",      // "" if no default route via this iface
//   dns: ["192.168.110.1"],        // per-link DNS resolvers
//   rxBytes, txBytes,              // raw counters from /proc/net/dev
//   rxRate, txRate,                // bytes/sec, computed from previous-sample delta
//   isVpnTunnel,                   // true when name matches ^(tun|wg|tailscale)
//   connectionName,                // nmcli's NAME column or OVPN profile name
//   ssid, signal,                  // wifi-only; "" / 0 otherwise
//   vnstatToday, vnstatMonth,      // formatted "1.2GB↓ 200MB↑" or "" if vnstat absent
// }

property string defaultRouteIface
property string publicIp
property bool publicIpFetching
property string publicIpError

property bool dnsLeak                  // true when any VPN iface is up AND default DNS is via non-VPN iface
property string dnsLeakReason          // human-readable

property var proxychain                // null if no config; else { type, configPath, proxies: [{type, host, port}] }

property bool tabOpen                  // driven by parent sidebar layout

function refreshPublicIp(): void
```

### Polling

Following `shell/modules/sidebarRight/sysmon/SysMonWidget.qml:291-296`, which is the established peer for "live data only when sidebar is open":

```qml
Timer {
    running: GlobalStates.sidebarRightOpen && root.tabOpen
    interval: 2000
    repeat: true
    triggeredOnStart: true
    onTriggered: pollProc.running = true
}
```

This double-gate (sidebar open AND tab is the active one) directly matches the user's requirement: live status when sidebar AND tab is open, no background work otherwise. When the user switches to another tab or closes the sidebar, `tabOpen` flips false and the Timer stops. No process is spawned, no work is done.

The poll Process runs a small bash pipeline that emits one JSON blob with every datum the service needs. The pipeline runs six upstream commands and assembles them with `jq`:

```
{
  "addrs":   ip -j addr show,
  "routes":  ip -j route show default,
  "links":   ip -j -s link show,
  "nmcli":   nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active,
  "wifi":    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi,
  "dns":     resolvectl --json=short status
}
```

Notes:

1. `nmcli connection show --active` does NOT include SSID or SIGNAL columns. WiFi-specific data needs the separate `nmcli device wifi` call. Both are joined by `IN-USE=*` row matching the active wifi connection's BSSID/SSID.
2. `resolvectl --json=short` requires systemd-resolved 252+. The spec assumes it; fallback degrades the per-link DNS display only. It can loop over `resolvectl status` text otherwise, or just gate the DNS row on the JSON form being available.
3. One process invocation per poll. Cheap.

### Public IP fetch

One-shot when the tab opens, plus on manual `refreshPublicIp()` click. Uses:

```
curl --max-time 5 --silent https://api.ipify.org
```

Cached in `publicIp` for the session. NEVER fetched on a periodic timer; that would be one outbound request per 2s leaking your egress to a third party every time you have the tab open. The whole point of this tab is hygiene.

If the user has a VPN tunnel up at the moment of fetch, the public IP reflects the tunnel's egress. If they connect or disconnect a tunnel, the cached value is stale until they click refresh; the UI shows a small dot or timestamp on the value to make staleness visible.

### VPN tunnel detection

An interface is flagged `isVpnTunnel: true` when its name matches the regex `^(tun|wg|tailscale)`. That covers OpenVPN (`tun0`, `tun1`, ...), WireGuard (`wg0`, `wg-quick-*`), and Tailscale (`tailscale0`). No DBus probe, no protocol heuristic, just the kernel-naming convention which is stable across all three.

### DNS leak detection

For each iface in `interfaces`:

1. If `isVpnTunnel && state == "UP"`: collect that iface's `dns` resolvers into `vpnResolvers`.

After scanning all interfaces:

2. Find the default-route iface (`defaultRouteIface`).
3. Get the system's default DNS resolver (first entry in `resolvectl status` "Current DNS Server").
4. If `vpnResolvers` is non-empty (at least one VPN tunnel up) AND the default resolver is not in `vpnResolvers`: set `dnsLeak = true`, `dnsLeakReason = "VPN <name> is up but DNS queries route via <leakIface>"`.
5. Otherwise: `dnsLeak = false`, `dnsLeakReason = ""`.

This is purely a configuration check, not an active probe. No queries are sent.

### Proxychains parsing

A FileView watches the first existing of these paths (in order):

1. `~/.proxychains/proxychains.conf`
2. `/etc/proxychains.conf`

If neither exists, `proxychain = null` and the UI hides the proxychain section.

Parser: `awk` extracts the chain-mode line (`strict_chain` / `dynamic_chain` / `random_chain` / `round_robin_chain`, exactly one is uncommented) and the `[ProxyList]` block. Each proxy line follows the format `type host port [user pass]` where type is `socks4`, `socks5`, `http`, or `raw`. The service emits `{type: "strict", configPath: "/etc/proxychains.conf", proxies: [{type, host, port}, ...]}`.

The user/auth pieces are intentionally NOT parsed or surfaced. We only show the proxy chain shape, not credentials.

### vnstat opt-in (historical totals)

If `vnstat` is on PATH, the service runs `vnstat --json -i <iface>` once per active iface on tab open and on manual refresh. Output: today's RX/TX and this-month's RX/TX, formatted human-readable. Stored in `vnstatToday` and `vnstatMonth`.

If `vnstat` is absent or returns an error, those properties stay empty strings and the UI hides the row. No fallback, no install nag. Pure opt-in.

### NetworkManager DBus subscription (deferred to future work)

The brainstorming round considered subscribing to NetworkManager DBus signals (`StateChanged`, `DeviceStateChanged`, `ActiveConnectionStateChanged`) so that interface state transitions reflect within ~100ms instead of waiting up to 2s for the next periodic poll. **Confirmed during spec self-review that this is NOT possible in the current codebase**: Quickshell does not expose a generic DBus API in any version this repo imports, and `Quickshell.Services.NetworkManager` does not exist (the available `Quickshell.Services.*` modules are `Mpris`, `Notifications`, `Pipewire`, `Polkit`, `SystemTray`, `UPower`).

Implementing event-driven NM state would require either:

1. An upstream Quickshell module that surfaces NetworkManager DBus signals to QML, OR
2. A long-running `Process` that pumps `dbus-monitor --system "type='signal',interface='org.freedesktop.NetworkManager'"` lines into stdout and parses them in QML.

Option 2 is messy (parsing dbus-monitor's text output is fragile) and adds a long-lived child process to the shell. Not worth the complexity premium versus 2s polling for a sidebar tab the user opens manually.

**This spec ships polling-only.** Event-driven state is filed as future work conditional on a Quickshell upstream NetworkManager service module landing. Polling at 2s is good enough for sidebar UX (the user manually opens the tab, sees state within 2s, and can wait that long for a transition to appear).

## UI shape (`NetMonTab.qml`)

```
ColumnLayout (anchors.fill, margins 14, spacing 12)

  Egress strip (Rectangle, rounded card, top-of-tab)
    RowLayout
      MaterialSymbol "public" (size larger)
      ColumnLayout (fillWidth)
        StyledText  "Public IP: 1.2.3.4"  bold (or spinner/error)
        StyledText  "via wlan0"  small subtext
      RippleButton "refresh"  size 32  onClicked: RyokuNetMon.refreshPublicIp()
    Rectangle (DNS-leak banner, visible: dnsLeak)
      red transparentized background
      MaterialSymbol "warning" red
      StyledText (red)  dnsLeakReason
    Rectangle (VPN-active pill, visible: any iface isVpnTunnel and UP)
      accent transparentized background
      MaterialSymbol "vpn_key" accent
      StyledText  "VPN: <connectionName> · <ip>"

  Proxychain card (Rectangle, visible: proxychain !== null)
    Header row
      MaterialSymbol "filter_alt"  StyledText "ProxyChain"  StyledText "(strict)"  small
      Item fillWidth
      StyledText (small subtext)  configPath  monospace, ellipsize
    ColumnLayout
      Repeater  model: proxychain.proxies
        delegate: RowLayout
          StyledText  small monospace  "<index+1>."
          StyledText  small  type
          StyledText  small monospace fillWidth  host + ":" + port

  Active connections header
    MaterialSymbol "lan"  StyledText "Active connections"  StyledText "(N)" small subtext

  ScrollView (fillHeight, clip)
    ColumnLayout
      Repeater  model: interfaces.filter(i => i.state === "UP")
        delegate: ConnCard (Rectangle, colLayer2, radius normal)
          ColumnLayout (margins 12, spacing 4)
            RowLayout (header)
              MaterialSymbol  text: typeIcon(type)  color: isVpnTunnel ? colAccent : colSubtext
              StyledText  bold  connectionName || name
              Item fillWidth
              Rectangle (badge, visible: isVpnTunnel)  small accent pill "VPN"
              StyledText (small)  state pill
            StyledText (small monospace) ipv4  visible: ipv4.length > 0
            StyledText (small monospace subtext) ipv6  visible: ipv6.length > 0
            StyledText (small subtext) "via " + gateway  visible: gateway.length > 0
            StyledText (small subtext) "DNS: " + dns.join(", ")
            RowLayout (rate)
              MaterialSymbol "arrow_downward" small
              StyledText  formatRate(rxRate)
              MaterialSymbol "arrow_upward" small
              StyledText  formatRate(txRate)
            StyledText (small subtext, visible: vnstatToday !== "")  "Today: " + vnstatToday + " · Month: " + vnstatMonth
            StyledText (small subtext, visible: type === "wifi" && ssid !== "")  ssid + " · " + signal + "%"
```

`typeIcon(type)`:
- `wifi` → `signal_wifi_4_bar`
- `ether` → `lan`
- `vpn` → `vpn_key`
- `bridge` → `hub`
- `loopback` → `repeat`
- default → `device_hub`

`formatRate(bytesPerSec)`:
- < 1024 → "12 B/s"
- < 1024 * 1024 → "12.3 KB/s"
- < 1024 * 1024 * 1024 → "12.3 MB/s"
- else → "12.3 GB/s"

Tab title: `Network`. Tab icon (in the bottom-tab strip): `lan`.

## Error handling

| Failure mode | Visible behavior |
|---|---|
| `ip -j addr` fails | `interfaces` stays empty, UI shows empty hero "No active connections detected" |
| `nmcli` not installed | `connectionName` falls back to interface name, `ssid`/`signal` stay empty |
| `nmcli device wifi` fails (e.g. radio off) | wifi card still renders without SSID/signal; non-wifi cards unaffected |
| `resolvectl` not installed or older than 252 | `dns` stays empty per iface, dns leak detection skipped |
| `curl` fails or times out | `publicIpError` populated with the curl error, UI shows "fetch failed" with retry button |
| `vnstat` not installed | `vnstatToday`/`vnstatMonth` stay empty, UI hides those rows |
| `proxychains.conf` not present | `proxychain = null`, UI hides the proxychain card |
| Tab closed mid-poll | Process completes, result is parsed, no harm. Next poll will not fire because Timer.running flipped to false. |

## Tests

`tests/sidebar-netmon.sh` (new) asserts:

1. `shell/services/RyokuNetMon.qml` exists.
2. `shell/services/qmldir` registers the singleton.
3. Service exposes `interfaces`, `dnsLeak`, `proxychain`, `tabOpen` properties.
4. Service exposes `refreshPublicIp` function.
5. Service polls via `ip -j` and reads `/proc/net/dev`.
6. Service includes the VPN-tunnel name regex anchor (`tun|wg|tailscale`).
7. `shell/modules/sidebarRight/netmon/NetMonTab.qml` exists.
8. `BottomWidgetGroup.qml` instantiates the tab and drives `RyokuNetMon.tabOpen`.
9. `CompactSidebarRightContent.qml` does the same.
10. `shell/defaults/config.json`, `Config.qml`, `InterfaceConfig.qml` all include `netmon` in their default arrays.
11. A migration file exists that appends `netmon` to user `enabledWidgets`.

Run the existing test suite to confirm no collateral regressions. Manual visual smoke covers the live behavior (rates, badges, leak warning, proxychain card if present).

## Risks and rollback

1. **2s polling latency for state transitions.** A WiFi disconnect or fresh VPN dial-up takes up to 2s to appear in the tab. Acceptable for a manually-opened sidebar surface. Event-driven via NM DBus is documented as future work but blocked until Quickshell upstream adds an NM service module.
2. **Public IP fetch leaks one outbound request per tab-open.** Documented and intentional. Cached for the session. Mitigated by NEVER putting it on the 2s poll loop.
3. **Three default-array drift sites stay in lockstep.** Same risk we acknowledged for Hosts. A future consolidation refactor can collapse all three into a single QML constant; out of scope here.
4. **vnstat opt-in might be confusing for new users** who don't know the daemon needs to run for a while before showing meaningful totals. Mitigation: only render the row when totals are non-zero.
5. **The proxychains parser is conservative**: rejects lines that don't match the canonical `type host port` shape. Comment lines, blank lines, and `[ProxyList]` header are skipped. If a user has heavy customization with auth fields, the proxies still parse but auth is dropped from the surface (intentional, no credentials in UI).
6. **DNS leak detection is configuration-based**, not behavioral. A leak that occurs because a process bypasses systemd-resolved (e.g., uses /etc/resolv.conf directly) won't be caught here. Active probing is out of scope (would itself leak).

Rollback: revert all listed files plus delete the new ones. No persistent system-state is created. User config gets `netmon` removed if they manually edit (or it stays as a dead entry, which is benign because no Component is registered for that type).

## Open questions resolved during brainstorming

| Question | Decision |
|---|---|
| Live source for per-interface state? | Parse `ip -j` and `/proc/net/dev` directly. Existing tools (bmon, bwm-ng, iftop) are TUI-only. |
| Public IP fetch on a timer? | No. One-shot on tab open + manual refresh. Periodic would leak an outbound query every 2s. |
| vnstat integration? | Yes, opt-in. Gracefully degrades when binary is missing. |
| NetworkManager DBus events? | Filed as future work. Confirmed during self-review that Quickshell does not expose a generic DBus API or an NM service module in any version this repo imports. Spec ships polling-only. |
| Proxychain edit affordance? | No. Read-only display. |
| Auth fields in proxychain display? | No. Type, host, port only. |
| Active DNS leak probing? | No. Compare configured resolvers per link to active default; never send probe queries. |
| Tor/nyx integration? | No. Separate concern, separate feature later. |
| Lab CIDR auto-labels (THM/HTB)? | No. CIDRs change without notice; OVPN profile name carries the signal already. |
| Topbar widget? | No. Matches your hosts/secpulse decision pattern. |
| Module toggle in `bar.modules`? | No. Tab visibility lives in `sidebar.right.enabledWidgets`. |
| Migration for existing users? | Yes. Idempotent append, mirrors Hosts pattern. |
