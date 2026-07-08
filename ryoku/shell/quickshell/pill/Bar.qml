pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "Singletons"

// bar content riding one of the frame's thickened edges, drawn in the frame's
// own scene: no separate program, no seam. the composition and the module
// look follow Config.barStyle: noctalia (dot pills) and caelestia (rounded
// cell strip) are the carried reference dialects; aegis (flat modules with
// hairline accent underlines) and stele (engraved bracket cells) are ours.
//   the row is launcher glyph + workspaces + title left, the clock centred,
//   now-playing + status + tray + power right. triptych groups the three into
//   rounded islands on the band, with now-playing joining the centred clock.
// a wheel over bare band nudges the sink volume, narrated by the OSD.
Item {
    id: bar

    required property real s
    property string position: "top"
    // the band the frame edge swelled by; module pills size against it.
    property real band: 0
    required property var trayWindow

    signal popoutRequested(string name, real center)
    signal hoverPopoutRequested(string name, real center, bool hovered)

    readonly property real moduleSpan: Math.round(bar.band * 0.76)
    readonly property bool triptych: Config.barStyle === "triptych"
    // triptych wraps each cluster in a transparent hugger and shell.qml grows a
    // matching frame lobe under it, so the bar dips between the three; every
    // other skin keeps the hugger invisible and the plain straight band.
    readonly property real islandPad: 10 * bar.s
    readonly property real edgeMargin: (bar.triptych ? 12 : 24) * bar.s
    // each cluster hugger's rect in overlay coords (the bar sits at the overlay
    // origin), so shell.qml can fuse a blob lobe beneath it.
    readonly property real leftX: leftIsland.x
    readonly property real leftW: leftIsland.width
    readonly property real centreX: centreIsland.x
    readonly property real centreW: centreIsland.width
    readonly property real rightX: rightIsland.x
    readonly property real rightW: rightIsland.width
    // the bell's along-axis centre (from the status cluster), so the toast
    // popout can grow from the bell like the inbox does. -1 when the status
    // cluster is hidden (no bell), so the toast falls back to the bar end.
    readonly property real bellCenter: Config.barShowStatus ? hStatus.bellCenter : -1

    property int seedWsId: -1
    readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : seedWsId

    // quickshell's refreshWorkspaces parses nothing out of this Hyprland's
    // IPC, so the focused workspace stays null on a fresh instance until the
    // first event. seed once from hyprctl; events own it from the first switch.
    Process {
        running: true
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { bar.seedWsId = JSON.parse(text).id; } catch (e) {}
            }
        }
    }

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
        id: face
        anchors.fill: parent

        // ---- left island: seal + workspaces + title --------------------
        Rectangle {
            id: leftIsland
            anchors.left: parent.left
            anchors.leftMargin: bar.edgeMargin
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: leftRow.implicitWidth + (bar.triptych ? 2 * bar.islandPad : 0)
            color: "transparent"

            Row {
                id: leftRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: bar.triptych ? bar.islandPad : 0
                spacing: 8 * bar.s

                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    width: bar.moduleSpan
                    filled: false
                    onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"])

                    Text {
                        text: "力"
                        color: Theme.brand
                        font.family: Theme.fontJp
                        font.weight: Font.Medium
                        font.pixelSize: 11 * bar.s
                    }
                }

                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    padX: (Config.barStyle === "noctalia" || bar.triptych) ? 10 * bar.s : (Config.barStyle === "stele" ? 7 * bar.s : 4 * bar.s)
                    interactive: false

                    BarWorkspaces {
                        s: bar.s
                        activeWsId: bar.activeWsId
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Config.barShowTitle && text.length > 0
                    width: Math.min(implicitWidth, (bar.triptych ? 240 : 340) * bar.s)
                    elide: Text.ElideRight
                    leftPadding: 6 * bar.s
                    text: ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 10.5 * bar.s
                    font.weight: Font.Medium
                }
            }
        }

        // ---- centre island: clock, and now-playing on triptych ----------
        Rectangle {
            id: centreIsland
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: centerRow.implicitWidth + (bar.triptych ? 2 * bar.islandPad : 0)
            color: "transparent"

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 8 * bar.s

                BarModule {
                    id: clockMod
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    padX: 13 * bar.s
                    onTapped: bar.popoutRequested("calendar", clockMod.mapToItem(null, clockMod.width / 2, clockMod.height / 2).x)

                    BarClock {
                        s: bar.s
                    }
                }

                BarModule {
                    id: mediaCenter
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    visible: bar.triptych && Config.barShowMedia && Media.present
                    onTapped: hMediaCenter.toggle()
                    onWheeled: (steps) => bar.nudgeVolume(steps)
                    onHoveredChanged: bar.hoverPopoutRequested("media", mediaCenter.mapToItem(null, mediaCenter.width / 2, mediaCenter.height / 2).x, mediaCenter.hovered)

                    BarMedia {
                        id: hMediaCenter
                        s: bar.s
                    }
                }
            }
        }

        // ---- right island: now-playing (other skins) + status + tray + power
        Rectangle {
            id: rightIsland
            anchors.right: parent.right
            anchors.rightMargin: bar.edgeMargin
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: rightRow.implicitWidth + (bar.triptych ? 2 * bar.islandPad : 0)
            color: "transparent"

            Row {
                id: rightRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: bar.triptych ? bar.islandPad : 0
                spacing: 8 * bar.s

                BarModule {
                    id: mediaMod
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    visible: !bar.triptych && Config.barShowMedia && Media.present
                    onTapped: hMedia.toggle()
                    onWheeled: (steps) => bar.nudgeVolume(steps)
                    onHoveredChanged: bar.hoverPopoutRequested("media", mediaMod.mapToItem(null, mediaMod.width / 2, mediaMod.height / 2).x, mediaMod.hovered)

                    BarMedia {
                        id: hMedia
                        s: bar.s
                    }
                }

                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    visible: Config.barShowStatus
                    interactive: false

                    BarStatus {
                        id: hStatus
                        s: bar.s
                        onRequestPopout: (name, center) => bar.popoutRequested(name, center)
                    }
                }

                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    visible: hTray.count > 0
                    padX: 11 * bar.s
                    interactive: false

                    BarTray {
                        id: hTray
                        s: bar.s
                        trayWindow: bar.trayWindow
                        menuEdgeY: bar.height
                    }
                }

                BarModule {
                    id: hPowerMod
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    padX: 10 * bar.s
                    onTapped: bar.popoutRequested("power", hPowerMod.mapToItem(null, hPowerMod.width / 2, hPowerMod.height / 2).x)

                    MaterialIcon {
                        text: "power_settings_new"
                        color: Theme.verm
                        font.pixelSize: 14 * bar.s
                    }
                }
            }
        }
    }
}
