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
    readonly property bool nacre: Config.barStyle === "nacre"
    // triptych wraps each cluster in a transparent hugger and shell.qml grows a
    // matching frame lobe under it, so the bar dips between the three; every
    // other skin keeps the hugger invisible and the plain straight band.
    readonly property real islandPad: 10 * bar.s
    readonly property real edgeMargin: (bar.triptych ? 12 : 24) * bar.s
    // each cluster hugger's rect in overlay coords (the bar sits at the overlay
    // origin), so shell.qml can fuse a blob lobe beneath it.
    readonly property real leftX: bar.nacre ? (nacreLoader.item ? nacreLoader.item.leftX : 0) : leftIsland.x
    readonly property real leftW: bar.nacre ? (nacreLoader.item ? nacreLoader.item.leftW : 0) : leftIsland.width
    readonly property real centreX: bar.nacre ? (nacreLoader.item ? nacreLoader.item.centreX : 0) : centreIsland.x
    readonly property real centreW: bar.nacre ? (nacreLoader.item ? nacreLoader.item.centreW : 0) : centreIsland.width
    readonly property real rightX: bar.nacre ? (nacreLoader.item ? nacreLoader.item.rightX : 0) : rightIsland.x
    readonly property real rightW: bar.nacre ? (nacreLoader.item ? nacreLoader.item.rightW : 0) : rightIsland.width
    // the bell's along-axis centre (from the status cluster), so the toast
    // popout can grow from the bell like the inbox does. -1 when the status
    // cluster is hidden (no bell), so the toast falls back to the bar end.
    readonly property real bellCenter: bar.nacre
        ? (nacreLoader.item ? nacreLoader.item.bellCenter : -1)
        : (Config.barShowStatus ? hStatus.bellCenter : -1)

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
        visible: !bar.nacre
        enabled: !bar.nacre

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

                    BrandMark {
                        size: 11 * bar.s
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

                BarTitle {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    maxWidth: (bar.triptych ? 240 : 340) * bar.s
                    label: Config.barShowTitle && ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
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
                spacing: 0

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

                BarReveal {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    gap: 8 * bar.s
                    shown: bar.triptych && Config.barShowMedia && Media.present

                    BarModule {
                        id: mediaCenter
                        s: bar.s
                        height: bar.moduleSpan
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

                BarReveal {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    dropWhenClosed: true
                    shown: !bar.triptych && Config.barShowMedia && Media.present

                    BarModule {
                        id: mediaMod
                        s: bar.s
                        height: bar.moduleSpan
                        onTapped: hMedia.toggle()
                        onWheeled: (steps) => bar.nudgeVolume(steps)
                        onHoveredChanged: bar.hoverPopoutRequested("media", mediaMod.mapToItem(null, mediaMod.width / 2, mediaMod.height / 2).x, mediaMod.hovered)

                        BarMedia {
                            id: hMedia
                            s: bar.s
                        }
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

    // ---- nacre: three frosted capsules riding a flat, straight band. loaded
    // only when the skin is active, so the five other skins pay nothing for it.
    Loader {
        id: nacreLoader
        anchors.fill: parent
        active: bar.nacre
        sourceComponent: nacreComp
    }
    Component {
        id: nacreComp
        Item {
            id: nacreFace

            readonly property real capPad: 12 * bar.s
            readonly property real edge: 16 * bar.s
            // the bell's centre, published up so the toast grows from it.
            readonly property real bellCenter: Config.barShowStatus ? nStatus.bellCenter : -1
            // a side capsule must not reach the centred centre capsule: cap the
            // width each side may take, so the title elides instead of overlapping.
            readonly property real sideMax: Math.max(0, (nacreFace.width - nCentreCap.width) / 2 - nacreFace.edge - 14 * bar.s)
            // cluster rects, published up so shell.qml grows a blob lobe under
            // each (the triptych mechanic): the frame dips between them and the
            // wallpaper shows in the gaps.
            readonly property real leftX: nLeftCap.x
            readonly property real leftW: nLeftCap.width
            readonly property real centreX: nCentreCap.x
            readonly property real centreW: nCentreCap.width
            readonly property real rightX: nRightCap.x
            readonly property real rightW: nRightCap.width

            // left capsule: seal, now-playing, title.
            Rectangle {
                id: nLeftCap
                readonly property real titleMax: Math.max(0, nacreFace.sideMax - 2 * nacreFace.capPad - nSeal.width - nLeftRow.spacing - (nMediaMod.visible ? nMediaMod.width + nLeftRow.spacing : 0))
                anchors.left: parent.left
                anchors.leftMargin: 0
                anchors.top: parent.top
                height: parent.height
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: 0
                bottomRightRadius: height / 3
                color: Config.surfaceColor
                width: nLeftRow.implicitWidth + 2 * nacreFace.capPad
                Behavior on width { NumberAnimation { duration: Motion.spatial; easing.type: Easing.OutCubic } }

                Row {
                    id: nLeftRow
                    anchors.centerIn: parent
                    spacing: 6 * bar.s

                    BarModule {
                        id: nSeal
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        width: bar.moduleSpan
                        filled: false
                        onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"])
                        BrandMark { size: 11 * bar.s }
                    }
                    BarModule {
                        id: nMediaMod
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 8 * bar.s
                        visible: Config.barShowMedia && Media.present
                        onTapped: nMedia.toggle()
                        onWheeled: (steps) => bar.nudgeVolume(steps)
                        onHoveredChanged: bar.hoverPopoutRequested("media", nMediaMod.mapToItem(null, nMediaMod.width / 2, nMediaMod.height / 2).x, nMediaMod.hovered)
                        BarMedia { id: nMedia; s: bar.s; vertical: true }
                    }
                    BarTitle {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        maxWidth: nLeftCap.titleMax
                        label: Config.barShowTitle && ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
                    }
                }
            }

            // centre capsule: clock, workspaces, system stats.
            Rectangle {
                id: nCentreCap
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                height: parent.height
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: height / 3
                bottomRightRadius: height / 3
                color: Config.surfaceColor
                width: nCentreRow.implicitWidth + 2 * nacreFace.capPad
                Behavior on width { NumberAnimation { duration: Motion.spatial; easing.type: Easing.OutCubic } }

                Row {
                    id: nCentreRow
                    anchors.centerIn: parent
                    spacing: 10 * bar.s

                    BarModule {
                        id: nClockMod
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 8 * bar.s
                        onTapped: bar.popoutRequested("calendar", nClockMod.mapToItem(null, nClockMod.width / 2, nClockMod.height / 2).x)
                        BarClock { s: bar.s }
                    }
                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 6 * bar.s
                        interactive: false
                        BarWorkspaces { s: bar.s; activeWsId: bar.activeWsId }
                    }
                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 6 * bar.s
                        interactive: false
                        BarStats { s: bar.s; onRequestPopout: (name, center) => bar.popoutRequested(name, center) }
                    }
                }
            }

            // right capsule: status glyphs, tray.
            Rectangle {
                id: nRightCap
                anchors.right: parent.right
                anchors.rightMargin: 0
                anchors.top: parent.top
                height: parent.height
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: height / 3
                bottomRightRadius: 0
                color: Config.surfaceColor
                width: nRightRow.implicitWidth + 2 * nacreFace.capPad
                Behavior on width { NumberAnimation { duration: Motion.spatial; easing.type: Easing.OutCubic } }

                Row {
                    id: nRightRow
                    anchors.centerIn: parent
                    spacing: 6 * bar.s

                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 8 * bar.s
                        visible: Config.barShowStatus
                        interactive: false
                        BarStatus { id: nStatus; s: bar.s; onRequestPopout: (name, center) => bar.popoutRequested(name, center) }
                    }
                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 8 * bar.s
                        visible: nTray.count > 0
                        interactive: false
                        BarTray { id: nTray; s: bar.s; trayWindow: bar.trayWindow; menuEdgeY: bar.height }
                    }
                }
            }
        }
    }
}
