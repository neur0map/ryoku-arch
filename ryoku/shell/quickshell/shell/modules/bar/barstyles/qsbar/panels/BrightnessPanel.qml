import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../RyokuPower.js" as RyokuPower

PanelWindow {
    id: briPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-brightness"

    readonly property int barBottom: 35
    readonly property int gap: 8

    property int percent: 0
    property int queuedSetPercent: -1
    property bool brightnessErrorNotified: false

    property real reveal: root.brightnessVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.brightnessVisible ? 160 : 120
            easing.type: root.brightnessVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.brightnessVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.brightnessVisible = false }

    function refresh() { briData.running = false; briData.running = true }

    function requestSetPercent(p) {
        queuedSetPercent = Math.max(1, Math.min(100, p))
        percent = queuedSetPercent
        setDebounce.restart()
    }

    function drainSetQueue() {
        if (setRunner.running || queuedSetPercent < 0) return
        var p = queuedSetPercent
        queuedSetPercent = -1
        setRunner.command = ["bash", "-c", RyokuPower.brightnessSetCmd(p + "%")]
        setRunner.running = true
    }

    function notifyBrightnessError(action, exitCode) {
        if (exitCode === 0 || brightnessErrorNotified) return
        brightnessErrorNotified = true
        brightnessErrNotify.command = ["bash", "-c",
            "notify-send -a 'QS-Shell' 'Brightness command failed' '" + action + " failed; brightness backend unavailable.' 2>/dev/null || true"]
        brightnessErrNotify.running = false
        brightnessErrNotify.running = true
    }

    function runStep(up) {
        var runner = up ? upRunner : downRunner
        if (runner.running) return
        runner.running = true
    }

    Rectangle {
        id: card
        width: 280
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.brightnessBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: briPanel.reveal
        focus: root.brightnessVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.brightnessVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Brightness"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.brightnessVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── interactive bar ──
            Item {
                width: parent.width
                height: 30
                UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: briPanel.percent + "%"
                    color: root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    id: track
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 8; radius: 4
                    color: root.fillActive
                    Rectangle {
                        width: parent.width * briPanel.percent / 100
                        height: parent.height; radius: 4; color: root.seal
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (e) => setFromX(e.x)
                        onPositionChanged: (e) => { if (pressed) setFromX(e.x) }
                        function setFromX(px) {
                            var p = Math.max(1, Math.min(100, Math.round(px / track.width * 100)))
                            briPanel.requestSetPercent(p)
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── +/- buttons ──
            Row {
                width: parent.width
                spacing: 8
                Rectangle {
                    id: btnDown
                    width: root.evenW((parent.width - 8) / 2); height: 28; radius: root.tileRadius
                    color: _dn.containsMouse ? root.fillHover : root.fillIdle
                    border.color: _dn.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: "− 5%"; color: _dn.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: _dn
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: briPanel.runStep(false)
                    }
                }
                Rectangle {
                    id: btnUp
                    width: root.evenW((parent.width - 8) / 2); height: 28; radius: root.tileRadius
                    color: _up.containsMouse ? root.fillHover : root.fillIdle
                    border.color: _up.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: "+ 5%"; color: _up.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 11
                    }
                    MouseArea {
                        id: _up
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: briPanel.runStep(true)
                    }
                }
            }
        }
    }

    Timer {
        id: setDebounce
        interval: 90
        repeat: false
        onTriggered: briPanel.drainSetQueue()
    }

    Process {
        id: briData
        command: ["bash", "-c", RyokuPower.brightnessPercentCmd]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text.trim())
                if (!isNaN(v)) briPanel.percent = Math.max(0, Math.min(100, v))
            }
        }
    }

    Process { id: brightnessErrNotify }
    Process {
        id: setRunner
        command: ["bash", "-c", "true"]
        onExited: (code) => {
            briPanel.notifyBrightnessError("Set brightness", code)
            if (briPanel.queuedSetPercent >= 0) briPanel.drainSetQueue()
            else briPanel.refresh()
        }
    }
    Process {
        id: upRunner
        command: ["bash", "-c", RyokuPower.brightnessSetCmd("+5%")]
        onExited: (code) => {
            briPanel.notifyBrightnessError("Brightness up", code)
            briPanel.refresh()
        }
    }
    Process {
        id: downRunner
        command: ["bash", "-c", RyokuPower.brightnessSetCmd("5%-")]
        onExited: (code) => {
            briPanel.notifyBrightnessError("Brightness down", code)
            briPanel.refresh()
        }
    }

    onVisibleChanged: { if (visible) refresh() }
}
