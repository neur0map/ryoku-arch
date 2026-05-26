import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NComboBox {
    // TODO: wire bar mouse-wheel action to ryoku (no mouseWheelAction config in ryoku barconfig)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.behavior-workspace-scroll-label")
    description: I18n.tr("panels.bar.behavior-workspace-scroll-description")
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "none",
        "name": I18n.tr("common.none")
      }
    ]
    currentKey: "none"
  }

  NToggle {
    // TODO: wire reverse-scroll to ryoku (no reverseScroll config in ryoku barconfig)
    Layout.fillWidth: true
    label: I18n.tr("panels.general.reverse-scrolling-label")
    description: I18n.tr("panels.general.reverse-scrolling-description")
    checked: false
    enabled: false
    opacity: 0.45
    visible: false
  }

  NToggle {
    // TODO: wire mouse-wheel wrap to ryoku (no mouseWheelWrap config in ryoku barconfig)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.behavior-wheel-wrap-label")
    description: I18n.tr("panels.bar.behavior-wheel-wrap-description")
    checked: false
    enabled: false
    opacity: 0.45
    visible: false
  }

  NComboBox {
    // TODO: wire middle-click action to ryoku (no middleClickAction config in ryoku barconfig)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.behavior-middle-click-label")
    description: I18n.tr("panels.bar.behavior-middle-click-description")
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "none",
        "name": I18n.tr("common.none")
      }
    ]
    currentKey: "none"
  }

  NComboBox {
    // TODO: wire right-click action to ryoku (no rightClickAction config in ryoku barconfig)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.behavior-right-click-label")
    description: I18n.tr("panels.bar.behavior-right-click-description")
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "none",
        "name": I18n.tr("common.none")
      }
    ]
    currentKey: "none"
  }
}
