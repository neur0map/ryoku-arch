# Network Monitor Sidebar Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Network` tab to the right sidebar showing live per-interface status, public egress IP, VPN tunnel detection, DNS leak warnings, parsed proxychain config, and per-interface RX/TX rate. Polling is gated so the tab is silent when not visible.

**Architecture:** A `bin/ryoku-netmon-collect` bash helper emits a single JSON blob from six upstream commands (`ip -j` x3, `nmcli` x2, `resolvectl --json`). A `RyokuNetMon` singleton runs the helper every 2s when `sidebarRightOpen && tabOpen` are both true, parses the blob, computes RX/TX rates from byte deltas, runs DNS-leak detection, and exposes typed properties. A `NetMonTab.qml` widget renders an egress strip, optional proxychain card, and a scrollable list of per-active-connection cards. Wiring mirrors the established Hosts/Tailscale/SecPulse tab pattern for both regular and compact sidebar layouts. Polling-only (no DBus) per spec self-review.

**Tech Stack:** Quickshell QML 6, bash, awk, jq, `ip`, `nmcli`, `resolvectl`, optional `vnstat`, `curl`. Tests are static asserts in `tests/sidebar-netmon.sh` plus the existing `shell/scripts/qml-check.fish`.

**Spec:** `docs/superpowers/specs/2026-05-08-network-monitor-tab-design.md`

---

## File Structure

```
bin/ryoku-netmon-collect                                          NEW   ~70 lines bash, JSON-blob assembly
shell/services/RyokuNetMon.qml                                    NEW   ~260 lines singleton
shell/services/qmldir                                             EDIT  one register line
shell/modules/sidebarRight/netmon/NetMonTab.qml                   NEW   ~240 lines widget
shell/modules/sidebarRight/BottomWidgetGroup.qml                  EDIT  import + Component + allTabs + tabOpen Binding + fallback
shell/modules/sidebarRight/CompactSidebarRightContent.qml         EDIT  import + Component + widgetSections + tabOpen Binding + fallback
shell/defaults/config.json                                        EDIT  add "netmon" to sidebar.right.enabledWidgets
shell/modules/common/Config.qml                                   EDIT  same drift site (line 1412)
shell/modules/settings/InterfaceConfig.qml                        EDIT  same drift site (line 931)
migrations/<unix-ts>.sh                                           NEW   idempotent append for existing users
tests/sidebar-netmon.sh                                           NEW   static asserts, 7 blocks
```

Each file has one responsibility. The helper is a leaf with no QML dependencies. The service depends only on the helper. The widget depends only on the service. Sidebar layout files wire the widget into both tab strips. Defaults sync covers all four drift sites. Migration handles existing users with curated `enabledWidgets`.

---

## Task 1: Helper script + test scaffold + first assertion (TDD pair)

The helper assembles a single JSON blob from six commands. Leaf with no other dependencies; safe to write and test first.

**Files:**
- Create: `tests/sidebar-netmon.sh`
- Create: `bin/ryoku-netmon-collect`

- [ ] **Step 1: Create the test scaffold with first assertion**

Create `tests/sidebar-netmon.sh` with EXACTLY this content:

```bash
#!/bin/bash

# Static asserts for the Network Monitor sidebar tab. Mirrors the style
# of tests/sidebar-openvpn.sh, tests/sidebar-tailscale.sh, and
# tests/sidebar-hosts.sh. Spec:
# docs/superpowers/specs/2026-05-08-network-monitor-tab-design.md.

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

assert_executable() {
  local path="$1"
  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
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

# 1. Helper script: emits one JSON blob with addrs/routes/links/nmcli/wifi/dns.
assert_executable "bin/ryoku-netmon-collect"
assert_contains   "bin/ryoku-netmon-collect" "ip -j addr show"
assert_contains   "bin/ryoku-netmon-collect" "ip -j route show default"
assert_contains   "bin/ryoku-netmon-collect" "ip -j -s link show"
assert_contains   "bin/ryoku-netmon-collect" "nmcli"
assert_contains   "bin/ryoku-netmon-collect" "resolvectl"
assert_contains   "bin/ryoku-netmon-collect" "addrs"
assert_contains   "bin/ryoku-netmon-collect" "wifi"

echo "ok: sidebar-netmon static asserts"
```

- [ ] **Step 2: Make the test executable, run it, expect FAIL**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
chmod +x tests/sidebar-netmon.sh
bash tests/sidebar-netmon.sh
```

Expected: non-zero exit, stderr `FAIL: bin/ryoku-netmon-collect should exist`. Capture as TDD red evidence.

- [ ] **Step 3: Create the helper script**

Create `bin/ryoku-netmon-collect` with EXACTLY this content:

```bash
#!/usr/bin/env bash
# Collect kernel network state into a single JSON blob. Used by the
# RyokuNetMon QML singleton's poll Process. Each upstream command's
# output is a top-level key in the emitted blob:
#
#   { "addrs": <ip -j addr>, "routes": <ip -j route default>,
#     "links": <ip -j -s link>, "nmcli": <active connections array>,
#     "wifi":  <wifi scan array>,  "dns":   <resolvectl json> }
#
# Missing tools degrade gracefully: nmcli/resolvectl absent => empty
# arrays/objects in the corresponding slots. The QML side hides the
# DNS row and wifi-specific fields when their slots are empty.

set -uo pipefail

# Tiny awk JSON-encoder for nmcli's colon-separated `-t` output.
# Escapes backslashes and double quotes; nmcli already escapes literal
# colons in field values as `\:` which we leave as-is in the output.
nmcli_json() {
  awk -F: '
    function jq_esc(s) {
      gsub(/\\/, "\\\\", s)
      gsub(/"/, "\\\"", s)
      return s
    }
    BEGIN { sep = ""; printf "[" }
    {
      printf "%s{", sep
      for (i = 1; i <= NF; i++) {
        printf "\"f%d\":\"%s\"%s", i, jq_esc($i), (i == NF ? "" : ",")
      }
      printf "}"
      sep = ","
    }
    END { printf "]\n" }
  '
}

# Each command degrades to a JSON empty value if the tool is missing
# or the call fails.
ip_addrs="$(ip -j addr show 2>/dev/null || echo '[]')"
ip_routes="$(ip -j route show default 2>/dev/null || echo '[]')"
ip_links="$(ip -j -s link show 2>/dev/null || echo '[]')"

