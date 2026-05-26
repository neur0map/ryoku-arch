import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Modules.OSD
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var addType
  property var removeType

  // Volume OSD — no ryoku config toggle (volume OSD always on when osd.enabled)
  NCheckbox {
    // TODO: wire volume OSD enable to ryoku (no per-type enable for volume in ryoku osdconfig)
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.types-volume-label")
    description: I18n.tr("panels.osd.types-volume-description")
    checked: true
    enabled: false
    opacity: 0.45
  }

  // Input Volume OSD — no ryoku config toggle
  NCheckbox {
    // TODO: wire input volume OSD enable to ryoku (no per-type enable for input volume in ryoku osdconfig)
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.types-input-volume-label")
    description: I18n.tr("panels.osd.types-input-volume-description")
    checked: true
    enabled: false
    opacity: 0.45
  }

  // Brightness OSD
  NCheckbox {
    // RYOKU WIRED: GlobalConfig.osd.enableBrightness (osdconfig.hpp:13)
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.types-brightness-label")
    description: I18n.tr("panels.osd.types-brightness-description")
    checked: GlobalConfig.osd.enableBrightness
    onToggled: checked => {
                 GlobalConfig.osd.enableBrightness = checked;
                 GlobalConfig.save();
               }
  }

  // Lock Key OSD (microphone in ryoku maps to this position)
  NCheckbox {
    // RYOKU WIRED: GlobalConfig.osd.enableMicrophone (osdconfig.hpp:14)
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.types-lockkey-label")
    description: I18n.tr("panels.osd.types-lockkey-description")
    checked: GlobalConfig.osd.enableMicrophone
    onToggled: checked => {
                 GlobalConfig.osd.enableMicrophone = checked;
                 GlobalConfig.save();
               }
  }
}
