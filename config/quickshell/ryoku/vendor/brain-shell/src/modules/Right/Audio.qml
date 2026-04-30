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

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Text {
            id: iconText
            text:           root.icon
            color:          Theme.text
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text:           root.pct + "%"
            color:          Theme.text
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
            visible:        root.showPercentage
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
