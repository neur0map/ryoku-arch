import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

// RYOKU WIRED: Notifs (Notifs.qml). ryoku always persists history to notifs.json and
// auto-detects markdown, so the upstream clear-on-dismiss / markdown / per-urgency
// history toggles have no backend and were dropped. What ryoku does expose is the
// stored history and a clear action, so that is what this subtab drives.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property bool confirming: false

  NText {
    Layout.fillWidth: true
    text: qsTr("Notifications are kept after they leave the screen and survive a shell reload. Markdown bodies render automatically.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NText {
    Layout.fillWidth: true
    text: qsTr("Stored notifications: %1").arg(Notifs.list.length)
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: qsTr("Clear history")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }
  NText {
    Layout.fillWidth: true
    text: qsTr("Dismiss every stored notification. This cannot be undone.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  RowLayout {
    spacing: Style.marginM

    NButton {
      visible: !root.confirming
      enabled: Notifs.list.length > 0
      text: qsTr("Clear all notifications")
      icon: "trash"
      backgroundColor: Color.mError
      onClicked: root.confirming = true
    }
    NButton {
      visible: root.confirming
      text: qsTr("Confirm clear")
      icon: "trash"
      backgroundColor: Color.mError
      onClicked: {
        // Snapshot first: close() mutates Notifs.list as it removes each item.
        const items = Notifs.list;
        for (let i = 0; i < items.length; i++)
          items[i].close();
        root.confirming = false;
      }
    }
    NButton {
      visible: root.confirming
      text: qsTr("Cancel")
      outlined: true
      onClicked: root.confirming = false
    }
  }
}
