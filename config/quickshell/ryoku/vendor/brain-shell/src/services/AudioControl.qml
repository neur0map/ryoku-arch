import QtQuick
import Quickshell.Services.Pipewire
import "../components"
import "../"

Item {
    id: root

    readonly property var sink:   Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    
    function reset() { switcher.reset() }

    PwObjectTracker {
        objects: Pipewire.nodes.values
    }

    readonly property var sinkNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && !n.isStream && n.isSink)
                result.push(n)
        }
        return result
    }

    readonly property var sourceNodes: {
        var result = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n.audio !== null && !n.isStream && !n.isSink)
                result.push(n)
        }
        return result
    }

    function deviceName(node) {
        return node.nickname || node.description || node.name || "Unknown"
    }

    property string page: "output"

    Row {
        anchors.fill: parent
        spacing: 8

        // ── Page content ──────────────────────────────────────────────────────
        Item {
            width:  parent.width - switcher.implicitWidth - parent.spacing - 1 - parent.spacing
            height: parent.height
            clip:   true

            // Output
            PopupPage {
                anchors.fill: parent
                visible:      root.page === "output"

                ChannelColumn {
                    width:  parent.width
                    label:  root.sink?.ready ? root.deviceName(root.sink) : "Output"
                    icon: {
                        if (!root.sink?.ready)           return "󰕾"
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
                        if (root.sink?.ready)
                            root.sink.audio.muted = !root.sink.audio.muted
                    }
                }
            }

            // Input
            PopupPage {
                anchors.fill: parent
                visible:      root.page === "input"

                ChannelColumn {
                    width:  parent.width
                    label:  root.source?.ready ? root.deviceName(root.source) : "Input"
                    icon:   root.source?.audio.muted ? "󰍭" : "󰍬"
                    value:  root.source?.ready ? root.source.audio.volume : 0
                    muted:  root.source?.audio.muted ?? false
                    active: root.source?.ready ?? false
                    onVolumeChanged: function(v) {
                        if (root.source?.ready) root.source.audio.volume = v
                    }
                    onMuteToggled: {
                        if (root.source?.ready)
                            root.source.audio.muted = !root.source.audio.muted
                    }
                }
            }

            // Mixer
            PopupPage {
                anchors.fill: parent
                visible:      root.page === "mixer"

                SectionLabel { text: "Output Devices" }

                Repeater {
                    model: root.sinkNodes
                    delegate: DeviceRow {
                        width:     parent.width
                        label:     root.deviceName(modelData)
                        isDefault: root.sink?.ready && modelData.name === root.sink.name
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }

                Text {
                    visible:        root.sinkNodes.length === 0
                    text:           "No output devices"
                    color:          Qt.rgba(1,1,1,0.2)
                    font.pixelSize: 11
                    leftPadding:    10
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                SectionLabel { text: "Input Devices" }

                Repeater {
                    model: root.sourceNodes
                    delegate: DeviceRow {
                        width:     parent.width
                        label:     root.deviceName(modelData)
                        isDefault: root.source?.ready && modelData.name === root.source.name
                        onClicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }

                Text {
                    visible:        root.sourceNodes.length === 0
                    text:           "No input devices"
                    color:          Qt.rgba(1,1,1,0.2)
                    font.pixelSize: 11
                    leftPadding:    10
                }
            }
        }

        // Divider
        Rectangle {
            width: 1; height: parent.height
            color: Qt.rgba(1, 1, 1, 0.1)
        }

        // Tab switcher — right side
        TabSwitcher {
            id: switcher
            orientation: "vertical"
            height: (parent.height - 17)
            anchors.verticalCenter: parent.verticalCenter
            model: [
                { key: "output", icon: "󰕾" },
                { key: "input",  icon: "󰍬" },
                { key: "mixer",  icon: "󰾝" },
            ]
            currentPage: root.page
            onPageChanged: function(key) { root.page = key }
        }
    }

    // ── ChannelColumn ─────────────────────────────────────────────────────────
    component ChannelColumn: Item {
        id: col

        property string label:  ""
        property string icon:   ""
        property real   value:  0.0
        property bool   muted:  false
        property bool   active: false

        readonly property int trackHeight: 160
        readonly property int barW:        22
        readonly property int thumbD:      barW - 6

        signal volumeChanged(real value)
        signal muteToggled()

        // Expose size so PopupPage Flickable can measure content
        implicitWidth:  inner.implicitWidth
        implicitHeight: inner.implicitHeight

        readonly property string pctText:
            active ? Math.round(value * 100) + "%" : "--%"

        Column {
            id: inner
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

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

                    // Drag to change volume
                    MouseArea {
                        anchors.fill: parent
                        cursorShape:  Qt.SizeVerCursor
                        function calc(my) {
                            var travel = track.height - thumb.height
                            return Math.max(0.0, Math.min(1.0,
                                1.0 - (my - thumb.height / 2) / travel))
                        }
                        onPressed:         col.volumeChanged(calc(mouseY))
                        onPositionChanged: if (pressed) col.volumeChanged(calc(mouseY))
                    }

                    // Scroll wheel to change volume
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

            // Mute button
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width:  col.barW + 32
                height: 28
                radius: Theme.cornerRadius
                color:  col.muted
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2)
                            : Qt.rgba(1,1,1,0.06)
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text:           col.icon
                        font.pixelSize: 13
                        color:          col.muted ? Theme.active : Qt.rgba(1,1,1,0.55)
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text:           col.muted ? "Muted" : "Mute"
                        font.pixelSize: 11
                        color:          col.muted ? Theme.active : Qt.rgba(1,1,1,0.4)
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: parent.radius
                    color: muteHov.hovered ? Qt.rgba(1,1,1,0.05) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                HoverHandler { id: muteHov; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: col.muteToggled() }
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
                width:           col.barW + 60
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── SectionLabel ──────────────────────────────────────────────────────────
    component SectionLabel: Text {
        color:           Qt.rgba(1, 1, 1, 0.35)
        font.pixelSize:  10
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
        leftPadding: 4
        topPadding:  2
    }

    // ── DeviceRow ─────────────────────────────────────────────────────────────
    component DeviceRow: Item {
        id: row
        implicitHeight: 28

        property string label:     ""
        property bool   isDefault: false
        signal clicked()

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadius - 4
            color:  row.isDefault
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                        : (rowHov.hovered ? Qt.rgba(1,1,1,0.05) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Row {
            anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 6

            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: row.isDefault ? Theme.active : Qt.rgba(1,1,1,0.2)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                text:           row.label
                color:          row.isDefault ? Theme.text : Qt.rgba(1,1,1,0.5)
                font.pixelSize: 11
                elide:          Text.ElideRight
                width:          parent.width - 14 - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: row.clicked() }
    }
}
