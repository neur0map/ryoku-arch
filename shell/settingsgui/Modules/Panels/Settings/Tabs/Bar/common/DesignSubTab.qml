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

  NComboBox {
    // RYOKU WIRED: GlobalConfig.bar.design (barconfig.hpp). Selects the bar's
    // visual design; sidebar-left is the user's customisable default, others
    // are presets. Non-destructive — only bar.design changes.
    Layout.fillWidth: true
    label: qsTr("Bar design")
    description: qsTr("Switch the bar's visual design. Sidebar (left) is your customisable default; others are presets.")
    model: BarDesign.available
    currentKey: GlobalConfig.bar.design
    onSelected: key => {
                  if (key === GlobalConfig.bar.design)
                    return;
                  GlobalConfig.bar.design = key;
                  GlobalConfig.save();
                  // Switching the design changes edge anchoring, exclusion zones and
                  // the blob frame; a hot swap leaves stale layout state, so reload
                  // the shell cleanly (same idiom as the desktop menu's restart).
                  Quickshell.execDetached(["systemctl", "--user", "restart", "ryoku-shell.service"]);
                }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    // RYOKU WIRED: GlobalConfig.bar.persistent + showOnHover (barconfig.hpp:130-131)
    // always_visible = persistent:true, auto_hide = persistent:false showOnHover:true
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
    // RYOKU WIRED: GlobalConfig.bar.dragThreshold (barconfig.hpp:132) — only relevant
    // while auto-hiding (how far to drag from the screen edge to reveal the bar).
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
