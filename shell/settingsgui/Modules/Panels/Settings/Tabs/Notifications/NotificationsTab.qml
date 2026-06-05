import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU: Sound and Rules subtabs were removed. The Ryoku notification backend
// has no sound playback and no per-app rule engine, so those upstream subtabs had no
// backing and were dropped rather than shipped as dead UI.
ColumnLayout {
  id: root
  spacing: 0

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: false
    currentIndex: tabView.currentIndex

    NTabButton {
      text: I18n.tr("common.appearance")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: I18n.tr("common.duration")
      tabIndex: 1
      checked: subTabBar.currentIndex === 1
    }
    NTabButton {
      text: I18n.tr("common.toast")
      tabIndex: 2
      checked: subTabBar.currentIndex === 2
    }
    NTabButton {
      text: I18n.tr("common.history")
      tabIndex: 3
      checked: subTabBar.currentIndex === 3
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Style.marginL
  }

  NTabView {
    id: tabView
    currentIndex: subTabBar.currentIndex

    GeneralSubTab {}
    DurationSubTab {}
    ToastSubTab {}
    HistorySubTab {}
  }
}
