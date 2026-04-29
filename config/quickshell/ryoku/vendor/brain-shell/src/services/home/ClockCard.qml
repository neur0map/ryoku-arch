import QtQuick
import Quickshell.Io
import "../../"
import "../../components"

// ClockCard — Clock / Timer / Alarm / Stopwatch

StatCard {
    id: root
    padding: 0

    // ── Mode ──────────────────────────────────────────────────────────────────
    property string _mode: "clock"

    // ── Clock ─────────────────────────────────────────────────────────────────
    property string _hm:       "00:00"
    property string _hStr:     "00"
    property string _mStr:     "00"
    property string _sec:      "00"
    property int    _currentH: 0
    property int    _currentM: 0

    // ── Timer ─────────────────────────────────────────────────────────────────
    property int  _timerTotal:   10 * 60
    property int  _timerLeft:    10 * 60
    property bool _timerRunning: false
    property bool _timerStarted:   false
    property bool _addTimerOpen: false

    // ── Stopwatch ─────────────────────────────────────────────────────────────
    property int  _swMs:      0
    property bool _swRunning: false
    property bool _swStarted:   false

    // ── Alarms ────────────────────────────────────────────────────────────────
    property var  _alarms:     []
    property int  _alarmIdSeq: 0
    property bool _addOpen:    false
    property int  _addHour:    7
    property int  _addMinute:  0

    // ── Notification ─────────────────────────────────────────────────────────
    Process {
        id: notifyProc
        command: []
        running: false
    }

    function _notify(title, body) {
        notifyProc.command = ["notify-send", "-a", "Brain Shell", "-i", "alarm", title, body]
        notifyProc.running = false
        notifyProc.running = true
    }

    // ── Master tick ───────────────────────────────────────────────────────────
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root._tick()
            if (root._swRunning) root._swMs += 1000
            if (root._timerRunning && root._timerLeft > 0) {
                root._timerLeft--
                if (root._timerLeft === 0) {
                    root._timerRunning = false
                    if (!root._timerFired) {
                        root._timerFired = true
                        root._notify("Timer finished",
                            "Your " + root._timerTotalLabel() + " timer is done.")
                    }
                }
            }
            if (root._sec === "00") root._checkAlarms()
            // Repaint ring only when on timer page and timer is running
            if (root._mode === "timer") timerCanvas.requestPaint()
            root._syncState()
        }
    }

    Component.onCompleted: { _tick(); _syncState() }

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _zp(n) { return n < 10 ? "0"+n : ""+n }

    function _tick() {
        var d = new Date()
        var h = d.getHours(), m = d.getMinutes(), s = d.getSeconds()
        _currentH = h; _currentM = m
        _hm  = _zp(h) + ":" + _zp(m) + ":" + _zp(s)
        _hStr = _zp(h)
        _mStr = _zp(m)
        _sec = _zp(s)
    }

    function _timerDisplay() {
        var h = Math.floor(_timerLeft / 3600)
        var m = Math.floor((_timerLeft % 3600) / 60)
        var s = _timerLeft % 60
        return h > 0
            ? _zp(h) + ":" + _zp(m) + ":" + _zp(s)
            : _zp(m) + ":" + _zp(s)
    }

    function _timerTotalLabel() {
        var h = Math.floor(_timerTotal / 3600)
        var m = Math.floor((_timerTotal % 3600) / 60)
        return h > 0 ? h + "h " + _zp(m) + "m" : m + "m"
    }

    function _timerProgress() {
        return _timerTotal > 0 ? (_timerTotal - _timerLeft) / _timerTotal : 0
    }

    function _swDisplay() {
        var t = Math.floor(_swMs / 1000)
        return _zp(Math.floor(t / 60)) + ":" + _zp(t % 60)
    }

    function _checkAlarms() {
        var list = _alarms.slice(), changed = false
        for (var i = 0; i < list.length; i++) {
            var a = list[i]
            if (!a.enabled) continue
            if (a.hour === _currentH && a.minute === _currentM && !a.firedToday) {
                list[i] = Object.assign({}, a, { firedToday: true })
                changed = true
                _notify("Alarm", (a.label !== "" ? a.label : "Alarm") +
                        " — " + _zp(a.hour) + ":" + _zp(a.minute))
            }
            if (a.firedToday && !(a.hour === _currentH && a.minute === _currentM)) {
                list[i] = Object.assign({}, a, { firedToday: false })
                changed = true
            }
        }
        if (changed) _alarms = list
    }

    function _addAlarm() {
        var list = _alarms.slice()
        list.push({
            id:         _alarmIdSeq++,
            hour:       _addHour,
            minute:     _addMinute,
            label:      "",
            enabled:    true,
            firedToday: false
        })
        _alarms  = list
        _addOpen = false
        _syncState()
    }

    function _toggleAlarm(id) {
        var list = _alarms.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                list[i] = Object.assign({}, list[i], { enabled: !list[i].enabled })
                break
            }
        }
        _alarms = list
        _syncState()
    }

    function _deleteAlarm(id) {
        _alarms = _alarms.filter(function(a) { return a.id !== id })
        _syncState()
    }

    function _syncState() {
        ClockState.timerRunning = _timerRunning
        ClockState.timerLeft    = _timerLeft
        ClockState.timerTotal   = _timerTotal
        ClockState.timerDisplay = _timerDisplay()
        ClockState.swRunning    = _swRunning
        ClockState.swDisplay    = _swDisplay()
        ClockState.alarms       = _alarms
        ClockState.swStarted    = _swStarted
        ClockState.timerStarted = _timerStarted

        var now = _currentH * 60 + _currentM, best = null
        for (var i = 0; i < _alarms.length; i++) {
            var a = _alarms[i]
            if (!a.enabled) continue
            var t    = a.hour * 60 + a.minute
            var diff = t >= now ? t - now : t + 1440 - now
            if (best === null || diff < best.minsUntil)
                best = { hour: a.hour, minute: a.minute, label: a.label, minsUntil: diff }
        }
        ClockState.nextAlarm = best
    }
    
    Connections {
        target: ClockState
      
        function onSwRunningChanged() {
            // Sync internal state if the singleton is changed externally (e.g., from the notch)
            if (root._swRunning !== ClockState.swRunning) {
                root._swRunning = ClockState.swRunning
            }
        }
        
        function onRequestStopwatchReset() {
            root._swMs = 0
            root._swRunning = false
            root._swStarted = false
            root._syncState()
        }
        
        function onTimerRunningChanged() {
            if (root._timerRunning !== ClockState.timerRunning) {
                root._timerRunning = ClockState.timerRunning
            }
        }
        
        function onRequestTimerReset() {
            root._timerLeft    = root._timerTotal
            root._timerRunning = false
            root._timerStarted = false
            root._syncState()
            timerCanvas.requestPaint()
        }
    }
    
    // ── UI ────────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // ── CLOCK ─────────────────────────────────────────────────────────────
        Item {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: tabs.top }
            visible: root._mode === "clock"

            Row {
                anchors.centerIn: parent
                spacing: 10

                // HH stacked above MM with diagonal offset
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    // Width fits both texts plus the one-char offset
                    readonly property int charOffset: 40
                    width:  hhText.implicitWidth + charOffset
                    height: hhText.implicitHeight + mmText.implicitHeight - 8

                    Text {
                        id: hhText
                        anchors.left: parent.left
                        anchors.top:  parent.top
                        text: root._hStr
                        font.pixelSize: 72; font.weight: Font.Bold
                        font.family: "JetBrains Mono"; font.letterSpacing: -4
                        color: Theme.text
                    }
                    Text {
                        id: mmText
                        anchors.left: parent.left
                        anchors.leftMargin: parent.charOffset
                        anchors.top:  hhText.bottom
                        anchors.topMargin: -8
                        text: root._mStr
                        font.pixelSize: 72; font.weight: Font.Bold
                        font.family: "JetBrains Mono"; font.letterSpacing: -4
                        color: Theme.active
                    }
                }

                // Seconds — vertically centered beside the stack
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._sec
                    font.pixelSize: 22; font.weight: Font.Medium
                    font.family: "JetBrains Mono"
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                }
            }
        }

        // ── TIMER ─────────────────────────────────────────────────────────────
        Item {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: tabs.top }
            visible: root._mode === "timer"

            // "+" / "x" toggle — top-right corner
            Item {
                id: addTimerBtn
                anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                width: 24; height: 24

                Rectangle {
                    anchors.fill: parent; radius: 7
                    color: _addTimerHov.hovered
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                           : Qt.rgba(1,1,1,0.06)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2); border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: root._addTimerOpen ? "x" : "+"
                        font.pixelSize: 14; color: Theme.active
                    }
                }
                HoverHandler { id: _addTimerHov; cursorShape: Qt.PointingHandCursor }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root._addTimerOpen = !root._addTimerOpen
                }
            }

            Column {
                anchors.centerIn: parent; spacing: 10

                // ── Ring — hidden while add-timer panel is open ────────────────
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 100; height: 100
                    visible: !root._addTimerOpen

                    Canvas {
                        id: timerCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width/2, cy = height/2, r = 44
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI*2)
                            ctx.strokeStyle = Qt.rgba(1,1,1,0.08)
                            ctx.lineWidth = 5; ctx.stroke()
                            var p = root._timerProgress()
                            if (p > 0) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + Math.PI*2*p)
                                ctx.strokeStyle = Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.85)
                                ctx.lineWidth = 5; ctx.lineCap = "round"; ctx.stroke()
                            }
                        }
                        Connections {
                            target: Theme
                            function onActiveChanged() { timerCanvas.requestPaint() }
                        }
                    }

                    Column {
                        anchors.centerIn: parent; spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root._timerDisplay()
                            font.pixelSize: root._timerLeft >= 3600 ? 16 : 22
                            font.weight: Font.Bold; font.family: "JetBrains Mono"
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.9)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "remaining"; font.pixelSize: 8
                            color: Qt.rgba(1,1,1,0.25)
                        }
                    }
                }

                // ── Presets — hidden while add-timer panel is open ─────────────
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5
                    visible: !root._addTimerOpen && !root._timerRunning
                    Repeater {
                        model: [5, 10, 15, 30]
                        delegate: Rectangle {
                            required property int modelData
                            required property int index
                            width: 36; height: 22; radius: 6
                            color: _pH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.1) : Qt.rgba(1,1,1,0.05)
                            border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: modelData < 60 ? modelData+"m" : "1h"
                                font.pixelSize: 9; font.family: "JetBrains Mono"; font.weight: Font.Bold
                                color: Qt.rgba(1,1,1,0.45)
                            }
                            HoverHandler { id: _pH; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root._timerTotal   = modelData * 60
                                    root._timerLeft    = modelData * 60
                                    root._timerRunning = false
                                    root._timerFired   = false
                                    root._syncState()
                                    timerCanvas.requestPaint()
                                }
                            }
                        }
                    }
                }

                // ── Custom duration — visible only when add-timer panel is open
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root._addTimerOpen
                    width:  _timerInputCol.implicitWidth
                    height: _timerInputCol.implicitHeight

                    Column {
                        id: _timerInputCol
                        anchors.centerIn: parent
                        spacing: 10

                        TimeInput {
                            id: timerTimeInput
                            anchors.horizontalCenter: parent.horizontalCenter
                            minuteStep: 1
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 58; height: 26; radius: 8
                            color: _setTimerHov.hovered
                                   ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.18)
                                   : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.1)
                            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.25); border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent; text: "Set Timer"
                                font.pixelSize: 11; font.weight: Font.Medium
                                color: Theme.active
                            }
                            HoverHandler { id: _setTimerHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var total = timerTimeInput.hours * 3600
                                              + timerTimeInput.minutes * 60
                                    if (total > 0) {
                                        root._timerTotal   = total
                                        root._timerLeft    = total
                                        root._timerRunning = false
                                        root._timerFired   = false
                                        root._syncState()
                                        timerCanvas.requestPaint()
                                    }
                                    root._addTimerOpen = false
                                }
                            }
                        }
                    }
                }

                // ── Start / Pause + Reset ─────────────────────
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    visible: !root._addTimerOpen

                    // Start / Pause
                    Rectangle {
                        width: 58; height: 26; radius: 8
                        color: _startHov.hovered
                               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.2)
                               : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.12)
                        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.22); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: root._timerRunning ? "Pause" : "Start"
                            font.pixelSize: 10; font.weight: Font.Medium
                            color: Theme.active
                        }
                        HoverHandler { id: _startHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root._timerRunning = !root._timerRunning
                                root._timerStarted = true
                                root._timerFired   = false
                                root._syncState()
                            }
                        }
                    }

                    // Reset
                    Rectangle {
                        width: 58; height: 26; radius: 8
                        color: _resetHov.hovered
                               ? Qt.rgba(1,1,1,0.1)
                               : Qt.rgba(1,1,1,0.05)
                        border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "Reset"
                            font.pixelSize: 10; font.weight: Font.Medium
                            color: Qt.rgba(1,1,1,0.4)
                        }
                        HoverHandler { id: _resetHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root._timerLeft    = root._timerTotal
                                root._timerRunning = false
                                root._timerFired   = false
                                root._timerStarted = false
                                root._syncState()
                                timerCanvas.requestPaint()
                            }
                        }
                    }
                }
            }
        }

        // ── ALARM ─────────────────────────────────────────────────────────────
        Item {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: tabs.top }
            visible: root._mode === "alarm"
            clip: true

            Item {
                anchors { fill: parent; margins: 10 }

                // ── Header — Item, not Row, so right-anchor on + button works ──
                Item {
                    id: alarmHeader
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 28

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "Alarms"; font.pixelSize: 12; font.weight: Font.DemiBold
                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.7)
                    }

                    Item {
                        id: addAlarmBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 24; height: 24

                        Rectangle {
                            anchors.fill: parent; radius: 7
                            color: _addHov.hovered
                                   ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.15)
                                   : Qt.rgba(1,1,1,0.06)
                            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.2); border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: root._addOpen ? "✕" : "+"
                                font.pixelSize: 14; color: Theme.active
                            }
                        }
                        HoverHandler { id: _addHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var opening = !root._addOpen
                                root._addOpen = opening
                                if (opening) {
                                    // Snap to next nearest 5-min mark from now
                                    var d = new Date()
                                    var totalMins = d.getHours() * 60 + d.getMinutes() + 1
                                    var snapped   = Math.ceil(totalMins / 5) * 5
                                    var h = Math.floor(snapped / 60) % 24
                                    var m = snapped % 60
                                    root._addHour   = h
                                    root._addMinute = m
                                    alarmTimeInput.initialize(h, m)
                                }
                            }
                        }
                    }
                }

                // ── Add alarm panel ────────────────────────────────────────────
                Rectangle {
                    id: addPanel
                    anchors { left: parent.left; right: parent.right; top: alarmHeader.bottom; topMargin: 6 }
                    height:  root._addOpen ? 140 : 0
                    clip:    true
                    color:   Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.05)
                    radius:  8
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.1); border.width: 1
                    opacity: root._addOpen ? 1 : 0
                    Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        TimeInput {
                            id: alarmTimeInput
                            anchors.horizontalCenter: parent.horizontalCenter
                            minuteStep: 1
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 58; height: 26; radius: 8
                            color: _setAlarmHov.hovered
                                   ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.18)
                                   : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.1)
                            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.25); border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent; text: "Set Alarm"
                                font.pixelSize: 11; font.weight: Font.Medium
                                color: Theme.active
                            }
                            HoverHandler { id: _setAlarmHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root._addHour   = alarmTimeInput.hours
                                    root._addMinute = alarmTimeInput.minutes
                                    root._addAlarm()
                                }
                            }
                        }
                    }
                }

                // ── Alarm list ─────────────────────────────────────────────────
                ListView {
                    id: alarmList
                    anchors {
                        left: parent.left; right: parent.right
                        top: addPanel.bottom; topMargin: 6
                        bottom: parent.bottom
                    }
                    model: root._alarms
                    clip: true; spacing: 4
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: alarmList.width; height: 36; radius: 8
                        color: Qt.rgba(1,1,1,0.04)
                        border.color: modelData.enabled
                                      ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.15)
                                      : Qt.rgba(1,1,1,0.07)
                        border.width: 1

                        // Time label
                        Text {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: root._zp(modelData.hour) + ":" + root._zp(modelData.minute)
                            font.pixelSize: 15; font.weight: Font.Bold; font.family: "JetBrains Mono"
                            color: modelData.enabled
                                   ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.9)
                                   : Qt.rgba(1,1,1,0.3)
                        }

                        // Toggle
                        Rectangle {
                            id: toggleBtn
                            anchors { right: deleteBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            width: 28; height: 18; radius: 9
                            color: modelData.enabled
                                   ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.25)
                                   : Qt.rgba(1,1,1,0.1)
                            Behavior on color { ColorAnimation { duration: 130 } }
                            Rectangle {
                                width: 12; height: 12; radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                x: modelData.enabled ? parent.width - width - 3 : 3
                                color: modelData.enabled ? Theme.active : Qt.rgba(1,1,1,0.3)
                                Behavior on x     { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation  { duration: 130 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root._toggleAlarm(modelData.id)
                            }
                        }

                        // Delete
                        Rectangle {
                            id: deleteBtn
                            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            width: 22; height: 22; radius: 6
                            color: _delH.hovered ? Qt.rgba(248/255,113/255,113/255,0.18) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 10; color: Qt.rgba(248/255,113/255,113/255,0.6) }
                            HoverHandler { id: _delH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._deleteAlarm(modelData.id) }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root._alarms.length === 0 && !root._addOpen
                        text: "No alarms set\nTap + to add one"
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 11; color: Qt.rgba(1,1,1,0.2)
                        lineHeight: 1.5
                    }
                }
            }
        }

        // ── STOPWATCH ─────────────────────────────────────────────────────────
        Item {
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: tabs.top }
            visible: root._mode === "stopwatch"

            Column {
                anchors.centerIn: parent; spacing: 12

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root._swDisplay()
                    font.pixelSize: 52; font.weight: Font.Bold
                    font.family: "JetBrains Mono"; font.letterSpacing: -1
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.9)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    // Start / Stop
                    Rectangle {
                        width: 58; height: 26; radius: 8
                        color: _swStartHov.hovered
                               ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.2)
                               : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.12)
                        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b,0.22); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent
                            text: root._swRunning ? "Stop" : "Start"
                            font.pixelSize: 10; font.weight: Font.Medium
                            color: Theme.active
                        }
                        HoverHandler { id: _swStartHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root._swRunning = !root._swRunning; root._swStarted = true; root._syncState();}
                            
                        }
                    }
                    // Reset
                    Rectangle {
                        width: 58; height: 26; radius: 8
                        color: _swResetHov.hovered
                               ? Qt.rgba(1,1,1,0.1)
                               : Qt.rgba(1,1,1,0.05)
                        border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text {
                            anchors.centerIn: parent; text: "Reset"
                            font.pixelSize: 10; font.weight: Font.Medium
                            color: Qt.rgba(1,1,1,0.4)
                        }
                        HoverHandler { id: _swResetHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root._swMs = 0; root._swRunning = false; root._swStarted = false; root._syncState() }
                        }
                    }
                }
            }
        }

        // ── Tab bar ───────────────────────────────────────────────────────────
        TabSwitcher {
            id: tabs
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            orientation: "horizontal"; width: parent.width
            currentPage: root._mode
            model: [
                { key: "clock",     icon: "󰥔", label: "Clock"     },
                { key: "timer",     icon: "󱎫", label: "Timer"     },
                { key: "alarm",     icon: "󰀠", label: "Alarm"     },
                { key: "stopwatch", icon: "󰔚", label: "Stopwatch" }
            ]
            onPageChanged: function(key) { root._mode = key }
        }
    }
}
