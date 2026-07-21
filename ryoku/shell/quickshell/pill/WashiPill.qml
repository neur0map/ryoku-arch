pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Ryoku.Ui
import "Singletons"

// washi: the floating warping pill. a small rest pill at top-centre that warps
// in place into full surfaces (calendar, clipboard, link, notifications,
// workspaces ...), the surface growing out of the body as it morphs on
// Motion.morphCurve, exactly like the reference this was ported from (Ricelin,
// which Ryoku forked from). re-homed on Ryoku's own PillSurfaces, Ame flame and
// Theme/Motion tokens. two looks via Config.washiVariant: `ryoku` (paper-ink,
// 力 mark) or `ricelin` (faithful: warm, 時 kanji, JetBrains).
//
// shell.qml hosts this in the overlay when Config.barStyle === "washi", drives
// the open surface through `surface`, and unions hudX/Y/W/H (body) + trigX/Y/W/H
// (hover strip) into the input mask.
Item {
    id: pill
    anchors.fill: parent

    property var group: null
    property real s: 1
    property bool active: true
    required property var trayWindow

    readonly property bool ricelin: Config.washiVariant === "ricelin"
    // the faithful (ricelin) look leans on JetBrains Mono; the ryoku look uses
    // the shell's own Space Grotesk. glyph + font are the two variant tells.
    readonly property string uiFont: ricelin ? Theme.mono : Theme.font

    // the open surface, driven by shell.qml. empty = rest/hover only.
    property string surface: ""
    signal requestSurface(string name)
    signal requestClose()

    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool clipboardOpen: surface === "clipboard"
    readonly property bool linkOpen: surface === "link"
    readonly property bool inboxOpen: surface === "inbox"
    readonly property bool workspacesOpen: surface === "workspaces"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool mixerOpen: surface === "mixer"
    readonly property bool resourcesOpen: surface === "resources"
    readonly property bool powerOpen: surface === "power"
    readonly property bool wallpaperOpen: surface === "wallpaper"
    readonly property bool surfaceOpen: surface.length > 0

    // hover / pin expansion (the hover face between rest and a surface).
    property bool hoverLatch: false
    property bool pinned: false
    // Hyprland hands a freshly-mapped layer pointer focus at the cursor, which
    // reads as a hover and would latch the pill open on startup. Only latch after
    // boot settles, so that spurious enter is filtered (a real hover just expands
    // a touch late).
    property bool bootSettled: false
    Timer { interval: 2500; running: true; onTriggered: pill.bootSettled = true }
    readonly property bool expanded: surfaceOpen || pinned || hoverLatch

    // ---- geometry + morph ------------------------------------------------
    readonly property real restW: 168 * s
    readonly property real restH: 30 * s
    readonly property real hoverH: 50 * s
    readonly property real restCorner: restH / 2
    readonly property real openCorner: 22 * s

    // single source of truth per surface: its full open size (a thunk so the
    // geometry it reads is a live dep of targetSize) and the item Ame docks to.
    // each surface's Loader activates when its surface opens (below); the thunks
    // read the loaded item and guard the transient null (before it resolves)
    // with a fallback height so the morph target is never starved.
    readonly property var surfaces: ({
        calendar:   { size: () => { const it = ldCalendar.item; return Qt.size(318 * s, (it ? it.implicitHeight : 300 * s) + 32 * s); }, ame: () => ldCalendar.item },
        clipboard:  { size: () => Qt.size(360 * s, 332 * s), ame: () => ldClip.item },
        link:       { size: () => { const it = ldLink.item; return Qt.size(it && it.desiredW > 0 ? it.desiredW : 300 * s, (it ? it.implicitHeight : 220 * s) + 26 * s); }, ame: () => ldLink.item },
        inbox:      { size: () => { const it = ldInbox.item; return Qt.size(340 * s, (it ? it.implicitHeight : 240 * s) + 26 * s); }, ame: () => ldInbox.item },
        workspaces: { size: () => { const it = ldWs.item; return Qt.size(it && it.desiredW > 0 ? it.desiredW : 392 * s, (it ? it.implicitHeight : 260 * s) + 32 * s); }, ame: () => ldWs.item },
        media:      { size: () => { const it = ldMedia.item; return Qt.size((it ? it.implicitWidth : 400 * s), (it ? it.implicitHeight : 150 * s)); }, ame: () => ldMedia.item },
        mixer:      { size: () => { const it = ldMixer.item; return Qt.size((it ? it.implicitWidth : 360 * s), (it ? it.implicitHeight : 320 * s)); }, ame: () => ldMixer.item },
        resources:  { size: () => { const it = ldRes.item; return Qt.size((it ? it.implicitWidth : 300 * s), (it ? it.implicitHeight : 320 * s)); }, ame: () => ldRes.item },
        power:      { size: () => Qt.size(74 * s, 312 * s), ame: () => ldPower.item },
        wallpaper:  { size: () => Qt.size(660 * s, 172 * s), ame: () => null }
    })

    readonly property string mode: (surfaceOpen && surfaces[surface] !== undefined) ? surface
        : (expanded ? "hover" : "rest")

    readonly property size targetSize: {
        const sf = surfaces[surface];
        if (sf)
            return sf.size();
        if (mode === "hover")
            return Qt.size(Math.max(restW, hoverRow.implicitWidth + 44 * s), hoverH);
        return Qt.size(Math.max(restW, restRow.implicitWidth + 40 * s), restH);
    }
    readonly property real targetW: targetSize.width
    readonly property real targetH: targetSize.height

    property real bodyW: targetW
    property real bodyH: targetH
    property real morphRadius: surfaceOpen ? openCorner : restCorner
    Behavior on bodyW { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on bodyH { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on morphRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    // 1 when the live body has reached its target, 0 far off. drives the surface
    // cross-fade so content only appears once the shape is nearly there.
    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(bodyW - targetW), Math.abs(bodyH - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }
    // how open the island actually is (0 rest, 1 full), from the live height.
    readonly property real openProgress: surfaceOpen
        ? Math.max(0, Math.min(1, (bodyH - restH) / Math.max(1, targetH - restH))) : 0

    // hold the surface through the close morph so its content clips away like a
    // curtain rather than blinking out at the first frame of the close.
    property string shownSurface: ""
    onSurfaceChanged: if (surface.length > 0) shownSurface = surface
    onBodyHChanged: if (surface === "" && shownSurface !== "" && Math.abs(bodyH - restH) < 2 * s) shownSurface = ""
    function shownIs(n) { return shownSurface === n; }

    // ---- placement: top-centre at the frame's top lip --------------------
    readonly property real lipT: Math.max(0, Config.effectiveFrameBorder - 50)
    readonly property real bodyX: Math.round((width - bodyW) / 2)
    readonly property real bodyY: lipT + 4 * s

    property real prog: active ? 1 : 0
    Behavior on prog { NumberAnimation { duration: Motion.morph; easing.type: Easing.InOutCubic } }
    visible: active && prog > 0.002

    // ---- input mask (shell.qml unions these) -----------------------------
    readonly property real hudX: bodyX
    readonly property real hudY: bodyY
    readonly property real hudW: bodyW
    readonly property real hudH: bodyH
    readonly property real trigW: Math.max(bodyW, 280 * s)
    readonly property real trigX: Math.round((width - trigW) / 2)
    readonly property real trigY: 0
    readonly property real trigH: bodyY + restH + 12 * s

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // hover latch with a small close grace so crossing the blob rim never blinks.
    Timer { id: hoverGrace; interval: 220; onTriggered: pill.hoverLatch = false }
    function onHover(h) {
        if (h && pill.bootSettled) { hoverGrace.stop(); pill.hoverLatch = true; }
        else if (!pill.surfaceOpen && !pill.pinned) hoverGrace.restart();
    }

    // the flame's anchor while a surface is open (its declared ameForm/amePoint).
    readonly property var ameSurface: (surfaceOpen && surfaces[surface] !== undefined)
        ? surfaces[surface].ame() : null

    // ===================== body =====================
    Item {
        id: bodyHost
        x: pill.bodyX
        y: pill.bodyY
        width: pill.bodyW
        height: pill.bodyH
        opacity: pill.prog
        transformOrigin: Item.Top
        scale: 0.92 + 0.08 * pill.prog

        Rectangle {
            id: body
            anchors.fill: parent
            radius: pill.morphRadius
            border.width: 1
            // ryoku is a crisp bone-outlined flat plate (paper-ink); ricelin is a
            // soft warm gradient card.
            border.color: pill.ricelin ? Theme.border : Theme.lineStrong
            color: pill.ricelin ? Theme.cardBot : Theme.paper
            gradient: pill.ricelin ? warmGrad : null
            Gradient {
                id: warmGrad
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
                shadowBlur: 0.7
                shadowVerticalOffset: 3 * pill.s
            }
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: body.radius * 0.6
                anchors.rightMargin: body.radius * 0.6
                height: 1
                color: Theme.sheen
            }
        }

        // ryoku wears the hub's matte grain over pure black (Theme.paper is
        // #000000, which reads as a void without the speckle); ricelin keeps its
        // warm gradient card. The grain is intrinsic to the variant, like the
        // hub's own (Ryoku.Ui Tokens.grainOpacity, carried by Grain) -- not the
        // user's shell-wide grainStrength, which they may turn off. A rounded
        // ClippingRectangle keeps the tile inside the capsule.
        ClippingRectangle {
            anchors.fill: body
            radius: body.radius
            color: "transparent"
            visible: !pill.ricelin
            Grain { anchors.fill: parent }
        }

        // ---- rest face: glyph + time ----
        Item {
            anchors.fill: parent
            opacity: (pill.expanded) ? 0 : Math.pow(pill.morphCloseness, 1.5)
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            Row {
                id: restRow
                anchors.centerIn: parent
                spacing: 9 * pill.s
                Item {
                    width: 13 * pill.s
                    height: pill.restH
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.ricelin ? "時" : Theme.mark
                    color: Theme.cream
                    font.family: pill.ricelin ? Theme.fontJp : Theme.font
                    font.pixelSize: 15 * pill.s
                    font.weight: Font.Medium
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.cream
                    font.family: pill.uiFont
                    font.pixelSize: 16 * pill.s
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                }
                Item {
                    id: restMediaChip
                    visible: Media.present
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: restMediaRow.implicitWidth
                    implicitHeight: restMediaRow.implicitHeight
                    // the pill widens to carry a now-playing chip while music
                    // sounds, so the rest face shows what plays at a glance;
                    // hover exposes the media icon to open the full surface.
                    Row {
                        id: restMediaRow
                        anchors.centerIn: parent
                        spacing: 7 * pill.s
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16 * pill.s; color: Theme.hair }
                        BarMedia { anchors.verticalCenter: parent.verticalCenter; s: pill.s; maxW: 150 * pill.s }
                    }
                }
            }
        }

        // ---- hover face: workspaces + clock/date + quick surfaces ----
        Item {
            anchors.fill: parent
            opacity: pill.mode === "hover" ? Math.pow(pill.morphCloseness, 1.2) : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            Row {
                id: hoverRow
                anchors.centerIn: parent
                spacing: 16 * pill.s

                BarWorkspaces {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    activeWsId: Workspaces.activeId
                }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 22 * pill.s; color: Theme.hair }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: hoverClock.implicitWidth
                    height: hoverClock.implicitHeight
                    Column {
                        id: hoverClock
                        anchors.centerIn: parent
                        spacing: 2 * pill.s
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatTime(clock.date, "HH:mm")
                            color: Theme.cream
                            font.family: pill.uiFont
                            font.pixelSize: 18 * pill.s
                            font.weight: Font.DemiBold
                            font.features: ({ "tnum": 1 })
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.locale("en_US").toString(clock.date, "ddd d MMM").toUpperCase()
                            color: Theme.dim
                            font.family: pill.uiFont
                            font.pixelSize: 8.5 * pill.s
                            font.weight: Font.Medium
                            font.letterSpacing: 1.6 * pill.s
                        }
                    }
                    MouseArea {
                        anchors.centerIn: parent
                        width: hoverClock.implicitWidth + 24 * pill.s
                        height: hoverClock.implicitHeight + 12 * pill.s
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("calendar")
                    }
                }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 22 * pill.s; color: Theme.hair }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 13 * pill.s
                    Repeater {
                        model: {
                            var m = [{ g: "notifications", surf: "inbox" }, { g: "wifi", surf: "link" }, { g: "content_paste", surf: "clipboard" }];
                            if (Media.present) m.push({ g: "music_note", surf: "media" });
                            return m;
                        }
                        delegate: Item {
                            id: qi
                            required property var modelData
                            width: 20 * pill.s
                            height: 20 * pill.s
                            anchors.verticalCenter: parent.verticalCenter
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: qi.modelData.g
                                color: qh.containsMouse ? Theme.verm : Theme.subtle
                                font.pixelSize: 17 * pill.s
                            }
                            MouseArea {
                                id: qh
                                anchors.fill: parent
                                anchors.margins: -4 * pill.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pill.requestSurface(qi.modelData.surf)
                            }
                        }
                    }
                }
            }
        }

        // ---- surfaces (reused Ryoku PillSurfaces, morphed in place) ----
        Loader { id: ldCalendar; active: pill.calendarOpen;   anchors.fill: parent; sourceComponent: calComp }
        Loader { id: ldClip;     active: pill.clipboardOpen;  anchors.fill: parent; sourceComponent: clipComp }
        Loader { id: ldLink;     active: pill.linkOpen;       anchors.fill: parent; sourceComponent: linkComp }
        Loader { id: ldInbox;    active: pill.inboxOpen;      anchors.fill: parent; sourceComponent: inboxComp }
        Loader { id: ldWs;       active: pill.workspacesOpen; anchors.fill: parent; sourceComponent: wsComp }
        Loader { id: ldMedia;    active: pill.mediaOpen;      anchors.fill: parent; sourceComponent: mediaComp }
        Loader { id: ldMixer;    active: pill.mixerOpen;      anchors.fill: parent; sourceComponent: mixerComp }
        Loader { id: ldRes;      active: pill.resourcesOpen;  anchors.fill: parent; sourceComponent: resComp }
        Loader { id: ldPower;    active: pill.powerOpen;      anchors.fill: parent; sourceComponent: powerComp }
        Loader { id: ldWall;     active: pill.wallpaperOpen;  anchors.fill: parent; sourceComponent: wallComp }

        Component { id: calComp;   Calendar          { s: pill.s; open: pill.calendarOpen;   shown: pill.shownIs("calendar");   morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: clipComp;  Clipboard         { s: pill.s; open: pill.clipboardOpen;  shown: pill.shownIs("clipboard");  morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: linkComp;  Link              { s: pill.s; open: pill.linkOpen;       shown: pill.shownIs("link");       morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: inboxComp; Inbox             { s: pill.s; open: pill.inboxOpen;      shown: pill.shownIs("inbox");      morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: wsComp;    WorkspacesSurface { s: pill.s; open: pill.workspacesOpen; shown: pill.shownIs("workspaces"); morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: mediaComp; MediaSurface     { s: pill.s; open: pill.mediaOpen;     shown: pill.shownIs("media");     morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: mixerComp; MixerSurface     { s: pill.s; open: pill.mixerOpen;     shown: pill.shownIs("mixer");     morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: resComp;   ResourcesSurface { s: pill.s; open: pill.resourcesOpen; shown: pill.shownIs("resources"); morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: powerComp; PowerSurface     { s: pill.s; open: pill.powerOpen;     shown: pill.shownIs("power");     morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }
        Component { id: wallComp;  WallpaperSurface { s: pill.s; open: pill.wallpaperOpen; shown: pill.shownIs("wallpaper"); morphCloseness: pill.morphCloseness; openProgress: pill.openProgress; openW: pill.targetW; openH: pill.targetH; onRequestClose: pill.requestClose() } }

        // ---- Ame: the molten-glass flame, docked to the open surface ----
        Ame {
            id: ame
            anchors.fill: parent
            s: pill.s
            wake: Qt.point(restRow.x + 6.5 * pill.s, pill.restH / 2)
            form: pill.ameSurface ? pill.ameSurface.ameForm : (pill.expanded ? "off" : "rest")
            point: pill.ameSurface
                ? pill.ameSurface.mapToItem(bodyHost, pill.ameSurface.amePoint.x, pill.ameSurface.amePoint.y)
                : Qt.point(restRow.x + 6.5 * pill.s, pill.restH / 2)
        }

        HoverHandler { id: hh; onHoveredChanged: pill.onHover(hh.hovered) }
    }
}