if command -v nmcli >/dev/null 2>&1; then
  nmcli_active="$(nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active 2>/dev/null | nmcli_json)"
  wifi_scan="$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi 2>/dev/null | nmcli_json)"
else
  nmcli_active='[]'
  wifi_scan='[]'
fi

if command -v resolvectl >/dev/null 2>&1; then
  dns_state="$(resolvectl --json=short status 2>/dev/null || echo '{}')"
else
  dns_state='{}'
fi

# Defense in depth: validate every JSON value before assembling.
# Anything malformed gets replaced with an empty placeholder.
for var in ip_addrs ip_routes ip_links nmcli_active wifi_scan dns_state; do
  val="${!var}"
  if ! printf '%s' "$val" | jq -e . >/dev/null 2>&1; then
    case "$var" in
      dns_state) printf -v "$var" '%s' '{}' ;;
      *)         printf -v "$var" '%s' '[]' ;;
    esac
  fi
done

jq -n \
  --argjson addrs  "$ip_addrs" \
  --argjson routes "$ip_routes" \
  --argjson links  "$ip_links" \
  --argjson nmcli  "$nmcli_active" \
  --argjson wifi   "$wifi_scan" \
  --argjson dns    "$dns_state" \
  '{addrs: $addrs, routes: $routes, links: $links, nmcli: $nmcli, wifi: $wifi, dns: $dns}'
```

- [ ] **Step 4: Make the helper executable, run the test + a sanity execution**

```bash
chmod +x bin/ryoku-netmon-collect
bash -n bin/ryoku-netmon-collect && echo "syntax OK"
bash tests/sidebar-netmon.sh
# Sanity: verify the helper actually runs and emits parseable JSON
./bin/ryoku-netmon-collect | jq -e 'has("addrs") and has("routes") and has("links") and has("nmcli") and has("wifi") and has("dns")' >/dev/null && echo "JSON shape OK"
```

Expected: `syntax OK`, `ok: sidebar-netmon static asserts`, `JSON shape OK`.

- [ ] **Step 5: Commit**

Stage ONLY the two files:

```bash
git add tests/sidebar-netmon.sh bin/ryoku-netmon-collect
git status --short
```

Verify exactly two files staged. Then:

```bash
git commit -m "feat(netmon): add ryoku-netmon-collect helper for kernel network state JSON"
```

---

## Task 2: `RyokuNetMon` singleton + qmldir + assertion

The singleton runs the helper every 2s when sidebar+tab are open, parses the JSON, computes per-interface state and rate, runs DNS leak detection, parses proxychain config, fetches public IP, optionally reads vnstat history.

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add second assertion block)
- Create: `shell/services/RyokuNetMon.qml`
- Modify: `shell/services/qmldir`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-netmon static asserts"` line in `tests/sidebar-netmon.sh`. Add a blank-line separator from block #1, then this new block:

```bash
# 2. Service singleton + qmldir registration. Service exposes the typed
#    surface, polls via the helper, and runs DNS-leak detection.
assert_file       "shell/services/RyokuNetMon.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuNetMon 1.0 RyokuNetMon.qml"
assert_contains   "shell/services/RyokuNetMon.qml" "ryoku-netmon-collect"
assert_matches    "shell/services/RyokuNetMon.qml" 'property var interfaces'
assert_matches    "shell/services/RyokuNetMon.qml" 'property bool tabOpen'
assert_contains   "shell/services/RyokuNetMon.qml" "GlobalStates.sidebarRightOpen && root.tabOpen"
assert_contains   "shell/services/RyokuNetMon.qml" "function refreshPublicIp"
assert_matches    "shell/services/RyokuNetMon.qml" '\^\(tun\|wg\|tailscale\)'
assert_contains   "shell/services/RyokuNetMon.qml" "dnsLeak"
assert_contains   "shell/services/RyokuNetMon.qml" "proxychain"
assert_contains   "shell/services/RyokuNetMon.qml" "https://api.ipify.org"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
bash tests/sidebar-netmon.sh
```

Expected stderr first line: `FAIL: shell/services/RyokuNetMon.qml should exist`.

- [ ] **Step 3: Create the singleton**

Create `shell/services/RyokuNetMon.qml` with EXACTLY this content:

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.modules.common

/**
 * Ryoku Network Monitor service: polls the helper script every 2s when
 * the right sidebar AND this tab are open. Computes per-interface
 * RX/TX rates from byte deltas, detects VPN tunnels, runs DNS leak
 * detection, fetches public IP one-shot on tab open, parses
 * proxychains.conf if present, and optionally reads vnstat history.
 *
 * No background work when the tab is not visible. Polling-only (no
 * DBus); see spec for why.
 */
