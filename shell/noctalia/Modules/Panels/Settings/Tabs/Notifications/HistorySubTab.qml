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

  // TODO: wire notification history controls to ryoku (no clearDismissed, enableMarkdown,
  //   saveToHistory.low/normal/critical config in ryoku notifsconfig)

  NToggle {
    label: I18n.tr("panels.notifications.history-clear-dismiss-label")
    description: I18n.tr("panels.notifications.history-clear-dismiss-description")
    checked: false
  }

  NToggle {
    label: I18n.tr("panels.notifications.settings-markdown-label")
    description: I18n.tr("panels.notifications.settings-markdown-description")
    checked: false
  }

  NToggle {
    label: I18n.tr("panels.notifications.history-low-urgency-label")
    description: I18n.tr("panels.notifications.history-low-urgency-description")
    checked: true
  }

  NToggle {
    label: I18n.tr("panels.notifications.history-normal-urgency-label")
    description: I18n.tr("panels.notifications.history-normal-urgency-description")
    checked: true
  }

  NToggle {
    label: I18n.tr("panels.notifications.history-critical-urgency-label")
    description: I18n.tr("panels.notifications.history-critical-urgency-description")
    checked: true
  }
}
