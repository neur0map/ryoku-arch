pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "Singletons"

// bar content riding the frame's thickened top edge. when the bar is on, the
// frame's top border swells into a band (BlobInvertedRect.borderTop in
// shell.qml) and this draws the options directly on it, in the frame's own
// scene: no separate program, no seam.
//
// the band is composed of module plates (BarPlate): sharp slabs with a faint
// warm fill that lifts on hover, so every module reads as touchable. left =
// the 力 seal (launcher) + workspace strip + focused title; centre = the clock
// plate (the anchor the calendar drops from); right = now-playing, the status
// cluster, tray, power. a wheel over bare band nudges the sink volume and the
// OSD panel narrates it.
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
    signal surfaceRequested(string name)

    readonly property var loc: Qt.locale("en_US")
    readonly property real bandH: height - contentTop
    readonly property real plateH: Math.round(bandH * 0.74)

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

    // wheel anywhere on the bare band = sink volume. plates sit above this
    // handler and take their own wheel where they care (workspaces, media).
    readonly property var sink: Pipewire.defaultAudioSink
    function nudgeVolume(steps) {
        if (!sink || !sink.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + steps * 0.03));
    }
    WheelHandler {
        onWheel: (w) => bar.nudgeVolume(w.angleDelta.y > 0 ? 1 : -1)
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: bar.contentTop

        // left: seal + workspaces + focused title.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 26 * bar.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * bar.s

            BarPlate {
                anchors.verticalCenter: parent.verticalCenter
                s: bar.s
                height: bar.plateH
                padX: 9 * bar.s
                onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"])

                Text {
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 13 * bar.s
                }
            }

            BarPlate {
                anchors.verticalCenter: parent.verticalCenter
                s: bar.s
                height: bar.plateH
                padX: 7 * bar.s
                interactive: false

                BarWorkspaces {
                    s: bar.s
                    activeWsId: bar.activeWsId
                }
            }

            // focused-window title, live via foreign-toplevel (Hyprland's
            // model deliberately skips title events to avoid refresh spam).
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.barShowTitle && text.length > 0
                width: Math.min(implicitWidth, 340 * bar.s)
                elide: Text.ElideRight
                leftPadding: 6 * bar.s
                text: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 10.5 * bar.s
                font.weight: Font.Medium
            }
        }

        // centre: the clock plate, the fixed anchor a summoned surface drops
        // from. fades while a panel is open so the two never overprint.
        BarPlate {
            id: clockPlate
            anchors.centerIn: parent
            s: bar.s
            height: bar.plateH
            padX: 12 * bar.s
            opacity: bar.surfaceOpen ? 0 : 1
            interactive: !bar.surfaceOpen
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            onTapped: bar.calendarRequested()

            Row {
                spacing: 7 * bar.s

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        text: Qt.formatTime(clock.date, "HH")
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * bar.s
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        text: ":"
                        color: Theme.brand
                        font.family: Theme.font
                        font.pixelSize: 12.5 * bar.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: Qt.formatTime(clock.date, "mm")
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * bar.s
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.loc.toString(clock.date, "ddd d MMM").toUpperCase()
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * bar.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1 * bar.s
                }
            }
        }

        // right: now-playing, status cluster, tray, power.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 26 * bar.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * bar.s

            BarPlate {
                id: mediaPlate
                anchors.verticalCenter: parent.verticalCenter
                s: bar.s
                height: bar.plateH
                visible: Config.barShowMedia && mediaRow.present
                onTapped: mediaRow.toggle()
                onWheeled: (steps) => bar.nudgeVolume(steps)

                BarMedia {
                    id: mediaRow
                    s: bar.s
                }
            }

            BarPlate {
                anchors.verticalCenter: parent.verticalCenter
                s: bar.s
                height: bar.plateH
                visible: Config.barShowStatus
                interactive: false

                BarStatus {
                    s: bar.s
                    onRequestSurface: (name) => bar.surfaceRequested(name)
                }
            }

            // system tray: quiet plate, surfaces on hover.
            BarPlate {
                anchors.verticalCenter: parent.verticalCenter
                s: bar.s
                height: bar.plateH
                visible: trayRow.count > 0
                quiet: true
                interactive: false

                Row {
                    id: trayRow
                    spacing: 9 * bar.s
                    readonly property int count: SystemTray.items ? SystemTray.items.values.length : 0

                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            id: trayItem
                            required property var modelData
                            width: 16 * bar.s
                            height: 16 * bar.s
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: trayArea.containsMouse ? 1 : 0.78
                            Behavior on opacity { NumberAnimation { duration: Motion.hover } }

                            IconImage {
                                anchors.fill: parent
                                source: trayItem.modelData ? trayItem.modelData.icon : ""
                            }
                            MouseArea {
                                id: trayArea
                                anchors.fill: parent
                                anchors.margins: -3 * bar.s
                                hoverEnabled: true
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
            }

            BarPlate {
                anchors.verticalCenter: parent.verticalCenter
                s: bar.s
                height: bar.plateH
                padX: 9 * bar.s
                quiet: true
                onTapped: bar.powerRequested()
                GlyphIcon {
                    width: 14 * bar.s
                    height: 14 * bar.s
                    name: "shutdown"
                    color: Theme.dim
                    stroke: 1.7
                }
            }
        }
    }
}
