pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell.Io

/**
 * The Ryoku topbar: an opt-in traditional bar, an alternative to the morphing
 * pill island. It is its own `qs -c topbar` instance and shares the warm shell
 * surface (Theme.cardTop) so it reads as the frame's top edge thickened into a
 * bar rather than a panel stacked on top. It reserves its height so tiles tuck
 * under it, sits inside the frame's side gaps, and reuses the existing pill
 * surfaces for its actions: the clock opens the calendar, the power glyph opens
 * the power popout. Enable it from Ryoku Settings (Shell -> Bar), which also
 * hides the resting pill island so the two never overlap.
 *
 * Layout: left = 力 mark + workspaces; centre = clock; right = now-playing +
 * system tray + power.
 */
ShellRoot {
    id: root

    // Local chrome tokens (own config), mirroring the shell's warm surface.
    readonly property color cardTop: "#1a1b26"
    readonly property color cardBot: "#16161e"
    readonly property color border:  "#2f3549"
    readonly property color hair:    Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.13)
    readonly property color sheen:   Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.07)
    readonly property color brand:   "#F25623"
    readonly property color cream:   "#c0caf5"
    readonly property color dim:     "#7aa2f7"
    readonly property color faint:   "#565f89"
    readonly property color verm:    "#e0563b"
    readonly property color vermLit: "#ff7a45"
    readonly property string uiFont: "Inter"
    readonly property string jpFont: "Noto Sans CJK JP"

    readonly property string shellDir: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/"
    function shellCmd(name) {
        actionProc.command = ["ryoku-shell", name];
        actionProc.running = true;
    }
    Process { id: actionProc }

    // Opt-in gate: the bar shows only when Ryoku Settings (Shell -> Bar) turns it
    // on. The same shell.json the pill reads carries the flag, watched live, so
    // toggling it shows or hides the bar with no restart. Default off: the daemon
    // keeps this instance alive but the window stays hidden until it is enabled.
    readonly property bool barEnabled: barCfg.barEnabled
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: barCfg
            property bool barEnabled: false
        }
    }

    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            Hyprland.refreshWorkspaces();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    readonly property var locale: Qt.locale("en_US")

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property real s: modelData ? Math.max(0.85, modelData.height / 1080) : 1
            readonly property real barH: 34 * s
            readonly property real sideGap: 26 * s
            readonly property real topGap: 6 * s

            visible: root.barEnabled
            screen: modelData
            color: "transparent"
            exclusiveZone: win.barH
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "ryoku-topbar"
            anchors { top: true; left: true; right: true }
            margins { top: 0 }
            implicitHeight: win.barH

            // The bar surface: a flat warm fill, the same colour as the frame, with
            // rounded top corners matching the screen's. Flush to the very top and
            // full width, so it reads as the frame's top edge thickened into a bar
            // rather than a panel laid over it.
            Rectangle {
                id: surface
                anchors.fill: parent
                color: root.cardTop
                radius: 16 * win.s
                clip: true

                // ── Left: brand + workspaces ──────────────────────────────────
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: win.sideGap + 8 * win.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12 * win.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "力"
                        color: root.brand
                        font.family: root.jpFont
                        font.weight: Font.Medium
                        font.pixelSize: 16 * win.s
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7 * win.s

                        Repeater {
                            model: 10
                            delegate: Item {
                                id: wsDot
                                required property int index
                                readonly property int wsId: index + 1
                                readonly property var ws: {
                                    var v = Hyprland.workspaces.values;
                                    for (var i = 0; i < v.length; i++)
                                        if (v[i] && v[i].id === wsId)
                                            return v[i];
                                    return null;
                                }
                                readonly property bool occupied: wsDot.ws !== null
                                readonly property bool active: Hyprland.focusedWorkspace
                                    && Hyprland.focusedWorkspace.id === wsDot.wsId
                                visible: occupied || active || wsId <= 5
                                width: active ? 20 * win.s : 8 * win.s
                                height: 8 * win.s
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: wsDot.active ? root.vermLit
                                        : (wsDot.occupied ? Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.42)
                                        : Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.16))
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3 * win.s
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + wsDot.wsId)
                                }
                            }
                        }
                    }
                }

                // ── Centre: clock (opens the pill calendar) ───────────────────
                Item {
                    id: clockRow
                    anchors.centerIn: parent
                    height: parent.height
                    implicitWidth: clockInner.implicitWidth

                    Row {
                        id: clockInner
                        anchors.centerIn: parent
                        spacing: 8 * win.s

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: root.cream
                            font.family: root.uiFont
                            font.pixelSize: 13 * win.s
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.locale.toString(clock.date, "ddd d MMM").toUpperCase()
                            color: root.dim
                            font.family: root.uiFont
                            font.pixelSize: 10 * win.s
                            font.weight: Font.Medium
                            font.letterSpacing: 0.6 * win.s
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8 * win.s
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shellCmd("calendar")
                    }
                }

                // ── Right: now-playing + tray + power ─────────────────────────
                Row {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.rightMargin: win.sideGap + 8 * win.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10 * win.s

                    readonly property var player: {
                        var l = Mpris.players.values;
                        for (var i = 0; i < l.length; i++)
                            if (l[i] && l[i].isPlaying)
                                return l[i];
                        return (l && l.length > 0) ? l[0] : null;
                    }

                    Item {
                        id: mprisItem
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        visible: rightRow.player !== null && rightRow.player.trackTitle
                        readonly property real titleW: Math.min(titleText.implicitWidth, 200 * win.s)
                        implicitWidth: visible ? (playGlyph.implicitWidth + 7 * win.s + titleW) : 0

                        Row {
                            id: mprisInner
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7 * win.s

                            Text {
                                id: playGlyph
                                anchors.verticalCenter: parent.verticalCenter
                                text: rightRow.player && rightRow.player.isPlaying ? "▶" : "Ⅱ"
                                color: root.dim
                                font.family: root.uiFont
                                font.pixelSize: 11 * win.s
                            }
                            Text {
                                id: titleText
                                anchors.verticalCenter: parent.verticalCenter
                                width: mprisItem.titleW
                                elide: Text.ElideRight
                                text: rightRow.player ? (rightRow.player.trackTitle || "") : ""
                                color: root.cream
                                font.family: root.uiFont
                                font.pixelSize: 11 * win.s
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (rightRow.player && rightRow.player.canTogglePlaying) rightRow.player.togglePlaying()
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 16 * win.s
                        color: root.hair
                        visible: rightRow.player !== null && rightRow.player.trackTitle
                    }

                    // System tray.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * win.s

                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                id: trayItem
                                required property var modelData
                                width: 18 * win.s
                                height: 18 * win.s
                                anchors.verticalCenter: parent.verticalCenter

                                IconImage {
                                    anchors.fill: parent
                                    source: trayItem.modelData ? trayItem.modelData.icon : ""
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (e) => {
                                        if (!trayItem.modelData)
                                            return;
                                        if (e.button === Qt.RightButton && trayItem.modelData.hasMenu)
                                            trayItem.modelData.display(win, trayItem.x, win.barH);
                                        else
                                            trayItem.modelData.activate();
                                    }
                                }
                            }
                        }
                    }

                    // Power.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⏻"
                        color: powerArea.containsMouse ? root.verm : root.dim
                        font.family: root.uiFont
                        font.pixelSize: 15 * win.s
                        Behavior on color { ColorAnimation { duration: 120 } }
                        MouseArea {
                            id: powerArea
                            anchors.fill: parent
                            anchors.margins: -6 * win.s
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shellCmd("power")
                        }
                    }
                }
            }
        }
    }
}
