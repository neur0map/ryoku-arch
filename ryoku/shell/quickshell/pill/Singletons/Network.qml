pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// light network presence for the bar's status cluster: connection kind
// (ethernet/wifi/none) and wifi signal, polled gently through nmcli. the Link
// surface owns the heavy lifting (scans, connecting); this only answers "am I
// online and how well" without waking the radio (--rescan no).
Singleton {
    id: root

    // "ethernet" | "wifi" | "" (offline / no nmcli)
    property string kind: ""
    // 0..1 wifi signal, meaningful while kind === "wifi"
    property real level: 0
    property bool wifiRadio: true

    function refresh() {
        stateProc.running = true;
    }

    Process {
        id: stateProc
        running: true
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE d 2>/dev/null | grep ':connected$' | cut -d: -f1; " +
            "echo --; nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^\\*' | cut -d: -f2; " +
            "echo --; nmcli radio wifi 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split("--");
                var types = (parts[0] || "").trim().split("\n").filter(function(t) { return t.length > 0; });
                var eth = types.indexOf("ethernet") >= 0;
                var wifi = types.indexOf("wifi") >= 0;
                root.kind = eth ? "ethernet" : (wifi ? "wifi" : "");
                var sig = parseInt((parts[1] || "").trim(), 10);
                root.level = isNaN(sig) ? 0 : Math.max(0, Math.min(1, sig / 100));
                root.wifiRadio = (parts[2] || "").indexOf("enabled") >= 0;
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
