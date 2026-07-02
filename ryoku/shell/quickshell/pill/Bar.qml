pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import "Singletons"

// bar content riding the frame's thickened top edge. when the bar is on, the
// frame's top border swells into a band (BlobInvertedRect.borderTop in
// shell.qml) and this draws the options directly on it, in the frame's own
// scene. no separate program, no seam: the frame just has options on top, the
// same way the island is the frame swelling at the centre.
//
// layout: left = 力 mark + workspaces + focused-window title, centre = clock,
// right = now-playing + system tray + power. content sits below `contentTop`
// (the frame's own top edge) so it reads as riding the thickened frame, not
// floating in the border.
Item {
    id: bar

    required property real s
    // frame's own top-edge thickness, content sits below it.
    required property real contentTop
    // window the tray menus anchor to.
    required property var trayWindow
    // a summoned surface drops out of the bar over the centre; the clock
    // fades under it so the two never overprint.
    property bool surfaceOpen: false

    signal calendarRequested()
    signal powerRequested()

    readonly property var loc: Qt.locale("en_US")

    // quickshell's refreshWorkspaces/refreshMonitors parse nothing out of
    // this Hyprland's IPC, so Hyprland.focusedWorkspace stays null on a
    // fresh instance until the first workspace event. seed the highlight
    // once from hyprctl; events own it from the first real switch.
    property int seedWsId: -1
    readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : seedWsId

    Process {
        running: true
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { bar.seedWsId = JSON.parse(text).id; } catch (e) {}
            }
        }
    }

    SystemClock {
        id: clock
        // the bar shows HH:mm; minute precision avoids a needless per-second tick.
        precision: SystemClock.Minutes
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: bar.contentTop

        // left: 力 mark + workspaces.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 34 * bar.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * bar.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "力"
                color: Theme.brand
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * bar.s
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * bar.s

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
                        readonly property bool active: bar.activeWsId === wsDot.wsId
                        visible: occupied || active || wsId <= 5
                        width: active ? 20 * bar.s : 8 * bar.s
                        height: 8 * bar.s
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: wsDot.active ? Theme.vermLit
                                : (wsDot.occupied ? Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.42)
                                : Qt.rgba(192 / 255, 202 / 255, 245 / 255, 0.16))
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3 * bar.s
                            cursorShape: Qt.PointingHandCursor
                            // this Hyprland's dispatchers are Lua; the plain
                            // "workspace N" form is a syntax error. mirror the
                            // Super+N keybind: pull the workspace to the
                            // monitor under the cursor, then focus it.
                            onClicked: {
                                Hyprland.dispatch('hl.dsp.workspace.move({ workspace = ' + wsDot.wsId + ', monitor = "current" })');
                                Hyprland.dispatch('hl.dsp.focus({ workspace = ' + wsDot.wsId + ' })');
                            }
                        }
                    }
                }
            }

            // focused-window title, live via foreign-toplevel (Hyprland's
            // model deliberately skips title events to avoid refresh spam).
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.barShowTitle && text.length > 0
                width: Math.min(implicitWidth, 380 * bar.s)
                elide: Text.ElideRight
                text: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * bar.s
                font.weight: Font.Medium
            }
        }

        // centre: clock (tap opens the pill calendar). fades away while a
        // surface panel is dropped over the centre.
        Item {
            anchors.centerIn: parent
            height: parent.height
            implicitWidth: clockInner.implicitWidth
            opacity: bar.surfaceOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            Row {
                id: clockInner
                anchors.centerIn: parent
                spacing: 8 * bar.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * bar.s
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.loc.toString(clock.date, "ddd d MMM").toUpperCase()
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10 * bar.s
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6 * bar.s
                }
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8 * bar.s
                enabled: !bar.surfaceOpen
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.calendarRequested()
            }
        }

        // right: now-playing + tray + power.
        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: 34 * bar.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * bar.s

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
                visible: Config.barShowMedia && rightRow.player !== null && rightRow.player.trackTitle
                readonly property real titleW: Math.min(titleText.implicitWidth, 200 * bar.s)
                implicitWidth: visible ? (playGlyph.implicitWidth + 7 * bar.s + titleW) : 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7 * bar.s

                    Text {
                        id: playGlyph
                        anchors.verticalCenter: parent.verticalCenter
                        text: rightRow.player && rightRow.player.isPlaying ? "▶" : "Ⅱ"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11 * bar.s
                    }
                    Text {
                        id: titleText
                        anchors.verticalCenter: parent.verticalCenter
                        width: mprisItem.titleW
                        elide: Text.ElideRight
                        text: rightRow.player ? (rightRow.player.trackTitle || "") : ""
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11 * bar.s
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
                height: 16 * bar.s
                color: Theme.hair
                visible: mprisItem.visible
            }

            // system tray.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * bar.s

                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        id: trayItem
                        required property var modelData
                        width: 18 * bar.s
                        height: 18 * bar.s
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
                                    trayItem.modelData.display(bar.trayWindow, trayItem.x, bar.height);
                                else
                                    trayItem.modelData.activate();
                            }
                        }
                    }
                }
            }

            // power (opens the pill's power popout).
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "⏻"
                color: powerArea.containsMouse ? Theme.verm : Theme.dim
                font.family: Theme.font
                font.pixelSize: 15 * bar.s
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    anchors.margins: -6 * bar.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.powerRequested()
                }
            }
        }
    }
}
