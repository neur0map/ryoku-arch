pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * Ryoku OpenVPN service: discovers profiles in /etc/openvpn/client/,
 * tracks the active openvpn-client@<name>.service if any, and exposes
 * connect/disconnect/remove actions that go through systemctl (gated
 * by the 49-ryoku-openvpn.rules polkit rule for password-less control).
 *
 * Polling is gated: the 5s status poll only runs while the SecPulse
 * bar indicator is enabled or the sidebar VPN tab is open; the 30s
 * profile rescan only runs while the tab is open. A FileView on
 * last-import.json triggers an immediate rescan after imports.
 */
Singleton {
    id: root

    // ── public state ──────────────────────────────────────────────
    property var profiles: []                 // [{name, path, isActive}]
    property string activeProfile: ""
    property string activeIp: ""
    property string activeSince: ""
    property int otherActiveCount: 0          // >0 if user manually started extras
    property bool transitioning: false        // disables Connect/Disconnect during state change
    property string transitionTarget: ""      // empty when transitioning=false
    property bool openvpnInstalled: true      // false iff `openvpn` binary is missing

    // ── activation gates (parents flip these) ─────────────────────
    property bool barIndicatorEnabled: Config.options?.bar?.secPulse?.showOpenVpn ?? true
    property bool tabOpen: false              // OpenVpnTab sets this in onCompleted/onDestruction
    readonly property bool _statusActive: barIndicatorEnabled || tabOpen
    readonly property bool _discoveryActive: tabOpen

    // ── status poll: 5s, gated on _statusActive ───────────────────
    Process {
        id: statusProc
        command: ["sh", "-c",
            "set -e; " +
            "active=$(systemctl --type=service --state=active --no-legend 'openvpn-client@*.service' 2>/dev/null || true); " +
            "if [ -z \"$active\" ]; then echo '{\"profile\":\"\",\"ip\":\"\",\"since\":\"\",\"others\":0}'; exit 0; fi; " +
            "first=$(printf '%s\\n' \"$active\" | head -1 | awk '{print $1}'); " +
            "count=$(printf '%s\\n' \"$active\" | wc -l); " +
            "name=${first#openvpn-client@}; name=${name%.service}; " +
            "since=$(systemctl show \"$first\" -p ActiveEnterTimestamp --value 2>/dev/null); " +
            "ip=$(ip -j addr show 2>/dev/null | jq -r '[.[] | select(.ifname|test(\"^tun\")) | .addr_info[]? | select(.family==\"inet\") | .local] | first // \"\"'); " +
            "printf '{\"profile\":\"%s\",\"ip\":\"%s\",\"since\":\"%s\",\"others\":%d}\\n' \"$name\" \"$ip\" \"$since\" \"$((count-1))\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.activeProfile = d.profile || ""
                    root.activeIp = d.ip || ""
                    root.activeSince = d.since || ""
                    root.otherActiveCount = d.others || 0
                } catch (e) {
                    root.activeProfile = ""
                    root.activeIp = ""
                    root.activeSince = ""
                    root.otherActiveCount = 0
                }
                root._reconcileTransition()
            }
        }
    }
    Timer {
        running: root._statusActive
        repeat: true
        triggeredOnStart: true
        interval: 5000
        onTriggered: statusProc.running = true
    }

    // ── discovery poll: 30s, gated on _discoveryActive + on-demand rescan() ──
    Process {
        id: discoveryProc
        command: ["sh", "-c",
            "ls -1 /etc/openvpn/client/*.conf 2>/dev/null | sed 's|^/etc/openvpn/client/||; s|\\.conf$||' | sort"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.split("\n").filter(s => s.length > 0)
                const out = []
                for (const n of names) {
                    out.push({
                        name: n,
                        path: "/etc/openvpn/client/" + n + ".conf",
                        isActive: (n === root.activeProfile)
                    })
                }
                root.profiles = out
            }
        }
    }
    Timer {
        running: root._discoveryActive
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: discoveryProc.running = true
    }

    // ── openvpn-installed check (one-shot at startup) ─────────────
    Process {
        id: presenceProc
        command: ["sh", "-c", "command -v openvpn >/dev/null 2>&1 && echo y || echo n"]
        stdout: StdioCollector {
            onStreamFinished: { root.openvpnInstalled = (this.text.trim() === "y") }
        }
    }
    Component.onCompleted: presenceProc.running = true

    // ── on-demand: importer / remove / rename signal via FileView ─
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/ryoku/openvpn/last-import.json"
        watchChanges: true
        onFileChanged: { reload(); root.rescan() }
        onLoadFailed: (err) => { /* expected before first import */ }
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/ryoku/openvpn/last-op.json"
        watchChanges: true
        onFileChanged: { reload(); root.rescan() }
        onLoadFailed: (err) => { /* expected before first op */ }
    }

    // ── public API ────────────────────────────────────────────────
    function rescan(): void {
        discoveryProc.running = true
        statusProc.running = true
    }

    function connect(name: string): void {
        if (!name) return
        if (root.transitioning) return
        if (root.activeProfile && root.activeProfile !== name) {
            root._beginTransition(name)
            Quickshell.execDetached(["sh", "-c",
                "systemctl stop 'openvpn-client@" + root.activeProfile + ".service' 2>/dev/null; " +
                "systemctl start 'openvpn-client@" + name + ".service'"])
        } else {
            root._beginTransition(name)
            Quickshell.execDetached(["systemctl", "start", "openvpn-client@" + name + ".service"])
        }
    }

    function disconnect(): void {
        if (!root.activeProfile) return
        if (root.transitioning) return
        root._beginTransition("")
        Quickshell.execDetached(["systemctl", "stop", "openvpn-client@" + root.activeProfile + ".service"])
    }

    function remove(name: string): void {
        if (!name) return
        Quickshell.execDetached(["ryoku-openvpn-remove", name])
    }

    function importNew(): void {
        Quickshell.execDetached(["ryoku-openvpn-import"])
    }

    function rename(oldName: string, newName: string): void {
        if (!oldName || !newName) return
        Quickshell.execDetached(["ryoku-openvpn-rename", oldName, newName])
    }

    // ── transition state machine ──────────────────────────────────
    function _beginTransition(target: string): void {
        root.transitioning = true
        root.transitionTarget = target
        transitionTimeout.restart()
    }
    function _reconcileTransition(): void {
        if (!root.transitioning) return
        if (root.activeProfile === root.transitionTarget) {
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
}
