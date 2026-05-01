import QtQuick
import Quickshell.Services.Pipewire
import "../../"
import "../../shapes/"
import "../../services/home/."

Item {
  id: root

  property bool active: false

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volume: sink?.ready ? Math.max(0, Math.min(1, sink.audio.volume)) : 0
  readonly property int pct: Math.round(volume * 100)
  readonly property bool muted: sink?.ready ? sink.audio.muted : false
  readonly property string icon: {
    if (!sink?.ready) return "󰕾"
    if (muted) return "󰝟"
    if (volume > 0.6) return "󰕾"
    if (volume > 0.2) return "󰖀"
    return "󰕿"
  }

  implicitWidth: 150
  implicitHeight: 28
  visible: active || y > -height
  y: active ? Theme.notchHeight - 8 : -height - 2

  Behavior on y {
    enabled: !Theme.staticMode
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  Connections {
    target: VolumeFeedback
    function onSerialChanged() {
      hideTimer.restart()
    }
  }

  Timer {
    id: hideTimer
    interval: 1250
    repeat: false
    onTriggered: VolumeFeedback.hide()
  }

  PopupShape {
    anchors.fill: parent
    attachedEdge: "top"
    radius: 13
    flareWidth: 13
    flareHeight: 8
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.94)
    strokeWidth: 1
    strokeColor: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.34)
  }

  Row {
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
      leftMargin: 10
      rightMargin: 10
    }
    spacing: 6

    Text {
      width: 16
      text: root.icon
      color: root.muted ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.56) : Theme.text
      font.pixelSize: 14
      font.letterSpacing: 0
      horizontalAlignment: Text.AlignHCenter
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      width: 36
      text: root.muted ? "MUTED" : root.pct + "%"
      color: root.muted ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.62) : Theme.text
      font.family: "JetBrains Mono"
      font.pixelSize: root.muted ? 9 : 11
      font.weight: Font.Bold
      font.letterSpacing: 0
      horizontalAlignment: Text.AlignRight
      anchors.verticalCenter: parent.verticalCenter
    }

    Item {
      width: Math.max(52, parent.width - 16 - 36 - parent.spacing * 2)
      height: 11
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors {
          left: parent.left
          right: parent.right
          verticalCenter: parent.verticalCenter
        }
        height: 2
        radius: 1
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15)
      }

      WaveBar {
        anchors.fill: parent
        value: root.muted ? 0 : root.volume
        color: Theme.active
        wavelength: 12
        amplitude: 1.8
        strokeWidth: 2
        speed: 1400
        valueDuration: 140
      }
    }
  }
}
