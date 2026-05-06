pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * Ryoku security pulse: Tailscale status, optional public IP, optional
 * listening-socket count. Used only by the Three-Island topbar
 * (cornerStyle === 4). Polls are gated on bar.secPulse.show* toggles;
 * nothing runs at startup unless a feature is on.
 */
Singleton {
    id: root

    // Public state (read by SecPulseIndicator widget)
    property bool tsConnected: false
    property string tsHostname: ""
    property string tsIp: ""
    property string tsRelay: ""
    property string tsExitNode: ""   // "" when no remote exit node is in use
    property string publicIp: ""
    property int listeningCount: 0

    // Config gates
    readonly property bool _vpnEnabled: Config.options?.bar?.secPulse?.showVpn ?? true
    readonly property bool _ipEnabled: Config.options?.bar?.secPulse?.showPublicIp ?? false
    readonly property bool _listeningEnabled: Config.options?.bar?.secPulse?.showListening ?? false

    // Tailscale status: single `tailscale status --json` parse. Stays empty
    // (tsConnected=false) when tailscale isn't installed or the daemon
    // isn't running.
    Process {
        id: tsProc
        command: ["sh", "-c", "command -v tailscale >/dev/null 2>&1 && tailscale status --json 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim()
                if (raw.length === 0) {
                    root.tsConnected = false
                    root.tsHostname = ""
                    root.tsIp = ""
                    root.tsRelay = ""
                    root.tsExitNode = ""
                    return
                }
                try {
                    const data = JSON.parse(raw)
                    const self = data?.Self ?? {}
                    const running = data?.BackendState === "Running"
                    root.tsConnected = running && (self.Online === true)
                    root.tsHostname = self.HostName ?? ""
                    root.tsIp = (self.TailscaleIPs && self.TailscaleIPs.length > 0) ? self.TailscaleIPs[0] : ""
                    root.tsRelay = self.Relay ?? ""
                    let exit = ""
                    const peers = data?.Peer ?? {}
                    for (const k in peers) {
                        if (peers[k]?.ExitNode === true) {
                            exit = peers[k]?.HostName ?? ""
                            break
                        }
                    }
                    root.tsExitNode = exit
                } catch (e) {
                    root.tsConnected = false
                }
            }
        }
    }
    Timer {
        running: root._vpnEnabled
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: tsProc.running = true
    }

    // Public IP: opt-in, network-bound
    Process {
        id: ipProc
        command: ["curl", "-s", "--max-time", "5", "ifconfig.me"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.publicIp = this.text.trim()
            }
        }
    }
    Timer {
        running: root._ipEnabled
        repeat: true
        triggeredOnStart: true
        interval: 300000
        onTriggered: ipProc.running = true
    }

    // Listening sockets: opt-in
    Process {
        id: listeningProc
        command: ["sh", "-c", "ss -lntH 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.listeningCount = parseInt(this.text.trim(), 10) || 0
            }
        }
    }
    Timer {
        running: root._listeningEnabled
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: listeningProc.running = true
    }
}
