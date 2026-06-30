pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Mpris
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
    property string displayedSurface: ""

    // Island hover is the OR of two sources so it works everywhere without one
    // swallowing the other: `bodyHover` is a passive HoverHandler on the pill
    // (an ancestor of every surface and tray icon, so their own hoverEnabled
    // MouseAreas still receive hover), and `externalHover` is set by the shell
    // for the neck above the body and the auto-hide reveal strip, which sit
    // outside the pill item. `hoverSuppressed` lets the music bud steal it.
    property bool externalHover: false
    property bool hoverSuppressed: false
    readonly property bool hovered: !hoverSuppressed && (externalHover || bodyHover.hovered)

    // A bud beside the island (music/update island, activity strip) is hovered.
    // While it is, the pill holds its expand state (see graceTimer) so the bud --
    // whose x tracks the pill width -- never slides out from under the cursor,
    // which is what let a revealed auto-hidden island collapse as you reached it.
    property bool satelliteHover: false
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
    readonly property bool clipboardOpen: surface === "clipboard"
    readonly property bool wallpaperOpen: surface === "wallpaper"
    readonly property bool mediaOpen: surface === "media"
    readonly property bool linkOpen: surface === "link"
    readonly property bool inboxOpen: surface === "inbox"
    readonly property bool batteryOpen: surface === "battery"
    readonly property bool sysinfoOpen: surface === "sysinfo"
    readonly property bool stashOpen: surface === "stash"
    readonly property bool toolkitOpen: surface === "toolkit"
    readonly property bool utilitiesOpen: surface === "utilities"
    readonly property bool voiceOpen: surface === "voice"
    readonly property bool workspacesOpen: surface === "workspaces"
    readonly property bool keyringOpen: surface === "keyring"
    readonly property bool hasMedia: Mpris.players.values.length > 0

    readonly property bool surfaceOpen: surface.length > 0
    property bool hoverLatch: false
    readonly property bool expanded: surfaceOpen || held || hoverLatch
    readonly property bool toastActive: Notifs.popups.length > 0
    readonly property bool osdActive: osd.flashing

    readonly property real restW: Config.islandWidth * s
    readonly property real restH: Config.islandHeight * s
    readonly property real hoverPad: 20 * s
    readonly property real hoverW: hoverRow.implicitWidth + 2 * hoverPad
    readonly property real hoverH: 58 * s
    readonly property real calendarW: 318 * s
    readonly property real calendarH: calendar.implicitHeight + 32 * s
    readonly property real clipboardW: 360 * s
    readonly property real clipboardH: 332 * s
    readonly property real wallpaperW: 720 * s
    readonly property real wallpaperH: 146 * s
    readonly property real mediaW: 390 * s
    readonly property real mediaH: 150 * s
    readonly property real batteryW: 316 * s
    readonly property real inboxW: 340 * s
    readonly property real sysinfoW: 360 * s
    readonly property real deckW: 660 * s
    readonly property real voiceW: 320 * s
    readonly property real toastW: 342 * s
    readonly property real keyringW: 380 * s
    readonly property real restCorner: Config.islandRestCorner * s
    readonly property real openCorner: Config.islandOpenCorner * s

    readonly property string mode: keyringOpen ? "keyring" : baseMode
    readonly property string baseMode: calendarOpen ? "calendar"
        : (clipboardOpen ? "clipboard"
        : (wallpaperOpen ? "wallpaper"
        : (mediaOpen ? "media"
        : (linkOpen ? "link"
        : (inboxOpen ? "inbox"
        : (batteryOpen ? "battery"
        : (sysinfoOpen ? "sysinfo"
        : (stashOpen ? "stash"
        : (toolkitOpen ? "toolkit"
        : (utilitiesOpen ? "utilities"
        : (voiceOpen ? "voice"
        : (workspacesOpen ? "workspaces"
        : (osdActive && !held ? "osd"
        : (toastActive && !held ? "toast"
        : (expanded ? "hover" : "rest")))))))))))))))

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

    // Track which surface owns the island. Follows `surface` while open and
    // lingers through the close morph (so content rides the shrinking shape),
    // clearing once the pill settles back into a non-surface mode.
    onSurfaceChanged: if (surface !== "") displayedSurface = surface

    QtObject {
        id: clock
        readonly property var loc: Qt.locale("en_US")
        readonly property var now: sysClock.date
        readonly property string hhmm: Qt.formatTime(now, "HH:mm")
        readonly property string date: loc.toString(now, "ddd d MMM")
        readonly property string hh: Qt.formatTime(now, "HH")
        readonly property string mm: Qt.formatTime(now, "mm")
        readonly property string weekday: loc.toString(now, "ddd").toUpperCase()
        readonly property string daymon: loc.toString(now, "d MMM").toUpperCase()
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
        clipboard: () => Qt.size(clipboardW, clipboardH),
        wallpaper: () => Qt.size(wallpaperW, wallpaperH),
        media:     () => Qt.size(mediaW, mediaH),
        link:      () => Qt.size(link.desiredW, link.implicitHeight + 26 * s),
        inbox:     () => Qt.size(inboxW, inbox.implicitHeight + 26 * s),
        battery:   () => Qt.size(batteryW, battery.implicitHeight + 26 * s),
        sysinfo:   () => Qt.size(sysinfoW, sysinfo.implicitHeight + 32 * s),
        stash:     () => Qt.size(deckW, deck.implicitHeight + 28 * s),
        toolkit:   () => Qt.size(deckW, deck.implicitHeight + 28 * s),
        utilities: () => Qt.size(deckW, deck.implicitHeight + 28 * s),
        keyring:   () => Qt.size(keyringW, keyring.implicitHeight + 32 * s),
        voice:     () => Qt.size(voiceW, voice.implicitHeight + 26 * s),
        workspaces: () => Qt.size(workspaces.desiredW, workspaces.implicitHeight + 32 * s),
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

    onMorphClosenessChanged: if (displayedSurface !== "" && !surfaceOpen && morphCloseness > 0.95) displayedSurface = "";

    /**
     * How open the island actually is: 0 at rest, 1 at the displayed surface's
     * full size, read from the live (animating) width. Surface content opacity
     * rides this, so it grows and shrinks with the shape and cannot fade out of a
     * still-open island or linger in a closing one.
     */
    readonly property real openW: {
        if (displayedSurface === "")
            return restW;
        const f = surfaceSize[displayedSurface];
        return f ? f().width : restW;
    }
    readonly property real openH: {
        if (displayedSurface === "")
            return restH;
        const f = surfaceSize[displayedSurface];
        return f ? f().height : restH;
    }
    readonly property real openProgress: {
        const span = Math.max(1, openW - restW);
        return Math.max(0, Math.min(1, (width - restW) / span));
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
        return restClock.mapToItem(pill, restClock.width / 2, restClock.height / 2);
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
        if (soulTarget === "battery")
            return batteryIcon.mapToItem(pill, batteryIcon.width / 2, batteryIcon.height + drop * 0.55);
        if (soulTarget === "inbox")
            return inboxIcon.mapToItem(pill, inboxIcon.width / 2, inboxIcon.height + drop * 0.55);
        return pill.wakePoint;
    }

    /**
     * Which open surface owns Ame's anchor, in priority order. Each surface
     * exports its own `ameForm`/`amePoint`; the pill just picks one and maps it.
     * Null = nothing open, so Ame falls back to the pill's own hover/wake anchor.
     */
    readonly property var ameSurface: mediaOpen ? media
        : (clipboardOpen ? clip
        : (calendarOpen ? calendar
        : (linkOpen ? link
        : (inboxOpen ? inbox
        : (sysinfoOpen ? sysinfo
        : (stashOpen ? deck
        : (toolkitOpen ? deck
        : (utilitiesOpen ? deck
        : (voiceOpen ? voice
        : (workspacesOpen ? workspaces
        : (batteryOpen ? battery : null)))))))))))

    Ame {
        id: ame
        anchors.fill: parent
        s: pill.s
        heat: 0
        wake: pill.wakePoint
        wickDir: -1
        // bead removed: never renders. the anchor machinery (ameSurface/soulPoint)
        // is left dormant to avoid destabilizing the untested hover/morph wiring.
        form: "off"
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
            // Hold the latch while the pill is mid-morph, or while a bud is hovered
            // (freezing its size) so the bud never slides out from under the cursor.
            if (pill.satelliteHover || pill.morphCloseness < 0.95) {
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

    // Passive hover over the whole island body. Being a handler on the pill (an
    // ancestor of the surfaces and tray icons) it never blocks their own hover,
    // unlike a covering sibling would.
    HoverHandler { id: bodyHover }

    Item {
        id: rest
        anchors.fill: parent
        opacity: (pill.expanded || pill.mode === "toast" || pill.mode === "osd") ? 0 : Math.pow(pill.morphCloseness, 1.5)
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: pill.mode === "rest" ? Motion.fast : 260 } }

        Column {
            anchors.centerIn: parent
            spacing: 2 * pill.s

            // Clock + date: tabular HH:MM with a vermilion colon beside a stacked
            // mono weekday/date, the dossier masthead idiom.
            Row {
                id: restRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9 * pill.s

                Row {
                    id: restClock
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: clock.hh
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 14 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ":"
                        color: Theme.brand
                        font.family: Theme.font
                        font.pixelSize: 14 * pill.s
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: clock.mm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 14 * pill.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * pill.s

                    Text {
                        text: clock.weekday
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 6 * pill.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.3 * pill.s
                        font.capitalization: Font.AllUppercase
                    }
                    Text {
                        text: clock.daymon
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 6 * pill.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.3 * pill.s
                        font.capitalization: Font.AllUppercase
                    }
                }
            }

            WorkspaceWave {
                anchors.horizontalCenter: parent.horizontalCenter
                screenName: pill.screenName
                s: pill.s
                // the auto-hidden pill stays in the scene at opacity 0; gate the
                // wave on it so a hidden pill triggers no repaints.
                live: pill.opacity > 0.01
            }
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

        // Corner registration ticks: frame the readout like a foundry specimen.
        Repeater {
            model: 4
            Item {
                id: tick
                required property int index
                readonly property bool onLeft: index % 2 === 0
                readonly property bool onTop: index < 2
                readonly property real len: 9 * pill.s
                width: len
                height: len
                anchors.left: onLeft ? parent.left : undefined
                anchors.right: onLeft ? undefined : parent.right
                anchors.top: onTop ? parent.top : undefined
                anchors.bottom: onTop ? undefined : parent.bottom
                anchors.margins: 11 * pill.s

                Rectangle {
                    width: tick.len
                    height: 1.5 * pill.s
                    color: Qt.alpha(Theme.cream, 0.22)
                    anchors.top: tick.onTop ? parent.top : undefined
                    anchors.bottom: tick.onTop ? undefined : parent.bottom
                    anchors.left: tick.onLeft ? parent.left : undefined
                    anchors.right: tick.onLeft ? undefined : parent.right
                }
                Rectangle {
                    width: 1.5 * pill.s
                    height: tick.len
                    color: Qt.alpha(Theme.cream, 0.22)
                    anchors.top: tick.onTop ? parent.top : undefined
                    anchors.bottom: tick.onTop ? undefined : parent.bottom
                    anchors.left: tick.onLeft ? parent.left : undefined
                    anchors.right: tick.onLeft ? undefined : parent.right
                }
            }
        }

        Row {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 14 * pill.s

            // 力 stamp: the foundry seal.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 28 * pill.s
                height: 28 * pill.s
                radius: 6 * pill.s
                color: Qt.alpha(Theme.brand, 0.10)
                border.width: 1
                border.color: Qt.alpha(Theme.brand, 0.6)
                Text {
                    anchors.centerIn: parent
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 15 * pill.s
                }
            }

            // Clock: tabular time over a mono date/weather micro-line.
            Item {
                id: clockHero
                anchors.verticalCenter: parent.verticalCenter
                width: clockCol.implicitWidth
                height: clockCol.implicitHeight

                Column {
                    id: clockCol
                    spacing: 3 * pill.s

                    Text {
                        text: clock.hhmm
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 20 * pill.s
                        font.weight: Font.Bold
                        font.letterSpacing: -0.5 * pill.s
                        font.features: { "tnum": 1 }
                    }
                    Row {
                        spacing: 6 * pill.s
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: clock.date
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8 * pill.s
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1.6 * pill.s
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Weather.available
                            width: 1
                            height: 8 * pill.s
                            color: Theme.hair
                        }
                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Weather.available
                            width: 10 * pill.s
                            height: 10 * pill.s
                            name: Weather.glyph
                            color: Theme.faint
                            stroke: 1.6
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Weather.available
                            text: Weather.temp
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 8.5 * pill.s
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 * pill.s
                    enabled: hover.live
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.requestSurface("calendar")
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: leftZone.has
                width: 1
                height: 24 * pill.s
                color: Theme.hair
            }

            // Running apps + minimized windows.
            Row {
                id: leftZone
                anchors.verticalCenter: parent.verticalCenter
                spacing: 11 * pill.s
                readonly property bool has: appDock.count > 0 || minimized.count > 0
                visible: has

                AppDock {
                    id: appDock
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    screenName: pill.screenName
                    live: hover.live
                    visible: count > 0
                }
                MinimizedTray {
                    id: minimized
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    screenName: pill.screenName
                    enabled: hover.live
                    visible: count > 0
                    opacity: 0.7
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 24 * pill.s
                color: Theme.hair
            }

            // Status: tray · dnd · network · battery · notifications.
            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 13 * pill.s

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                    s: pill.s
                    barWindow: pill.barWindow
                    enabled: hover.live
                }

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.dnd
                    width: 16 * pill.s
                    height: 16 * pill.s
                    name: "dnd"
                    color: Theme.vermLit
                    stroke: 1.6
                }

                // Battery: cell + percentage.
                Item {
                    id: batteryIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Battery.present
                    width: battRow.implicitWidth
                    height: 17 * pill.s

                    Row {
                        id: battRow
                        anchors.centerIn: parent
                        spacing: 6 * pill.s
                        BatteryGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            s: pill.s
                            frac: Battery.frac
                            charging: Battery.charging
                            low: Battery.low
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Battery.pct + "%"
                            color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                            font.family: Theme.font
                            font.pixelSize: 12 * pill.s
                            font.weight: Battery.charging ? Font.DemiBold : Font.Medium
                            font.features: { "tnum": 1 }
                        }
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

                // Notifications.
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
                        onClicked: pill.requestSurface("inbox")
                        onContainsMouseChanged: if (containsMouse) pill.soulTarget = "inbox"
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
        shown: pill.displayedSurface === "calendar"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
    }

    Clipboard {
        id: clip
        s: pill.s
        open: pill.clipboardOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "clipboard"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    Wallpaper {
        id: wall
        s: pill.s
        open: pill.wallpaperOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "wallpaper"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    Media {
        id: media
        s: pill.s
        open: pill.mediaOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "media"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    Link {
        id: link
        s: pill.s
        open: pill.linkOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "link"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    Inbox {
        id: inbox
        s: pill.s
        open: pill.inboxOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "inbox"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    BatterySurface {
        id: battery
        s: pill.s
        open: pill.batteryOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "battery"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    SysInfoSurface {
        id: sysinfo
        s: pill.s
        open: pill.sysinfoOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "sysinfo"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    DeckSurface {
        id: deck
        s: pill.s
        open: pill.stashOpen || pill.toolkitOpen || pill.utilitiesOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "stash" || pill.displayedSurface === "toolkit" || pill.displayedSurface === "utilities"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    WorkspacesSurface {
        id: workspaces
        s: pill.s
        screenName: pill.screenName
        open: pill.workspacesOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "workspaces"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    VoiceSurface {
        id: voice
        s: pill.s
        open: pill.voiceOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "voice"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
        onRequestClose: pill.requestClose()
    }

    KeyringSurface {
        id: keyring
        s: pill.s
        open: pill.keyringOpen
        morphCloseness: pill.morphCloseness
        shown: pill.displayedSurface === "keyring"
        openProgress: pill.openProgress
        openW: pill.openW
        openH: pill.openH
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
                onOpenCenter: pill.requestSurface("inbox")
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
