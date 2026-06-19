pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Networking
import "Singletons"

/**
 * The pill body. One element carries every state. Width/height driven by `state`
 * (rest, hover/pinned, calendar) with a no-overshoot easing so surfaces
 * grow out of the pill in place. Surfaces are stacked absolutely and cross-fade.
 *
 * Hover comes from a passive HoverHandler, pin from a passive TapHandler, so
 * neither swallows pointer events from the surfaces stacked above: workspace
 * dots, the clock target and tray icons get their own clicks and drags.
 */
Item {
    id: pill

    property real s: 1
    property string screenName: ""
    property var barWindow
    property string surface: ""

    property bool hovered: false
    property bool pinned: false
    property bool forcePinned: false

    containmentMask: QtObject {
        function contains(point: point) : bool {
            if (pill.expanded)
                return point.x >= 0 && point.y >= 0 && point.x <= pill.width && point.y <= pill.height;
            return pill.insideRounded(point.x, point.y, pill.width, pill.height, pill.morphRadius);
        }
    }

    readonly property bool held: pinned || forcePinned
    readonly property bool calendarOpen: surface === "calendar"
    readonly property bool launcherOpen: surface === "launcher"
    readonly property bool clipboardOpen: surface === "clipboard"
    readonly property bool wallpaperOpen: surface === "wallpaper"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool linkOpen: surface === "link"
    readonly property bool batteryOpen: surface === "battery"
    readonly property bool sysinfoOpen: surface === "sysinfo"
    readonly property bool stashOpen: surface === "stash"
    readonly property bool toolkitOpen: surface === "toolkit"
    readonly property bool utilitiesOpen: surface === "utilities"
    readonly property bool hasMedia: Mpris.players.values.length > 0

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null
    readonly property real wifiLevel: (wifiActive && wifiActive.signalStrength) || 0
    readonly property bool surfaceOpen: surface.length > 0
    property bool hoverLatch: false
    readonly property bool expanded: surfaceOpen || held || hoverLatch
    readonly property bool toastActive: Notifs.popups.length > 0
    readonly property bool osdActive: osd.flashing

    readonly property real restW: 108 * s
    readonly property real restH: 38 * s
    readonly property real hoverPad: 20 * s
    readonly property real hoverW: hoverRow.implicitWidth + 2 * hoverPad
    readonly property real hoverH: 58 * s
    readonly property real calendarW: 318 * s
    readonly property real calendarH: calendar.implicitHeight + 32 * s
    readonly property real launcherW: 360 * s
    readonly property real launcherH: 332 * s
    readonly property real clipboardW: 360 * s
    readonly property real clipboardH: 332 * s
    readonly property real wallpaperW: 720 * s
    readonly property real wallpaperH: 146 * s
    readonly property real mediaW: 390 * s
    readonly property real mediaH: 150 * s
    readonly property real batteryW: 316 * s
    readonly property real sysinfoW: 360 * s
    readonly property real stashW: 420 * s
    readonly property real toolkitW: 418 * s
    readonly property real utilitiesW: 360 * s
    readonly property real toastW: 342 * s
    readonly property real restCorner: 18 * s
    readonly property real openCorner: 22 * s

    readonly property string mode: calendarOpen ? "calendar"
        : (launcherOpen ? "launcher"
        : (clipboardOpen ? "clipboard"
        : (wallpaperOpen ? "wallpaper"
        : (mediaOpen ? "media"
        : (linkOpen ? "link"
        : (batteryOpen ? "battery"
        : (sysinfoOpen ? "sysinfo"
        : (stashOpen ? "stash"
        : (toolkitOpen ? "toolkit"
        : (utilitiesOpen ? "utilities"
        : (osdActive && !held ? "osd"
        : (toastActive && !held ? "toast"
        : (expanded ? "hover" : "rest")))))))))))))

    signal requestSurface(string name)
    signal requestClose()


    /**
     * Pop the open link surface one subview back. Returns true when the step was
     * consumed, false when the surface is already at its root (or not open) and
     * Escape should close the surface instead.
     */
    function linkBack() {
        return pill.linkOpen ? link.back() : false;
    }

    /**
     * Slide the open wallpaper strip's focus by `dir` thumbs; +1 is right (older)
     * and -1 is left (newer). No-op unless the wallpaper surface is open.
     */
    function wallpaperMove(dir) {
        if (pill.wallpaperOpen)
            wall.move(dir);
    }

    /**
     * Apply the wallpaper strip's focused thumb through ryoku-shell wallpaper. The
     * surface stays open so the pick can be iterated. No-op unless the
     * wallpaper surface is open.
     */
    function wallpaperActivate() {
        if (pill.wallpaperOpen)
            wall.activate();
    }

    onSurfaceOpenChanged: if (surfaceOpen) pinned = false

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string hhmm: Qt.formatTime(now, "HH:mm")
        readonly property string date: loc.toString(now, "ddd d MMM")
    }

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    property real morphRadius: (mode === "rest" || mode === "hover") ? restCorner : openCorner

    /**
     * Target geometry per mode, one entry per surface. Thunks (not plain sizes)
     * so the properties they read are evaluated inside the targetSize binding and
     * register as live deps. Adding a surface is one line here.
     */
    readonly property var surfaceSize: ({
        calendar:  () => Qt.size(calendarW, calendarH),
        launcher:  () => Qt.size(launcherW, launcherH),
        clipboard: () => Qt.size(clipboardW, clipboardH),
        wallpaper: () => Qt.size(wallpaperW, wallpaperH),
        media:     () => Qt.size(mediaW, mediaH),
        link:      () => Qt.size(link.desiredW, link.implicitHeight + 26 * s),
        battery:   () => Qt.size(batteryW, battery.implicitHeight + 26 * s),
        sysinfo:   () => Qt.size(sysinfoW, sysinfo.implicitHeight + 32 * s),
        stash:     () => Qt.size(stashW, stash.implicitHeight + 28 * s),
        toolkit:   () => Qt.size(toolkitW, toolkit.implicitHeight + 28 * s),
        utilities: () => Qt.size(utilitiesW, utilities.implicitHeight + 30 * s),
        osd:       () => Qt.size(osd.desiredW, osd.desiredH),
        toast:     () => Qt.size(toastW, toastLoader.item ? toastLoader.item.implicitHeight + 24 * s : restH),
        hover:     () => Qt.size(hoverW, hoverH)
    })

    readonly property size targetSize: {
        const f = surfaceSize[mode];
        return f ? f() : Qt.size(Math.max(restW, restRow.implicitWidth + 36 * s), restH);
    }
    readonly property real targetW: targetSize.width
    readonly property real targetH: targetSize.height

    width: targetW
    height: targetH

    /**
     * How settled the pill is into its target geometry: 0 while the morph is far
     * away, 1 once it arrives. Content opacities key off this, not their own
     * timers, so a surface fades in as the pill reaches full size, never over a
     * half-grown pill.
     */
    readonly property real morphCloseness: {
        const d = Math.max(Math.abs(width - targetW), Math.abs(height - targetH));
        return 1 - Math.min(1, d / (110 * s));
    }

    /**
     * Gate the soul bead until the hover morph has arrived and its icons exist.
     * Fire it earlier and the bead aims at anchors that aren't laid out yet.
     * Latched so small width changes inside hover (workspace dot growing, tray
     * icons appearing) don't flicker the bead off.
     */
    property bool hoverSoulGate: false
    readonly property bool hoverArrived: mode === "hover" && morphCloseness > 0.55
    onHoverArrivedChanged: if (hoverArrived) hoverSoulGate = true;
    onModeChanged: if (mode !== "hover") {
        hoverSoulGate = false;
        soulTarget = "";
        soulWsIndex = -1;
    }
    onHoverSoulGateChanged: if (hoverSoulGate) kanjiFlashAnim.restart()

    property string soulTarget: ""
    property int soulWsIndex: -1

    property real kanjiFlash: 0

    SequentialAnimation {
        id: kanjiFlashAnim
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 1; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: pill; property: "kanjiFlash"; to: 0; duration: 320; easing.type: Easing.OutCubic }
    }

    Behavior on width { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on height { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }
    Behavior on morphRadius { NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve } }

    function insideRounded(px, py, w, h, r) {
        if (px < 0 || py < 0 || px > w || py > h)
            return false;
        var rr = Math.max(0, Math.min(r, w / 2, h / 2));
        var cx = px < rr ? rr : (px > w - rr ? w - rr : px);
        var cy = py < rr ? rr : (py > h - rr ? h - rr : py);
        var dx = px - cx;
        var dy = py - cy;
        return dx * dx + dy * dy <= rr * rr + 0.01;
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: pill.morphRadius
        color: "transparent"
    }

    /**
     * Rest anchor for Ame: the Ryoku mark centre. The idle outline condenses into
     * the bead here before it moves.
     */
    readonly property point wakePoint: {
        void pill.width;
        void pill.height;
        return restKanji.mapToItem(pill, restKanji.width / 2, restKanji.height / 2);
    }

    /**
     * Bead target while hovered. soulTarget is a sticky key written by the hover
     * sources: the bead parks on the last focused dot or icon and glides to the
     * next, so crossing a gap between targets doesn't snap it back to the active
     * workspace. Pill geometry is voided so the anchor follows the hover morph,
     * the point stays live.
     */
    readonly property point soulPoint: {
        void pill.width;
        void pill.height;
        const drop = 12 * pill.s;
        if (soulTarget === "wifi")
            return wifiIcon.mapToItem(pill, wifiIcon.width / 2, wifiIcon.height + drop * 0.55);
        if (soulTarget === "battery")
            return batteryIcon.mapToItem(pill, batteryIcon.width / 2, batteryIcon.height + drop * 0.55);
        if (soulTarget === "inbox")
            return inboxIcon.mapToItem(pill, inboxIcon.width / 2, inboxIcon.height + drop * 0.55);
        if (soulTarget === "sysinfo")
            return sysinfoIcon.mapToItem(pill, sysinfoIcon.width / 2, sysinfoIcon.height + drop * 0.55);
        return pill.wakePoint;
    }

    /**
     * Which open surface owns Ame's anchor, in priority order. Each surface
     * exports its own `ameForm`/`amePoint`; the pill just picks one and maps it.
     * Null = nothing open, so Ame falls back to the pill's own hover/wake anchor.
     */
    readonly property var ameSurface: mediaOpen ? media
        : (launcherOpen ? launcher
        : (clipboardOpen ? clip
        : (calendarOpen ? calendar
        : (linkOpen ? link
        : (sysinfoOpen ? sysinfo
        : (stashOpen ? stash
        : (toolkitOpen ? toolkit
        : (utilitiesOpen ? utilities
        : (batteryOpen ? battery : null)))))))))

    Ame {
        id: ame
        anchors.fill: parent
        s: pill.s
        heat: 0
        wake: pill.wakePoint
        wickDir: -1
        form: pill.ameSurface ? pill.ameSurface.ameForm : "off"
        point: pill.ameSurface
            ? Qt.point(pill.ameSurface.x + pill.ameSurface.amePoint.x,
                       pill.ameSurface.y + pill.ameSurface.amePoint.y)
            : (pill.mode === "hover" ? pill.soulPoint : pill.wakePoint)
    }

    onHoveredChanged: {
        if (hovered) {
            hoverLatch = true;
            graceTimer.stop();
        } else {
            graceTimer.restart();
        }
    }

    Timer {
        id: graceTimer
        interval: 300
        onTriggered: {
            if (pill.morphCloseness < 0.95) {
                graceTimer.restart();
                return;
            }
            pill.hoverLatch = false;
        }
    }

    TapHandler {
        enabled: !pill.surfaceOpen
        gesturePolicy: TapHandler.WithinBounds
        onTapped: pill.pinned = !pill.pinned
    }

    Item {
        id: rest
        anchors.fill: parent
        opacity: (pill.expanded || pill.mode === "toast" || pill.mode === "osd") ? 0 : Math.pow(pill.morphCloseness, 1.5)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: pill.mode === "rest" ? Motion.fast : 260 } }

        Row {
            id: restRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -5 * pill.s
            spacing: 9 * pill.s
            Item {
                id: restKanji
                anchors.verticalCenter: parent.verticalCenter
                width: kanjiFill.implicitWidth
                height: kanjiFill.implicitHeight

                Text {
                    anchors.fill: parent
                    text: kanjiFill.text
                    color: "transparent"
                    font: kanjiFill.font
                    style: Text.Outline
                    styleColor: Qt.alpha(Theme.brand,
                        Math.min(1, (pill.mode === "rest" || !pill.hoverSoulGate ? 0.5 : 0) + pill.kanjiFlash))
                }

                Text {
                    id: kanjiFill
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 15 * pill.s
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.hhmm
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 16 * pill.s
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        WorkspaceWave {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: restRow.bottom
            anchors.topMargin: 3 * pill.s
            screenName: pill.screenName
            s: pill.s
        }
    }

    Item {
        id: hover
        anchors.fill: parent
        // Clip the content to the pill so it can fade in immediately as the island
        // grows, without spilling past the island edges mid-morph.
        clip: true
        opacity: pill.mode === "hover" ? 1 : 0
        visible: true
        Behavior on opacity { NumberAnimation { duration: pill.mode === "hover" ? Motion.fast : 40 } }

        readonly property bool live: pill.mode === "hover"

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 20 * pill.s

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
                        text: clock.hhmm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 18 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: clock.date
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 8.5 * pill.s
                        font.weight: Font.Medium
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6 * pill.s
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Weather.available
                        spacing: 4 * pill.s

                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11 * pill.s
                            height: 11 * pill.s
                            name: Weather.glyph
                            color: Theme.dim
                            stroke: 1.6
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.temp
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 9 * pill.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                MouseArea {
                    anchors.centerIn: parent
                    width: hoverClock.implicitWidth + 22 * pill.s
                    height: hoverClock.implicitHeight + 10 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * pill.s
                color: Theme.hair
            }

            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * pill.s

                MinimizedTray {
                    id: minimized
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    screenName: pill.screenName
                    enabled: hover.live
                    visible: count > 0
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: minimized.count > 0
                    width: 1
                    height: 14 * pill.s
                    color: Theme.hair
                    opacity: 0.7
                }

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                }

                Shape {
                    id: dndIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.dnd
                    width: 16 * pill.s
                    height: 16 * pill.s
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.5 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: 5.2 * pill.s; startY: 12.2 * pill.s
                        PathLine { x: 12.2 * pill.s; y: 12.2 * pill.s }
                        PathLine { x: 12.2 * pill.s; y: 7.2 * pill.s }
                        PathCubic {
                            control1X: 12.2 * pill.s; control1Y: 5.4 * pill.s
                            control2X: 11.2 * pill.s; control2Y: 4.0 * pill.s
                            x: 9.5 * pill.s; y: 3.5 * pill.s
                        }
                    }
                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.5 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 6.8 * pill.s; startY: 13.6 * pill.s
                        PathLine { x: 9.2 * pill.s; y: 13.6 * pill.s }
                    }
                    ShapePath {
                        strokeColor: Theme.vermLit
                        strokeWidth: 1.6 * pill.s
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        startX: 3.2 * pill.s; startY: 2.8 * pill.s
                        PathLine { x: 13.0 * pill.s; y: 13.4 * pill.s }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Battery.present
                    spacing: 12 * pill.s

                    Item {
                        id: wifiIcon
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pill.wifiDev !== null && pill.wifiOn
                        width: 17 * pill.s
                        height: 17 * pill.s

                        WifiGlyph {
                            anchors.centerIn: parent
                            s: pill.s
                            level: pill.wifiLevel
                            on: pill.wifiOn
                        }

                        MouseArea {
                            id: wifiArea
                            anchors.fill: parent
                            anchors.margins: -6 * pill.s
                            hoverEnabled: true
                            enabled: hover.live
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pill.requestSurface("link")
                            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "wifi"
                        }

                    }

                    Item {
                        id: batteryIcon
                        anchors.verticalCenter: parent.verticalCenter
                        width: battPct.implicitWidth
                        height: 17 * pill.s

                        Text {
                            id: battPct
                            anchors.centerIn: parent
                            text: Battery.pct + "%"
                            color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                            font.family: Theme.font
                            font.pixelSize: 13 * pill.s
                            font.weight: Battery.charging ? Font.DemiBold : Font.Medium
                            font.features: { "tnum": 1 }
                        }

                        MouseArea {
                            id: batteryArea
                            anchors.fill: parent
                            anchors.margins: -6 * pill.s
                            hoverEnabled: true
                            enabled: hover.live
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pill.requestSurface("battery")
                            onContainsMouseChanged: if (containsMouse) pill.soulTarget = "battery"
                        }

                    }
                }

                Item {
                    id: inboxIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "inbox"
                        color: inboxArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    Rectangle {
                        visible: Notifs.unread > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2 * pill.s
                        anchors.rightMargin: -2 * pill.s
                        width: 5 * pill.s
                        height: 5 * pill.s
                        radius: width / 2
                        color: Theme.flameGlow
                    }

                    MouseArea {
                        id: inboxArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("link")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "inbox"
                    }

                }

                Item {
                    id: sysinfoIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * pill.s
                    height: 17 * pill.s

                    GlyphIcon {
                        anchors.fill: parent
                        name: "cpu"
                        color: sysinfoArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.7
                    }

                    MouseArea {
                        id: sysinfoArea
                        anchors.fill: parent
                        anchors.margins: -6 * pill.s
                        hoverEnabled: true
                        enabled: hover.live
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pill.requestSurface("sysinfo")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "sysinfo"
                    }

                }
            }
        }
    }

    Calendar {
        id: calendar
        s: pill.s
        open: pill.calendarOpen
        morphCloseness: pill.morphCloseness
    }

    Launcher {
        id: launcher
        s: pill.s
        open: pill.launcherOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Clipboard {
        id: clip
        s: pill.s
        open: pill.clipboardOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Wallpaper {
        id: wall
        s: pill.s
        open: pill.wallpaperOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Media {
        id: media
        s: pill.s
        open: pill.mediaOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Link {
        id: link
        s: pill.s
        open: pill.linkOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    BatterySurface {
        id: battery
        s: pill.s
        open: pill.batteryOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    SysInfoSurface {
        id: sysinfo
        s: pill.s
        open: pill.sysinfoOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    StashSurface {
        id: stash
        s: pill.s
        open: pill.stashOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    ToolkitSurface {
        id: toolkit
        s: pill.s
        open: pill.toolkitOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    UtilitiesSurface {
        id: utilities
        s: pill.s
        open: pill.utilitiesOpen
        morphCloseness: pill.morphCloseness
        onRequestClose: pill.requestClose()
    }

    Osd {
        id: osd
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 18 * pill.s
        anchors.rightMargin: 18 * pill.s
        anchors.bottomMargin: 12 * pill.s
        s: pill.s
        suppressed: pill.surfaceOpen || pill.held
        enabled: pill.mode === "osd"
        opacity: pill.mode === "osd" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
    }

    Loader {
        id: toastLoader
        active: pill.toastActive
        anchors.fill: parent
        anchors.topMargin: 12 * pill.s
        anchors.leftMargin: 16 * pill.s
        anchors.rightMargin: 16 * pill.s
        anchors.bottomMargin: 12 * pill.s
        enabled: pill.mode === "toast"
        opacity: pill.mode === "toast" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        sourceComponent: Item {
            implicitHeight: toastContent.implicitHeight

            Toast {
                id: toastContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                s: pill.s
                live: pill.mode === "toast"
                notif: Notifs.popups.length > 0 ? Notifs.popups[Notifs.popups.length - 1] : null
                onOpenCenter: pill.requestSurface("link")
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: Notifs.popups.length > 1
                text: "+" + (Notifs.popups.length - 1)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9 * pill.s
                font.weight: Font.DemiBold
            }
        }
    }

}
