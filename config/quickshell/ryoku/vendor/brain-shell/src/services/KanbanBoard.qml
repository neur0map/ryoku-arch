import QtQuick
import Quickshell.Io
import "../"
import "../components"

// KanbanBoard — three columns, JSON at $HOME/.config/Brain_Shell/src/user_data/tasks.json.
//
// Key behaviours:
//   • Draft: task only saved when Enter pressed or focus lost with text.
//   • Arrow move: card appears in new column offset by ±dir*36px, springs
//     to 0 with OutBack overshoot (rubber-band feel).
//   • Due date: mini calendar + optional time picker, both optional.
//     Time-only → today's date prepended automatically.
//   • Delete confirm: Enter = confirm, Esc = cancel; only active when overlay
//     is showing; dashboard close cancels automatically.

Item {
    id: root

    // ── Persistent state ──────────────────────────────────────────────────────
    property var    _tasks:    []
    property int    _nextId:   0
    property string _filePath: ""

    // ── Animation tracking ────────────────────────────────────────────────────
    // Plain objects — mutated in-place, no signal needed, checked once per card.
    property var _newCardIds:      ({})   // id → true  (y slide-in on creation)
    property var _entryDirections: ({})   // id → dir   (x spring on column move)

    // ── Delete confirm ────────────────────────────────────────────────────────
    property int delConfirmId: -1   // task id with overlay open, -1 = none

    // ── Due date picker state ─────────────────────────────────────────────────
    property int    pickerTaskId:  -1
    property int    pickerYear:    0
    property int    pickerMonth:   0
    property int    pickerDay:     0     // 0 = date not selected
    property bool   pickerHasTime: false
    property int    pickerTimeH:   12
    property int    pickerTimeM:   0
    property var    pickerDays:    []

    readonly property var _monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var _dowNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

    // ── Boot: resolve $HOME → create file if missing → load ──────────────────
    Process {
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var h = line.trim()
                if (h === "") return
                root._filePath = h + "/.config/Brain_Shell/src/user_data/tasks.json"
                mkProc.command = [
                    "bash", "-c",
                    "[ -f '" + root._filePath + "' ] || " +
                    "(mkdir -p \"$HOME/.config/Brain_Shell/src/user_data\" && " +
                    "printf '%s' '{\"tasks\":[],\"nextId\":0}' > '" + root._filePath + "')"
                ]
                mkProc.running = false; mkProc.running = true
            }
        }
    }

    Process {
        id: mkProc; command: []; running: false
        onRunningChanged: {
            if (!running && root._filePath !== "") {
                rdProc.command = ["cat", root._filePath]
                rdProc.running = false; rdProc.running = true
            }
        }
    }

    Process {
        id: rdProc; command: []; running: false
        stdout: StdioCollector {
            id: rdBuf
            onStreamFinished: {
                try {
                    var o = JSON.parse(rdBuf.text)
                    root._tasks  = o.tasks  || []
                    root._nextId = o.nextId || 0
                } catch(e) { root._tasks = []; root._nextId = 0 }
            }
        }
    }

    // ── Save ──────────────────────────────────────────────────────────────────
    function _save() {
        if (_filePath === "") return
        var s = JSON.stringify({ tasks: _tasks, nextId: _nextId })
        wrProc.command = [
            "bash", "-c",
            "printf '%s' '" + s.replace(/'/g, "'\\''") + "' > '" + _filePath + "'"
        ]
        wrProc.running = false; wrProc.running = true
    }
    Process { id: wrProc; command: []; running: false }

    // ── Reset state when dashboard closes ─────────────────────────────────────
    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen) {
                root.delConfirmId = -1
                root.pickerTaskId = -1
            }
        }
    }

    // ── Mutations ─────────────────────────────────────────────────────────────
    function _addTask(col, title) {
        var id   = root._nextId++
        var list = root._tasks.slice()
        list.unshift({ id: id, title: title, column: col, urgency: "", dueDate: "" })
        root._newCardIds = Object.assign({}, root._newCardIds, { [id]: true })
        root._tasks = list
        _save()
    }

    function _moveTask(id, dir) {
        var list = root._tasks.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id) continue
            var nc = list[i].column + dir
            if (nc < 0 || nc > 2) return
            // Record direction before model changes so new card can read it
            root._entryDirections = Object.assign({}, root._entryDirections, { [id]: dir })
            list[i] = Object.assign({}, list[i], { column: nc })
            break
        }
        root._tasks = list
        _save()
    }

    function _removeTask(id) {
        root._tasks = root._tasks.filter(function(t) { return t.id !== id })
        if (root.delConfirmId === id) root.delConfirmId = -1
        _save()
    }

    function _patchTask(id, key, val) {
        var list = root._tasks.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id) continue
            var t = Object.assign({}, list[i]); t[key] = val; list[i] = t; break
        }
        root._tasks = list
        _save()
    }

    // ── Urgency helpers ───────────────────────────────────────────────────────
    function _urgColor(u) {
        if (u === "high")   return "#f38ba8"
        if (u === "medium") return "#f9e2af"
        if (u === "low")    return "#a6e3a1"
        return "transparent"
    }
    function _urgLabel(u) {
        if (u === "high")   return "High"
        if (u === "medium") return "Med"
        if (u === "low")    return "Low"
        return ""
    }

    // ── Due date helpers ──────────────────────────────────────────────────────
    function _zp2(n) { return n < 10 ? "0" + n : "" + n }

    function _formatDue(s) {
        if (!s || s === "") return ""
        var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        var now = new Date()
        var todayStr = now.getFullYear() + "-" + _zp2(now.getMonth()+1) + "-" + _zp2(now.getDate())
        var datePart = s.length >= 10 ? s.substring(0, 10) : ""
        var timePart = s.length >= 16 ? s.substring(11, 16) : ""
        var dateLabel = ""
        if (datePart !== "") {
            if (datePart === todayStr) dateLabel = "Today"
            else {
                var dp = datePart.split("-")
                dateLabel = months[parseInt(dp[1]) - 1] + " " + parseInt(dp[2])
            }
        }
        if (dateLabel !== "" && timePart !== "") return dateLabel + "  " + timePart
        if (dateLabel !== "") return dateLabel
        if (timePart !== "") return "Today  " + timePart
        return ""
    }

    // ── Picker helpers ────────────────────────────────────────────────────────
    function _openPicker(taskId) {
        root.pickerTaskId  = taskId
        var now = new Date()
        root.pickerYear    = now.getFullYear()
        root.pickerMonth   = now.getMonth()
        root.pickerDay     = 0
        root.pickerHasTime = false
        root.pickerTimeH   = 12
        root.pickerTimeM   = 0

        for (var i = 0; i < root._tasks.length; i++) {
            if (root._tasks[i].id !== taskId) continue
            var s = root._tasks[i].dueDate || ""
            if (s === "") break
            var dp2 = s.length >= 10 ? s.substring(0, 10) : ""
            var tp  = s.length >= 16 ? s.substring(11, 16) : ""
            if (dp2 !== "") {
                var p = dp2.split("-")
                root.pickerYear  = parseInt(p[0])
                root.pickerMonth = parseInt(p[1]) - 1
                root.pickerDay   = parseInt(p[2])
            }
            if (tp !== "") {
                var tParts = tp.split(":")
                root.pickerTimeH   = parseInt(tParts[0]) || 0
                root.pickerTimeM   = parseInt(tParts[1]) || 0
                root.pickerHasTime = true
            }
            break
        }
        _rebuildPickerDays()
    }

    function _rebuildPickerDays() {
        var firstDow   = new Date(root.pickerYear, root.pickerMonth, 1).getDay()
        var daysInMon  = new Date(root.pickerYear, root.pickerMonth + 1, 0).getDate()
        var daysInPrev = new Date(root.pickerYear, root.pickerMonth, 0).getDate()
        var days = []
        for (var p = firstDow - 1; p >= 0; p--)
            days.push({ n: daysInPrev - p, cur: false })
        for (var d = 1; d <= daysInMon; d++)
            days.push({ n: d, cur: true })
        var tail = 42 - days.length
        for (var t = 1; t <= tail; t++)
            days.push({ n: t, cur: false })
        root.pickerDays = days
    }

    onPickerYearChanged:  _rebuildPickerDays()
    onPickerMonthChanged: _rebuildPickerDays()

    function _commitPicker() {
        if (root.pickerTaskId < 0) return
        var datePart = "", timePart = ""
        if (root.pickerDay > 0) {
            var m = root.pickerMonth + 1
            datePart = root.pickerYear + "-" + _zp2(m) + "-" + _zp2(root.pickerDay)
        }
        if (root.pickerHasTime)
            timePart = _zp2(root.pickerTimeH) + ":" + _zp2(root.pickerTimeM)

        var result = ""
        if (datePart !== "" && timePart !== "") result = datePart + " " + timePart
        else if (datePart !== "") result = datePart
        else if (timePart !== "") {
            var now = new Date()
            result = now.getFullYear() + "-" + _zp2(now.getMonth()+1) + "-" + _zp2(now.getDate())
                     + " " + timePart
        }
        _patchTask(root.pickerTaskId, "dueDate", result)
        root.pickerTaskId = -1
    }

    // ── Delete keyboard handler ───────────────────────────────────────────────
    // Grabs focus when delete confirm opens; Enter = delete, Esc = cancel.
    Item {
        id: deleteKeyHandler
        Keys.onReturnPressed: function(ev) {
            if (root.delConfirmId >= 0) {
                root._removeTask(root.delConfirmId)
                ev.accepted = true
            }
        }
        Keys.onEscapePressed: function(ev) {
            if (root.delConfirmId >= 0) {
                root.delConfirmId = -1
                ev.accepted = true
            }
        }
    }

    onDelConfirmIdChanged: {
        if (delConfirmId >= 0) deleteKeyHandler.forceActiveFocus()
    }

    // ── Column defs ───────────────────────────────────────────────────────────
    readonly property var colDefs: [
        { idx: 0, label: "To Do"   },
        { idx: 1, label: "Ongoing" },
        { idx: 2, label: "Done"    }
    ]

    // ── Column layout ─────────────────────────────────────────────────────────
    Row {
        id: mainRow
        anchors.fill: parent
        anchors.topMargin: 8
        spacing: 8

        Repeater {
            model: root.colDefs

            delegate: Item {
                id: colItem
                required property var modelData

                readonly property int    cIdx:   modelData.idx
                readonly property string cLabel: modelData.label
                readonly property var    cTasks: {
                    var ci = cIdx
                    return root._tasks.filter(function(t) { return t.column === ci })
                }

                property bool draftOpen: false

                width:  (mainRow.width - mainRow.spacing * 2) / 3
                height: parent.height

                Rectangle {
                    anchors.fill: parent; radius: Theme.cornerRadius
                    color:        Qt.rgba(1, 1, 1, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.07); border.width: 1
                }

                Column {
                    anchors { fill: parent; margins: 10 }
                    spacing: 8

                    // Header
                    Item {
                        width: parent.width; height: 26

                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            spacing: 7
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: colItem.cLabel; color: Theme.active
                                font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: cntT.implicitWidth + 10; height: 16; radius: 8
                                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                                Text {
                                    id: cntT; anchors.centerIn: parent
                                    text: colItem.cTasks.length
                                    color: Theme.active; font.pixelSize: 9; font.weight: Font.Bold
                                }
                            }
                        }

                        // Add (+) button
                        Rectangle {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 22; height: 22; radius: 6
                            color: addH.hovered
                                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                                : Qt.rgba(1, 1, 1, 0.05)
                            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "+"; color: Theme.active; font.pixelSize: 15 }
                            HoverHandler { id: addH; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { colItem.draftOpen = true; draftTimer.restart() }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

                    Timer {
                        id: draftTimer; interval: 50
                        onTriggered: if (colItem.draftOpen) draftInput.forceActiveFocus()
                    }

                    // Content area
                    Item {
                        width:  parent.width
                        height: parent.height - 26 - 1 - parent.spacing * 2

                        // Draft card — slides in from top
                        Item {
                            id: draftWrap; z: 2; width: parent.width
                            height: colItem.draftOpen ? draftRect.implicitHeight + 6 : 0
                            clip:   true
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            Rectangle {
                                id: draftRect
                                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 3 }
                                radius: 8
                                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.06)
                                border.color: draftInput.activeFocus
                                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.50)
                                    : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
                                border.width: 1
                                implicitHeight: draftInput.contentHeight + 24
                                Behavior on border.color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                    visible: draftInput.text === ""
                                    text: "Task title…"; color: Qt.rgba(1,1,1,0.25); font.pixelSize: 12
                                }

                                TextInput {
                                    id: draftInput
                                    anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    color: Theme.text; font.pixelSize: 12
                                    wrapMode: TextInput.WordWrap
                                    selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)

                                    function commit() {
                                        var t = text.trim()
                                        if (t !== "") root._addTask(colItem.cIdx, t)
                                        colItem.draftOpen = false; text = ""
                                    }

                                    Keys.onReturnPressed: function(ev) { commit(); ev.accepted = true }
                                    Keys.onEscapePressed: function(ev) { colItem.draftOpen = false; text = ""; ev.accepted = true }
                                    onActiveFocusChanged: if (!activeFocus && colItem.draftOpen) commit()
                                }
                            }
                        }

                        // Task list
                        Flickable {
                            anchors.top:       draftWrap.bottom
                            anchors.left:      parent.left
                            anchors.right:     parent.right
                            anchors.topMargin: colItem.draftOpen ? 4 : 0
                            height:            parent.height - draftWrap.height - (colItem.draftOpen ? 4 : 0)
                            contentWidth:      width
                            contentHeight:     taskCol.implicitHeight + 4
                            clip:              true
                            boundsBehavior:    Flickable.StopAtBounds

                            Column {
                                id: taskCol
                                width: parent.width; spacing: 6

                                Repeater {
                                    model: colItem.cTasks
                                    delegate: TaskCard {
                                        required property var modelData
                                        width:    parent.width
                                        taskData: modelData
                                        colIdx:   colItem.cIdx
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Picker dim overlay ────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; z: 29
        visible: root.pickerTaskId >= 0
        color:   Qt.rgba(0, 0, 0, 0.35)
        MouseArea { anchors.fill: parent; onClicked: root.pickerTaskId = -1 }
    }

    // ── Date / time picker popup ──────────────────────────────────────────────
    Rectangle {
        id: datePicker
        z:              30
        anchors.centerIn: parent
        visible:        root.pickerTaskId >= 0

        width:  230
        height: pickerCol.implicitHeight + 24
        radius: Theme.cornerRadius
        color: Qt.rgba(
            Math.min(1, Theme.background.r + 0.06),
            Math.min(1, Theme.background.g + 0.06),
            Math.min(1, Theme.background.b + 0.06), 0.98)
        border.color: Qt.rgba(1,1,1,0.15); border.width: 1

        // Swallow clicks so they don't reach the dim overlay below
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: pickerCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            // ── Month nav ──────────────────────────────────────────────────────
            Item {
                width: parent.width; height: 22
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "‹"; font.pixelSize: 17
                    color: pmH.hovered ? Qt.rgba(1,1,1,0.85) : Qt.rgba(1,1,1,0.30)
                    Behavior on color { ColorAnimation { duration: 80 } }
                    HoverHandler { id: pmH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.pickerMonth === 0) { root.pickerMonth = 11; root.pickerYear-- }
                            else root.pickerMonth--
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text:  root._monthNames[root.pickerMonth].substring(0,3) + "  " + root.pickerYear
                    color: Theme.text; font.pixelSize: 11; font.weight: Font.DemiBold
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "›"; font.pixelSize: 17
                    color: nmH.hovered ? Qt.rgba(1,1,1,0.85) : Qt.rgba(1,1,1,0.30)
                    Behavior on color { ColorAnimation { duration: 80 } }
                    HoverHandler { id: nmH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.pickerMonth === 11) { root.pickerMonth = 0; root.pickerYear++ }
                            else root.pickerMonth++
                        }
                    }
                }
            }

            // ── Day-of-week headers ────────────────────────────────────────────
            Item {
                width: parent.width; height: 14
                Row {
                    anchors.fill: parent
                    Repeater {
                        model: root._dowNames
                        delegate: Text {
                            width: Math.floor(parent.parent.width / 7)
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData; font.pixelSize: 8; font.weight: Font.Bold
                            color: Qt.rgba(1,1,1,0.18)
                        }
                    }
                }
            }

            // ── Day grid ──────────────────────────────────────────────────────
            Grid {
                id: dayGrid
                width: parent.width; columns: 7; rows: 6
                readonly property real cW: width / 7
                readonly property real cH: 24

                Repeater {
                    model: root.pickerDays
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: dayGrid.cW; height: dayGrid.cH

                        readonly property bool isSel: modelData.cur && modelData.n === root.pickerDay
                        readonly property bool isNow: {
                            var n = new Date()
                            return modelData.cur &&
                                   modelData.n   === n.getDate() &&
                                   root.pickerMonth === n.getMonth() &&
                                   root.pickerYear  === n.getFullYear()
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(dayGrid.cW, dayGrid.cH) - 2; height: width; radius: width / 2
                            color: isSel
                                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.82)
                                : isNow ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                                        : dayH.hovered && modelData.cur ? Qt.rgba(1,1,1,0.08) : "transparent"
                            border.color: isNow && !isSel ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35) : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.n
                                font.pixelSize: 9; font.weight: isSel ? Font.Bold : Font.Normal
                                color: isSel ? Theme.background
                                    : modelData.cur ? Qt.rgba(1,1,1,0.78) : Qt.rgba(1,1,1,0.14)
                            }
                        }
                        HoverHandler { id: dayH; enabled: modelData.cur; cursorShape: Qt.PointingHandCursor }
                        TapHandler  { enabled: modelData.cur; onTapped: root.pickerDay = modelData.n }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }

            // ── Time row ──────────────────────────────────────────────────────
            Item {
                width: parent.width; height: timeInner.implicitHeight

                Row {
                    id: timeInner
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⏰"; font.pixelSize: 13
                    }

                    // Controls when time is set
                    Row {
                        spacing: 4; visible: root.pickerHasTime
                        anchors.verticalCenter: parent.verticalCenter

                        // ── Hour col ──────────────────────────────────────────
                        Column {
                            spacing: 2; anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: hUpH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: hUpH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeH = (root.pickerTimeH + 1) % 24 }
                            }
                            Rectangle {
                                width: 26; height: 24; radius: 4
                                color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: root._zp2(root.pickerTimeH)
                                    font.pixelSize: 13; font.family: "JetBrains Mono"; font.weight: Font.Bold
                                    color: Theme.active
                                }
                            }
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: hDnH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: hDnH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeH = (root.pickerTimeH + 23) % 24 }
                            }
                        }

                        Text { anchors.verticalCenter: parent.verticalCenter; text: ":"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text }

                        // ── Minute col ────────────────────────────────────────
                        Column {
                            spacing: 2; anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: mUpH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▲"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: mUpH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeM = (root.pickerTimeM + 5) % 60 }
                            }
                            Rectangle {
                                width: 26; height: 24; radius: 4
                                color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: root._zp2(root.pickerTimeM)
                                    font.pixelSize: 13; font.family: "JetBrains Mono"; font.weight: Font.Bold
                                    color: Theme.active
                                }
                            }
                            Rectangle {
                                width: 26; height: 18; radius: 4
                                color: mDnH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                                border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: "▼"; font.pixelSize: 7; color: Qt.rgba(1,1,1,0.50) }
                                HoverHandler { id: mDnH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root.pickerTimeM = (root.pickerTimeM + 55) % 60 }
                            }
                        }

                        // Clear time ✕
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18; radius: 9
                            color: clrTH.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.05)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 8; color: Qt.rgba(1,1,1,0.40) }
                            HoverHandler { id: clrTH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root.pickerHasTime = false }
                        }
                    }

                    // "Add time" pill (shown when no time set)
                    Rectangle {
                        visible: !root.pickerHasTime
                        anchors.verticalCenter: parent.verticalCenter
                        width: addTL.implicitWidth + 18; height: 24; radius: 12
                        color: addTH.hovered
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                            : Qt.rgba(1,1,1,0.06)
                        border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            id: addTL; anchors.centerIn: parent
                            text: "Add time"; font.pixelSize: 10
                            color: addTH.hovered ? Theme.active : Qt.rgba(1,1,1,0.45)
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }
                        HoverHandler { id: addTH; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.pickerHasTime = true; root.pickerTimeH = 12; root.pickerTimeM = 0 }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.08) }

            // ── Clear / Done ───────────────────────────────────────────────────
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10; bottomPadding: 0

                Rectangle {
                    width: 86; height: 28; radius: 8
                    color: clrH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: "Clear"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.50) }
                    HoverHandler { id: clrH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root._patchTask(root.pickerTaskId, "dueDate", ""); root.pickerTaskId = -1 }
                    }
                }

                Rectangle {
                    width: 86; height: 28; radius: 8
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, doneH.hovered ? 0.28 : 0.16)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.38); border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text {
                        anchors.centerIn: parent; text: "Done"
                        font.pixelSize: 11; font.weight: Font.Medium; color: Theme.active
                    }
                    HoverHandler { id: doneH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root._commitPicker() }
                }
            }
        }
    }

    // ── TaskCard ──────────────────────────────────────────────────────────────
    component TaskCard: Item {
        id: card

        property var taskData
        property int colIdx

        property bool showExtra: false
        property real xEntry:    0
        property real dragX:     0

        readonly property bool isDelConfirm: root.delConfirmId === taskData.id

        height: cardBg.implicitHeight + 2

        transform: [
            Translate { x: card.dragX + card.xEntry },
            // 3D Tilt: card physically tilts in the direction you drag it
            Rotation {
                origin.x: card.width / 2; origin.y: card.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: (card.dragX / 65.0) * -12
                Behavior on angle { SpringAnimation { spring: 2.5; damping: 0.3 } }
            }
        ]

        // Lift Effect: card scales down slightly when grabbed
        scale: dragHandler.active ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }

        // Fluid Column Jumps: smooth gliding instead of teleporting
        Behavior on x { SpringAnimation { spring: 2.0; damping: 0.25 } }
        Behavior on y { SpringAnimation { spring: 2.0; damping: 0.25 } }

        // ── Entry animation ────────────────────────────────────────────────────
        // New cards: no x offset (draft gives enough visual feedback).
        // Moved cards: appear at ±36px in move direction, spring to 0.
        Component.onCompleted: {
            var id = card.taskData.id
            if (root._newCardIds[id]) {
                delete root._newCardIds[id]
                // No extra animation — draft open/close is the creation affordance
            } else if (root._entryDirections[id] !== undefined) {
                var dir = root._entryDirections[id]
                delete root._entryDirections[id]
                // dir=1 (moved right) → xEntry=+36 (card overshoots right, bounces left to 0)
                // dir=-1 (moved left) → xEntry=-36 (card overshoots left, bounces right to 0)
                card.xEntry = dir * 36
                xSpringAnim.restart()
            }
        }

        // Spring to 0 with OutBack rubber-band feel
        NumberAnimation {
            id: xSpringAnim
            target:           card; property: "xEntry"; to: 0
            duration:         400
            easing.type:      Easing.OutBack
            easing.overshoot: 1.6
        }

        // ── Swipe to move ─────────────────────────────────────────────────────
        DragHandler {
            id: dragHandler
            target: null
            xAxis.enabled: true; yAxis.enabled: false; dragThreshold: 12
            
            onActiveChanged: {
                if (!active) {
                    var d = card.dragX; snapAnim.start()
                    var dir = d > 0 ? 1 : -1
                    if (Math.abs(d) > 50 && card.colIdx + dir >= 0 && card.colIdx + dir <= 2)
                        root._moveTask(card.taskData.id, dir)
                }
            }
            onTranslationChanged: {
                if (active) card.dragX = Math.max(-65, Math.min(65, translation.x))
            }
        }

        // Elastic Snap: wobbles slightly when snapping back to place
        NumberAnimation {
            id: snapAnim; target: card; property: "dragX"; to: 0
            duration: 600
            easing.type:      Easing.OutElastic
            easing.amplitude: 1.2
            easing.period:    0.6
        }

        // Dynamic Glow: stronger, smoother color tinting
        readonly property real dragAmt:  Math.abs(dragX) / 65.0
        readonly property color dragTint: {
            if (dragX >  2) return Qt.rgba(166/255, 227/255, 161/255, dragAmt * 0.35)
            if (dragX < -2) return Qt.rgba(243/255, 139/255, 168/255, dragAmt * 0.35)
            return "transparent"
        }

        // ── Card body ─────────────────────────────────────────────────────────
        Rectangle {
            id: cardBg
            width: parent.width; radius: 8
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: {
                var u = card.taskData.urgency
                if (u === "high")   return Qt.rgba(243/255, 139/255, 168/255, 0.45)
                if (u === "medium") return Qt.rgba(249/255, 226/255, 175/255, 0.35)
                if (u === "low")    return Qt.rgba(166/255, 227/255, 161/255, 0.35)
                return Qt.rgba(1, 1, 1, 0.10)
            }
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }
            implicitHeight: body.implicitHeight + 18

            // Drag direction tint
            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: card.dragTint
                Behavior on color { ColorAnimation { duration: 60 } }
            }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10; top: parent.top; topMargin: 9 }
                spacing: 6

                // Title (inline edit)
                TextInput {
                    width: parent.width
                    text:           card.taskData.title
                    color:          Theme.text; font.pixelSize: 12; font.weight: Font.Medium
                    wrapMode:       TextInput.WordWrap
                    selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                    onEditingFinished: { var t = text.trim(); if (t !== "") root._patchTask(card.taskData.id, "title", t) }
                }

                // Badges row
                Row {
                    visible: card.taskData.urgency !== "" || (card.taskData.dueDate || "") !== ""
                    spacing: 6
                    Rectangle {
                        visible: card.taskData.urgency !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: urgL.implicitWidth + 12; height: 16; radius: 8
                        color: root._urgColor(card.taskData.urgency); opacity: 0.85
                        Text { id: urgL; anchors.centerIn: parent; text: root._urgLabel(card.taskData.urgency); font.pixelSize: 9; font.weight: Font.Bold; color: "#1e1e2e" }
                    }
                    Row {
                        visible: (card.taskData.dueDate || "") !== ""
                        anchors.verticalCenter: parent.verticalCenter; spacing: 3
                        Text { text: "📅"; font.pixelSize: 9 }
                        Text { text: root._formatDue(card.taskData.dueDate || ""); font.pixelSize: 9; color: Qt.rgba(1,1,1,0.50) }
                    }
                }

                // Expandable extra fields
                Column {
                    visible: card.showExtra; width: parent.width; spacing: 6

                    // Urgency picker
                    Row {
                        spacing: 5
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Urgency"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }
                        Repeater {
                            model: ["", "low", "medium", "high"]
                            delegate: Rectangle {
                                required property string modelData
                                property bool sel: card.taskData.urgency === modelData
                                width: uT.implicitWidth + 12; height: 17; radius: 9
                                color: sel ? (modelData === "" ? Qt.rgba(1,1,1,0.15) : root._urgColor(modelData))
                                           : (uH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05))
                                border.color: Qt.rgba(1,1,1, sel ? 0.20 : 0.08); border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    id: uT; anchors.centerIn: parent; font.pixelSize: 9
                                    text: modelData === "" ? "None" : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                    color: (sel && modelData !== "") ? "#1e1e2e" : Qt.rgba(1,1,1,0.65)
                                }
                                HoverHandler { id: uH; cursorShape: Qt.PointingHandCursor }
                                MouseArea { anchors.fill: parent; onClicked: root._patchTask(card.taskData.id, "urgency", modelData) }
                            }
                        }
                    }

                    // Due date button row
                    Row {
                        spacing: 6
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Due"; font.pixelSize: 9; color: Qt.rgba(1,1,1,0.35) }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width:  dueLbl.implicitWidth + 20; height: 20; radius: 10
                            color: dueBH.hovered
                                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                                : Qt.rgba(1,1,1,0.07)
                            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text {
                                id: dueLbl; anchors.centerIn: parent; font.pixelSize: 9
                                text:  (card.taskData.dueDate || "") !== "" ? root._formatDue(card.taskData.dueDate) : "Set due date"
                                color: (card.taskData.dueDate || "") !== "" ? Theme.active : Qt.rgba(1,1,1,0.40)
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }
                            HoverHandler { id: dueBH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._openPicker(card.taskData.id) }
                        }

                        // Clear ✕
                        Rectangle {
                            visible: (card.taskData.dueDate || "") !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 8
                            color: clrDH.hovered ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.05)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 8; color: Qt.rgba(1,1,1,0.35) }
                            HoverHandler { id: clrDH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._patchTask(card.taskData.id, "dueDate", "") }
                        }
                    }
                }

                // Action bar
                Item {
                    width: parent.width; height: 22

                    // ▾/▴ extra fields
                    Rectangle {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: 20; height: 20; radius: 5
                        color: optH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: card.showExtra ? "▴" : "▾"; font.pixelSize: 9; color: Qt.rgba(1,1,1, optH.hovered ? 0.70 : 0.30) }
                        HoverHandler { id: optH; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: card.showExtra = !card.showExtra }
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 4

                        // ← left
                        Rectangle {
                            visible: card.colIdx > 0
                            width: 20; height: 20; radius: 5
                            color: lH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 10; color: Qt.rgba(1,1,1, lH.hovered ? 0.80 : 0.40) }
                            HoverHandler { id: lH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._moveTask(card.taskData.id, -1) }
                        }

                        // → right
                        Rectangle {
                            visible: card.colIdx < 2
                            width: 20; height: 20; radius: 5
                            color: rH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.04)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 10; color: Qt.rgba(1,1,1, rH.hovered ? 0.80 : 0.40) }
                            HoverHandler { id: rH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._moveTask(card.taskData.id, 1) }
                        }

                        // ✕ delete
                        Rectangle {
                            width: 20; height: 20; radius: 5
                            color: dH.hovered ? Qt.rgba(248/255,113/255,113/255,0.20) : Qt.rgba(1,1,1,0.04)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text {
                                anchors.centerIn: parent; text: "✕"; font.pixelSize: 10
                                color: Qt.rgba(248/255,113/255,113/255, dH.hovered ? 1.0 : 0.60)
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }
                            HoverHandler { id: dH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root.delConfirmId = card.taskData.id }
                        }
                    }
                }
            }

            // ── Delete confirmation overlay ────────────────────────────────────
            Rectangle {
                anchors.fill: parent; radius: parent.radius
                visible: card.isDelConfirm
                color: Qt.rgba(
                    Math.min(1, Theme.background.r + 0.05),
                    Math.min(1, Theme.background.g + 0.05),
                    Math.min(1, Theme.background.b + 0.05), 0.96)

                Column {
                    anchors.centerIn: parent; spacing: 10
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Delete task?"; color: Theme.text; font.pixelSize: 12; font.weight: Font.Medium
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                        Rectangle {
                            width: 64; height: 24; radius: 6
                            color: cnH.hovered ? Qt.rgba(1,1,1,0.10) : Qt.rgba(1,1,1,0.05)
                            border.color: Qt.rgba(1,1,1,0.10); border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.60) }
                            HoverHandler { id: cnH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root.delConfirmId = -1 }
                        }
                        Rectangle {
                            width: 64; height: 24; radius: 6
                            color: cfH.hovered ? "#cc3a3a" : "#993030"
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "Delete"; font.pixelSize: 11; font.weight: Font.Bold; color: "white" }
                            HoverHandler { id: cfH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._removeTask(card.taskData.id) }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "↵ confirm · ⎋ cancel"; font.pixelSize: 9
                        color: Qt.rgba(1,1,1,0.20)
                    }
                }
            }
        }
    }
}
