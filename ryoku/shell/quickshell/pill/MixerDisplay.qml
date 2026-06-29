pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

// display section of the mixer: screen vibrance (nvibrant) and per external
// monitor brightness (ddcutil), as HFader rows reusing Devices.qml. brightness
// reads once per monitor on load; writes debounce so a drag never floods i2c.
Column {
    id: root

    property real s: 1

    spacing: 6 * s

    property real pendingVibrance: -1

    Timer {
        id: vibDebounce
        interval: 160
        onTriggered: if (root.pendingVibrance >= 0) {
            Devices.setVibrance(root.pendingVibrance);
            root.pendingVibrance = -1;
        }
    }

    HFader {
        width: parent.width
        s: root.s
        icon: "monitor"
        lit: vibHover.hovered
        value: Devices.vibrance / 100
        valueLabel: Devices.vibrance + "%"
        onMoved: (v) => Devices.vibrance = Math.round(v * 100)
        onCommitted: (v) => { root.pendingVibrance = v * 100; vibDebounce.restart(); }

        HoverHandler { id: vibHover }
    }

    Repeater {
        model: Devices.ddcMonitors

        HFader {
            id: brFader
            required property var modelData

            property int pct: 75
            property real pendingPct: -1

            width: parent.width
            s: root.s
            icon: "sun"
            lit: brHover.hovered
            value: pct / 100
            valueLabel: pct + "%"
            onMoved: (v) => pct = Math.max(5, Math.min(100, Math.round(v * 100)))
            onCommitted: (v) => {
                pendingPct = Math.max(5, Math.min(100, Math.round(v * 100)));
                brCommit.restart();
            }

            HoverHandler { id: brHover }

            Timer {
                id: brCommit
                interval: 160
                onTriggered: if (brFader.pendingPct >= 0) {
                    Devices.setBrightness(brFader.modelData.bus, brFader.pendingPct);
                    brFader.pendingPct = -1;
                }
            }

            Process {
                command: ["timeout", "3", "ddcutil", "getvcp", "10", "--bus", brFader.modelData.bus, "--brief"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        var v = Devices.parseBrightness(this.text);
                        if (v >= 0)
                            brFader.pct = v;
                    }
                }
            }
        }
    }
}
