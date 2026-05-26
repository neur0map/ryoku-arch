import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  // TODO: wire visualizerType, spectrumMirrored, spectrumFrameRate to ryoku CavaProvider (no Cava UI config in ryoku)
  enabled: false
  opacity: 0.45

  NComboBox {
    label: I18n.tr("panels.audio.visualizer-type-label")
    description: I18n.tr("panels.audio.visualizer-type-description")
    model: [
      {
        "key": "none",
        "name": I18n.tr("common.none")
      },
      {
        "key": "linear",
        "name": I18n.tr("options.visualizer-types.linear")
      },
      {
        "key": "mirrored",
        "name": I18n.tr("options.visualizer-types.mirrored")
      },
      {
        "key": "wave",
        "name": I18n.tr("options.visualizer-types.wave")
      }
    ]
    currentKey: "none"
  }

  NToggle {
    label: I18n.tr("panels.audio.spectrum-mirrored-label")
    description: I18n.tr("panels.audio.spectrum-mirrored-description")
    checked: false
  }

  NComboBox {
    label: I18n.tr("panels.audio.media-frame-rate-label")
    description: I18n.tr("panels.audio.media-frame-rate-description")
    model: [
      {
        "key": "60",
        "name": I18n.tr("options.frame-rates-fps", {
                          "fps": "60"
                        })
      }
    ]
    currentKey: "60"
  }
}
