import QtQuick
import Quickshell.Services.Pipewire
import "../../"

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

  implicitWidth: 186
  implicitHeight: 26
  visible: active || opacity > 0.01
  opacity: active ? 1 : 0
  scale: active ? 1 : 0.96
  transformOrigin: Item.Right

  Behavior on opacity {
    enabled: !Theme.staticMode
    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
  }

  Behavior on scale {
    enabled: !Theme.staticMode
    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
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
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.94)
    border.width: 1
    border.color: Qt.rgba(Theme.border.r, Theme.border.g, Theme.border.b, 0.34)
  }

  Row {
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
      leftMargin: 11
      rightMargin: 11
    }
    spacing: 8

    Text {
      width: 18
      text: root.icon
      color: root.muted ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.56) : Theme.text
      font.pixelSize: 14
      font.letterSpacing: 0
      horizontalAlignment: Text.AlignHCenter
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      width: 48
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
      width: Math.max(46, parent.width - 18 - 48 - parent.spacing * 2)
      height: 5
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15)
      }

      Rectangle {
        anchors {
          left: parent.left
          top: parent.top
          bottom: parent.bottom
        }
        width: root.muted ? 0 : parent.width * root.volume
        radius: height / 2
        color: Theme.active

        Behavior on width {
          enabled: !Theme.staticMode
          NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
      }
    }
  }
}
