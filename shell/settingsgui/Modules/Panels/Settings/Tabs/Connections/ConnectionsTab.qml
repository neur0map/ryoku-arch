import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Services.Networking
import qs.settingsgui.Widgets

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
      text: I18n.tr("common.wifi")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: I18n.tr("common.bluetooth")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
      opacity: 0.6 // RYOKU: greyed preview marker — no bluetooth backend yet
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    WifiSubTab {}
    // RYOKU: bluetooth has no ryoku backend yet — greyed, non-interactive preview (still viewable)
    BluetoothSubTab {
      enabled: false
      opacity: 0.45
    }
  }
}
