import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  enabled: false
  opacity: 0.45

  // TODO: wire notification rules to ryoku (no NotificationRulesService / notification filter rules
  //   in ryoku; ryoku uses mako/dunst directly with no in-shell rule management)

  NLabel {
    label: I18n.tr("panels.notifications.rules-label")
    description: I18n.tr("panels.notifications.rules-description")
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    Layout.bottomMargin: Style.marginS
  }

  NButton {
    text: I18n.tr("panels.notifications.rules-add")
    icon: "add"
    enabled: false
  }
}
