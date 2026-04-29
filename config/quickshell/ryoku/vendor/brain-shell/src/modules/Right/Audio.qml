import QtQuick
import Quickshell.Services.Pipewire
import "../../components"
import "../../"

Item {
    id: root

    property bool showPercentage: false

    implicitWidth:  row.implicitWidth + 16
    implicitHeight: Theme.notchHeight

    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property string icon: {
        if (!sink?.ready)            return "󰕾"
        if (sink.audio.muted)        return "󰝟"
        if (sink.audio.volume > 0.6) return "󰕾"
        if (sink.audio.volume > 0.2) return "󰖀"
        return "󰕿"
    }

    readonly property int pct: sink?.ready ? Math.round(sink.audio.volume * 100) : 0

    HoverHandler {
        id: hov
    }

    // Ryoku: subtle background highlight on hover. Animates reliably
    // (Rectangle.color is a true color property) where Text.color
    // animations have been flaky.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius:  6
        color:   hov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.0)
        Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.OutQuart } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            id: iconText
            text:           root.icon
            color:          hov.hovered ? Theme.active : Theme.text
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuart } }
        }

        Text {
            text:           root.pct + "%"
            color:          hov.hovered ? Theme.active : Theme.text
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
            visible:        root.showPercentage || hov.hovered
            Behavior on color { ColorAnimation { duration: 700; easing.type: Easing.OutQuart } }
        }
    }

    MouseArea {
        anchors.fill:        parent
        acceptedButtons:     Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (root.sink?.ready)
                    root.sink.audio.muted = !root.sink.audio.muted
            } else {
                var next = !Popups.audioOpen
                Popups.closeAll()
                Popups.audioOpen = next
            }
        }
    }
}
