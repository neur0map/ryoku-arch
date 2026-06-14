import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: GlobalConfig.utilities.* (utilitiesconfig.hpp). Toasts are the small
// status popups (Toaster). Each toggle below is a real GlobalConfig.utilities.toasts.*
// flag; ryoku exposes the full set, so we surface all of them here grouped by source.
// Writes use explicit property assignment (bracket-indexed writes on the C++ config
// object are unreliable).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  component SectionHeader: NText {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NText {
    Layout.fillWidth: true
    text: qsTr("Status toasts are the small popups that confirm system changes. Pick which ones appear.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NSpinBox {
    // RYOKU WIRED: GlobalConfig.utilities.maxToasts (utilitiesconfig.hpp)
    Layout.fillWidth: true
    label: qsTr("Maximum toasts on screen")
    description: qsTr("How many status toasts can stack before the oldest is dropped.")
    from: 1
    to: 8
    stepSize: 1
    value: GlobalConfig.utilities.maxToasts
    onValueChanged: {
      if (GlobalConfig.utilities.maxToasts !== value) {
        GlobalConfig.utilities.maxToasts = value;
        GlobalConfig.save();
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  SectionHeader {
    text: qsTr("System")
  }

  NCheckbox {
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.toast-battery-label")
    description: qsTr("Plugged in or running on battery.")
    checked: GlobalConfig.utilities.toasts.chargingChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.chargingChanged = checked;
                 GlobalConfig.save();
               }
  }
  NCheckbox {
    Layout.fillWidth: true
    label: qsTr("Game mode toggled")
    checked: GlobalConfig.utilities.toasts.gameModeChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.gameModeChanged = checked;
                 GlobalConfig.save();
               }
  }
  NCheckbox {
    Layout.fillWidth: true
    label: qsTr("Do Not Disturb toggled")
    checked: GlobalConfig.utilities.toasts.dndChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.dndChanged = checked;
                 GlobalConfig.save();
               }
  }
  NCheckbox {
    Layout.fillWidth: true
    label: qsTr("VPN connection changed")
    checked: GlobalConfig.utilities.toasts.vpnChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.vpnChanged = checked;
                 GlobalConfig.save();
               }
  }

  SectionHeader {
    text: qsTr("Audio")
  }

  NCheckbox {
    Layout.fillWidth: true
    label: qsTr("Output device changed")
    checked: GlobalConfig.utilities.toasts.audioOutputChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.audioOutputChanged = checked;
                 GlobalConfig.save();
               }
  }
  NCheckbox {
    Layout.fillWidth: true
    label: qsTr("Input device changed")
    checked: GlobalConfig.utilities.toasts.audioInputChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.audioInputChanged = checked;
                 GlobalConfig.save();
               }
  }

  SectionHeader {
    text: qsTr("Keyboard")
  }

  NCheckbox {
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.toast-keyboard-label")
    description: qsTr("Active keyboard layout changed.")
    checked: GlobalConfig.utilities.toasts.kbLayoutChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.kbLayoutChanged = checked;
                 GlobalConfig.save();
               }
  }
  NCheckbox {
    Layout.fillWidth: true
    label: qsTr("Caps Lock toggled")
    checked: GlobalConfig.utilities.toasts.capsLockChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.capsLockChanged = checked;
                 GlobalConfig.save();
               }
  }
  NCheckbox {
    Layout.fillWidth: true
    label: qsTr("Num Lock toggled")
    checked: GlobalConfig.utilities.toasts.numLockChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.numLockChanged = checked;
                 GlobalConfig.save();
               }
  }

  SectionHeader {
    text: qsTr("Media")
  }

  NCheckbox {
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.toast-media-label")
    description: qsTr("Now-playing changes from the active media player.")
    checked: GlobalConfig.utilities.toasts.nowPlaying
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.nowPlaying = checked;
                 GlobalConfig.save();
               }
  }
}
