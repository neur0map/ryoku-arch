import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Pipewire
import "../../"
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

  implicitWidth: 142
  implicitHeight: 22
  visible: active || y > -height + 1
  y: active ? (Theme.notchHeight - height) / 2 : -height

  Behavior on y {
    enabled: !Theme.staticMode
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
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

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.74)
    border.width: 1
    border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.32)
    antialiasing: true
  }

  Shape {
    id: topbarCornerCaps
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: Theme.background
      strokeColor: "transparent"
      strokeWidth: 0

      PathSvg {
        path: "M 0 0 L 16 0 Q 16 8 8 8 L 0 8 Z"
      }
    }

    ShapePath {
      fillColor: Theme.background
      strokeColor: "transparent"
      strokeWidth: 0

      PathSvg {
        path: "M " + root.width + " 0 L " + (root.width - 16) + " 0 Q " + (root.width - 16) + " 8 " + (root.width - 8) + " 8 L " + root.width + " 8 Z"
      }
    }
  }

  Row {
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
      leftMargin: 4
      rightMargin: 4
    }
    spacing: 5

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
      width: 34
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
      width: Math.max(48, parent.width - 16 - 34 - parent.spacing * 2)
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
