pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * Ryoku security pulse: VPN, optional public IP, optional listening-socket count.
 * Used only by the Three-Island topbar (cornerStyle === 4). Polls are gated
 * on bar.secPulse.show* toggles; nothing runs at startup unless a feature is on.
 */
Singleton {
    id: root

    // Public state (read by SecPulseIndicator widget)
    property bool vpnActive: false
    property string vpnProvider: ""   // "wireguard" | "tailscale" | "openvpn" | "networkmanager" | ""
    property string publicIp: ""
    property int listeningCount: 0

    // Config gates
    readonly property bool _vpnEnabled: Config.options?.bar?.secPulse?.showVpn ?? true
    readonly property bool _ipEnabled: Config.options?.bar?.secPulse?.showPublicIp ?? false
    readonly property bool _listeningEnabled: Config.options?.bar?.secPulse?.showListening ?? false

    // VPN detection: checks wireguard, tailscale, openvpn, and any
    // NetworkManager-managed VPN connection. First hit wins. The shell
    // command exits 0 quickly even when nothing is running.
    Process {
        id: vpnProc
        command: ["sh", "-c",
            "if wg show interfaces 2>/dev/null | grep -q .; then echo wireguard; " +
            "elif command -v tailscale >/dev/null 2>&1 && tailscale status --peers=false 2>/dev/null | grep -qE '^[0-9]'; then echo tailscale; " +
            "elif pgrep -x openvpn >/dev/null 2>&1; then echo openvpn; " +
            "elif command -v nmcli >/dev/null 2>&1 && nmcli -t -f TYPE,STATE connection show --active 2>/dev/null | grep -q '^vpn:activated\\|^wireguard:activated'; then echo networkmanager; " +
            "else echo ''; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const provider = this.text.trim()
                root.vpnProvider = provider
                root.vpnActive = provider.length > 0
            }
        }
    }
    Timer {
        running: root._vpnEnabled
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: vpnProc.running = true
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
