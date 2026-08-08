import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: memPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-memory"

    readonly property int barBottom: 35
    readonly property int gap: 8

    readonly property int memTotal: root.systemMemTotalMiB
    readonly property int memAvail: root.systemMemAvailMiB
    readonly property int memFree: root.systemMemFreeMiB
    readonly property int memBuffers: root.systemMemBuffersMiB
    readonly property int memCached: root.systemMemCachedMiB
    readonly property int memUsed: root.systemMemUsedMiB
    readonly property int pct: root.systemMemPercent
    readonly property real usedGiB: memUsed / 1024
    readonly property real totalGiB: memTotal / 1024

    property real reveal: root.memVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.memVisible ? 160 : 120
            easing.type: root.memVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.memVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.memVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.memoryBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: memPanel.reveal
        focus: root.memVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.memVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Memory"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.memVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── usage bar ──
            Item {
                width: parent.width
                height: 30
                UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: memPanel.pct + "%"
                    color: root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 8; radius: 4
                    color: root.fillActive
                    Rectangle {
                        width: parent.width * memPanel.pct / 100
                        height: parent.height; radius: 4
                        color: root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            // ── stats ──
            Column {
                width: parent.width
                spacing: 4
                Row {
                    width: parent.width
                    UiText { text: "Used"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: memPanel.usedGiB.toFixed(1) + " GiB"; color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                    UiText { text: memPanel.memUsed + " MiB"; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6); font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                }
                Row {
                    width: parent.width
                    UiText { text: "Available"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: (memPanel.memAvail / 1024).toFixed(1) + " GiB"; color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                    UiText { text: memPanel.memAvail + " MiB"; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6); font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                }
                Row {
                    width: parent.width
                    UiText { text: "Total"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.4 }
                    UiText { text: memPanel.totalGiB.toFixed(1) + " GiB"; color: root.ink; font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                    UiText { text: memPanel.memTotal + " MiB"; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6); font.family: root.mono; font.pixelSize: 11; width: parent.width * 0.3 }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── button ──
            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                color: btopMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: root.paper
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.memVisible = false;
                        btopRunner.running = false;
                        btopRunner.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: btopRunner
        command: ["bash", "-c", "kitty 'btop'"]
    }
}
