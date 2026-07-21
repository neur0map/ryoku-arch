pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Ryoku.Ui
import "Singletons"

// atoll: the multi-island bar ported from ilyamiro's nixos shell. instead of
// one band, separate dark rounded islands float in the top strip (frame-off),
// each cascading in on startup and lifting on hover; the active / on state
// inverts to a bone chip, Ryoku's own emphasis. reuses Ryoku's data modules
// (workspaces, clock, weather, media, status, tray) and singletons, restyled
// into the island layout. click a module to open its edge popout.
Item {
    id: atoll
    anchors.fill: parent

    required property real s
    required property real band
    required property var trayWindow
    signal popoutRequested(string name, real center)
    signal hoverPopoutRequested(string name, real center, bool hovered)

    readonly property int activeWsId: Workspaces.activeId
    readonly property real islandH: Math.max(28 * s, band - 8 * s)
    readonly property real edge: 12 * s
    readonly property real gap: 6 * s
    // ryoku variant: square grainy paper-black islands floating over the wallpaper,
    // Space Grotesk. ilyamiro (default): rounded translucent islands, JetBrains.
    readonly property bool ryoku: Config.atollVariant === "ryoku"

    // startup cascade: islands reveal in slot order.
    property bool booted: false
    Timer { interval: 10; running: true; onTriggered: atoll.booted = true }

    // along-axis centre of a module in window coords (the popout's space).
    function centre(item) { return item.mapToItem(null, item.width / 2, item.height / 2).x; }

    // island chrome: a dark translucent rounded panel with a hairline border,
    // self-staggering a slide + fade on startup.
    component Island: Rectangle {
        id: isl
        property int slot: 0
        property bool reveal: false
        color: atoll.ryoku ? Theme.paper : Qt.alpha(Theme.cardBot, 0.75)
        radius: atoll.ryoku ? 4 * atoll.s : 14 * atoll.s
        border.width: 1
        border.color: atoll.ryoku ? Theme.border : Theme.hair
        clip: atoll.ryoku
        height: atoll.islandH
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (atoll.band - atoll.islandH) / 2
        opacity: reveal ? 1 : 0
        visible: opacity > 0.01
        transform: Translate {
            y: isl.reveal ? 0 : -18 * atoll.s
            Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        }
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Timer { interval: 40 + isl.slot * 90; running: atoll.booted; onTriggered: isl.reveal = true }
        // ryoku wears the hub's matte grain over paper-black (the washi ryoku
        // pill idiom); ilyamiro keeps the plain translucent card, no speckle.
        Grain { anchors.fill: parent; anchors.margins: 1; visible: atoll.ryoku }
    }

    // a hover-lifting icon button for the left island.
    component IconBtn: Rectangle {
        id: ib
        property string glyph
        signal act()
        width: atoll.islandH - 8 * atoll.s
        height: atoll.islandH - 12 * atoll.s
        radius: atoll.ryoku ? 4 * atoll.s : 10 * atoll.s
        anchors.verticalCenter: parent.verticalCenter
        color: iba.containsMouse ? Qt.alpha(Theme.tileBg, 0.7) : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }
        MaterialIcon {
            anchors.centerIn: parent
            text: ib.glyph
            color: iba.containsMouse ? Theme.bright : Theme.cream
            font.pixelSize: Math.round((atoll.islandH - 12 * atoll.s) * 0.58)
            scale: iba.containsMouse ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        MouseArea {
            id: iba
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.act()
        }
    }

    // ---- left group: launcher + settings, workspaces, now-playing ----------
    Row {
        anchors.left: parent.left
        anchors.leftMargin: atoll.edge
        anchors.bottom: parent.bottom
        height: parent.height
        spacing: atoll.gap

        Island {
            id: leftIsland
            slot: 0
            width: leftIcons.implicitWidth + 12 * atoll.s
            Row {
                id: leftIcons
                anchors.centerIn: parent
                spacing: 2 * atoll.s
                IconBtn { glyph: "search"; onAct: Quickshell.execDetached(["ryoku-shell", "launcher"]) }
                IconBtn { glyph: "settings"; onAct: Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryoku-hub.lock qs -c hub"]) }
                IconBtn { glyph: "power_settings_new"; onAct: atoll.popoutRequested("power", atoll.centre(leftIsland)) }
            }
        }

        Island {
            id: wsIsland
            slot: 1
            width: wsMod.implicitWidth + 20 * atoll.s
            AtollWorkspaces {
                id: wsMod
                anchors.centerIn: parent
                s: atoll.s
                activeWsId: atoll.activeWsId
                ryoku: atoll.ryoku
                slotH: atoll.islandH - 12 * atoll.s
            }
        }

        Island {
            id: mediaIsland
            slot: 2
            reveal: atoll.booted && Media.present
            width: Media.present ? mediaMod.implicitWidth + 24 * atoll.s : 0
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            BarMedia {
                id: mediaMod
                anchors.centerIn: parent
                s: atoll.s
                // keep the left group of islands clear of the centre island: the
                // title elides to the room between them.
                maxW: Math.max(0, (atoll.width - centreIsland.width) / 2 - atoll.edge - leftIsland.width - wsIsland.width - 2 * atoll.gap - 36 * atoll.s)
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: atoll.hoverPopoutRequested("media", atoll.centre(mediaIsland), true)
                onExited: atoll.hoverPopoutRequested("media", atoll.centre(mediaIsland), false)
            }
        }
    }

    // ---- centre island: clock + weather ------------------------------------
    Island {
        id: centreIsland
        slot: 3
        width: centreRow.implicitWidth + 30 * atoll.s
        anchors.horizontalCenter: parent.horizontalCenter
        Row {
            id: centreRow
            anchors.centerIn: parent
            spacing: 16 * atoll.s
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: clockMod.implicitWidth
                height: clockMod.implicitHeight
                BarClock { id: clockMod; anchors.centerIn: parent; s: atoll.s }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8 * atoll.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: atoll.popoutRequested("calendar", atoll.centre(centreIsland))
                }
            }
            BarWeather {
                anchors.verticalCenter: parent.verticalCenter
                s: atoll.s
                onRequestPopout: (name, center) => atoll.popoutRequested(name, center)
            }
        }
    }

    // ---- right group: tray, status -----------------------------------------
    Row {
        anchors.right: parent.right
        anchors.rightMargin: atoll.edge
        anchors.bottom: parent.bottom
        height: parent.height
        spacing: atoll.gap

        Island {
            slot: 5
            reveal: atoll.booted && trayMod.count > 0
            width: trayMod.count > 0 ? trayMod.implicitWidth + 22 * atoll.s : 0
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            BarTray {
                id: trayMod
                anchors.centerIn: parent
                s: atoll.s
                trayWindow: atoll.trayWindow
                menuEdgeY: atoll.height
            }
        }

        Island {
            slot: 4
            width: statusMod.implicitWidth + 22 * atoll.s
            AtollStatus {
                id: statusMod
                anchors.centerIn: parent
                s: atoll.s
                ryoku: atoll.ryoku
                slotH: atoll.islandH - 12 * atoll.s
                onRequestPopout: (name, center) => atoll.popoutRequested(name, center)
            }
        }
    }
}
