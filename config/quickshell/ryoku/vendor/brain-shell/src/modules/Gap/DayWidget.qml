import QtQuick
import "../../"

Item {
  id: root

  property bool active: true
  property string dayText: ""

  implicitWidth: dayLabel.implicitWidth + 20
  implicitHeight: Theme.notchHeight
  visible: active || opacity > 0.01
  opacity: active ? 1 : 0

  Behavior on opacity {
    enabled: !Theme.staticMode
    NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
  }

  Text {
    id: dayLabel
    anchors.centerIn: parent
    text: root.dayText
    color: Theme.text
    opacity: 0.86
    renderType: Text.NativeRendering
    font.family: "iA Writer Quattro S"
    font.pixelSize: 19
    font.weight: Font.Bold
    font.letterSpacing: 0
  }

  Rectangle {
    anchors {
      horizontalCenter: dayLabel.horizontalCenter
      top: dayLabel.bottom
      topMargin: 1
    }
    width: Math.min(dayLabel.implicitWidth, 44)
    height: 1
    radius: 1
    color: Theme.active
    opacity: 0.42
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.updateDay()
  }

  function updateDay() {
    root.dayText = Qt.formatDateTime(new Date(), "dddd").toUpperCase()
  }

  Component.onCompleted: updateDay()
}
