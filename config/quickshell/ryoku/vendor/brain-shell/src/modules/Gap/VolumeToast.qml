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
  readonly property real wrapperRadius: 9
  readonly property color wrapperColor: Theme.background
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

  Shape {
    id: wrapperShape
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: root.wrapperColor
      strokeColor: "transparent"
      strokeWidth: 0
      joinStyle: ShapePath.RoundJoin

      PathSvg {
        path: root._wrapperPath(root.width, root.height, root.wrapperRadius)
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

  function _wrapperPath(w, h, r) {
    return "M 0 0"
      + " L " + w + " 0"
      + " L " + w + " " + (h - r)
      + " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + h
      + " L " + r + " " + h
      + " A " + r + " " + r + " 0 0 1 0 " + (h - r)
      + " Z"
  }
}
