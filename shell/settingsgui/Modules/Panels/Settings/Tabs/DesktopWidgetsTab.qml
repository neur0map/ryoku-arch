import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.settingsgui.Modules.Panels.Settings.Tabs.DesktopWidgets

ColumnLayout {
  id: root
  spacing: 0

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: qsTr("Built-in")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: qsTr("Custom")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginS
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    BuiltinSubTab {}
    CustomSubTab {}
  }
}
