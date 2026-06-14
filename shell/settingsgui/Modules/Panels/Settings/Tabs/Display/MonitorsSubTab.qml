import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Force a fresh monitor query so modes/refresh populate when the tab opens.
  Component.onCompleted: DisplayService.refresh()

  function roundRate(r) {
    return Math.round(r);
  }

  NHeader {
    label: I18n.tr("panels.display.layout-title")
    description: I18n.tr("panels.display.layout-description")
  }

  // Non-Hyprland compositors (Niri/Sway/...) can't apply monitor layout from here.
  NText {
    visible: !DisplayService.supported
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    text: I18n.tr("panels.display.unsupported-body")
    color: Color.mOnSurfaceVariant
  }

  NText {
    visible: DisplayService.supported && DisplayService.monitors.length === 0
    Layout.fillWidth: true
    text: I18n.tr("panels.display.layout-none")
    color: Color.mOnSurfaceVariant
  }

  Repeater {
    model: DisplayService.supported ? DisplayService.monitors : []

    MonitorCard {
      required property var modelData
      Layout.fillWidth: true
      mon: modelData
    }
  }

  // Surface a refused apply (unsupported compositor / last active output).
  Connections {
    target: DisplayService
    function onBlocked(reasonKey) {
      ToastService.showWarning(I18n.tr("panels.display.layout-title"), I18n.tr(reasonKey));
    }
    function onApplyError(message) {
      ToastService.showWarning(I18n.tr("panels.display.layout-title"), (message && message.length > 0) ? message : I18n.tr("panels.display.apply-failed"));
    }
  }

  // Confirm-or-revert dialog. The apply state + countdown live in DisplayService so they
  // survive even if this panel closes (a non-confirmed change safely auto-reverts).
  Popup {
    id: confirmDialog
    parent: Overlay.overlay
    modal: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: Overlay.overlay
    padding: Style.marginL

    Connections {
      target: DisplayService
      function onPendingActiveChanged() {
        if (DisplayService.pendingActive)
          confirmDialog.open();
        else
          confirmDialog.close();
      }
    }

    background: NBox {
      forceOpaque: true
      color: Color.mSurfaceVariantOpaque
    }

    contentItem: ColumnLayout {
      spacing: Style.marginM

      NText {
        Layout.fillWidth: true
        text: I18n.tr("panels.display.confirm-title")
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL
      }
      NText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        text: I18n.tr("panels.display.confirm-body", {
                        "seconds": DisplayService.remaining
                      })
      }
      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Style.marginM
        NButton {
          text: I18n.tr("panels.display.confirm-revert")
          outlined: true
          onClicked: DisplayService.revert()
        }
        NButton {
          text: I18n.tr("panels.display.confirm-keep")
          onClicked: DisplayService.keep()
        }
      }
    }
  }

  component MonitorCard: NBox {
    id: card
    required property var mon

    // Pending selections (initialised from the live values).
    property bool pendingEnabled: !mon.disabled
    property string pendingRes: mon.width + "x" + mon.height
    property string pendingRate: String(root.roundRate(mon.refresh_rate))
    property real pendingScale: mon.scale
    property int pendingTransform: mon.transform
    property string pendingMirror: mon.mirrorOf || "none"
    property bool pendingVrr: mon.vrr || false
    property int pendingX: mon.x
    property int pendingY: mon.y

    // The only enabled output may not be turned off (would blank the session).
    readonly property bool isLastEnabledOutput: !mon.disabled && DisplayService.enabledCount === 1

    // Parse availableModes ("2560x1440@240.00Hz") into resolution + rate options.
    readonly property var resolutions: {
      var seen = {};
      var list = [];
      var modes = mon.availableModes || [];
      for (var i = 0; i < modes.length; i++) {
        var res = String(modes[i]).split("@")[0];
        if (res && !seen[res]) {
          seen[res] = true;
          list.push({
                      "key": res,
                      "name": res.replace("x", " x ")
                    });
        }
      }
      if (list.length === 0)
        list.push({
                    "key": pendingRes,
                    "name": pendingRes.replace("x", " x ")
                  });
      return list;
    }

    function ratesFor(res) {
      var seen = {};
      var list = [];
      var modes = mon.availableModes || [];
      for (var i = 0; i < modes.length; i++) {
        var parts = String(modes[i]).split("@");
        if (parts[0] !== res)
          continue;
        var hz = String(Math.round(parseFloat(parts[1])));
        if (!seen[hz]) {
          seen[hz] = true;
          list.push({
                      "key": hz,
                      "name": hz + " Hz"
                    });
        }
      }
      if (list.length === 0)
        list.push({
                    "key": pendingRate,
                    "name": pendingRate + " Hz"
                  });
      return list;
    }

    // The highest-resolution mode (and its highest refresh) from availableModes. More
    // reliable than EDID "preferred", which some monitors (e.g. old SyncMasters) report
    // wrongly as a 16:9 mode on a 16:10 panel.
    function recommendedMode() {
      var modes = mon.availableModes || [];
      var best = null;
      var bestPx = 0;
      var bestHz = 0;
      for (var i = 0; i < modes.length; i++) {
        var parts = String(modes[i]).split("@");
        var wh = String(parts[0]).split("x");
        var w = parseInt(wh[0]);
        var h = parseInt(wh[1]);
        var hz = Math.round(parseFloat(parts[1]));
        if (!w || !h)
          continue;
        var px = w * h;
        if (px > bestPx || (px === bestPx && hz > bestHz)) {
          bestPx = px;
          bestHz = hz;
          best = {
            "res": parts[0],
            "hz": String(hz)
          };
        }
      }
      return best;
    }

    // Suggest a scale from physical DPI; the rule lives in DisplayService so it is shared
    // and unit-testable.
    function suggestScale() {
      return DisplayService.suggestScale(mon.physicalWidth, mon.physicalHeight, pendingRes);
    }

    Layout.fillWidth: true
    implicitHeight: cardCol.implicitHeight + Style.margin2L

    ColumnLayout {
      id: cardCol
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        NText {
          Layout.fillWidth: true
          text: card.mon.name + (card.mon.description ? "  -  " + card.mon.description : "")
          font.weight: Style.fontWeightBold
        }
        NToggle {
          checked: card.pendingEnabled
          // Can't disable the last active output.
          enabled: !card.isLastEnabledOutput
          onToggled: checked => card.pendingEnabled = checked
        }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.marginM
        rowSpacing: Style.marginM
        enabled: card.pendingEnabled

        NComboBox {
          Layout.fillWidth: true
          label: I18n.tr("panels.display.resolution")
          model: card.resolutions
          currentKey: card.pendingRes
          onSelected: key => {
            card.pendingRes = key;
            // reset rate to the highest available for the new resolution
            var r = card.ratesFor(key);
            card.pendingRate = r.length > 0 ? r[0].key : card.pendingRate;
            // keep the scale on a clean pixel divisor for the new resolution
            card.pendingScale = DisplayService.snapScale(key, card.pendingScale);
          }
        }

        NComboBox {
          Layout.fillWidth: true
          label: I18n.tr("panels.display.refresh-rate")
          model: card.ratesFor(card.pendingRes)
          currentKey: card.pendingRate
          onSelected: key => card.pendingRate = key
        }

        NComboBox {
          Layout.fillWidth: true
          label: I18n.tr("panels.display.scale")
          model: DisplayService.scaleOptions(card.pendingRes, card.pendingScale)
          currentKey: String(card.pendingScale)
          onSelected: key => card.pendingScale = parseFloat(key)
        }

        NComboBox {
          Layout.fillWidth: true
          label: I18n.tr("panels.display.rotation")
          model: [
            {
              "key": "0",
              "name": I18n.tr("panels.display.rotation-normal")
            },
            {
              "key": "1",
              "name": "90"
            },
            {
              "key": "2",
              "name": "180"
            },
            {
              "key": "3",
              "name": "270"
            }
          ]
          currentKey: String(card.pendingTransform)
          onSelected: key => card.pendingTransform = parseInt(key)
        }

        NSpinBox {
          Layout.fillWidth: true
          label: I18n.tr("panels.display.position-x")
          from: 0
          to: 32768
          stepSize: 1
          value: card.pendingX
          onValueChanged: card.pendingX = value
        }

        NSpinBox {
          Layout.fillWidth: true
          label: I18n.tr("panels.display.position-y")
          from: 0
          to: 32768
          stepSize: 1
          value: card.pendingY
          onValueChanged: card.pendingY = value
        }
      }

      NToggle {
        Layout.fillWidth: true
        label: I18n.tr("panels.display.vrr")
        description: I18n.tr("panels.display.vrr-desc")
        enabled: card.pendingEnabled
        checked: card.pendingVrr
        onToggled: checked => card.pendingVrr = checked
      }

      RowLayout {
        Layout.fillWidth: true
        NButton {
          text: I18n.tr("panels.display.recommended")
          icon: "star"
          outlined: true
          enabled: card.pendingEnabled
          onClicked: {
            var m = card.recommendedMode();
            if (m) {
              card.pendingRes = m.res;
              card.pendingRate = m.hz;
            }
            card.pendingScale = card.suggestScale();
          }
        }
        NButton {
          text: I18n.tr("panels.display.auto-scale")
          icon: "wand"
          outlined: true
          enabled: card.pendingEnabled
          onClicked: card.pendingScale = card.suggestScale()
        }
        Item {
          Layout.fillWidth: true
        }
        NButton {
          text: I18n.tr("panels.display.apply")
          icon: "check"
          onClicked: {
            var parts = String(card.pendingRes).split("x");
            var cfg = {
              "name": card.mon.name,
              "enabled": card.pendingEnabled,
              "width": parseInt(parts[0]),
              "height": parseInt(parts[1]),
              "refreshRate": parseInt(card.pendingRate),
              "x": card.pendingX,
              "y": card.pendingY,
              "scale": DisplayService.snapScale(card.pendingRes, card.pendingScale),
              "transform": card.pendingTransform,
              "mirror": card.pendingMirror,
              "vrr": card.pendingVrr
            };
            DisplayService.applyWithConfirm(cfg, DisplayService.currentConfigOf(card.mon));
          }
        }
      }
    }
  }
}
