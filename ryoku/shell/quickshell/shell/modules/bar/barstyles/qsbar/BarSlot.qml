// ─────────────────────────────────────────────────────────────────────────────
// BarSlot — slot-based bar (WIP port). Step 3: full static layout, all 15 groups
// in 3 regions on one continuous section-pill (matches the default no-split look).
// Real widgets via a component registry. Splits + unlock/drag + slot-aware panel
// bindings come next. Runs as the real TOP bar (shell.qml: Bar → BarSlot).
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "modules"

PanelWindow {
    id: barSlot
    required property var root
    readonly property string screenName: barSlot.screen ? barSlot.screen.name : ""

    color: "transparent"
    // ALWAYS screen-tall → window never resizes → NO compositor resize animation.
    // Reserve 35px via exclusiveZone; the mask limits the INPUT region: only the bar
    // strip when locked (clicks below pass through), full screen when unlocked (drag).
    // anchored to left+right always; top OR bottom by barPosition (exclusiveZone
    // reserves space on whichever edge is anchored → no extra logic needed)
    anchors {
        left: true; right: true
        top:    barSlot.root.barPosition === "top"
        bottom: barSlot.root.barPosition === "bottom"
    }
    implicitHeight: barSlot.screen ? barSlot.screen.height : 1440
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 38        // 35 bar + 3px breathing room
    mask: Region {
        x: 0
        y: barSlot.root.barUnlocked ? 0
           : (barSlot.root.barPosition === "bottom" ? barSlot.height - 35 : 0)
        width: barSlot.width
        height: barSlot.root.barUnlocked ? barSlot.height : 35
    }
    // grab keyboard while unlocked so ESC can exit
    WlrLayershell.keyboardFocus: barSlot.root.barUnlocked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HoverHandler {
        onHoveredChanged: if (hovered && !barSlot.root.anyPopupVisible) barSlot.root.activatePopupScreen(barSlot.screen)
    }

    // keep Hyprland awake while the idle-inhibitor toggle is on (carried over
    // from the legacy single-bar implementation)
    IdleInhibitor { window: barSlot; enabled: barSlot.root.idleInhibited }

    // if unlock ends mid-drag (ESC / ipc lock / click backdrop), kill the drag so the
    // ghost doesn't stay frozen + the source widget doesn't stay dimmed
    Connections {
        target: barSlot.root
        function onBarUnlockedChanged() {
            if (!barSlot.root.barUnlocked && barSlot.dragging) barSlot.cancelDrag()
        }
    }

    readonly property color accent: barSlot.root.seal

    // ── dim backdrop while unlocked (edit mode); click empty → lock ──
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: barSlot.root.barUnlocked ? 0.4 : 0.0
        visible: opacity > 0.001
        z: 1
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea {
            anchors.fill: parent
            enabled: barSlot.root.barUnlocked
            onClicked: barSlot.root.barUnlocked = false
        }
    }

    // ── unlock drag&drop: ghost + state ──
    property bool dragging: false          // ghost visible (incl. snap-back phase)
    property bool dragActive: false        // mouse currently down (follow cursor)
    property Item dragItem: null           // slot content mirrored by the ghost
    property var  srcModel: null           // source region model + index
    property int  srcIndex: -1
    property var  dropModel: null          // current drop-target model + index
    property int  dropIndex: -1
    property real ghostW: 0
    property real ghostH: 0
    property real ghostHomeX: 0
    property real ghostHomeY: 0
    property real ghostX: 0
    property real ghostY: 0
    function beginDrag(item, hx, hy, w, h, sm, si) {
        dragItem = item; ghostW = w; ghostH = h; ghostHomeX = hx; ghostHomeY = hy
        ghostX = hx; ghostY = hy; srcModel = sm; srcIndex = si
        dropModel = null; dropIndex = -1; dragActive = true; dragging = true
    }
    // which slot (model+index) is under a window-point?
    function slotAt(wx, wy) {
        var rows = [leftRowItem, centerRowItem, rightRowItem]
        for (var r = 0; r < rows.length; r++) {
            var rep = rows[r].rep
            for (var k = 0; k < rep.count; k++) {
                var it = rep.itemAt(k)
                if (!it || !it.visible || !it.autoShown) continue
                var p = it.mapToItem(null, 0, 0)
                if (wx >= p.x && wx <= p.x + it.width && wy >= p.y && wy <= p.y + it.height)
                    return { model: rows[r].rmodel, index: k }
            }
        }
        return null
    }
    function moveDrag(wx, wy) {
        ghostX = wx - ghostW / 2; ghostY = wy - ghostH / 2
        var hit = slotAt(wx, wy)
        dropModel = hit ? hit.model : null
        dropIndex = hit ? hit.index : -1
    }
    function endDrag() {
        dragActive = false
        var swapped = false
        if (dropModel && dropIndex >= 0 && !(dropModel === srcModel && dropIndex === srcIndex)) {
            var sg = srcModel.get(srcIndex).gid, tg = dropModel.get(dropIndex).gid
            srcModel.setProperty(srcIndex, "gid", tg)
            dropModel.setProperty(dropIndex, "gid", sg)
            swapped = true
        }
        dropModel = null; dropIndex = -1
        if (swapped) { if (_orderLoaded) saveOrder(); dragging = false }   // content swapped in place + persist
        else { ghostX = ghostHomeX; ghostY = ghostHomeY; snapTimer.restart() }   // snap back
    }
    Timer { id: snapTimer; interval: 240; onTriggered: barSlot.dragging = false }
    // abort a drag with no swap (ESC / ipc lock / backdrop-click while dragging, or a
    // compositor grab-cancel) → clear the ghost immediately so it can't freeze on screen
    function cancelDrag() {
        snapTimer.stop()
        dragActive = false; dragging = false; dragItem = null
        dropModel = null; dropIndex = -1
    }

    // ── order persistence (survives restart) ──
    readonly property string orderCachePath: Quickshell.env("HOME") + "/.cache/quickshell_barorder"
    property bool _orderLoaded: false
    function gidsOf(m) { var a = []; for (var i = 0; i < m.count; i++) a.push(m.get(i).gid); return a }
    function serializeOrder() {
        return gidsOf(leftModel).join(",") + "|" + gidsOf(centerModel).join(",") + "|" + gidsOf(rightModel).join(",")
    }
    function applyTo(m, gids) {
        if (gids.length !== m.count) return                       // stale cache → keep default
        for (var i = 0; i < m.count; i++) if (registry[gids[i]]) m.setProperty(i, "gid", gids[i])
    }
    function applyOrder(str) {
        var parts = str.split("|")
        if (parts.length !== 3) return
        var l = parts[0].split(","), c = parts[1].split(","), r = parts[2].split(",")
        // F12: only apply a cache that is a valid permutation of all registry ids (correct region
        // sizes, every id known, no duplicate, none missing) — a corrupt cache would otherwise
        // duplicate one widget and silently drop another. On reject, keep the default order.
        if (l.length !== leftModel.count || c.length !== centerModel.count || r.length !== rightModel.count) return
        var all = l.concat(c, r), seen = {}
        for (var i = 0; i < all.length; i++) {
            if (!registry[all[i]] || seen[all[i]]) return
            seen[all[i]] = true
        }
        if (Object.keys(seen).length !== Object.keys(registry).length) return
        applyTo(leftModel,   l)
        applyTo(centerModel, c)
        applyTo(rightModel,  r)
    }
    function saveOrder() {
        var serialized = serializeOrder()
        orderSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + orderCachePath + "')\" && printf '%s' '" + serialized + "' > '" + orderCachePath + "'"]
        orderSaveProc.running = false; orderSaveProc.running = true
        if (!barSlot.root._barLayoutSyncing) barSlot.root.syncBarOrder(barSlot.screenName, serialized)
    }
    Process { id: orderSaveProc }
    Process {
        id: orderLoadProc
        command: ["cat", barSlot.orderCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t.length > 0) barSlot.applyOrder(t)
                barSlot._orderLoaded = true
            }
        }
    }
    // reset the 3 region models back to the default group order
    function resetOrder() {
        var dL = ["G1","G2","G3","G4","G5","G6","G7"]
        var dR = ["G9","G10","G11","G14","G12","G13","G15"]
        for (var i = 0; i < dL.length; i++) leftModel.setProperty(i, "gid", dL[i])
        centerModel.setProperty(0, "gid", "G8")
        for (var j = 0; j < dR.length; j++) rightModel.setProperty(j, "gid", dR[j])
        if (_orderLoaded) saveOrder()
    }

    property var layoutController: ({
        ready: function () {
            return barSlot._orderLoaded
                && island._splitsLoaded
                && barSlot.backingWindowVisible
        },
        splitAll: function () {
            island.leftSplits     = [true, true, true, true, true, true]
            island.rightSplits    = [true, true, true, true, true, true]
            island.boundarySplits = [true, true]
        },
        mergeAll: function () {
            island.leftSplits     = [false, false, false, false, false, false]
            island.rightSplits    = [false, false, false, false, false, false]
            island.boundarySplits = [false, false]
            barSlot.root.barAnim  = 0
        },
        defaultLayout: function () {
            barSlot.layoutController.mergeAll()
            barSlot.resetOrder()
        },
        applySplits: function (serialized) { island.applySplits(serialized) },
        applyOrder: function (serialized) { barSlot.applyOrder(serialized) }
    })

    Component.onCompleted: {
        if (!barSlot.root.activePopupScreenName) barSlot.root.activatePopupScreen(barSlot.screen)
        barSlot.root.registerBarLayoutController(barSlot.screenName, barSlot.layoutController)
    }

    Component.onDestruction: {
        if (barSlot.root
                && barSlot.root.isActivePopupScreenName(barSlot.screenName)
                && barSlot.root.anyPopupVisible) {
            barSlot.root.closePopups()
        }
        barSlot.root.unregisterBarLayoutController(barSlot.screenName, barSlot.layoutController)
    }

    ShaderEffectSource {
        id: ghost
        sourceItem: barSlot.dragItem
        width: barSlot.ghostW; height: barSlot.ghostH
        x: barSlot.ghostX; y: barSlot.ghostY
        visible: barSlot.dragging
        z: 100
        // dim while dragging over empty space (no valid drop → snap-back)
        opacity: barSlot.dragActive ? (barSlot.dropModel ? 0.95 : 0.45) : 0.92
        scale: barSlot.dragActive ? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on x { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 120 } }
    }

    // ─────────────────────────── group registry ───────────────────────────
    Component { id: compLauncher;  LauncherWidget  { root: barSlot.root } }
    Component { id: compWorkspace; WorkspaceWidget { root: barSlot.root } }
    Component {
        id: compStatus                                   // G3: arch · tray · notif
        Item {
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modStatus ? Math.round(statusRow.implicitWidth) + 10 : 0
            implicitHeight: 28
            opacity: barSlot.root.modStatus ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth; height: barSlot.root.pillH; radius: barSlot.root.pillRadius
                color: barSlot.root.pill; border.color: barSlot.root.pillBorder; border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
            }
            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: 4
                ArchUpdaterWidget  { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    TrayWidget         { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                    NotificationWidget { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Component { id: compMem;    MemoryWidget { root: barSlot.root } }
    Component { id: compCpu;    CpuWidget    { root: barSlot.root } }
    Component { id: compVol;    AudioWidget  { root: barSlot.root } }
    Component { id: compClaude; ClaudeWidget { root: barSlot.root } }
    Component {
        id: compShellFallbackUpdater
        Item {
            width: 26
            height: 28
            ArchUpdaterWidget {
                root: barSlot.root
                preferShell: true
                anchors.centerIn: parent
            }
        }
    }

    Component {
        id: compCenter                                   // G8: weather·clock·date·indicators
        Item {
            id: g8
            implicitWidth: Math.round(centerRow.implicitWidth) + 18
            implicitHeight: 28

            // ── responsive stage (narrow-monitor overlap fix) ──
            // Presentation-only inside G8 — never touches root.mod* user toggles.
            // Mutable state with hysteresis, NOT a computed property: downshift when
            // the CURRENT stage no longer fits (24px slack), upshift only when the
            // LARGER stage would fit with 48px slack — measured against that stage's
            // own needed width, else minimal⇄compact oscillates.
            property int stage: 0                        // 0 normal · 1 compact · 2 minimal
            readonly property bool showWeather: stage <= 1
            readonly property bool showDate:    stage === 0
            readonly property bool showIcons:   iconsRow.hasActive
            // needed widths per stage: reactive bindings over the UNCOLLAPSED content
            // (the stage-gated wrapper widths shrink and would mislead the upshift
            // decision). 18 = pill padding, 8 = row spacing per visible neighbour.
            readonly property real needMinimal: 18 + clock.implicitWidth
                + (showIcons && iconsRow.implicitWidth > 0.5 ? 8 + iconsRow.implicitWidth : 0)
            readonly property real needCompact: needMinimal
                + (weather.implicitWidth > 0.5 ? 8 + weather.implicitWidth : 0)
            readonly property real needNormal: needCompact
                + (dateLabel.implicitWidth > 0.5 ? 8 + dateLabel.implicitWidth : 0)
            function updateStage() {
                // compact only while G8 actually occupies the center slot: after a
                // drag swap G8 can sit in a SIDE row — its own width then feeds the
                // very side-row width that centerAvail is measured from, and the
                // stage delta (~weather+date) exceeds the 24/48px hysteresis window
                // → boundary-width flutter. As a side widget G8 stays at normal.
                if (centerModel.count < 1 || centerModel.get(0).gid !== "G8") {
                    if (stage !== 0) stage = 0
                    return
                }
                var avail = island.centerAvail
                var s = stage
                if (s === 0 && needNormal  + 24 > avail) s = 1
                if (s === 1 && needCompact + 24 > avail) s = 2
                if (s === 2 && needCompact + 48 <= avail) s = 1
                if (s === 1 && needNormal  + 48 <= avail) s = 0
                if (s !== stage) stage = s
            }
            // publish the clock + status-icon floor width for the side-row budget
            Binding { target: island; property: "g8FloorWidth"; value: g8.needMinimal }
            // 80ms one-shot coalesces width flutter (track changes, tray churn)
            Timer { id: restageTimer; interval: 80; repeat: false; onTriggered: g8.updateStage() }
            onNeedNormalChanged:  restageTimer.restart()
            onNeedCompactChanged: restageTimer.restart()
            Connections { target: island; function onCenterAvailChanged() { restageTimer.restart() } }
            Component.onCompleted: restageTimer.restart()

            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth; height: barSlot.root.pillH; radius: barSlot.root.pillRadius
                color: barSlot.root.pill; border.color: barSlot.root.pillBorder; border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
            }
            Row {
                id: centerRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)   // integer center → sharp text
                spacing: 8
                Item {                                   // weather wrapper (stage-gated)
                    visible: width > 0.5
                    width: g8.showWeather ? weather.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showWeather ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    WeatherWidget {
                        id: weather
                        anchors.fill: parent
                        root: barSlot.root
                    }
                }
                ClockWidget   { id: clock;   root: barSlot.root }
                Item {                                   // date (stage-gated)
                    visible: width > 0.5
                    width: g8.showDate ? dateLabel.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showDate ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    UiText {
                        id: dateLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            clock.now;
                            var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                            var d = new Date();
                            return days[d.getDay()] + " " + d.getDate();
                        }
                        color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.5)
                        font.family: barSlot.root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barSlot.root.activatePopupScreen(barSlot.screen)
                            barSlot.root.calendarTick++;
                            barSlot.root.calendarVisible = !barSlot.root.calendarVisible
                        }
                    }
                }
                Item {                                   // indicator icons wrapper (stage-gated)
                    visible: g8.showIcons || width > 0.5
                    width: g8.showIcons ? iconsRow.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showIcons ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Row {
                        id: iconsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        readonly property bool shellFallbackActive: !barSlot.root.modStatus
                            && (barSlot.root.shellUpdateBehind > 0 || barSlot.root.shellUpdateProgressVisible)
                        readonly property bool hasActive: idleInd.awake
                            || dndInd.silenced
                            || screenRecInd.recording
                            || voxInd.state === "recording"
                            || voxInd.state === "transcribing"
                            || omarchyUpdateInd.updateAvailable
                            || shellFallbackActive
                        IdleWidget               { id: idleInd;          root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        NotificationSilenceWidget{ id: dndInd;           root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        ScreenRecordWidget       { id: screenRecInd;     root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        VoxtypeWidget            { id: voxInd;           root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        UpdateWidget             { id: omarchyUpdateInd; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        Loader {
                            visible: iconsRow.shellFallbackActive || width > 0.5
                            active: iconsRow.shellFallbackActive
                            width: iconsRow.shellFallbackActive ? 26 : 0
                            height: 28
                            sourceComponent: compShellFallbackUpdater
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }

    Component { id: compMpris; MprisWidget { root: barSlot.root } }
    Component {
        id: compQuick                                    // G10: idle-inhib · media · theme
        Item {
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modQuick ? Math.round(qcRow.implicitWidth) + 16 : 0
            implicitHeight: 28
            opacity: barSlot.root.modQuick ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth; height: barSlot.root.pillH; radius: barSlot.root.pillRadius
                color: barSlot.root.pill; border.color: barSlot.root.pillBorder; border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
            }
            Row {
                id: qcRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: 4
                IdleInhibitorWidget { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                MediaBrowserWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
                ThemeDisplayWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Component { id: compNetwork;    NetworkWidget      { root: barSlot.root } }
    Component { id: compPower;      PowerProfileWidget { root: barSlot.root } }
    Component { id: compBattery;    BatteryWidget      { root: barSlot.root } }
    Component { id: compBrightness; BrightnessWidget   { root: barSlot.root } }
    Component { id: compBluetooth;  BluetoothWidget    { root: barSlot.root } }

    readonly property var registry: ({
        "G1": compLauncher, "G2": compWorkspace, "G3": compStatus,
        "G4": compMem, "G5": compCpu, "G6": compVol, "G7": compClaude,
        "G8": compCenter,
        "G9": compMpris, "G10": compQuick, "G11": compNetwork,
        "G12": compBattery, "G13": compBrightness, "G14": compPower, "G15": compBluetooth
    })

    // ───────────────────── reusable region row of slots ─────────────────────
    component SlotRow: Row {
        property var rmodel
        property var splitsArr          // per-gap split flags (split AFTER slot i)
        property var toggleGap          // function(i): toggle the split after slot i
        property alias rep: repeater
        spacing: 6
        height: 32
        // index of the LAST currently shown slot (skips disabled and auto-hidden
        // narrow-stage widgets) —
        // a split/grow only makes sense BEFORE this (else it opens a gap to nowhere)
        readonly property int lastVisibleIndex: {
            void(width)
            var last = -1
            for (var k = 0; k < repeater.count; k++) {
                var it = repeater.itemAt(k)
                if (it && it.hasContent && it.autoShown) last = k
            }
            return last
        }
        Repeater {
            id: repeater
            model: rmodel
            delegate: Item {
                id: slot
                required property string gid
                required property int index
                // workspace draws a pill 4px wider than its implicitWidth on each
                // side; pad its slot symmetrically so inter-group gaps stay uniform.
                readonly property int pad: slot.gid === "G2" ? barSlot.root.wsPillPad : 0
                readonly property bool hasContent: Math.round(ldr.implicitWidth) > 0.5
                readonly property bool hasGapAfter: splitsArr ? (index < splitsArr.length) : false
                // split AFTER this slot → grow it so the group separates (gap opens).
                // ONLY for widgets with content — a 0-width widget (battery/brightness on
                // a desktop) must NOT grow, else it shows up as an empty pill.
                readonly property bool splitAfter: autoShown && hasGapAfter && splitsArr[index]
                readonly property real grow: (splitAfter && hasContent && index < lastVisibleIndex) ? 16 : 0
                readonly property real cr: pad + Math.round(ldr.implicitWidth)
                // display width: follows the stage (grow via splitAfter is
                // autoShown-aware so hidden slots also drop their split growth)
                readonly property real naturalSlotWidth: Math.round(ldr.implicitWidth) + 2 * pad + grow
                // budget width: the ONLY width the narrow-stage decision may read.
                // MUST stay stage-independent (no autoShown/lastVisibleIndex terms,
                // which flip with the stage): a stage-dependent budget feeds back
                // into its own decision and oscillates once ≥2 split-grows (2×16px)
                // exceed the 24px hysteresis window. Conservative: counts the split
                // grow even for hidden/trailing slots (≤16px overestimate, fail-safe).
                readonly property real budgetSlotWidth: Math.round(ldr.implicitWidth) + 2 * pad
                    + ((hasGapAfter && splitsArr[index] && hasContent) ? 16 : 0)
                readonly property bool autoShown: island.groupVisibleAtStage(slot.gid, island.narrowStage)
                onBudgetSlotWidthChanged: island.scheduleNarrowUpdate()
                width: autoShown ? naturalSlotWidth : 0
                height: 32
                visible: hasContent && (autoShown || width > 0.5)   // stays visible while collapsing
                opacity: autoShown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Loader {
                    id: ldr
                    x: slot.pad
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: barSlot.registry[slot.gid]
                    // dim the original while its ghost is being dragged
                    opacity: (barSlot.dragItem === ldr && barSlot.dragActive) ? 0.25 : 1.0
                }
                // ── drag-catcher: only in unlock mode, overlays the widget ──
                MouseArea {
                    anchors.fill: parent
                    enabled: barSlot.root.barUnlocked && slot.autoShown
                    visible: barSlot.root.barUnlocked && slot.autoShown
                    z: 25
                    preventStealing: true
                    cursorShape: Qt.OpenHandCursor
                    onPressed: {
                        var p = ldr.mapToItem(null, 0, 0)
                        barSlot.beginDrag(ldr, p.x, p.y, Math.round(ldr.implicitWidth), slot.height, rmodel, slot.index)
                    }
                    onPositionChanged: (e) => {
                        if (!barSlot.dragging) return
                        var w = mapToItem(null, e.x, e.y)
                        barSlot.moveDrag(w.x, w.y)
                    }
                    onReleased: barSlot.endDrag()
                    onCanceled: barSlot.cancelDrag()
                }
                // drop-target highlight (the group under the cursor, not the source)
                Rectangle {
                    anchors.fill: parent
                    radius: barSlot.root.pillRadius
                    color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.18)
                    border.color: barSlot.accent
                    border.width: 2
                    z: 26
                    visible: barSlot.dragging
                        && barSlot.dropModel === rmodel && barSlot.dropIndex === slot.index
                        && !(barSlot.srcModel === rmodel && barSlot.srcIndex === slot.index)
                }
                // ── split toggle for the gap AFTER this slot (child of slot → tracks it) ──
                Item {
                    visible: slot.autoShown && slot.hasGapAfter && slot.index < lastVisibleIndex
                    width: 14
                    height: slot.height
                    x: (slot.cr + slot.pad + slot.width + 6) / 2 - width / 2   // centered in the gap (cr+pad = pill-right, matches gapInterval)
                    z: 30
                    Text {
                        anchors.centerIn: parent
                        text: slot.splitAfter ? "│" : "•"     // │ when split, • else
                        color: slot.splitAfter ? barSlot.root.seal : barSlot.root.sumi
                        font.pixelSize: 10; font.family: barSlot.root.mono
                        opacity: mkMa.containsMouse ? 0.9 : 0.0          // hover-revealed
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: mkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (toggleGap) toggleGap(slot.index)
                    }
                }
            }
        }
    }

    Item {
        id: island
        // vertical placement via y (NOT conditional top/bottom anchors): toggling
        // anchors live left a stale edge set → island stretched top+bottom → widgets
        // spread to mid-screen. A plain y switches cleanly on a live position change.
        anchors {
            left: parent.left; leftMargin: 5
            right: parent.right; rightMargin: 5
        }
        height: 32
        y: barSlot.root.barPosition === "bottom" ? (parent.height - height - 3) : 3
        z: 2                                  // above the dim backdrop
        focus: barSlot.root.barUnlocked       // receive keys while unlocked
        Keys.onEscapePressed: barSlot.root.barUnlocked = false

        // edit-mode frame around the bar while unlocked (gentle pulse)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: barSlot.root.islandRadius + 2
            color: "transparent"
            border.color: barSlot.accent
            border.width: barSlot.root.barUnlocked ? 1 : 0    // width 0 hides it when locked
            z: 40
            SequentialAnimation on opacity {
                running: barSlot.root.barUnlocked
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.45; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        // DOUBLE-click EMPTY bar area → unlock (sits below widgets/markers).
        // double-click so a stray single click while aiming for Control/Volume can't
        // accidentally trigger unlock. (lock again via dim backdrop click / ESC.)
        MouseArea {
            anchors.fill: parent
            z: -1
            onDoubleClicked: barSlot.root.barUnlocked = true
        }

        // ── split state (positional, per within-region gap) ──
        property var leftSplits:  [false, false, false, false, false, false]   // gaps in leftModel
        property var rightSplits: [false, false, false, false, false, false]   // gaps in rightModel
        property var boundarySplits: [true, true]   // [left↔center, center↔right] — split by default so the animated gap shows

        readonly property real lcBoundaryX: leftRowItem.x + leftRowItem.width + 9    // just right of Claude
        readonly property real crBoundaryX: rightRowItem.x - 9                       // just left of Mpris

        // ── G8 collision handling (narrow-monitor overlap fix) ──
        // free span between the side rows; the only stage-decision input — reads
        // ONLY left/right geometry (never the center row), so stage changes that
        // resize G8 cannot feed back into this value (no binding loop).
        readonly property int centerGap: 12
        readonly property int rowMargin: 4    // single source for the side-row edge margins + budget math
        readonly property real centerAvail: rightRowItem.x - (leftRowItem.x + leftRowItem.width) - 2 * centerGap
        // centered while space allows; clamped between the rows when squeezed.
        // If even the current G8 width cannot fit (max < min), fall back to the
        // screen-clamped ideal — the documented extreme case may overlap.
        readonly property real idealCenterX: Math.round((width - centerRowItem.width) / 2)
        readonly property real minCenterX: Math.round(leftRowItem.x + leftRowItem.width + centerGap)
        readonly property real maxCenterX: Math.round(rightRowItem.x - centerGap - centerRowItem.width)
        readonly property real centerTargetX: maxCenterX < minCenterX
            ? Math.max(4, Math.min(idealCenterX, width - centerRowItem.width - 4))
            : Math.max(minCenterX, Math.min(idealCenterX, maxCenterX))

        // ── side-row auto-compact (portrait/narrow) ──
        // Presentation-only stages that hide low-priority side groups when the bar
        // would otherwise overflow. Never touches root.mod* toggles, models, order
        // or split persistence. Budgets are summed from stage-independent budgetSlotWidth
        // values — never from the collapsed row widths — so hiding a group cannot
        // feed back into its own decision (same anti-flutter rule as the G8 stage).
        property int narrowStage: 0            // 0 normal · 1 compact · 2 portrait · 3 emergency
        property real g8FloorWidth: 80         // published by G8: its clock-only minimal width
        function groupVisibleAtStage(gid, stage) {
            if (gid === "G8") return true                                        // clock has its own stages
            if (stage <= 0) return true
            if (stage === 1) return ["G7", "G9", "G10"].indexOf(gid) < 0         // drop AI · MPRIS · Quick
            if (stage === 2) return ["G4", "G5", "G7", "G9", "G10"].indexOf(gid) < 0   // also MEM · CPU
            return ["G1", "G2", "G6", "G8", "G11", "G14"].indexOf(gid) >= 0      // emergency whitelist
        }
        function sideNaturalWidth(row, stage) {
            var sum = 0, n = 0
            for (var k = 0; k < row.rep.count; k++) {
                var it = row.rep.itemAt(k)
                if (!it || !it.hasContent) continue
                if (!groupVisibleAtStage(it.gid, stage)) continue
                sum += it.budgetSlotWidth; n++
            }
            return sum + Math.max(0, n - 1) * row.spacing
        }
        function narrowCandidateWidth(stage) {
            // side rows + G8 floor + row margins + both center gaps
            return sideNaturalWidth(leftRowItem, stage) + sideNaturalWidth(rightRowItem, stage)
                 + g8FloorWidth + 2 * centerGap + 2 * rowMargin
        }
        function updateNarrowStage() {
            var s = narrowStage, W = island.width
            if (W < 1) return                              // no layout yet
            // downshift while the CURRENT stage no longer fits (24px slack)…
            if (s === 0 && narrowCandidateWidth(0) + 24 > W) s = 1
            if (s === 1 && narrowCandidateWidth(1) + 24 > W) s = 2
            if (s === 2 && narrowCandidateWidth(2) + 24 > W) s = 3
            // …upshift only when the NEXT-LARGER stage fits with 48px slack,
            // measured against that stage's own candidate width.
            if (s === 3 && narrowCandidateWidth(2) + 48 <= W) s = 2
            if (s === 2 && narrowCandidateWidth(1) + 48 <= W) s = 1
            if (s === 1 && narrowCandidateWidth(0) + 48 <= W) s = 0
            if (s !== narrowStage) narrowStage = s
        }
        function scheduleNarrowUpdate() { narrowTimer.restart() }
        Timer { id: narrowTimer; interval: 80; repeat: false; onTriggered: island.updateNarrowStage() }
        onWidthChanged: scheduleNarrowUpdate()
        onG8FloorWidthChanged: scheduleNarrowUpdate()

        // ── split persistence (survives restart) ──
        readonly property string splitCachePath: Quickshell.env("HOME") + "/.cache/quickshell_barsplits"
        property bool _splitsLoaded: false
        function _b2s(a) { return a.map(function (b) { return b ? "1" : "0" }).join("") }
        function _s2b(s, n) { var a = []; for (var i = 0; i < n; i++) a.push(s.charAt(i) === "1"); return a }
        function serializeSplits() { return _b2s(leftSplits) + "|" + _b2s(rightSplits) + "|" + _b2s(boundarySplits) }
        function applySplits(str) {
            var p = str.split("|")
            if (p.length !== 3) return
            if (p[0].length === leftSplits.length)     leftSplits     = _s2b(p[0], leftSplits.length)
            if (p[1].length === rightSplits.length)    rightSplits    = _s2b(p[1], rightSplits.length)
            if (p[2].length === boundarySplits.length) boundarySplits = _s2b(p[2], boundarySplits.length)
        }
        function saveSplits() {
            var serialized = serializeSplits()
            splitSaveProc.command = ["bash", "-c",
                "mkdir -p \"$(dirname '" + splitCachePath + "')\" && printf '%s' '" + serialized + "' > '" + splitCachePath + "'"]
            splitSaveProc.running = false; splitSaveProc.running = true
            if (!barSlot.root._barLayoutSyncing) barSlot.root.syncBarSplits(barSlot.screenName, serialized)
        }
        onLeftSplitsChanged:     if (_splitsLoaded) saveSplits()
        onRightSplitsChanged:    if (_splitsLoaded) saveSplits()
        onBoundarySplitsChanged: if (_splitsLoaded) saveSplits()
        Process { id: splitSaveProc }
        Process {
            id: splitLoadProc
            command: ["cat", island.splitCachePath]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    var t = this.text.trim()
                    if (t.length > 0) island.applySplits(t)
                    island._splitsLoaded = true
                }
            }
        }

        // island-X of the gap between slot i and i+1 of a region's repeater
        // uncovered interval [from,to] for a within-region split: 4px after the
        // content-right of slot i, 4px before the next VISIBLE slot's content-left.
        function gapInterval(rep, i) {
            var a = rep.itemAt(i)
            if (!a || !a.hasContent || !a.autoShown) return null
            var b = null                                   // next VISIBLE slot (skip 0-width)
            for (var k = i + 1; k < rep.count; k++) { var it = rep.itemAt(k); if (it && it.hasContent && it.autoShown) { b = it; break } }
            if (!b) return null
            // a.width - a.grow = slot's pill-right edge (handles workspace ±4 overflow);
            // 0 = next slot's pill-left edge. 4px padding on each side.
            var aR = a.mapToItem(island, a.width - a.grow, 0).x + 4
            var bL = b.mapToItem(island, 0, 0).x - 4
            return (bL > aR) ? [aR, bL] : null
        }
        // run rectangles (island coords): pill breaks at each active split, small gap
        function computeRuns() {
            // each split = an uncovered interval [from, to]; runs = covered gaps between.
            var cuts = []
            // within-region: a small 12px gap around the break
            for (var i = 0; i < leftSplits.length; i++)
                if (leftSplits[i])  { var ci = gapInterval(leftRowItem.rep, i);  if (ci) cuts.push(ci) }
            for (var j = 0; j < rightSplits.length; j++)
                if (rightSplits[j]) { var cj = gapInterval(rightRowItem.rep, j); if (cj) cuts.push(cj) }
            // boundary: cut out the WHOLE empty whitespace so the pill hugs the content
            // center boundaries — if the center is empty (its widget disabled) AND both
            // sides are split, merge into ONE cut so no thin center pill is left over
            // right edge for boundary cuts: if the right region is empty, cut all the
            // way to the island edge so no thin pill is left at the right margin
            var rEnd = rightRowItem.width < 1 ? island.width : rightRowItem.x - 4
            if (boundarySplits[0] && boundarySplits[1] && centerRowItem.width < 1) {
                var lm = leftRowItem.x + leftRowItem.width + 4
                if (rEnd > lm) cuts.push([lm, rEnd])
            } else {
                if (boundarySplits[0]) { var l1 = leftRowItem.x + leftRowItem.width + 4, r1 = centerRowItem.x - 4; if (r1 > l1) cuts.push([l1, r1]) }
                if (boundarySplits[1]) { var l2 = centerRowItem.x + centerRowItem.width + 4; if (rEnd > l2) cuts.push([l2, rEnd]) }
            }
            cuts.sort(function (a, b) { return a[0] - b[0] })
            var runs = [], start = 0
            for (var k = 0; k < cuts.length; k++) {
                if (cuts[k][0] > start) runs.push({ x: start, w: cuts[k][0] - start })
                if (cuts[k][1] > start) start = cuts[k][1]
            }
            if (island.width > start) runs.push({ x: start, w: island.width - start })
            return runs
        }
        readonly property var runs: {
            void(leftSplits); void(rightSplits); void(boundarySplits);
            void(leftRowItem.width); void(rightRowItem.width); void(centerRowItem.width); void(island.width);
            void(centerRowItem.x);   // clamped center can move without any width change
            // (left x is anchor-constant; right x is derived from width + island.width above)
            return computeRuns()
        }

        // ── ParticleStream shim: expose the API it expects over our `runs` ──
        readonly property var pillRuns: { var a = []; for (var i = 0; i < runs.length; i++) a.push({ s: i, e: i }); return a }
        function runRightEdge(i) { return runs[i].x + runs[i].w }
        function runLeftEdge(i)  { return runs[i].x }

        // ── section pill(s): one per run (one continuous pill when no splits) ──
        Repeater {
            model: island.runs
            delegate: Rectangle {
                required property var modelData
                x: modelData.x
                width: Math.max(0, modelData.w)
                height: island.height
                radius: barSlot.root.islandRadius
                color: barSlot.root.barBg
                border.color: barSlot.root.islandBorder
                border.width: barSlot.root.pillBorderW
                PillShadow { theme: barSlot.root }
                // no Behavior: tracks the slot positions directly as the gap opens
            }
        }

        // ── gap particle animation (flows in split gaps only when enabled) ──
        Item {
            id: particleLayer
            anchors.fill: parent
            z: 1                          // above the section pills, below the widgets
            visible: barSlot.root.barAnim > 0 && island.runs.length > 1

            LazyLoader {
                active: particleLayer.visible

                ParticleStream {
                    parent: particleLayer
                    x: 0
                    y: 0
                    width: particleLayer.width
                    height: particleLayer.height
                    theme:  barSlot.root
                    layout: island
                    mode:   barSlot.root.barAnim
                    active: true
                    monitor: barSlot.screen ? barSlot.screen.name : ""
                }
            }
        }

        // ── region models (physical L→R order) ──
        ListModel {
            id: leftModel
            ListElement { gid: "G1" } ListElement { gid: "G2" } ListElement { gid: "G3" }
            ListElement { gid: "G4" } ListElement { gid: "G5" } ListElement { gid: "G6" }
            ListElement { gid: "G7" }
        }
        ListModel { id: centerModel; ListElement { gid: "G8" } }
        ListModel {
            id: rightModel
            ListElement { gid: "G9" }  ListElement { gid: "G10" } ListElement { gid: "G11" }
            ListElement { gid: "G14" } ListElement { gid: "G12" } ListElement { gid: "G13" }
            ListElement { gid: "G15" }
        }

        SlotRow {
            id: leftRowItem
            anchors { left: parent.left; leftMargin: island.rowMargin; verticalCenter: parent.verticalCenter }
            rmodel: leftModel
            splitsArr: island.leftSplits
            toggleGap: function (i) { var a = island.leftSplits.slice(); a[i] = !a[i]; island.leftSplits = a }
        }
        SlotRow {
            id: centerRowItem
            // no centerIn: x is clamped between the side rows on narrow monitors
            anchors.verticalCenter: parent.verticalCenter
            x: island.centerTargetX
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            rmodel: centerModel
        }
        SlotRow {
            id: rightRowItem
            anchors { right: parent.right; rightMargin: island.rowMargin; verticalCenter: parent.verticalCenter }
            rmodel: rightModel
            splitsArr: island.rightSplits
            toggleGap: function (i) { var a = island.rightSplits.slice(); a[i] = !a[i]; island.rightSplits = a }
        }

        // ── slot-aware panel X positions: publish per-screen anchors ──
        // find a group's slot and map its (frac·width) to window/screen X.
        function groupX(gid, frac) {
            var rows = [leftRowItem, centerRowItem, rightRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
                    if (it && it.gid === gid) {
                        return island.x + row.x + it.x + it.width * frac
                    }
                }
            }
            return 0
        }

        readonly property string panelScreenName: barSlot.screen ? barSlot.screen.name : ""
        readonly property var panelAnchors: {
            void(island.width)
            void(island.x)
            void(leftRowItem.x); void(centerRowItem.x); void(rightRowItem.x)
            void(leftRowItem.width); void(centerRowItem.width); void(rightRowItem.width)
            return {
                tray:         island.groupX("G3",  0.0),
                notif:        island.groupX("G3",  0.0),
                quickActions: island.groupX("G10", 0.5),
                volume:       island.groupX("G6",  0.5),
                network:      island.groupX("G11", 0.5),
                battery:      island.groupX("G12", 0.5),
                memory:       island.groupX("G4",  0.5),
                cpu:          island.groupX("G5",  0.5),
                ai:           island.groupX("G7",  0.5),
                workspace:    island.groupX("G2",  0.5),
                arch:         island.groupX("G3",  0.5),
                bluetooth:    island.groupX("G15", 0.5),
                brightness:   island.groupX("G13", 0.5),
                power:        island.groupX("G14", 0.5),
                mpris:        island.groupX("G9",  0.5),
                weather:      island.groupX("G8",  0.5),
                launcher:     island.groupX("G1",  0.5)
            }
        }
        onPanelAnchorsChanged: barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)
        Component.onCompleted: barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)

        // ── boundary split markers (left↔center, center↔right) ──
        // positioned via real Row geometries (no mapToItem → robust).
        component BoundaryMarker: Item {
            id: bm
            property real bx
            property bool splitOn
            property var toggleFn
            visible: bx > 0
            x: bx - width / 2
            width: 14
            height: island.height
            z: 30
            Text {
                anchors.centerIn: parent
                text: bm.splitOn ? "│" : "•"
                color: bm.splitOn ? barSlot.root.seal : barSlot.root.sumi
                font.pixelSize: 10; font.family: barSlot.root.mono
                opacity: bMa.containsMouse ? 0.9 : 0.0     // hover-revealed
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: bMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (bm.toggleFn) bm.toggleFn()
            }
        }
        BoundaryMarker {
            bx: island.lcBoundaryX
            splitOn: island.boundarySplits[0]
            toggleFn: function () { var a = island.boundarySplits.slice(); a[0] = !a[0]; island.boundarySplits = a }
        }
        BoundaryMarker {
            bx: island.crBoundaryX
            splitOn: island.boundarySplits[1]
            toggleFn: function () { var a = island.boundarySplits.slice(); a[1] = !a[1]; island.boundarySplits = a }
        }
    }
}
