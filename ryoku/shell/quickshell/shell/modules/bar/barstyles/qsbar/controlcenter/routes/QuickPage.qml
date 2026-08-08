import QtQuick
import Quickshell
import "../kit"
import "../../modules"

// QUICK page — 1:1 port of Shibumi's QuickControlPage, in qsbar's palette.
//   barLanding: thin V1/V2 variant rows (label + status badge + detail) on the
//   left, joined by a live bezier canvas to a single ACTIVE BAR preview card on
//   the right. actionDeck: two 4-row columns of thin action rows (icon + label +
//   detail) with a dotted rail canvas between them. Hover is neutral; the seal
//   accent marks only the active row, the routes, and destructive confirms.
Item {
    id: page
    property var root: null
    property var cc: null
    implicitHeight: col.implicitHeight

    // ── token shortcuts (all from root; fallbacks only while root is null) ──
    readonly property color fg: root ? root.ink : "#cccccc"
    readonly property color acc: root ? root.seal : "#c4746e"
    readonly property color danger: root ? root.color01 : "#c4746e"
    readonly property color idleFill: root ? root.fillIdle : "#111111"
    readonly property color hoverFill: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06) : "#161616"
    readonly property color idleBorder: root ? root.sep : "#333333"
    readonly property color hoverBorder: root ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28) : "#444444"
    readonly property int ctlR: root ? root.tileRadius : 6
    readonly property string mono: root ? root.mono : "monospace"

    // ── state ──
    property int hoveredBar: -1
    property int hoveredLeft: -1
    property int hoveredRight: -1
    property string pending: ""

    readonly property string runningVariant: (root && root.variantHost) ? String(root.variantHost.runningVariant) : "v1"
    readonly property bool switching: (root && root.variantHost) ? root.variantHost.switching === true : false
    readonly property string v2Form: root ? String(root.barShellStyle || "full") : "full"
    function cap(s) { return s && s.length ? s.charAt(0).toUpperCase() + s.slice(1) : s }

    readonly property var barOptions: [
        { id: "v1", label: "V1", detail: "Split islands", form: "islands" },
        { id: "v2", label: "V2", detail: page.cap(page.v2Form) + " shell", form: page.v2Form }
    ]
    readonly property int activeBarIndex: runningVariant === "v2" ? 1 : 0
    readonly property int shownBar: hoveredBar >= 0 ? hoveredBar : activeBarIndex

    readonly property var leftActions: [
        { id: "reload",     label: "Reload",     detail: "Reload the shell", glyph: "refresh" },
        { id: "bars",       label: "Bars",       detail: "Configure",        glyph: "view_agenda" },
        { id: "appearance", label: "Appearance", detail: "Widgets & icons",  glyph: "brush" },
        { id: "pickers",    label: "Pickers",    detail: "Media & images",   glyph: "collections" }
    ]
    readonly property var rightActions: [
        { id: "lock",     label: "Lock",     detail: "Lock session", glyph: "lock" },
        { id: "suspend",  label: "Suspend",  detail: "Sleep",        glyph: "bedtime" },
        { id: "reboot",   label: "Reboot",   detail: "System",       glyph: "restart_alt",       destructive: true },
        { id: "shutdown", label: "Shutdown", detail: "Power off",    glyph: "power_settings_new", destructive: true }
    ]

    function barStatus(o, active) {
        if (page.switching && root && root.variantHost && String(root.variantHost.switchTarget || "") === o.id) return "SWITCHING"
        return active ? "ACTIVE" : ""
    }
    function activateBar(id) {
        if (page.switching || id === page.runningVariant) return
        if (root && root.variantHost) root.variantHost.requestSwitch(id)
    }
    function activateAction(id) {
        if (id === "reboot" || id === "shutdown") {
            if (page.pending === id) { page.confirm(); return }
            page.pending = id; confirmTimer.restart(); return
        }
        page.pending = ""
        if (id === "reload") { Quickshell.reload(false); if (page.cc) page.cc.close() }
        else if (id === "bars" && page.cc) page.cc.open("bars")
        else if (id === "appearance" && page.cc) page.cc.open("appearance")
        else if (id === "pickers" && page.cc) page.cc.open("pickers")
        else if (id === "lock") { Quickshell.execDetached(["hyprlock"]); if (page.cc) page.cc.close() }
        else if (id === "suspend") { Quickshell.execDetached(["systemctl", "suspend"]); if (page.cc) page.cc.close() }
    }
    function confirm() {
        var id = page.pending
        page.pending = ""; confirmTimer.stop()
        if (id === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (id === "shutdown") Quickshell.execDetached(["systemctl", "poweroff"])
        if (page.cc) page.cc.close()
    }
    Timer { id: confirmTimer; interval: 5000; onTriggered: page.pending = "" }

    // ── a thin variant row (V1/V2) ──
    component VariantRow: Rectangle {
        id: vr
        required property var modelData
        required property int index
        readonly property bool active: page.activeBarIndex === vr.index
        readonly property string status: page.barStatus(vr.modelData, vr.active)
        width: parent ? parent.width : 0
        radius: page.ctlR
        color: vr.active ? Qt.rgba(page.acc.r, page.acc.g, page.acc.b, 0.09)
                         : (vrMa.containsMouse ? page.hoverFill : page.idleFill)
        border.width: 1
        border.color: vr.active ? Qt.rgba(page.acc.r, page.acc.g, page.acc.b, 0.52)
                                : (vrMa.containsMouse ? page.hoverBorder : page.idleBorder)
        Behavior on color { ColorAnimation { duration: 120 } }

        Column {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 11; anchors.rightMargin: 10
            spacing: 0
            Item {
                width: parent.width; height: label.implicitHeight
                UiText {
                    id: label
                    anchors.left: parent.left
                    text: vr.modelData.label
                    color: page.fg
                    opacity: vr.active ? 1 : 0.76
                    font.family: page.mono; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                UiText {
                    anchors.right: parent.right
                    text: vr.status
                    color: page.acc
                    opacity: vr.status === "" ? 0 : 0.82
                    font.family: page.mono; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.7
                }
            }
            UiText {
                width: parent.width
                text: vr.modelData.detail
                color: page.fg; opacity: 0.42
                elide: Text.ElideRight
                font.family: page.mono; font.pixelSize: 10
            }
        }
        MouseArea {
            id: vrMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: (page.switching || vr.active) ? Qt.ArrowCursor : Qt.PointingHandCursor
            onEntered: page.hoveredBar = vr.index
            onExited: if (page.hoveredBar === vr.index) page.hoveredBar = -1
            onClicked: page.activateBar(vr.modelData.id)
        }
    }

    // ── a thin action row (icon + label + detail; destructive → 2-tap confirm) ──
    component ActionRow: Rectangle {
        id: ar
        required property var modelData
        required property int index
        required property string side
        readonly property bool confirming: page.pending === String(ar.modelData.id || "")
        width: parent ? parent.width : 0
        radius: page.ctlR
        color: ar.confirming ? Qt.rgba(page.danger.r, page.danger.g, page.danger.b, 0.11)
                             : (arMa.containsMouse ? page.hoverFill : page.idleFill)
        border.width: 1
        border.color: ar.confirming ? page.danger
                                    : (arMa.containsMouse ? page.hoverBorder : page.idleBorder)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            anchors.left: parent.left; anchors.leftMargin: 9
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            IconText {
                anchors.verticalCenter: parent.verticalCenter
                width: 18; horizontalAlignment: Text.AlignHCenter
                text: ar.modelData.glyph
                color: ar.confirming ? page.danger : page.fg
                opacity: 0.88
                font.pixelSize: 17
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                UiText {
                    text: ar.confirming ? ("Confirm " + ar.modelData.label) : ar.modelData.label
                    color: ar.confirming ? page.danger : page.fg
                    font.family: page.mono; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                UiText {
                    text: ar.confirming ? "Click again" : ar.modelData.detail
                    color: page.fg; opacity: 0.42
                    font.family: page.mono; font.pixelSize: 10
                }
            }
        }
        MouseArea {
            id: arMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: { if (ar.side === "left") page.hoveredLeft = ar.index; else page.hoveredRight = ar.index }
            onExited: {
                if (ar.side === "left" && page.hoveredLeft === ar.index) page.hoveredLeft = -1
                if (ar.side === "right" && page.hoveredRight === ar.index) page.hoveredRight = -1
            }
            onClicked: page.activateAction(ar.modelData.id)
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 12

            // ── barLanding: variant rows + bezier routes + preview ──
            Item {
                id: barLanding
                width: parent.width
                height: 116
                readonly property real routeGap: 34
                readonly property real portOffset: 6

                Canvas {
                    id: routeCanvas
                    anchors.fill: parent
                    z: 2
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset(); ctx.clearRect(0, 0, width, height)
                        var n = page.barOptions.length
                        var rowH = (barCol.height - barCol.spacing * (n - 1)) / n
                        var startX = barCol.width + barLanding.portOffset
                        var endX = preview.x
                        var endY = preview.y + preview.height / 2
                        function route(i, emph) {
                            var sy = i * (rowH + barCol.spacing) + rowH / 2
                            var preview2 = (i === page.hoveredBar)
                            var c = emph ? page.acc
                                : preview2 ? Qt.rgba(page.acc.r, page.acc.g, page.acc.b, 0.54)
                                : Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.16)
                            ctx.beginPath(); ctx.moveTo(startX, sy)
                            ctx.bezierCurveTo(startX + (endX - startX) * 0.55, sy, endX - (endX - startX) * 0.55, endY, endX, endY)
                            ctx.strokeStyle = c; ctx.lineWidth = emph ? 1.7 : preview2 ? 1.25 : 1; ctx.stroke()
                            ctx.beginPath(); ctx.arc(startX, sy, 3.6, 0, Math.PI * 2); ctx.fillStyle = c; ctx.fill()
                        }
                        for (var i = 0; i < n; i++) if (i !== page.activeBarIndex) route(i, false)
                        route(page.activeBarIndex, true)
                        ctx.beginPath(); ctx.arc(endX, endY, 4.4, 0, Math.PI * 2); ctx.fillStyle = page.acc; ctx.fill()
                    }
                    Connections {
                        target: page
                        function onHoveredBarChanged() { routeCanvas.requestPaint() }
                        function onActiveBarIndexChanged() { routeCanvas.requestPaint() }
                        function onAccChanged() { routeCanvas.requestPaint() }
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }

                Column {
                    id: barCol
                    z: 1
                    anchors.left: parent.left
                    width: Math.min(270, parent.width * 0.42)
                    height: parent.height
                    spacing: 7
                    Repeater {
                        model: page.barOptions
                        delegate: VariantRow {
                            height: (barCol.height - barCol.spacing * (page.barOptions.length - 1)) / page.barOptions.length
                        }
                    }
                }

                Rectangle {
                    id: preview
                    z: 1
                    anchors.right: parent.right
                    width: parent.width - barCol.width - barLanding.routeGap
                    height: parent.height
                    radius: page.ctlR
                    color: pvMa.containsMouse ? page.hoverFill : page.idleFill
                    border.width: 1
                    border.color: pvMa.containsMouse ? page.hoverBorder : page.idleBorder
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.left: parent.left; anchors.top: parent.top
                        anchors.leftMargin: 14; anchors.topMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 14
                        spacing: 1
                        UiText {
                            text: page.switching ? "SWITCHING" : (page.hoveredBar >= 0 ? "BAR PREVIEW" : "ACTIVE BAR")
                            color: page.fg; opacity: 0.5
                            font.family: page.mono; font.pixelSize: 10; font.letterSpacing: 1
                        }
                        UiText {
                            text: page.barOptions[page.shownBar].id === "v2"
                                  ? ("V2 · " + page.cap(page.v2Form))
                                  : page.barOptions[page.shownBar].label
                            color: page.fg
                            font.family: page.mono; font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                    }
                    BarSilhouette {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        height: 44
                        root: page.root
                        form: page.barOptions[page.shownBar].form
                    }
                    MouseArea {
                        id: pvMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (page.cc) page.cc.open("bars")
                    }
                }
            }

            // ── actionDeck: two action columns + dotted rail ──
            Item {
                id: actionDeck
                width: parent.width
                height: 176

                Column {
                    id: leftCol
                    anchors.left: parent.left
                    width: Math.min(270, parent.width * 0.42)
                    height: parent.height
                    spacing: 5
                    Repeater {
                        model: page.leftActions
                        delegate: ActionRow {
                            side: "left"
                            height: (leftCol.height - leftCol.spacing * 3) / 4
                        }
                    }
                }

                Canvas {
                    id: railCanvas
                    x: leftCol.width
                    width: 34
                    height: parent.height
                    z: 2
                    antialiasing: true
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset(); ctx.clearRect(0, 0, width, height)
                        var rowH = (height - 5 * 3) / 4
                        var cx = width / 2
                        var idle = Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.18)
                        ctx.beginPath(); ctx.moveTo(cx, rowH / 2); ctx.lineTo(cx, height - rowH / 2)
                        ctx.strokeStyle = idle; ctx.lineWidth = 1; ctx.stroke()
                        for (var i = 0; i < 4; i++) {
                            var y = rowH / 2 + i * (rowH + 5)
                            var lh = page.hoveredLeft === i
                            var rh = page.hoveredRight === i
                            if (lh) {
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.bezierCurveTo(width * 0.25, y, width * 0.32, y, cx, y)
                                ctx.strokeStyle = page.acc; ctx.lineWidth = 1.35; ctx.stroke()
                                ctx.beginPath(); ctx.arc(0, y, 3.4, 0, Math.PI * 2); ctx.fillStyle = page.acc; ctx.fill()
                            }
                            if (rh) {
                                ctx.beginPath(); ctx.moveTo(cx, y); ctx.bezierCurveTo(width * 0.68, y, width * 0.75, y, width, y)
                                ctx.strokeStyle = page.acc; ctx.lineWidth = 1.35; ctx.stroke()
                                ctx.beginPath(); ctx.arc(width, y, 3.4, 0, Math.PI * 2); ctx.fillStyle = page.acc; ctx.fill()
                            }
                            ctx.beginPath(); ctx.arc(cx, y, (lh || rh) ? 3.2 : 2.7, 0, Math.PI * 2)
                            ctx.fillStyle = (lh || rh) ? page.acc : idle; ctx.fill()
                        }
                    }
                    Connections {
                        target: page
                        function onHoveredLeftChanged() { railCanvas.requestPaint() }
                        function onHoveredRightChanged() { railCanvas.requestPaint() }
                        function onAccChanged() { railCanvas.requestPaint() }
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }

                Column {
                    id: rightCol
                    anchors.right: parent.right
                    width: actionDeck.width - leftCol.width - railCanvas.width
                    height: parent.height
                    spacing: 5
                    Repeater {
                        model: page.rightActions
                        delegate: ActionRow {
                            side: "right"
                            height: (rightCol.height - rightCol.spacing * 3) / 4
                        }
                    }
                }
            }
        }
    }
}
