pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
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
    readonly property bool inir: Config.barStyle === "inir"
    readonly property bool aurora: Config.barStyle === "aurora"
    readonly property bool angel: Config.barStyle === "angel"
    // atoll: ilyamiro's multi-island bar, a separate loaded component like the
    // flat set; a frame-off row of floating islands (AtollBar.qml).
    readonly property bool atoll: Config.barStyle === "atoll"
    // the flat iNiR-ported skins: a flush full-width bar painting its own
    // background (TUI / glass / brutalist), no frame band, no lobes.
    readonly property bool flatBar: inir || aurora || angel
    // modular = the reorderable data-driven face (BarModularFace), opt-in: only
    // on a straight-band skin once the user customises a zone list. the bespoke
    // skins (triptych, nacre, the flat set) keep their designed layouts.
    readonly property bool modular: !bar.triptych && !bar.nacre && !bar.flatBar
        && ((Config.barLayoutLeft && Config.barLayoutLeft.length > 0)
            || (Config.barLayoutCentre && Config.barLayoutCentre.length > 0)
            || (Config.barLayoutRight && Config.barLayoutRight.length > 0))
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
        : bar.flatBar
        ? (flatLoader.item ? flatLoader.item.bellCenter : -1)
        : bar.modular
        ? (modularLoader.item ? modularLoader.item.bellCenter : -1)
        : (Config.barShowStatus ? hStatus.bellCenter : -1)

    readonly property int activeWsId: Workspaces.activeId

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
        visible: !bar.nacre && !bar.flatBar && !bar.modular && !bar.atoll
        enabled: !bar.nacre && !bar.flatBar && !bar.modular && !bar.atoll

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

                // seal, workspaces, special and stats are the fixed left group; the
                // now-playing chip and the title share the room left before the
                // centred clock, so the cluster never grows across it.
                Row {
                    id: leftFixed
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * bar.s

                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        width: bar.moduleSpan
                        filled: false
                        onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"])
                        BrandMark { size: 11 * bar.s }
                    }
                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: (Config.barStyle === "noctalia" || bar.triptych) ? 10 * bar.s : (Config.barStyle === "stele" ? 7 * bar.s : 4 * bar.s)
                        interactive: false
                        BarWorkspaces { s: bar.s; activeWsId: bar.activeWsId }
                    }
                    BarModule {
                        id: specialMod
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        visible: Config.barShowSpecialWs && specialWs.active
                        interactive: false
                        BarSpecialWs { id: specialWs; s: bar.s }
                    }
                    // system stats (temps/cpu/ram): on the left with the workspaces,
                    // like the flat and nacre skins, so the right cluster stays slim.
                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        interactive: false
                        BarStats { s: bar.s; onRequestPopout: (name, center) => bar.popoutRequested(name, center) }
                    }
                }

                // now-playing music section: a real chip with art + title, sized so
                // it and the window title share the room left before the clock.
                BarReveal {
                    id: leftMediaReveal
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    dropWhenClosed: true
                    shown: Config.barShowMedia && Media.present
                    BarModule {
                        id: mediaMod
                        s: bar.s
                        height: bar.moduleSpan
                        onTapped: hMedia.toggle()
                        onWheeled: (steps) => bar.nudgeVolume(steps)
                        onHoveredChanged: bar.hoverPopoutRequested("media", mediaMod.mapToItem(null, mediaMod.width / 2, mediaMod.height / 2).x, mediaMod.hovered)
                        BarMedia { id: hMedia; s: bar.s; maxW: 190 * bar.s }
                    }
                }

                BarTitle {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    // the room left before the centred clock, after the fixed group
                    // and (when present) the now-playing chip: elide, never cross it.
                    maxWidth: Math.max(0, (bar.width - centreIsland.width) / 2 - bar.edgeMargin - leftFixed.implicitWidth - (Config.barShowMedia && Media.present ? 210 * bar.s : 0) - 2 * leftRow.spacing - 12 * bar.s)
                    label: Config.barShowTitle && ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
                }
            }
        }

        // ---- centre island: the clock ------------------------------------
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

                Row {
                    id: rightFixed
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * bar.s

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
                        visible: Config.barShowWeather && Weather.available
                        interactive: false

                        BarWeather {
                            s: bar.s
                            onRequestPopout: (name, center) => bar.popoutRequested(name, center)
                        }
                    }

                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        visible: Config.barToggles.length > 0
                        interactive: false

                        BarToggles {
                            s: bar.s
                            kinds: Config.barToggles
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

    // ---- nacre: three frosted capsules riding a flat, straight band. loaded
    // only when the skin is active, so the five other skins pay nothing for it.
    Loader {
        id: nacreLoader
        anchors.fill: parent
        active: bar.nacre
        sourceComponent: nacreComp
    }

    // ---- atoll: floating dark islands (ported from ilyamiro's nixos shell) --
    Loader {
        id: atollLoader
        anchors.fill: parent
        active: bar.atoll
        sourceComponent: atollComp
    }
    Component {
        id: atollComp
        AtollBar {
            s: bar.s
            band: bar.band
            trayWindow: bar.trayWindow
            onPopoutRequested: (name, center) => bar.popoutRequested(name, center)
            onHoverPopoutRequested: (name, center, hovered) => bar.hoverPopoutRequested(name, center, hovered)
        }
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
                color: "transparent"
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
                color: "transparent"
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
                        visible: Config.barShowSpecialWs && nSpecialWs.active
                        interactive: false
                        BarSpecialWs { id: nSpecialWs; s: bar.s }
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
                color: "transparent"
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
                        visible: Config.barShowWeather && Weather.available
                        interactive: false
                        BarWeather { s: bar.s; onRequestPopout: (name, center) => bar.popoutRequested(name, center) }
                    }
                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 8 * bar.s
                        visible: Config.barToggles.length > 0
                        interactive: false
                        BarToggles { s: bar.s; kinds: Config.barToggles }
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

    // ---- flat iNiR skins: a flush full-width bar carrying borderless modules
    // (inir TUI, aurora glass, angel brutalist). loaded only when active, so the
    // other skins pay nothing for it.
    Loader {
        id: flatLoader
        anchors.fill: parent
        active: bar.flatBar
        sourceComponent: flatComp
    }
    Component {
        id: flatComp
        Item {
            id: flatFace

            readonly property real edge: 16 * bar.s
            // the visible bell's centre, so the toast grows from it like the inbox.
            readonly property real bellCenter: Config.barShowStatus ? flatStatus.bellCenter : -1

            // a hairline cell divider; the TUI feel is inir's alone, so the other
            // two flat skins hide it and the Row drops the gap.
            component Sep: Rectangle {
                visible: bar.inir
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, bar.s)
                height: Math.round(bar.moduleSpan * 0.62)
                color: Qt.alpha(Theme.border, 0.7)
            }

            // full-width flush surface. inir: flat opaque TUI panel; aurora:
            // translucent glass the wallpaper shows through; angel: opaque with a
            // heavy base border and a bright inset top edge (the brutalist glow).
            Rectangle {
                id: flatBg
                anchors.fill: parent
                readonly property color surf: Config.matchWallpaper ? Wallust.surface : Config.surfaceColor
                readonly property color deep: Config.matchWallpaper ? Wallust.base : Config.surfaceColor
                // aurora reads as a clean, modern niri-style bar: one flat
                // translucent tone the wallpaper shows faintly through, with a crisp
                // hairline top -- no layered gaussy sheen. inir and angel are flat
                // opaque, so both stops resolve to a single solid tone.
                gradient: Gradient {
                    GradientStop { position: 0; color: bar.aurora ? Qt.alpha(flatBg.surf, 0.85) : (bar.angel ? flatBg.deep : flatBg.surf) }
                    GradientStop { position: 1; color: bar.aurora ? Qt.alpha(flatBg.surf, 0.85) : (bar.angel ? flatBg.deep : flatBg.surf) }
                }

                Rectangle { // aurora crisp top hairline (a clean edge, not a glass glare)
                    visible: bar.aurora
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: Math.max(1, bar.s)
                    color: Qt.alpha(Theme.cream, 0.08)
                }
                Rectangle { // angel inset top glow
                    visible: bar.angel
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: Math.max(1, 2 * bar.s)
                    color: Qt.alpha(Theme.brand, 0.6)
                }
                Rectangle { // base border: inir hairline, aurora subtle, angel heavy
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: bar.angel ? Math.max(2, 3 * bar.s) : Math.max(1, bar.s)
                    color: bar.angel ? Theme.lineStrong : Qt.alpha(Theme.border, bar.aurora ? 0.55 : 1.0)
                }
            }

            // ---- left cluster: seal, workspaces, special, stats (fixed), then
            // media. the fixed cluster's own width caps the media title, so a long
            // track name can never push the cluster across the centred clock.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: flatFace.edge
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * bar.s

                Row {
                    id: flatLeftFixed
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * bar.s

                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        width: bar.moduleSpan
                        filled: false
                        onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"])
                        BrandMark { size: 11 * bar.s }
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
                        visible: Config.barShowSpecialWs && flatSpecialWs.active
                        interactive: false
                        BarSpecialWs { id: flatSpecialWs; s: bar.s }
                    }
                    Sep {}
                    BarModule {
                        anchors.verticalCenter: parent.verticalCenter
                        s: bar.s
                        height: bar.moduleSpan
                        padX: 8 * bar.s
                        interactive: false
                        BarStats { s: bar.s; onRequestPopout: (name, center) => bar.popoutRequested(name, center) }
                    }
                }
                Sep { visible: bar.inir && Config.barShowMedia && Media.present }
                BarReveal {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    dropWhenClosed: true
                    shown: Config.barShowMedia && Media.present
                    BarModule {
                        id: flatMediaMod
                        s: bar.s
                        height: bar.moduleSpan
                        onTapped: flatMedia.toggle()
                        onWheeled: (steps) => bar.nudgeVolume(steps)
                        onHoveredChanged: bar.hoverPopoutRequested("media", flatMediaMod.mapToItem(null, flatMediaMod.width / 2, flatMediaMod.height / 2).x, flatMediaMod.hovered)
                        BarMedia {
                            id: flatMedia
                            s: bar.s
                            // elide to the room left of the centred clock, past the
                            // fixed modules, so the cluster never crosses it.
                            maxW: Math.max(0, (bar.width - flatClockMod.width) / 2 - flatFace.edge - flatLeftFixed.implicitWidth - 22 * bar.s)
                        }
                    }
                }
            }

            // ---- centre: clock ----
            BarModule {
                id: flatClockMod
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                s: bar.s
                height: bar.moduleSpan
                padX: 13 * bar.s
                onTapped: bar.popoutRequested("calendar", flatClockMod.mapToItem(null, flatClockMod.width / 2, flatClockMod.height / 2).x)
                BarClock { s: bar.s }
            }

            // ---- right cluster: status, tray ----
            Row {
                anchors.right: parent.right
                anchors.rightMargin: flatFace.edge
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * bar.s

                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    visible: Config.barShowStatus
                    interactive: false
                    BarStatus { id: flatStatus; s: bar.s; onRequestPopout: (name, center) => bar.popoutRequested(name, center) }
                }
                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    padX: 8 * bar.s
                    visible: Config.barShowWeather && Weather.available
                    interactive: false
                    BarWeather { s: bar.s; onRequestPopout: (name, center) => bar.popoutRequested(name, center) }
                }
                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    padX: 8 * bar.s
                    visible: Config.barToggles.length > 0
                    interactive: false
                    BarToggles { s: bar.s; kinds: Config.barToggles }
                }
                Sep { visible: bar.inir && flatTray.count > 0 }
                BarModule {
                    anchors.verticalCenter: parent.verticalCenter
                    s: bar.s
                    height: bar.moduleSpan
                    visible: flatTray.count > 0
                    padX: 11 * bar.s
                    interactive: false
                    BarTray { id: flatTray; s: bar.s; trayWindow: bar.trayWindow; menuEdgeY: bar.height }
                }
            }
        }
    }

    // ---- modular face: the reorderable data-driven straight-band bar, loaded
    // only when the user customises a zone on a band skin (Config.barLayout*).
    Loader {
        id: modularLoader
        anchors.fill: parent
        active: bar.modular
        sourceComponent: modularComp
    }
    Component {
        id: modularComp
        BarModularFace {
            s: bar.s
            moduleSpan: bar.moduleSpan
            activeWsId: bar.activeWsId
            trayWindow: bar.trayWindow
            edgeMargin: bar.edgeMargin
            onPopoutRequested: (name, center) => bar.popoutRequested(name, center)
            onHoverPopoutRequested: (name, center, hovered) => bar.hoverPopoutRequested(name, center, hovered)
            onNudgeVolume: (steps) => bar.nudgeVolume(steps)
        }
    }
}