Singleton {
    id: root

    // ── public state ──────────────────────────────────────────────
    property var interfaces: []           // see spec for object shape
    property string defaultRouteIface: ""
    property string publicIp: ""
    property bool publicIpFetching: false
    property string publicIpError: ""
    property bool dnsLeak: false
    property string dnsLeakReason: ""
    property var proxychain: null         // null when no config; else {type, configPath, proxies}
    property bool tabOpen: false          // driven by parent sidebar layout

    // ── internal: previous-sample byte counters for rate calculation
    property var _prevCounters: ({})      // { ifname: {rx, tx, ts} }

    // ── poll (2s, gated on sidebar+tab open) ──────────────────────
    Process {
        id: pollProc
        command: ["ryoku-netmon-collect"]
        stdout: StdioCollector {
            onStreamFinished: { root._parsePoll(this.text || "") }
        }
    }
    Timer {
        running: GlobalStates.sidebarRightOpen && root.tabOpen
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProc.running = true
    }

    function _parsePoll(jsonText: string): void {
        let blob
        try {
            blob = JSON.parse(jsonText)
        } catch (e) {
            return  // partial/empty stdout; next tick will retry
        }
        const addrs  = Array.isArray(blob.addrs)  ? blob.addrs  : []
        const routes = Array.isArray(blob.routes) ? blob.routes : []
        const links  = Array.isArray(blob.links)  ? blob.links  : []
        const nmcli  = Array.isArray(blob.nmcli)  ? blob.nmcli  : []
        const wifi   = Array.isArray(blob.wifi)   ? blob.wifi   : []
        const dns    = blob.dns || {}

        // Default-route interface is the dev field of the first default route.
        root.defaultRouteIface = (routes.length > 0 && routes[0].dev) ? routes[0].dev : ""

        // Build a map: ifname -> nmcli connection metadata (f1=name, f2=type, f3=device, f4=state)
        const nmByDev = {}
        for (const c of nmcli) {
            if (c.f3) nmByDev[c.f3] = { name: c.f1, type: c.f2, state: c.f4 }
        }
        // Active wifi entry: row whose IN-USE marker is "*"
        let activeWifi = null
        for (const w of wifi) {
            if (w.f1 === "*") { activeWifi = { ssid: w.f2, signal: w.f3, security: w.f4 }; break }
        }

        // Per-link DNS map: extract from resolvectl JSON. The structure has a
        // top-level array of link entries; each link has an ifname and a
        // dnsServers array of {addressString,...}. Format varies; pull what
        // we can find and accept empty when the layout doesn't match.
        const dnsByDev = {}
        const dnsLinks = Array.isArray(dns) ? dns : (Array.isArray(dns.links) ? dns.links : [])
        for (const link of dnsLinks) {
            const name = link.name || link.ifname || ""
            if (!name) continue
            const servers = (link.dnsServers || link.DNS || []).map(s => s.addressString || s.address || "").filter(s => s.length > 0)
            if (servers.length > 0) dnsByDev[name] = servers
        }
        // Default DNS resolver: first server from the default-route link, else first global fallback.
        let defaultDns = ""
        if (root.defaultRouteIface && dnsByDev[root.defaultRouteIface] && dnsByDev[root.defaultRouteIface].length > 0) {
            defaultDns = dnsByDev[root.defaultRouteIface][0]
        }

        // Compose the per-interface entries.
        const out = []
        const now = Date.now()
        const linkByIfname = {}
        for (const link of links) linkByIfname[link.ifname] = link

        const vpnIfaces = []   // for DNS leak detection
        for (const a of addrs) {
            const name = a.ifname || ""
            if (!name) continue
            // Filter: skip loopback and DOWN bridges from the cards. The widget can choose
            // to filter further (e.g. only state == UP).
            const state = (a.operstate || "UNKNOWN").toUpperCase()
            const link  = linkByIfname[name] || {}
            const stats = link.stats64 || {}
            const rxBytes = (stats.rx && stats.rx.bytes) || 0
            const txBytes = (stats.tx && stats.tx.bytes) || 0

            // Rate calculation: delta vs previous sample, divided by elapsed seconds.
            let rxRate = 0, txRate = 0
            const prev = root._prevCounters[name]
            if (prev && now > prev.ts) {
                const dt = (now - prev.ts) / 1000.0
                rxRate = Math.max(0, (rxBytes - prev.rx) / dt)
                txRate = Math.max(0, (txBytes - prev.tx) / dt)
            }

            // Pick first IPv4 + first IPv6 (prefer global over link-local but fall back gracefully).
            let ipv4 = "", ipv6 = "", ipv6Global = ""
            for (const ai of (a.addr_info || [])) {
                if (ai.family === "inet" && !ipv4) ipv4 = ai.local || ""
                else if (ai.family === "inet6") {
                    if (ai.scope === "global" && !ipv6Global) ipv6Global = ai.local || ""
                    else if (!ipv6) ipv6 = ai.local || ""
                }
            }
            ipv6 = ipv6Global || ipv6

            // Gateway: only set on the iface carrying the default route.
            let gateway = ""
            if (name === root.defaultRouteIface && routes[0] && routes[0].gateway) gateway = routes[0].gateway

            // VPN tunnel: kernel name regex from spec.
            const isVpnTunnel = /^(tun|wg|tailscale)/.test(name)
            if (isVpnTunnel && state === "UP") vpnIfaces.push(name)

            // Type classification.
            let type = "unknown"
            if (name === "lo") type = "loopback"
            else if (isVpnTunnel) type = "vpn"
            else if ((nmByDev[name] && nmByDev[name].type === "802-11-wireless") || activeWifi && nmByDev[name] && nmByDev[name].name === activeWifi.ssid) type = "wifi"
            else if (a.link_type === "ether") type = "ether"
            else if (nmByDev[name] && nmByDev[name].type === "bridge") type = "bridge"

            const connName = (nmByDev[name] && nmByDev[name].name) || ""
            const ssid     = (type === "wifi" && activeWifi) ? activeWifi.ssid : ""
            const signal   = (type === "wifi" && activeWifi) ? parseInt(activeWifi.signal, 10) || 0 : 0

            out.push({
                name: name,
                type: type,
                state: state,
                ipv4: ipv4,
                ipv6: ipv6,
                gateway: gateway,
                dns: dnsByDev[name] || [],
                rxBytes: rxBytes,
                txBytes: txBytes,
                rxRate: rxRate,
                txRate: txRate,
                isVpnTunnel: isVpnTunnel,
                connectionName: connName,
                ssid: ssid,
                signal: signal,
                vnstatToday: (root._vnstatByIface[name] && root._vnstatByIface[name].today) || "",
                vnstatMonth: (root._vnstatByIface[name] && root._vnstatByIface[name].month) || ""
            })
            root._prevCounters[name] = { rx: rxBytes, tx: txBytes, ts: now }
        }
        root.interfaces = out

        // DNS leak: any VPN iface up AND default DNS resolver is not in any VPN iface's DNS list.
        let leak = false, reason = ""
        if (vpnIfaces.length > 0 && defaultDns) {
            let defaultIsVpn = false
            for (const v of vpnIfaces) {
                if (dnsByDev[v] && dnsByDev[v].indexOf(defaultDns) !== -1) { defaultIsVpn = true; break }
            }
            if (!defaultIsVpn) {
                leak = true
                reason = "VPN " + vpnIfaces[0] + " is up but DNS queries route via " + (root.defaultRouteIface || "an unknown link")
            }
        }
        root.dnsLeak = leak
        root.dnsLeakReason = reason
    }

    // ── public IP (one-shot on tabOpen toggle, plus manual refresh) ──
    Process {
        id: publicIpProc
        command: ["sh", "-c", "curl --max-time 5 --silent https://api.ipify.org || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ip = (this.text || "").trim()
                root.publicIpFetching = false
                if (ip.length === 0) {
                    root.publicIp = ""
                    root.publicIpError = "fetch failed (no response within 5s)"
                } else {
                    root.publicIp = ip
                    root.publicIpError = ""
                }
            }
        }
    }
    onTabOpenChanged: {
        if (tabOpen && root.publicIp.length === 0 && !root.publicIpFetching) refreshPublicIp()
    }
    function refreshPublicIp(): void {
        root.publicIpFetching = true
        root.publicIpError = ""
        publicIpProc.running = true
    }

    // ── proxychains: one-shot probe at startup + on tab-open ──────
    property var _vnstatByIface: ({})
    Process {
        id: proxychainsProc
        command: ["sh", "-c", `
            for f in "$HOME/.proxychains/proxychains.conf" "/etc/proxychains.conf"; do
                if [ -f "$f" ]; then
                    echo "PATH:$f"
                    awk '
                      /^[[:space:]]*(strict_chain|dynamic_chain|random_chain|round_robin_chain)[[:space:]]*$/ {
                          gsub(/[[:space:]]/, "")
                          print "MODE:" $0
                      }
                      /^\\[ProxyList\\][[:space:]]*$/ { in_list = 1; next }
                      in_list && /^[[:space:]]*#/ { next }
                      in_list && /^[[:space:]]*$/ { next }
                      in_list && /^\\[/ { in_list = 0; next }
                      in_list && NF >= 3 {
                          # type host port [user pass]
                          print "PROXY:" $1 ":" $2 ":" $3
                      }
                    ' "$f"
                    exit 0
                fi
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (this.text || "").split("\n")
                let configPath = "", mode = "", proxies = []
                for (const line of lines) {
                    if (line.startsWith("PATH:")) configPath = line.slice(5)
                    else if (line.startsWith("MODE:")) mode = line.slice(5)
                    else if (line.startsWith("PROXY:")) {
                        const parts = line.slice(6).split(":")
                        if (parts.length >= 3) proxies.push({ type: parts[0], host: parts[1], port: parts[2] })
                    }
                }
                if (configPath.length > 0 && proxies.length > 0) {
                    root.proxychain = { type: mode, configPath: configPath, proxies: proxies }
                } else {
                    root.proxychain = null
                }
            }
        }
    }
    Component.onCompleted: proxychainsProc.running = true

    // ── vnstat (opt-in): per-iface daily + monthly totals on tab open ─
    Process {
        id: vnstatProbe
        command: ["sh", "-c", `command -v vnstat >/dev/null 2>&1 && echo y || echo n`]
        stdout: StdioCollector {
            onStreamFinished: {
                if ((this.text || "").trim() === "y") root._vnstatAvailable = true
            }
        }
    }
    property bool _vnstatAvailable: false
    Component.onCompleted: vnstatProbe.running = true

    function _refreshVnstat(): void {
        if (!root._vnstatAvailable) return
        for (const iface of root.interfaces) {
            if (iface.state !== "UP" || iface.name === "lo") continue
            const proc = Qt.createQmlObject(`
                import Quickshell.Io; Process {
                    command: ["sh", "-c", "vnstat --json -i ` + iface.name + ` 2>/dev/null"]
                    stdout: StdioCollector { onStreamFinished: root._absorbVnstat("` + iface.name + `", text) }
                    Component.onCompleted: running = true
                }`, root)
        }
    }
    function _absorbVnstat(name: string, jsonText: string): void {
        try {
            const data = JSON.parse(jsonText || "{}")
            const ifaces = data.interfaces || []
            if (ifaces.length === 0) return
            const traffic = ifaces[0].traffic || {}
            const day = (traffic.day && traffic.day[traffic.day.length - 1]) || {}
            const month = (traffic.month && traffic.month[traffic.month.length - 1]) || {}
            const fmt = function(bytes) {
                if (!bytes) return "0"
                if (bytes < 1024) return bytes + "B"
                if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + "KB"
                if (bytes < 1024*1024*1024) return (bytes/(1024*1024)).toFixed(1) + "MB"
                return (bytes/(1024*1024*1024)).toFixed(2) + "GB"
            }
            const cache = root._vnstatByIface
            cache[name] = {
                today: fmt(day.rx || 0) + "↓ " + fmt(day.tx || 0) + "↑",
                month: fmt(month.rx || 0) + "↓ " + fmt(month.tx || 0) + "↑"
            }
            root._vnstatByIface = cache
        } catch (e) {
            // Ignore: stats stay empty for this iface, UI hides the row.
        }
    }
}
```

- [ ] **Step 4: Register the singleton in `shell/services/qmldir`**

Open `shell/services/qmldir`. Find the existing line `singleton RyokuHosts 1.0 RyokuHosts.qml` (currently line 60). Insert the new line immediately after it:

```
singleton RyokuNetMon 1.0 RyokuNetMon.qml
```

Preserve every other line of `qmldir` byte-for-byte.

- [ ] **Step 5: Run the test + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-netmon static asserts`. qml-check exits 0.

If qml-check reports an unresolved import or property, double-check imports match `shell/services/RyokuTailscale.qml`'s exactly. STOP and report rather than guessing.

- [ ] **Step 6: Commit**

Stage ONLY the three files:

```bash
git add tests/sidebar-netmon.sh shell/services/RyokuNetMon.qml shell/services/qmldir
git status --short
```

Verify exactly three files staged. Then:

```bash
git commit -m "feat(services): add RyokuNetMon singleton with polling + DNS leak + proxychain parsing"
```

---

## Task 3: `NetMonTab.qml` widget

Author the sidebar tab widget: egress strip, optional proxychain card, scrollable list of per-interface cards.

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add third assertion block)
- Create: `shell/modules/sidebarRight/netmon/NetMonTab.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-netmon static asserts"` line, with a blank-line separator from block #2:

```bash
# 3. Sidebar tab widget exists, binds to RyokuNetMon, surfaces egress
#    strip + DNS-leak banner + proxychain card + per-iface cards.
assert_file       "shell/modules/sidebarRight/netmon/NetMonTab.qml"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.interfaces"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.publicIp"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.refreshPublicIp()"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.dnsLeak"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.proxychain"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" '"public"'
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" '"warning"'
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "formatRate"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

Expected stderr first line: `FAIL: shell/modules/sidebarRight/netmon/NetMonTab.qml should exist`.

- [ ] **Step 3: Create the widget**

Create `shell/modules/sidebarRight/netmon/NetMonTab.qml` with EXACTLY this content:

```qml
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * Network Monitor sidebar tab. Shows public IP / default route / VPN
 * status / DNS leak warning / proxychain config / per-interface cards
 * with live RX/TX rate. Polling lives in RyokuNetMon and is gated on
 * sidebar+tab open; this widget is purely a view.
 */
Item {
    id: root
    anchors.fill: parent

    readonly property color colAccent:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimary
        : Appearance.colors.colPrimary

    function formatRate(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec < 1) return "0 B/s"
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        if (bytesPerSec < 1024 * 1024 * 1024) return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(2) + " GB/s"
    }

    function typeIcon(type) {
        if (type === "wifi") return "signal_wifi_4_bar"
        if (type === "ether") return "lan"
        if (type === "vpn") return "vpn_key"
        if (type === "bridge") return "hub"
        if (type === "loopback") return "repeat"
        return "device_hub"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Egress strip.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: egressCol.implicitHeight + 24
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal

            ColumnLayout {
                id: egressCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol {
                        text: "public"
                        iconSize: Appearance.font.pixelSize.larger
                        color: root.colAccent
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: RyokuNetMon.publicIpFetching
                                  ? "Fetching public IP..."
                                  : (RyokuNetMon.publicIp.length > 0
                                     ? "Public IP: " + RyokuNetMon.publicIp
                                     : (RyokuNetMon.publicIpError.length > 0
                                        ? "Public IP: " + RyokuNetMon.publicIpError
                                        : "Public IP: not yet fetched"))
                            color: Appearance.colors.colOnLayer2
                            font.weight: Font.Bold
                            font.family: Appearance.font.family.monospace ?? "monospace"
                        }
                        StyledText {
                            visible: RyokuNetMon.defaultRouteIface.length > 0
                            text: "via " + RyokuNetMon.defaultRouteIface
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                    Rectangle {
                        implicitWidth: 32; implicitHeight: 32
                        radius: Appearance.rounding.small
                        color: refreshMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !RyokuNetMon.publicIpFetching
                            onClicked: RyokuNetMon.refreshPublicIp()
                        }
                    }
                }

                // DNS-leak banner.
                Rectangle {
                    visible: RyokuNetMon.dnsLeak
                    Layout.fillWidth: true
                    Layout.preferredHeight: leakRow.implicitHeight + 12
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.85)
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.5)
                    RowLayout {
                        id: leakRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8
                        MaterialSymbol {
                            text: "warning"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3error ?? "#fb4934"
                        }
                        StyledText {
                            text: RyokuNetMon.dnsLeakReason
                            color: Appearance.m3colors.m3error ?? "#fb4934"
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // Proxychain card.
        Rectangle {
            visible: RyokuNetMon.proxychain !== null
            Layout.fillWidth: true
            Layout.preferredHeight: pxCol.implicitHeight + 24
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal

            ColumnLayout {
                id: pxCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol {
                        text: "filter_alt"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.colAccent
                    }
                    StyledText {
                        text: "ProxyChain"
                        color: Appearance.colors.colOnLayer2
                        font.weight: Font.Bold
                    }
                    StyledText {
                        text: "(" + (RyokuNetMon.proxychain ? RyokuNetMon.proxychain.type : "") + ")"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: RyokuNetMon.proxychain ? RyokuNetMon.proxychain.configPath : ""
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace ?? "monospace"
                        elide: Text.ElideLeft
                        Layout.maximumWidth: 200
                    }
                }
                Repeater {
                    model: RyokuNetMon.proxychain ? RyokuNetMon.proxychain.proxies : []
                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        spacing: 6
                        StyledText {
                            text: (index + 1) + "."
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.monospace ?? "monospace"
                        }
                        StyledText {
                            text: modelData.type
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                        StyledText {
                            text: modelData.host + ":" + modelData.port
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.monospace ?? "monospace"
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // Active connections header.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "lan"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: "Active connections"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.Bold
                font.pixelSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                text: "(" + RyokuNetMon.interfaces.filter(i => i.state === "UP" && i.name !== "lo").length + ")"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            Item { Layout.fillWidth: true }
        }

        // Cards.
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: 8
                Repeater {
                    model: RyokuNetMon.interfaces.filter(i => i.state === "UP" && i.name !== "lo")
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: cardCol.implicitHeight + 18
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.normal
                        border.width: modelData.isVpnTunnel ? 1 : 0
                        border.color: modelData.isVpnTunnel ? root.colAccent : "transparent"

                        ColumnLayout {
                            id: cardCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol {
                                    text: root.typeIcon(modelData.type)
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: modelData.isVpnTunnel ? root.colAccent : Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: modelData.connectionName.length > 0 ? modelData.connectionName : modelData.name
                                    color: Appearance.colors.colOnLayer2
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: modelData.isVpnTunnel
                                    implicitWidth: vpnLabel.implicitWidth + 12
                                    implicitHeight: vpnLabel.implicitHeight + 4
                                    radius: implicitHeight / 2
                                    color: ColorUtils.transparentize(root.colAccent, 0.85)
                                    StyledText {
                                        id: vpnLabel
                                        anchors.centerIn: parent
                                        text: "VPN"
                                        color: root.colAccent
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Bold
                                    }
                                }
                                StyledText {
                                    text: modelData.state
                                    color: modelData.state === "UP" ? root.colAccent : Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }
                            StyledText {
                                visible: modelData.ipv4.length > 0
                                text: modelData.ipv4
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.monospace ?? "monospace"
                            }
                            StyledText {
                                visible: modelData.ipv6.length > 0
                                text: modelData.ipv6
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.monospace ?? "monospace"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            StyledText {
                                visible: modelData.gateway.length > 0
                                text: "via " + modelData.gateway
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                            StyledText {
                                visible: modelData.dns && modelData.dns.length > 0
                                text: "DNS: " + (modelData.dns || []).join(", ")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 8
                                Layout.topMargin: 2
                                MaterialSymbol {
                                    text: "arrow_downward"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: root.formatRate(modelData.rxRate)
                                    color: Appearance.colors.colOnLayer2
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.monospace ?? "monospace"
                                }
                                MaterialSymbol {
                                    text: "arrow_upward"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: root.formatRate(modelData.txRate)
                                    color: Appearance.colors.colOnLayer2
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.monospace ?? "monospace"
                                }
                            }
                            StyledText {
                                visible: modelData.vnstatToday && modelData.vnstatToday.length > 0
                                text: "Today: " + modelData.vnstatToday + " | Month: " + modelData.vnstatMonth
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            StyledText {
                                visible: modelData.type === "wifi" && modelData.ssid && modelData.ssid.length > 0
                                text: modelData.ssid + " | " + modelData.signal + "%"
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }
                }
            }
        }
    }
}
```

Note: the directory `shell/modules/sidebarRight/netmon/` does not exist; `mkdir -p` it before writing.

- [ ] **Step 4: Run the test + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

Expected: `ok: sidebar-netmon static asserts`. qml-check exits 0.

If qml-check reports unresolved imports or properties, STOP and report. Do NOT add new properties or restructure. The peer reference is `shell/modules/sidebarRight/hosts/HostsTab.qml`.

- [ ] **Step 5: Commit**

```bash
git add tests/sidebar-netmon.sh shell/modules/sidebarRight/netmon/NetMonTab.qml
git commit -m "feat(sidebar): add NetMonTab widget with egress strip, proxychain card, per-iface cards"
```

---

## Task 4: Wire `NetMonTab` into `BottomWidgetGroup.qml`

Five surgical edits to the regular sidebar layout: import, Component, allTabs entry, fallback array, tabOpen Binding.

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add fourth assertion block)
- Modify: `shell/modules/sidebarRight/BottomWidgetGroup.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-netmon static asserts"` line, with a blank-line separator from block #3:

```bash
# 4. BottomWidgetGroup imports the netmon module, wraps NetMonTab in
#    a Component, declares the tab in allTabs, drives RyokuNetMon.tabOpen,
#    and includes "netmon" in the enabledWidgets fallback default.
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "import qs.modules.sidebarRight.netmon"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "id: netmonWidgetComponent"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"type": "netmon"'
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "target: RyokuNetMon"
assert_matches    "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"hosts",[[:space:]]*"netmon"'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

Expected stderr first line: `FAIL: shell/modules/sidebarRight/BottomWidgetGroup.qml should contain: import qs.modules.sidebarRight.netmon`.

- [ ] **Step 3: Add the import**

Edit `shell/modules/sidebarRight/BottomWidgetGroup.qml`. Find the existing line `import qs.modules.sidebarRight.hosts`. Add immediately after:

```qml
import qs.modules.sidebarRight.netmon
```

- [ ] **Step 4: Add the Component wrapper**

Locate the existing `hostsWidgetComponent` block (around lines 78-86). Add immediately after its closing `}`:

```qml

    // NetMon component
    Component {
        id: netmonWidgetComponent
        NetMonTab {
            anchors.fill: parent
            anchors.margins: 5
        }
    }
```

- [ ] **Step 5: Add the allTabs entry**

Locate the `allTabs` array. Find the existing entry:

```qml
        {"type": "hosts", "name": Translation.tr("Hosts"), "icon": "dns", "widget": hostsWidgetComponent},
```

Add a new line immediately after it (still inside the array's closing `]`):

```qml
        {"type": "netmon", "name": Translation.tr("Network"), "icon": "lan", "widget": netmonWidgetComponent},
```

- [ ] **Step 6: Update the enabledWidgets fallback default**

Locate the line:

```qml
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts"]
```

Replace with:

```qml
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts", "netmon"]
```

- [ ] **Step 7: Add the tabOpen Binding**

Locate the existing Binding for `RyokuHosts.tabOpen` (around lines 143-147):

```qml
    Binding {
        target: RyokuHosts
        property: "tabOpen"
        value: root.currentTabType === "hosts" && !root.collapsed
    }
```

Add an identical-looking sibling Binding immediately after it:

```qml
    Binding {
        target: RyokuNetMon
        property: "tabOpen"
        value: root.currentTabType === "netmon" && !root.collapsed
    }
```

- [ ] **Step 8: Verify diff is purely additive (one fallback-array edit aside)**

```bash
git diff -- shell/modules/sidebarRight/BottomWidgetGroup.qml
```

Expected: `+` lines for the five edits, plus one `+/-` pair on the fallback line. NO other changes. If you see pre-existing user modifications, STOP and report `BLOCKED`.

- [ ] **Step 9: Run tests + qml-check**

```bash
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

Both exit 0.

- [ ] **Step 10: Commit**

```bash
git add tests/sidebar-netmon.sh shell/modules/sidebarRight/BottomWidgetGroup.qml
git commit -m "feat(sidebar): wire NetMonTab into BottomWidgetGroup tab strip"
```

---

## Task 5: Wire `NetMonTab` into `CompactSidebarRightContent.qml`

Same five edits in the compact layout. Compact uses `widgetSections` array and a richer Component wrapper with surface chrome.

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add fifth assertion block)
- Modify: `shell/modules/sidebarRight/CompactSidebarRightContent.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-netmon static asserts"` line, with a blank-line separator from block #4:

```bash
# 5. CompactSidebarRightContent imports the netmon module, wraps
#    NetMonTab in a Component, declares the section in widgetSections,
#    drives RyokuNetMon.tabOpen, and includes "netmon" in the
#    enabledWidgets fallback default.
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "import qs.modules.sidebarRight.netmon"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "id: netmonComponent"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" 'id: "netmon"'
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "target: RyokuNetMon"
assert_matches    "shell/modules/sidebarRight/CompactSidebarRightContent.qml" '"hosts",[[:space:]]*"netmon"'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Add the import**

Find `import qs.modules.sidebarRight.hosts` in the imports block. Add immediately after:

```qml
import qs.modules.sidebarRight.netmon
```

- [ ] **Step 4: Add the Component wrapper**

Read the existing `hostsComponent` block first to learn the actual surface chrome:

```bash
sed -n '565,605p' shell/modules/sidebarRight/CompactSidebarRightContent.qml
```

Mirror that exact structure with identifier renames only (`hostsComponent` -> `netmonComponent`, `hostsSurface` -> `netmonSurface`, `HostsTab` -> `NetMonTab`). Insert immediately after the closing `}` of the `hostsComponent` block.

- [ ] **Step 5: Add the widgetSections entry**

Find the existing entry:

```qml
            {id: "hosts",      icon: "dns",           label: Translation.tr("Hosts"),      component: hostsComponent},
```

Add immediately after it (preserve column alignment):

```qml
            {id: "netmon",     icon: "lan",           label: Translation.tr("Network"),    component: netmonComponent},
```

- [ ] **Step 6: Update the enabledWidgets fallback default**

Find:

```qml
        const enabled = Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts"]
```

Replace with:

```qml
        const enabled = Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts", "netmon"]
```

- [ ] **Step 7: Add the tabOpen Binding**

Find the existing Binding for `RyokuHosts.tabOpen` (around lines 753-757):

```qml
    Binding {
        target: RyokuHosts
        property: "tabOpen"
        value: root.sections[root.activeSection]?.id === "hosts"
    }
```

Add an identical-looking sibling Binding immediately after it:

```qml
    Binding {
        target: RyokuNetMon
        property: "tabOpen"
        value: root.sections[root.activeSection]?.id === "netmon"
    }
```

- [ ] **Step 8: Verify diff + run tests + qml-check**

```bash
git diff -- shell/modules/sidebarRight/CompactSidebarRightContent.qml
bash tests/sidebar-netmon.sh
fish shell/scripts/qml-check.fish
```

Diff should be purely additive except the one fallback-array line. Tests pass.

- [ ] **Step 9: Commit**

```bash
git add tests/sidebar-netmon.sh shell/modules/sidebarRight/CompactSidebarRightContent.qml
git commit -m "feat(sidebar): wire NetMonTab into CompactSidebarRightContent layout"
```

---

## Task 6: Defaults sync (3 drift sites)

Add `"netmon"` to all three default-array literals: `shell/defaults/config.json`, `shell/modules/common/Config.qml:1412`, `shell/modules/settings/InterfaceConfig.qml:931`. Same drift pattern we closed for Hosts.

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add sixth assertion block)
- Modify: `shell/defaults/config.json`
- Modify: `shell/modules/common/Config.qml`
- Modify: `shell/modules/settings/InterfaceConfig.qml`

- [ ] **Step 1: Add the failing assertion**

Insert ABOVE the FINAL `echo "ok: sidebar-netmon static asserts"` line, with a blank-line separator from block #5:

```bash
# 6. Three defaults-array drift sites all include "netmon" so the tab
#    appears for fresh installs and survives Settings UI toggles.
assert_json_expr  "shell/defaults/config.json" '.sidebar.right.enabledWidgets | index("netmon") != null' \
  "shell defaults should include 'netmon' in sidebar.right.enabledWidgets"
assert_matches    "shell/modules/common/Config.qml" '"hosts",[[:space:]]*"netmon"'
assert_matches    "shell/modules/settings/InterfaceConfig.qml" '"hosts",[[:space:]]*"netmon"'
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Add `"netmon"` to `shell/defaults/config.json`**

Locate `.sidebar.right.enabledWidgets` (currently ends with `"openvpn", "hosts"`). Add `"netmon"` after `"hosts"`:

```json
[
  "dashboard",
  "calendar",
  "events",
  "todo",
  "notepad",
  "calculator",
  "sysmon",
  "timer",
  "openvpn",
  "hosts",
  "netmon"
]
```

- [ ] **Step 4: Add `"netmon"` to `shell/modules/common/Config.qml`**

Locate line 1412 (the `enabledWidgets` literal). Append `"netmon"`:

```qml
                    property list<string> enabledWidgets: ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts", "netmon"]
```

- [ ] **Step 5: Add `"netmon"` to `shell/modules/settings/InterfaceConfig.qml`**

Locate the `defaults` property literal (around line 931). Append `"netmon"`:

```qml
                readonly property var defaults: ["calendar", "todo", "notepad", "calculator", "sysmon", "timer", "openvpn", "hosts", "netmon"]
```

- [ ] **Step 6: Validate JSON + run tests + qml-check**

```bash
jq . shell/defaults/config.json >/dev/null && echo "JSON valid"
bash tests/sidebar-netmon.sh
bash tests/sidebar-hosts.sh
bash tests/sidebar-tailscale.sh
bash tests/sidebar-openvpn.sh
bash tests/bar-secpulse.sh
bash tests/topbar-removal-regression.sh
fish shell/scripts/qml-check.fish
echo "all green"
```

All exit 0; chain ends with `all green`.

- [ ] **Step 7: Commit**

If `git diff` shows pre-existing user modifications on `InterfaceConfig.qml` (the recurring `Inir`/`Ryoku` rebrand drift), use surgical staging: snapshot, restore to HEAD, apply just the defaults-line edit, stage, restore the rebrand to the worktree as unstaged. Same pattern used during Hosts Task 6.

```bash
git add tests/sidebar-netmon.sh \
        shell/defaults/config.json \
        shell/modules/common/Config.qml \
        shell/modules/settings/InterfaceConfig.qml
git status --short
git diff --cached -- shell/modules/settings/InterfaceConfig.qml
```

The cached diff for InterfaceConfig.qml MUST contain ONLY the defaults-array edit. If anything else is in there, surgically restore.

```bash
git commit -m "feat(defaults): add netmon to enabledWidgets across all three drift sites"
```

---

## Task 7: Migration for existing users

Idempotent append of `"netmon"` to existing users' `~/.config/ryoku-shell/config.json` `sidebar.right.enabledWidgets` arrays so the new tab appears on next `ryoku-update`. Mirrors `migrations/1778295165.sh` (the analogous Hosts migration).

**Files:**
- Modify: `tests/sidebar-netmon.sh` (add seventh assertion block)
- Create: `migrations/<unix-ts>.sh`

- [ ] **Step 1: Get a fresh unix timestamp and add the failing assertion**

```bash
date +%s
ls -t migrations/*.sh | head -1
```

Confirm the new timestamp is greater than the highest existing migration filename. Use that timestamp throughout.

Insert this assertion ABOVE the FINAL `echo "ok: sidebar-netmon static asserts"` line, with a blank-line separator from block #6:

```bash
# 7. Migration appends "netmon" to existing users' enabledWidgets so
#    the tab is visible on next ryoku-update without manual config edits.
operator_migration=$(grep -lE 'enabledWidgets.*netmon|index\("netmon"\)' "$ROOT_DIR"/migrations/*.sh 2>/dev/null | head -1)
[[ -n $operator_migration ]] || fail "a migration should append netmon to enabledWidgets"
echo "  found netmon migration: $(basename "$operator_migration")"
```

- [ ] **Step 2: Run it, expect FAIL**

```bash
bash tests/sidebar-netmon.sh
```

- [ ] **Step 3: Create the migration**

Create `migrations/<unix-ts>.sh` with EXACTLY this content (substitute the timestamp into the filename, NOT the body):

```bash
#!/usr/bin/env bash
# Add "netmon" to the user's right-sidebar enabledWidgets so the new
# Network Monitor tab appears for users who already had a curated config
# from before the tab existed. Idempotent. Per docs/ui-patterns.md:198-204:
# additive entries get appended only if missing, never replacing the
# user's full list, never seeding a list when none exists (the QML
# runtime fallback handles brand-new users).

set -euo pipefail

echo "Add netmon tab to right-sidebar enabledWidgets"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CFG="$CONFIG_HOME/ryoku-shell/config.json"

if [[ ! -f "$CFG" ]]; then
    echo "  no config at $CFG, skipping"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "  jq not available, skipping" >&2
    exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

jq '
    if (.sidebar.right.enabledWidgets // null) == null then
        .
    elif (.sidebar.right.enabledWidgets | index("netmon")) then
        .
    else
        .sidebar.right.enabledWidgets += ["netmon"]
    end
' "$CFG" > "$TMP"

if ! cmp -s "$CFG" "$TMP"; then
    cp "$TMP" "$CFG"
    echo "  appended netmon to enabledWidgets in $CFG"
else
    echo "  no change needed (key missing or already contains netmon)"
fi
```

```bash
chmod +x migrations/<unix-ts>.sh
```

- [ ] **Step 4: Verify the migration**

```bash
bash -n migrations/<unix-ts>.sh && echo "syntax OK"
grep -P '\xe2\x80\x94' migrations/<unix-ts>.sh && echo "EM-DASH FOUND" || echo "no em-dashes"
bin/ryoku-dev-scan-leaks --files migrations/<unix-ts>.sh && echo "leak scan OK"
```

Live-test idempotency on the user's current config (if it doesn't already have `"netmon"`):

```bash
cp ~/.config/ryoku-shell/config.json /tmp/cfg-pre-netmon-mig.json
bash migrations/<unix-ts>.sh
diff /tmp/cfg-pre-netmon-mig.json ~/.config/ryoku-shell/config.json
rm /tmp/cfg-pre-netmon-mig.json
```

Expected: either "appended netmon to enabledWidgets" with a one-line diff (if user lacked netmon) or "no change needed" with no diff (if already present).

Run all tests:

```bash
bash tests/sidebar-netmon.sh
bash tests/sidebar-hosts.sh
bash tests/sidebar-tailscale.sh
bash tests/sidebar-openvpn.sh
bash tests/bar-secpulse.sh
bash tests/topbar-removal-regression.sh
fish shell/scripts/qml-check.fish
```

All exit 0.

- [ ] **Step 5: Commit**

Stage ONLY the two files:

```bash
git add tests/sidebar-netmon.sh migrations/<unix-ts>.sh
git status --short
git commit -m "feat(migration): append netmon to existing users' sidebar.right.enabledWidgets"
```

---

## Task 8: Deploy to live runtime, restart shell, visual smoke test

Per `docs/ui-patterns.md`, dev to runtime sync via rsync.

**Files:** none (no commits)

- [ ] **Step 1: Sync dev shell to runtime + install helper to user-bin**

```bash
DEV="${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
RUNT="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryoku-shell"
rsync -a --delete "$DEV/shell/" "$RUNT/"
install -m 755 "$DEV/bin/ryoku-netmon-collect" "$HOME/.local/share/ryoku/bin/ryoku-netmon-collect"
```

- [ ] **Step 2: Restart the user shell**

```bash
systemctl --user restart ryoku-shell.service
sleep 2
systemctl --user is-active ryoku-shell.service
```

Expected: `is-active` prints `active`.

- [ ] **Step 3: Visual smoke test (manual)**

1. Open the right sidebar; bottom tab strip should show a "Network" tab with a `lan` icon, after Hosts.
2. Click the Network tab. Egress strip at top: "Public IP: <ip>" (after a ~2s fetch), "via wlan0" subtext, refresh button.
3. If your VPN tunnel is up: a "VPN: <name>" pill or accent-bordered card appears.
4. If `~/.proxychains/proxychains.conf` or `/etc/proxychains.conf` exists: a Proxychain card appears showing the chain mode and proxy list.
5. Active connections section shows one card per UP iface (excluding `lo`): name, IPv4, IPv6, gateway, DNS list, live RX/TX rate (updates every 2s), VPN badge for tun/wg/tailscale, SSID + signal % for wifi.
6. Switch to a different sidebar tab; verify the rate counter freezes (polling stopped). Switch back; counter resumes after a moment.
7. Close the sidebar entirely; confirm no `ryoku-netmon-collect` processes lurking via `pgrep -f ryoku-netmon-collect`.
8. (Optional) Bring a tunnel up/down via Tailscale or OpenVPN and watch the connection list update within 2s.
9. (Optional) If you want to test the DNS-leak banner: temporarily reconfigure your VPN to NOT push DNS while the tunnel is up; the banner should appear within 2s. Reverse the change afterward.

If any visual check fails, identify which task introduced the regression with `git bisect` or by inspecting the most recent commits, and `git revert` that specific commit.

---

## Task 9: Push to origin/main (after user confirms visual)

**Files:** none (push only)

- [ ] **Step 1: Wait for explicit user confirmation**

Do not push without the user confirming the visual smoke test passed.

- [ ] **Step 2: Push**

```bash
cd "${RYOKU_DEV_PATH:-$HOME/prowl/ryoku-arch}"
git push origin main
```

Expected: 7 commits land on `main` (Tasks 1-7). Other users running `ryoku-update` get the new Network Monitor tab on their next update via the now-fixed install pipeline + the migration that appends `"netmon"` to their curated `enabledWidgets` arrays. No new install-script dependencies; everything is read-only and unprivileged.

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
