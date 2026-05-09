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
    property bool transitioning: false   // user-initiated or parse-detected transition
    property string transitionTarget: ""   // "up" or "down" while transitioning, "" otherwise
    property string hostname: ""         // first-device hostname
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
                    root.hostname = ""
                    root.tailIp = ""
                    root.relay = ""
                    root.exitNode = ""
                    root._reconcileTransition()
                    return
                }
                try {
                    const data = JSON.parse(raw)
                    const state = data?.BackendState ?? ""
                    root.connected = (state === "Running") && (data?.Self?.Online === true)
                    root.hostname = data?.Self?.HostName ?? ""
                    root.tailIp = data?.Self?.TailscaleIPs?.[0] ?? ""
                    root.relay = data?.Self?.Relay ?? ""
                    let exit = ""
                    const peers = data?.Peer ?? {}
                    for (const k in peers) {
                        if (peers[k]?.ExitNode === true) {
                            exit = peers[k]?.HostName ?? ""
                            break
                        }
                    }
                    root.exitNode = exit
                    root._reconcileTransition()
                } catch (e) {
                    root.connected = false
                    root.hostname = ""
                    root.tailIp = ""
                    root.relay = ""
                    root.exitNode = ""
                    root._reconcileTransition()
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

    // ── public actions ────────────────────────────────────────────
    function openTrayscale(): void {
        Quickshell.execDetached(["trayscale"])
    }

    function connect(): void {
        if (root.transitioning) return
        root._beginTransition("up")
        Quickshell.execDetached(["tailscale", "up"])
    }

    function disconnect(): void {
        if (root.transitioning) return
        root._beginTransition("down")
        Quickshell.execDetached(["tailscale", "down"])
    }

    function _beginTransition(target: string): void {
        root.transitioning = true
        root.transitionTarget = target
        transitionTimeout.restart()
        postActionPoll.restart()
    }

    function _reconcileTransition(): void {
        if (!root.transitioning) return
        const expectedConnected = (root.transitionTarget === "up")
        if (root.connected === expectedConnected) {
            root.transitioning = false
            root.transitionTarget = ""
            transitionTimeout.stop()
        }
    }

    Timer {
        id: transitionTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            root.transitioning = false
            root.transitionTarget = ""
        }
    }

    Timer {
        id: postActionPoll
        interval: 1000
        repeat: false
        onTriggered: statusProc.running = true
    }
}
