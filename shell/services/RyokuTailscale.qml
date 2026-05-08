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
    property string hostname: ""         // Self.HostName
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
