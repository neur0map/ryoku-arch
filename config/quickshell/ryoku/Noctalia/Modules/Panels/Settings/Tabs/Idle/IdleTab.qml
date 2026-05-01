import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Noctalia.Commons
import qs.Noctalia.Services.Ryoku
import qs.Noctalia.Widgets

ColumnLayout {
  id: root
  spacing: 0
  enabled: false

  NText {
    text: RyokuFeatureAvailability.unavailableReason
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
  }

  NTabBar {
    id: subTabBar
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginM
    distributeEvenly: true
    currentIndex: tabView.currentIndex

    NTabButton {
      text: I18n.tr("panels.idle.tab-behavior")
      tabIndex: 0
      checked: subTabBar.currentIndex === 0
    }
    NTabButton {
      text: I18n.tr("panels.idle.tab-custom")
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

    BehaviorSubTab {}
    CustomSubTab {}
  }
}
