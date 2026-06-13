import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.dashboard.modules.services

// RYOKU WIRED: GlobalConfig.clipboard.* — enforced on the cliphist history (the
// Super+V list) by qs.modules.ClipboardMaintenance (size trim + scheduled wipe).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property bool confirming: false

  NText {
    Layout.fillWidth: true
    text: qsTr("Manage your clipboard history — the list you open with Super+V.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Manage clipboard history")
    description: qsTr("Apply the size limit and automatic cleanup below. When off, history is left untouched.")
    checked: GlobalConfig.clipboard.enabled
    onToggled: checked => {
      GlobalConfig.clipboard.enabled = checked;
      GlobalConfig.save();
    }
  }

  NSpinBox {
    Layout.fillWidth: true
    enabled: GlobalConfig.clipboard.enabled
    label: qsTr("History limit")
    description: qsTr("Keep at most this many entries; older ones are trimmed automatically.")
    from: 10
    to: 1000
    stepSize: 10
    value: GlobalConfig.clipboard.maxEntries
    onValueChanged: {
      if (GlobalConfig.clipboard.maxEntries !== value) {
        GlobalConfig.clipboard.maxEntries = value;
        GlobalConfig.save();
      }
    }
  }

  NComboBox {
    Layout.fillWidth: true
    enabled: GlobalConfig.clipboard.enabled
    label: qsTr("Automatic cleanup")
    description: qsTr("Wipe the whole history on a schedule.")
    model: [
      {
        "key": "off",
        "name": I18n.tr("common.none")
      },
      {
        "key": "daily",
        "name": qsTr("Daily")
      },
      {
        "key": "weekly",
        "name": qsTr("Weekly")
      }
    ]
    currentKey: GlobalConfig.clipboard.autoCleanup
    onSelected: key => {
      GlobalConfig.clipboard.autoCleanup = key;
      GlobalConfig.save();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NText {
      text: qsTr("Clear now")
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }
    NText {
      Layout.fillWidth: true
      text: qsTr("Remove all stored clipboard entries and clear the current selection.")
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }

    RowLayout {
      spacing: Style.marginM

      NButton {
        visible: !root.confirming
        text: qsTr("Clear clipboard history")
        icon: "trash"
        backgroundColor: Color.mError
        onClicked: root.confirming = true
      }
      NButton {
        visible: root.confirming
        text: qsTr("Confirm clear")
        icon: "trash"
        backgroundColor: Color.mError
        onClicked: {
          ClipboardService.clear();
          Quickshell.execDetached(["sh", "-lc", "cliphist wipe 2>/dev/null; wl-copy --clear 2>/dev/null || true"]);
          root.confirming = false;
        }
      }
      NButton {
        visible: root.confirming
        text: qsTr("Cancel")
        outlined: true
        onClicked: root.confirming = false
      }
    }
  }
}
