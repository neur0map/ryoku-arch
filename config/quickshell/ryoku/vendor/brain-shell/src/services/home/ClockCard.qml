import QtQuick
import "../../"
import "../../components"

// ClockCard - clock-only dashboard card.

StatCard {
  id: root
  padding: 0

  property string _hStr: "00"
  property string _mStr: "00"
  property string _sec: "00"

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root._tick()
  }

  Component.onCompleted: root._tick()

  function _zp(n) {
    return n < 10 ? "0" + n : "" + n
  }

  function _tick() {
    var d = new Date()
    root._hStr = root._zp(d.getHours())
    root._mStr = root._zp(d.getMinutes())
    root._sec = root._zp(d.getSeconds())
  }

  Item {
    anchors.fill: parent

    Row {
      anchors.centerIn: parent
      spacing: 10

      Item {
        anchors.verticalCenter: parent.verticalCenter
        readonly property int charOffset: 40
        width: hhText.implicitWidth + charOffset
        height: hhText.implicitHeight + mmText.implicitHeight - 8

        Text {
          id: hhText
          anchors.left: parent.left
          anchors.top: parent.top
          text: root._hStr
          font.pixelSize: 72
          font.weight: Font.Bold
          font.family: "JetBrains Mono"
          font.letterSpacing: 0
          color: Theme.text
        }

        Text {
          id: mmText
          anchors.left: parent.left
          anchors.leftMargin: parent.charOffset
          anchors.top: hhText.bottom
          anchors.topMargin: -8
          text: root._mStr
          font.pixelSize: 72
          font.weight: Font.Bold
          font.family: "JetBrains Mono"
          font.letterSpacing: 0
          color: Theme.active
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root._sec
        font.pixelSize: 22
        font.weight: Font.Medium
        font.family: "JetBrains Mono"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
      }
    }
  }
}
