pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * SYSTEM info for the operator card. A single read-out from the ryoku-sysinfo
 * helper (one field per line) re-polled every 30 s; each line maps to a field
 * below, falling back to its placeholder when absent. The helper is dual-GPU
 * aware (sysGpu / sysGpu2) and supplies the install's stable random `codename`.
 */
Singleton {
    id: root

    readonly property string helper: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-sysinfo"

    property string sysUser: "user"
    property string sysHost: "host"
    property string sysDistro: "Linux"
    property string sysArch: "x86_64"
    property string sysKernel: "-"
    property string sysWM: "Hyprland"
    property string sysShell: "sh"
    property string sysCpu: "-"
    property string sysCpuCores: "-"
    property string sysGpu: "-"
    property string sysGpu2: ""
    property string sysRam: "- / -"
    property int sysRamPct: 0
    property string sysDisk: "- / -"
    property int sysDiskPct: 0
    property string sysUptime: "-"
    property string sysPackages: "-"
    property string sysResolution: "-"
    property string sysRefresh: ""
    property string codename: "OPERATOR"

    Process {
        id: poller
        running: true
        command: ["bash", root.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                if (l.length < 17)
                    return;
                root.sysUser = (l[0] || "user").trim();
                root.sysHost = (l[1] || "host").trim();
                root.sysDistro = (l[2] || "Linux").trim();
                root.sysArch = (l[3] || "x86_64").trim();
                root.sysKernel = (l[4] || "-").trim();
                root.sysShell = (l[5] || "sh").trim();
                root.sysCpu = (l[6] || "-").trim();
                root.sysCpuCores = (l[7] || "-").trim();
                root.sysGpu = (l[8] || "-").trim();
                root.sysGpu2 = (l[9] || "").trim();
                root.sysRam = (l[10] || "- / -").trim();
                root.sysRamPct = parseInt(l[11]) || 0;
                root.sysDisk = (l[12] || "- / -").trim();
                root.sysDiskPct = parseInt(l[13]) || 0;
                root.sysUptime = (l[14] || "-").trim();
                root.sysPackages = (l[15] || "-").trim();
                root.sysResolution = (l[16] || "-").trim();
                root.sysRefresh = (l[17] || "").trim();
                const cn = (l[18] || "").trim();
                if (cn.length > 0)
                    root.codename = cn;
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }
}
