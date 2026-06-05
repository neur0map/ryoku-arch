import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Media
import qs.settingsgui.Services.System
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property real localVolume: AudioService.volume

  Connections {
    target: AudioService
    function onSinkChanged() {
      localVolume = AudioService.volume;
    }
    function onVolumeChanged() {
      localVolume = AudioService.volume;
    }
  }

  Connections {
    target: AudioService.sink?.audio ? AudioService.sink?.audio : null
    function onVolumeChanged() {
      localVolume = AudioService.volume;
    }
  }

  ColumnLayout {
    spacing: Style.marginXXS
    Layout.fillWidth: true

    NValueSlider {
      // RYOKU WIRED: max volume from GlobalConfig.services.maxVolume (serviceconfig.hpp:30)
      Layout.fillWidth: true
      label: I18n.tr("panels.osd.types-volume-label")
      description: I18n.tr("panels.audio.volumes-output-volume-description")
      from: 0
      to: GlobalConfig.services.maxVolume
      value: localVolume
      stepSize: 0.01
      text: Math.round(AudioService.volume * 100) + "%"
      onMoved: value => localVolume = value
    }

    Timer {
      interval: 100
      running: true
      repeat: true
      onTriggered: {
        if (!AudioService.isSwitchingSink && Math.abs(localVolume - AudioService.volume) >= 0.01) {
          AudioService.setVolume(localVolume);
        }
      }
    }
  }

  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true

    NToggle {
      label: I18n.tr("panels.audio.volumes-mute-output-label")
      description: I18n.tr("panels.audio.volumes-mute-output-description")
      checked: AudioService.muted
      onToggled: checked => AudioService.setOutputMuted(checked)
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    spacing: Style.marginXS
    Layout.fillWidth: true

    NValueSlider {
      // RYOKU WIRED: max volume from GlobalConfig.services.maxVolume (serviceconfig.hpp:30)
      Layout.fillWidth: true
      label: I18n.tr("panels.osd.types-input-volume-label")
      description: I18n.tr("panels.audio.volumes-input-volume-description")
      from: 0
      to: GlobalConfig.services.maxVolume
      value: AudioService.inputVolume
      stepSize: 0.01
      text: Math.round(AudioService.inputVolume * 100) + "%"
      onMoved: value => AudioService.setInputVolume(value)
    }
  }

  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true

    NToggle {
      label: I18n.tr("panels.audio.volumes-mute-input-label")
      description: I18n.tr("panels.audio.volumes-mute-input-description")
      checked: AudioService.inputMuted
      onToggled: checked => AudioService.setInputMuted(checked)
    }
  }

  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true

    NSpinBox {
      // RYOKU WIRED: GlobalConfig.services.audioIncrement (serviceconfig.hpp:28) — stored as 0.0-1.0, displayed as integer %
      Layout.fillWidth: true
      label: I18n.tr("panels.audio.volumes-step-size-label")
      description: I18n.tr("panels.audio.volumes-step-size-description")
      minimum: 1
      maximum: 25
      value: Math.round(GlobalConfig.services.audioIncrement * 100)
      stepSize: 1
      suffix: "%"
      onValueChanged: {
        const newVal = value / 100;
        if (Math.abs(GlobalConfig.services.audioIncrement - newVal) > 0.001) {
          GlobalConfig.services.audioIncrement = newVal;
          GlobalConfig.save();
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Raise maximum volume above 100%
  ColumnLayout {
    spacing: Style.marginS
    Layout.fillWidth: true

    NToggle {
      // RYOKU WIRED: GlobalConfig.services.maxVolume > 1.0 means overdrive enabled (serviceconfig.hpp:30)
      label: I18n.tr("panels.audio.volumes-volume-overdrive-label")
      description: I18n.tr("panels.audio.volumes-volume-overdrive-description")
      checked: GlobalConfig.services.maxVolume > 1.0
      onToggled: checked => {
                   GlobalConfig.services.maxVolume = checked ? 1.5 : 1.0;
                   GlobalConfig.save();
                 }
    }
  }
}
