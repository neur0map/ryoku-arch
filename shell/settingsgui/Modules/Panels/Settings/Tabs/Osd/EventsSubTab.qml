import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: GlobalConfig.osd.* (osdconfig.hpp). ryoku has no per-type toggle for
// the volume / input-volume OSD (they always show while the OSD is enabled), so those
// upstream stubs were dropped. Brightness and microphone are the real optional events.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NText {
    Layout.fillWidth: true
    text: qsTr("Volume and input-volume OSDs always show while the OSD is enabled. These event OSDs are optional:")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NCheckbox {
    // RYOKU WIRED: GlobalConfig.osd.enableBrightness (osd/Content.qml)
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.types-brightness-label")
    description: I18n.tr("panels.osd.types-brightness-description")
    checked: GlobalConfig.osd.enableBrightness
    onToggled: checked => {
                 GlobalConfig.osd.enableBrightness = checked;
                 GlobalConfig.save();
               }
  }

  NCheckbox {
    // RYOKU WIRED: GlobalConfig.osd.enableMicrophone (drives the microphone OSD in
    // osd/Content.qml). The upstream code mislabelled this as "Lock Key"; corrected here.
    Layout.fillWidth: true
    label: qsTr("Microphone")
    description: qsTr("Show an OSD when the microphone is muted or unmuted.")
    checked: GlobalConfig.osd.enableMicrophone
    onToggled: checked => {
                 GlobalConfig.osd.enableMicrophone = checked;
                 GlobalConfig.save();
               }
  }
}
