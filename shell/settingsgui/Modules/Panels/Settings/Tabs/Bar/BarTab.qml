import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services
import "common"
import "sidebar"
import "topnotch"

Item {
  id: root

  // true when the active bar design is the top-notch variant
  readonly property bool isTopNotch: BarDesign.templateId === "top-notch"

  implicitHeight: isTopNotch ? notchLayout.implicitHeight : sidebarLayout.implicitHeight
  Layout.fillWidth: true

  // --- Top-notch layout: Design / Behavior / Monitors / Notch ---
  ColumnLayout {
    id: notchLayout
    anchors.fill: parent
    spacing: 0
    visible: root.isTopNotch

    NTabBar {
      id: notchTabBar
      Layout.fillWidth: true
      Layout.bottomMargin: Style.marginM
      distributeEvenly: true
      currentIndex: notchTabView.currentIndex

      NTabButton { text: I18n.tr("common.design");   tabIndex: 0; checked: notchTabBar.currentIndex === 0 }
      NTabButton { text: I18n.tr("common.behavior"); tabIndex: 1; checked: notchTabBar.currentIndex === 1 }
      NTabButton { text: I18n.tr("common.monitors"); tabIndex: 2; checked: notchTabBar.currentIndex === 2 }
      NTabButton { text: I18n.tr("common.notch");    tabIndex: 3; checked: notchTabBar.currentIndex === 3 }
    }

    Item { Layout.fillWidth: true; Layout.preferredHeight: Style.marginS }

    NTabView {
      id: notchTabView
      currentIndex: notchTabBar.currentIndex

      DesignSubTab {}
      BehaviorSubTab {}
      MonitorsSubTab {}
      NotchSubTab {}
    }
  }

  // --- Sidebar layout: Design / Behavior / Monitors / Layout / Widgets ---
  ColumnLayout {
    id: sidebarLayout
    anchors.fill: parent
    spacing: 0
    visible: !root.isTopNotch

    NTabBar {
      id: sidebarTabBar
      Layout.fillWidth: true
      Layout.bottomMargin: Style.marginM
      distributeEvenly: true
      currentIndex: sidebarTabView.currentIndex

      NTabButton { text: I18n.tr("common.design");   tabIndex: 0; checked: sidebarTabBar.currentIndex === 0 }
      NTabButton { text: I18n.tr("common.behavior"); tabIndex: 1; checked: sidebarTabBar.currentIndex === 1 }
      NTabButton { text: I18n.tr("common.monitors"); tabIndex: 2; checked: sidebarTabBar.currentIndex === 2 }
      NTabButton { text: I18n.tr("common.layout");   tabIndex: 3; checked: sidebarTabBar.currentIndex === 3 }
      NTabButton { text: I18n.tr("common.widgets");  tabIndex: 4; checked: sidebarTabBar.currentIndex === 4 }
    }

    Item { Layout.fillWidth: true; Layout.preferredHeight: Style.marginS }

    NTabView {
      id: sidebarTabView
      currentIndex: sidebarTabBar.currentIndex

      DesignSubTab {}
      BehaviorSubTab {}
      MonitorsSubTab {}
      LayoutSubTab {}
      WidgetsSubTab {}
    }
  }
}
