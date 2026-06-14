import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
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
      text: I18n.tr("common.info")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    // RYOKU: Contributors/Supporters (upstream GitHub/donations) removed;
    // Upstream attribution moved to a dedicated Credits subtab.
    NTabButton {
      text: "Credits"
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

    VersionSubTab {}
    CreditsSubTab {}
  }
}
