import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // The config write is deferred (RootConfig batches it on a timer), so restarting
  // the shell straight after save() kills the process before the new design lands on
  // disk and the old one reloads. Restart only once the write is confirmed (the
  // saved signal below).
  property bool pendingDesignRestart: false

  Connections {
    target: GlobalConfig
    function onSaved() {
      if (!root.pendingDesignRestart)
        return;
      root.pendingDesignRestart = false;
      Quickshell.execDetached(["systemctl", "--user", "restart", "ryoku-shell.service"]);
    }
  }

  NComboBox {
    // Picks the bar design. sidebar-left is the editable default; the rest are presets.
    Layout.fillWidth: true
    label: qsTr("Bar design")
    description: qsTr("Switch the bar's visual design. Sidebar (left) is your customisable default; others are presets.")
    model: BarDesign.available
    currentKey: GlobalConfig.bar.design
    onSelected: key => {
                  if (key === GlobalConfig.bar.design)
                    return;
                  // Switching the design changes edge anchoring, exclusion zones and
                  // the blob frame, so reload the shell cleanly once the new value is
                  // written (see pendingDesignRestart above).
                  root.pendingDesignRestart = true;
                  GlobalConfig.bar.design = key;
                  GlobalConfig.save();
                }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    // always_visible keeps the bar shown; auto_hide reveals it on hover.
    Layout.fillWidth: true
    label: I18n.tr("common.display-mode")
    description: I18n.tr("panels.bar.appearance-display-mode-description")
    model: [
      {
        "key": "always_visible",
        "name": I18n.tr("hide-modes.visible")
      },
      {
        "key": "auto_hide",
        "name": I18n.tr("hide-modes.auto-hide")
      }
    ]
    currentKey: GlobalConfig.bar.persistent ? "always_visible" : "auto_hide"
    onSelected: key => {
                  GlobalConfig.bar.persistent = (key === "always_visible");
                  GlobalConfig.bar.showOnHover = (key === "auto_hide");
                  GlobalConfig.save();
                }
  }

  NSpinBox {
    // How far to drag from the edge to reveal the bar while auto-hiding.
    Layout.fillWidth: true
    label: qsTr("Reveal drag threshold")
    description: qsTr("How far to drag from the top edge to reveal the bar while auto-hiding.")
    enabled: !GlobalConfig.bar.persistent
    from: 0
    to: 200
    stepSize: 1
    suffix: "px"
    value: GlobalConfig.bar.dragThreshold
    onValueChanged: {
      if (GlobalConfig.bar.dragThreshold !== value) {
        GlobalConfig.bar.dragThreshold = value;
        GlobalConfig.save();
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    Layout.fillWidth: true
    text: qsTr("Bar size, transparency, fonts, corners and spacing are global — set them in Interface and General settings.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }
}
