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
