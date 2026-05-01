import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.Noctalia.Commons
import qs.Noctalia.Services.Media
import qs.Noctalia.Services.Ryoku
import qs.Noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  readonly property bool advancedControlsAvailable: false

  NText {
    text: RyokuFeatureAvailability.unavailableReason
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  // Output Devices
  ButtonGroup {
    id: sinks
  }

  ColumnLayout {
    spacing: Style.marginXS
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginL
    enabled: root.advancedControlsAvailable

    NLabel {
      label: I18n.tr("panels.audio.devices-output-device-label")
      description: I18n.tr("panels.audio.devices-output-device-description")
    }

    Repeater {
      model: AudioService.sinks
      NRadioButton {
        ButtonGroup.group: sinks
        required property PwNode modelData
        text: modelData.description
        checked: AudioService.sink?.id === modelData.id
        onClicked: {
          AudioService.setAudioSink(modelData);
        }
        Layout.fillWidth: true
      }
    }
  }

  // Input Devices
  ButtonGroup {
    id: sources
  }

  ColumnLayout {
    spacing: Style.marginXS
    Layout.fillWidth: true
    enabled: root.advancedControlsAvailable

    NLabel {
      label: I18n.tr("panels.audio.devices-input-device-label")
      description: I18n.tr("panels.audio.devices-input-device-description")
    }

    Repeater {
      model: AudioService.sources
      NRadioButton {
        ButtonGroup.group: sources
        required property PwNode modelData
        text: modelData.description
        checked: AudioService.source?.id === modelData.id
        onClicked: AudioService.setAudioSource(modelData)
        Layout.fillWidth: true
      }
    }
  }
}
