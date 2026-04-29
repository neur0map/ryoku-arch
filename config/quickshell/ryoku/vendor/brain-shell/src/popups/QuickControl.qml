import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../shapes"
import "../components"
import "../services"
import "../"

PopupWindow {
    id: root

    required property var anchorWindow

    // ── Config ────────────────────────────────────────────────────────────────
    readonly property int fw: Theme.cornerRadius
    readonly property int fh: Theme.cornerRadius
    readonly property int popupHeight: 340
    readonly property int popupWidth:  180 // Thinner than the 300px AudioPopup

    color:   "transparent"
    visible: slide.windowVisible
    mask:    Region { item: maskProxy }

    // ── Position: Right Center ────────────────────────────────────────────────
    anchor.window:  anchorWindow
    anchor.rect: Qt.rect(
        anchorWindow.width - root.fw,
        (root.screen.height + root.fh + 5)/2,
        0,
        0
    )
    anchor.gravity: Edges.Right
    
    Item {
        id:      maskProxy
        x:       root.popupWidth - sizer.width
        y:       ((root.popupHeight - sizer.height) / 2) - root.fh
        width:   sizer.width
        height:  sizer.height
    }

    implicitWidth:  popupWidth
    implicitHeight: popupHeight

    // ── Audio State ───────────────────────────────────────────────────────────
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    // ── Brightness State ──────────────────────────────────────────────────────
    property real _bVal:  0.72
    property int  _bMax:  100
    property bool _bBusy: false

    Process {
        id: brightRead
        command: ["bash", "-c", "brightnessctl -m"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.split(",")
                if (parts.length >= 5) {
                    var cur = parseInt(parts[2])
                    var max = parseInt(parts[4])
                    if (max > 0) {
                        root._bMax = max
                        root._bVal = cur / max
                    }
                }
            }
        }
    }

    Process {
        id: brightWrite
        command: ["bash", "-c", "brightnessctl set " + (Math.round(root._bVal * root._bMax) <= 0 ? 2 : Math.round(root._bVal * root._bMax))]
        running: false
        onRunningChanged: if (!running) root._bBusy = false
    }

    Timer {
        id: bDebounce
        interval: 50; repeat: false
        onTriggered: { root._bBusy = true; brightWrite.running = true }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: if (!root._bBusy) brightRead.running = true
    }

    Component.onCompleted: brightRead.running = true

    function setBrightness(v) {
        root._bVal = Math.max(0.0, Math.min(1.0, v))
        bDebounce.restart()
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    PopupSlide {
        id: slide
        anchors.fill:     parent
        edge:             "right"
        open:             Popups.quickOpen 
        hoverEnabled:     true
        triggerHovered:   Popups.quickTriggerHovered 
        onCloseRequested: Popups.quickOpen = false

        Item {
            id: sizer
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            width:  root.popupWidth
            height: root.popupHeight

            Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

            PopupShape {
                id: bg
                anchors.fill: parent
                attachedEdge: "right"
                color:        Theme.background
                radius:       Theme.cornerRadius
                flareWidth:   root.fw
                flareHeight:  root.fh
            }

            // ── Sliders Layout ────────────────────────────────────────────────
            Row {
                anchors {
                    fill:         parent
                    topMargin:    root.fh + 30
                    leftMargin:   8
                    rightMargin:  8
                }
                spacing: 8 
                anchors.horizontalCenter: parent.horizontalCenter

                // Audio Slider
                ChannelColumn {
                    icon: {
                        if (!root.sink?.ready)            return "󰕾"
                        if (root.sink.audio.muted)        return "󰖁"
                        if (root.sink.audio.volume > 0.6) return "󰕾"
                        if (root.sink.audio.volume > 0.2) return "󰖀"
                        return "󰕿"
                    }
                    value:  root.sink?.ready ? root.sink.audio.volume : 0
                    muted:  root.sink?.audio.muted ?? false
                    active: root.sink?.ready ?? false
                    
                    onVolumeChanged: function(v) {
                        if (root.sink?.ready) root.sink.audio.volume = v
                    }
                    onMuteToggled: {
                        if (root.sink?.ready) root.sink.audio.muted = !root.sink.audio.muted
                    }
                }

                // Brightness Slider
                ChannelColumn {
                    icon:   "󰃠"
                    value:  root._bVal 
                    muted:  false
                    active: true
                    
                    onVolumeChanged: function(v) {
                        root.setBrightness(v)
                    }
                }
            }
        }
    }

    // ── Reusable ChannelColumn Component ──────────────────────────────────────
    component ChannelColumn: Item {
        id: col

        property string label:  ""
        property string icon:   ""
        property real   value:  0.0
        property bool   muted:  false
        property bool   active: false

        readonly property int trackHeight: 180
        readonly property int barW:        22
        readonly property int thumbD:      barW - 6

        signal volumeChanged(real value)
        signal muteToggled()

        implicitWidth:  inner.implicitWidth
        implicitHeight: inner.implicitHeight

        readonly property string pctText: active ? Math.round(value * 100) + "%" : "--%"

        Column {
            id: inner
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           col.pctText
                color:          col.muted ? Qt.rgba(1,1,1,0.25) : Theme.text
                font.pixelSize: 13
                font.bold:      true
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  col.barW
                height: col.trackHeight

                Rectangle {
                    id: track
                    anchors.fill: parent
                    radius: width / 2
                    color:  Qt.rgba(1,1,1,0.08)

                    // Fill bar
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: Math.max(radius * 2, parent.height * col.value)
                        radius: parent.radius
                        color:  col.muted ? Qt.rgba(1,1,1,0.15) : Theme.active
                        Behavior on color  { ColorAnimation  { duration: 150 } }
                        Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    }

                    // Thumb
                    Rectangle {
                        id: thumb
                        anchors.horizontalCenter: parent.horizontalCenter
                        width:  col.thumbD
                        height: width
                        radius: width / 2
                        color:  col.muted ? Qt.rgba(1,1,1,0.3) : "#ffffff"
                        y: {
                            var travel = track.height - height
                            return Math.max(0, Math.min(travel, (1.0 - col.value) * travel))
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Drag to change value
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.SizeVerCursor
                        function calc(my) {
                            var travel = track.height - thumb.height
                            return Math.max(0.0, Math.min(1.0, 1.0 - (my - thumb.height / 2) / travel))
                        }
                        onPressed:         col.volumeChanged(calc(mouseY))
                        onPositionChanged: if (pressed) col.volumeChanged(calc(mouseY))
                    }

                    // Scroll wheel to change value
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            var step = 0.05
                            var delta = event.angleDelta.y > 0 ? step : -step
                            col.volumeChanged(Math.max(0.0, Math.min(1.0, col.value + delta)))
                        }
                    }
                }
            }

            // Icon & Mute Toggle
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  col.barW + 16
                height: 28
                radius: Theme.cornerRadius
                color:  col.muted
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2)
                            : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text:           col.icon
                    font.pixelSize: 14
                    color:          col.muted ? Theme.active : Qt.rgba(1,1,1,0.55)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: muteHov.hovered ? Qt.rgba(1,1,1,0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                HoverHandler { id: muteHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: col.muteToggled()}
            }

            // Label
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:            col.label
                color:           Qt.rgba(1,1,1,0.3)
                font.pixelSize:  10
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
                elide:           Text.ElideRight
                width:           col.barW + 50
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}