import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Services.System
import qs.noctalia.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var addMonitor
  property var removeMonitor

  NToggle {
    // TODO: wire notifications master enable to ryoku (no GlobalConfig.notifs.enabled toggle)
    label: I18n.tr("panels.notifications.settings-enabled-label")
    description: I18n.tr("panels.notifications.settings-enabled-description")
    checked: true
    enabled: false
    opacity: 0.45
  }

  ColumnLayout {
    spacing: Style.marginL

    NComboBox {
      // TODO: wire density to ryoku (no notification density config in ryoku)
      label: I18n.tr("panels.notifications.settings-density-label")
      description: I18n.tr("panels.notifications.settings-density-description")
      enabled: false
      opacity: 0.45
      model: [
        {
          "key": "default",
          "name": I18n.tr("options.notification-density.default")
        },
        {
          "key": "compact",
          "name": I18n.tr("options.notification-density.compact")
        }
      ]
      currentKey: "default"
    }

    NToggle {
      // RYOKU WIRED: Notifs.dnd (Notifs.qml:20) — toggleDnd via IpcHandler or direct property
      label: I18n.tr("tooltips.do-not-disturb-enabled")
      description: I18n.tr("panels.notifications.settings-do-not-disturb-description")
      checked: Notifs.dnd
      onToggled: checked => { Notifs.dnd = checked; }
    }

    NComboBox {
      // TODO: wire notification position to ryoku (position hardcoded in Wrapper.qml)
      label: I18n.tr("common.position")
      description: I18n.tr("panels.notifications.settings-location-description")
      enabled: false
      opacity: 0.45
      model: [
        {
          "key": "top_right",
          "name": I18n.tr("positions.top-right")
        }
      ]
      currentKey: "top_right"
    }

    NToggle {
      // TODO: wire overlayLayer to ryoku (no overlay layer config in ryoku)
      label: I18n.tr("panels.osd.always-on-top-label")
      description: I18n.tr("panels.notifications.settings-always-on-top-description")
      checked: false
      enabled: false
      opacity: 0.45
    }

    NValueSlider {
      // TODO: wire backgroundOpacity to ryoku (no per-notification opacity config)
      Layout.fillWidth: true
      label: I18n.tr("panels.osd.background-opacity-label")
      description: I18n.tr("panels.notifications.settings-background-opacity-description")
      from: 0
      to: 1
      stepSize: 0.01
      value: 1.0
      text: "100%"
      enabled: false
      opacity: 0.45
    }

    NDivider {
      Layout.fillWidth: true
    }

    NText {
      // TODO: wire notification monitors selection to ryoku (no per-monitor notif config)
      text: I18n.tr("panels.notifications.monitors-desc")
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      opacity: 0.45
    }

    Repeater {
      // TODO: wire per-monitor notifications to ryoku
      model: Quickshell.screens || []
      delegate: NCheckbox {
        Layout.fillWidth: true
        readonly property real compositorScale: {
          const info = CompositorService.displayScales[modelData.name];
          return (info && info.scale) ? info.scale : 1.0;
        }
        label: modelData.name || I18n.tr("common.unknown")
        description: {
          I18n.tr("system.monitor-description", {
                    "model": modelData.model,
                    "width": modelData.width * compositorScale,
                    "height": modelData.height * compositorScale,
                    "scale": compositorScale
                  });
        }
        checked: false
        enabled: false
        opacity: 0.45
      }
    }
  }
}
