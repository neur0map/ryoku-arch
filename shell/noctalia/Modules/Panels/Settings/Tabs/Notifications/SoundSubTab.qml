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

  // Interface kept for NotificationsTab.qml compatibility (greyed content doesn't use these).
  signal openUnifiedPicker
  signal openLowPicker
  signal openNormalPicker
  signal openCriticalPicker

  // TODO: wire notification sounds to ryoku (no notification sound config in ryoku notifsconfig;
  //   SoundService / QtMultimedia not available in ryoku shell)

  NToggle {
    label: I18n.tr("panels.notifications.sounds-enabled-label")
    description: I18n.tr("panels.notifications.sounds-enabled-description")
    checked: false
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.sounds-volume-label")
    description: I18n.tr("panels.notifications.sounds-volume-description")
    from: 0
    to: 1
    stepSize: 0.01
    value: 0.5
    text: "50%"
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.sounds-separate-label")
    description: I18n.tr("panels.notifications.sounds-separate-description")
    checked: false
  }
}
