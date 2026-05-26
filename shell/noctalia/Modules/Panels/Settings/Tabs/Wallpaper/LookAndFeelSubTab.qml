import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  // TODO: wire fillMode, fillColor, transitionType, transitionDuration, edgeSmoothness to ryoku (swww args not exposed as config)
  enabled: false
  opacity: 0.45

  property var screen

  NComboBox {
    label: I18n.tr("panels.wallpaper.look-feel-fill-mode-label")
    description: I18n.tr("panels.wallpaper.look-feel-fill-mode-description")
    model: []
    currentKey: ""
  }

  RowLayout {
    NLabel {
      label: I18n.tr("bar.audio-visualizer.color-name-label")
      description: I18n.tr("panels.wallpaper.look-feel-fill-color-description")
      Layout.alignment: Qt.AlignTop
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true

    NLabel {
      label: I18n.tr("panels.wallpaper.look-feel-transition-type-label")
      description: I18n.tr("panels.wallpaper.look-feel-transition-type-description")
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: I18n.tr("panels.wallpaper.look-feel-skip-startup-transition-label")
    description: I18n.tr("panels.wallpaper.look-feel-skip-startup-transition-description")
    checked: false
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.wallpaper.look-feel-transition-duration-label")
    description: I18n.tr("panels.wallpaper.look-feel-transition-duration-description")
    from: 500
    to: 10000
    stepSize: 100
    value: 2000
    text: "2.0s"
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.wallpaper.look-feel-edge-smoothness-label")
    description: I18n.tr("panels.wallpaper.look-feel-edge-smoothness-description")
    from: 0.0
    to: 1.0
    value: 0
    text: "0%"
  }
}
