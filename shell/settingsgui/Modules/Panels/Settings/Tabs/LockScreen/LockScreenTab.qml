import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU: the lock screen is qylock (github.com/Darkkal44/qylock). Themes subtab is the
// preview gallery + theme selection + refresh; Customize surfaces the active theme's
// own theme.conf options. Backed by the LockThemes service.
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
      text: qsTr("Themes")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: qsTr("Customize")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    ThemesSubTab {}
    CustomizeSubTab {}
  }
}
