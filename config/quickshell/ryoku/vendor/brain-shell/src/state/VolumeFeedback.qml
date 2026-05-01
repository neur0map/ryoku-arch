pragma Singleton
import QtQuick

QtObject {
  id: root

  property bool visible: false
  property int serial: 0

  function show() {
    serial += 1
    visible = true
  }

  function hide() {
    visible = false
  }
}
