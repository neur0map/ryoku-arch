pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "Singletons"

// The Profile dossier: the field sheet beside the specimen card, drawn in the same
// carbon vocabulary as the card itself, never as a generic stat dashboard. A
// timestamp masthead, a vitals strip read off hairline-split columns, runtime
// spec lines (label, rule, then value: the card's type-line motif), a package
// wave, the look, and the wallust palette as one spectrum. Extended values
// come from SysInfo; the clock ticks locally. No addresses are shown, so the shot
// is safe to post.
Item {
    id: panel

    property var now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: panel.now = new Date()
    }
    readonly property string clockTime: Qt.formatDateTime(panel.now, "HH:mm")
    readonly property string clockDate: Qt.formatDate(panel.now, "ddd · dd MMM yyyy").toUpperCase()
    readonly property var palette: SysInfo.sysPalette.length > 0 ? SysInfo.sysPalette.split(",") : []

    // ── Reusable bits, all in the card's mono/hairline idiom ─────────────────
    component MicroLabel: Row {
        id: ml
        property string label: ""
        spacing: 8
        Rectangle {
            width: 5
            height: 5
            radius: 1
            color: Theme.brand
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: ml.label
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 2.4
            font.capitalization: Font.AllUppercase
        }
    }

    // A spec line: label, a hairline that eats the gap, then the value, the
    // same shape as the card's SYSTEM type line, reused.
    component SpecRow: Row {
        id: sr
        property string k: ""
        property string v: ""
        width: parent ? parent.width : 0
        height: 31
        spacing: 12

        Text {
            id: srk
            anchors.verticalCenter: parent.verticalCenter
            text: sr.k
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 10
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(8, sr.width - srk.implicitWidth - srv.implicitWidth - 2 * sr.spacing)
            height: 1
            color: Theme.lineSoft
        }
        Text {
            id: srv
            anchors.verticalCenter: parent.verticalCenter
            text: sr.v
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    // A vitals column: big tabular figure over a mono micro-label.
    component Stat: Column {
        id: st
        property string value: "-"
        property string label: ""
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: st.value
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 21
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: st.label
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 8
            font.letterSpacing: 1.4
            font.capitalization: Font.AllUppercase
        }
    }

    component VDiv: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 30
        Layout.alignment: Qt.AlignVCenter
        color: Theme.line
    }

    // ── Content ─────────────────────────────────────────────────────────────
    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 24

        // Masthead: a local-time stamp, label + figure left, date + uptime right.
        Item {
            width: parent.width
            height: 60

            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: 0
                Text {
                    text: "LOCAL TIME"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2.2
                }
                Text {
                    text: panel.clockTime
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 42
                    font.weight: Font.Black
                    font.letterSpacing: -0.5
                    font.features: { "tnum": 1 }
                }
            }
            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                spacing: 5
                Text {
                    anchors.right: parent.right
                    text: panel.clockDate
                    color: Theme.subtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.4
                }
                Text {
                    anchors.right: parent.right
                    text: "UPTIME · " + SysInfo.sysUptime
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.4
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.line }

        // Vitals: figures split by hairlines, no boxes.
        Column {
            width: parent.width
            spacing: 12
            MicroLabel { label: "Vitals" }
            RowLayout {
                width: parent.width
                spacing: 0
                Stat { Layout.fillWidth: true; value: SysInfo.sysLoad; label: "Load" }
                VDiv {}
                Stat { Layout.fillWidth: true; value: SysInfo.sysTemp; label: "CPU" }
                VDiv {}
                Stat { Layout.fillWidth: true; value: SysInfo.sysProcs; label: "Proc" }
                VDiv {}
                Stat { Layout.fillWidth: true; value: SysInfo.sysBattery; label: "Batt" }
                VDiv {}
                Stat { Layout.fillWidth: true; value: SysInfo.sysMonitors; label: "Disp" }
            }
        }

        // Runtime spec lines.
        Column {
            width: parent.width
            spacing: 2
            MicroLabel { label: "Runtime" }
            Item { width: 1; height: 6 }
            SpecRow { k: "Compositor"; v: "Hyprland v" + SysInfo.sysHyprVer }
            SpecRow { k: "Architecture"; v: SysInfo.sysArch }
            SpecRow { k: "Swap"; v: SysInfo.sysSwap }
        }

        // Packages: a Ryoku wave filled to the share you installed yourself.
        Column {
            width: parent.width
            spacing: 12
            MicroLabel { label: "Packages" }
            WaveMeter {
                width: parent.width
                s: 1.5
                frac: {
                    const total = Math.max(1, parseInt(SysInfo.sysPackages) || 1);
                    const mine = (parseInt(SysInfo.sysPkgExplicit) || 0) + (parseInt(SysInfo.sysPkgAur) || 0);
                    return mine / total;
                }
            }
            Text {
                text: SysInfo.sysPkgExplicit + " explicit   ·   " + SysInfo.sysPkgAur + " aur   ·   " + SysInfo.sysPackages + " total"
                color: Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 10
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
            }
        }

        // Look spec lines.
        Column {
            width: parent.width
            spacing: 2
            MicroLabel { label: "Look" }
            Item { width: 1; height: 6 }
            SpecRow { k: "Cursor"; v: SysInfo.sysCursor }
            SpecRow { k: "UI Font"; v: Theme.font }
            SpecRow { k: "Mono"; v: Theme.mono }
        }

        // wallust palette as a single contiguous spectrum.
        Column {
            width: parent.width
            spacing: 12
            MicroLabel { label: "Palette" }
            Rectangle {
                width: parent.width
                height: 22
                radius: 5
                clip: true
                color: Theme.surfaceLo
                border.width: 1
                border.color: Theme.line
                Row {
                    anchors.fill: parent
                    anchors.margins: 1
                    Repeater {
                        model: panel.palette
                        Rectangle {
                            required property string modelData
                            width: (parent.width) / Math.max(1, panel.palette.length)
                            height: parent.height
                            color: modelData
                        }
                    }
                }
            }
        }
    }

    // Footer, aligned with the specimen's edition strip, to close the pair.
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 9
        Rectangle { width: parent.width; height: 1; color: Theme.line }
        Item {
            width: parent.width
            height: 12
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "SYSTEM DOSSIER · 力"
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1.8
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "RYOKU · " + SysInfo.codename
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1.8
            }
        }
    }
}
