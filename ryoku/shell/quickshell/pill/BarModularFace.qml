pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Singletons"

// the modular face: a straight-band bar whose left / centre / right zones are
// data-driven from Config.barLayout{Left,Centre,Right} (each an ordered list of
// module ids), so a user reorders, adds, removes and moves modules between the
// clusters -- iNiR's reorderable modular bar, ported. it is opt-in: the Bar
// loads it only when a zone list is customised and the skin is a straight-band
// one (noctalia, caelestia, aegis, stele), so the bespoke skins (triptych,
// nacre, the flat iNiR set, delos) keep their designed layouts and the default
// bar is untouched. each module self-emits its popout at its own centre; the
// modules skin themselves through BarModule, so a zone reads correctly on any of
// the four band skins.
Item {
    id: face

    required property real s
    required property real moduleSpan
    required property int activeWsId
    required property var trayWindow
    property real edgeMargin: 24 * s

    signal popoutRequested(string name, real center)
    signal hoverPopoutRequested(string name, real center, bool hovered)
    signal nudgeVolume(int steps)

    // a status module, wherever it sits, publishes its bell centre here so the
    // toast popout can still grow from the bell.
    property var bellSrc: null
    readonly property real bellCenter: face.bellSrc ? face.bellSrc.bellCenter : -1

    // resolve each zone to the user's list or the classic default.
    readonly property var resolvedLeft: (Config.barLayoutLeft && Config.barLayoutLeft.length > 0)
        ? Config.barLayoutLeft : ["seal", "workspaces", "special", "title"]
    readonly property var resolvedCentre: (Config.barLayoutCentre && Config.barLayoutCentre.length > 0)
        ? Config.barLayoutCentre : ["clock"]
    readonly property var resolvedRight: (Config.barLayoutRight && Config.barLayoutRight.length > 0)
        ? Config.barLayoutRight : ["media", "status", "weather", "toggles", "tray", "power"]

    function centreOf(item) {
        const p = item.mapToItem(null, item.width / 2, item.height / 2);
        return p.x;
    }

    // ---- module factory: one Component per id, each self-contained ----------
    component Slot: Loader {
        required property string modelData
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        sourceComponent: face.compFor(modelData)
    }
    function compFor(id) {
        switch (id) {
        case "seal": return sealC;
        case "workspaces": return wsC;
        case "special": return specialC;
        case "title": return titleC;
        case "clock": return clockC;
        case "media": return mediaC;
        case "stats": return statsC;
        case "weather": return weatherC;
        case "toggles": return togglesC;
        case "status": return statusC;
        case "tray": return trayC;
        case "power": return powerC;
        default: return null;
        }
    }

    Component {
        id: sealC
        BarModule {
            s: face.s; height: face.moduleSpan; width: face.moduleSpan; filled: false
            onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"])
            BrandMark { size: 11 * face.s }
        }
    }
    Component {
        id: wsC
        BarModule {
            s: face.s; height: face.moduleSpan; interactive: false
            padX: (Config.barStyle === "noctalia") ? 10 * face.s : (Config.barStyle === "stele" ? 7 * face.s : 4 * face.s)
            BarWorkspaces { s: face.s; activeWsId: face.activeWsId }
        }
    }
    Component {
        id: specialC
        BarModule {
            s: face.s; height: face.moduleSpan; interactive: false
            visible: Config.barShowSpecialWs && sws.active
            BarSpecialWs { id: sws; s: face.s }
        }
    }
    Component {
        id: titleC
        BarTitle {
            s: face.s; maxWidth: 340 * face.s
            label: Config.barShowTitle && ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : ""
        }
    }
    Component {
        id: clockC
        BarModule {
            id: cm
            s: face.s; height: face.moduleSpan; padX: 13 * face.s
            onTapped: face.popoutRequested("calendar", face.centreOf(cm))
            BarClock { s: face.s }
        }
    }
    Component {
        id: mediaC
        BarReveal {
            s: face.s; dropWhenClosed: true
            shown: Config.barShowMedia && Media.present
            BarModule {
                id: mm
                s: face.s; height: face.moduleSpan
                onTapped: hm.toggle()
                onWheeled: (steps) => face.nudgeVolume(steps)
                onHoveredChanged: face.hoverPopoutRequested("media", face.centreOf(mm), mm.hovered)
                BarMedia { id: hm; s: face.s }
            }
        }
    }
    Component {
        id: statsC
        BarModule {
            s: face.s; height: face.moduleSpan; padX: 6 * face.s; interactive: false
            BarStats { s: face.s; onRequestPopout: (name, center) => face.popoutRequested(name, center) }
        }
    }
    Component {
        id: weatherC
        BarModule {
            s: face.s; height: face.moduleSpan; interactive: false
            visible: Config.barShowWeather && Weather.available
            BarWeather { s: face.s; onRequestPopout: (name, center) => face.popoutRequested(name, center) }
        }
    }
    Component {
        id: togglesC
        BarModule {
            s: face.s; height: face.moduleSpan; interactive: false
            visible: Config.barToggles.length > 0
            BarToggles { s: face.s; kinds: Config.barToggles }
        }
    }
    Component {
        id: statusC
        BarModule {
            s: face.s; height: face.moduleSpan; interactive: false
            visible: Config.barShowStatus
            BarStatus {
                id: st
                s: face.s
                onRequestPopout: (name, center) => face.popoutRequested(name, center)
                Component.onCompleted: face.bellSrc = st
            }
        }
    }
    Component {
        id: trayC
        BarModule {
            s: face.s; height: face.moduleSpan; padX: 11 * face.s; interactive: false
            visible: tr.count > 0
            BarTray { id: tr; s: face.s; trayWindow: face.trayWindow; menuEdgeY: face.height }
        }
    }
    Component {
        id: powerC
        BarModule {
            id: pm
            s: face.s; height: face.moduleSpan; padX: 10 * face.s
            onTapped: face.popoutRequested("power", face.centreOf(pm))
            MaterialIcon { text: "power_settings_new"; color: Theme.verm; font.pixelSize: 14 * face.s }
        }
    }

    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: face.edgeMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * face.s
        Repeater { model: face.resolvedLeft; delegate: Slot {} }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * face.s
        Repeater { model: face.resolvedCentre; delegate: Slot {} }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: face.edgeMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * face.s
        Repeater { model: face.resolvedRight; delegate: Slot {} }
    }
}
