import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Base the list on the authoritative connected-screen list (Quickshell.screens) and
  // enrich each with the hyprctl-parsed details (modes/refresh/transform/...).
  // displayScales alone can be empty at first render, so never iterate it directly.
  readonly property var monitors: {
    var screens = Quickshell.screens || [];
    var ds = CompositorService.displayScales || ({});
    var out = [];
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i];
      var d = ds[s.name] || ({});
      out.push({
                 "name": s.name,
                 "description": d.description || s.model || s.name,
                 "width": d.width || s.width || 0,
                 "height": d.height || s.height || 0,
                 "refresh_rate": d.refresh_rate || 60,
                 "scale": d.scale || s.scale || 1.0,
                 "transform": d.transform || 0,
                 "disabled": d.disabled || false,
                 "mirrorOf": d.mirrorOf || "none",
                 "availableModes": d.availableModes || [],
                 "physicalWidth": d.physicalWidth || 0,
                 "physicalHeight": d.physicalHeight || 0,
                 "x": d.x || 0,
                 "y": d.y || 0
               });
    }
    return out;
  }

  // Force a fresh hyprctl query so modes/refresh are populated when the tab opens.
  Component.onCompleted: CompositorService.updateDisplayScales()

  function roundRate(r) {
    return Math.round(r);
  }

  // Build a Hyprland `monitor=` spec from a monitor's current/pending values.
  function buildSpec(name, enabled, res, rate, x, y, scale, transform, mirror) {
    if (!enabled)
      return name + ", disable";
    var spec = name + ", " + res + "@" + rate + ", " + x + "x" + y + ", " + scale;
    if (transform && transform !== 0)
      spec += ", transform, " + transform;
    if (mirror && mirror !== "none")
      spec += ", mirror, " + mirror;
    return spec;
  }

  function currentSpecOf(m) {
    return buildSpec(m.name, !m.disabled, m.width + "x" + m.height, roundRate(m.refresh_rate), m.x, m.y, m.scale, m.transform, m.mirrorOf);
  }

  // Preview a spec live, then ask to keep or revert.
  function applyWithConfirm(name, newSpec, prevSpec) {
    Quickshell.execDetached(["ryoku-monitor", "apply", newSpec]);
    confirmDialog.monitorName = name;
    confirmDialog.prevSpec = prevSpec;
    confirmDialog.open();
  }

  NHeader {
    label: I18n.tr("panels.display.layout-title")
    description: I18n.tr("panels.display.layout-description")
  }

  NText {
    visible: root.monitors.length === 0
    Layout.fillWidth: true
    text: I18n.tr("panels.display.layout-none")
    color: Color.mOnSurfaceVariant
  }

  Repeater {
    model: root.monitors

    MonitorCard {
      required property var modelData
      Layout.fillWidth: true
      mon: modelData
      allMonitors: root.monitors
    }
  }

  // ---- Confirm-or-revert dialog ----
  Popup {
    id: confirmDialog
    parent: Overlay.overlay
    modal: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: Overlay.overlay
    padding: Style.marginL

    property string monitorName: ""
    property string prevSpec: ""
    property int remaining: 15

    onOpened: {
      remaining = 15;
      countdown.restart();
    }
    onClosed: countdown.stop()

    function keep() {
      countdown.stop();
      Quickshell.execDetached(["ryoku-monitor", "persist"]);
      close();
    }
    function revert() {
      countdown.stop();
      if (prevSpec.length > 0)
        Quickshell.execDetached(["ryoku-monitor", "apply", prevSpec]);
      close();
    }

    Timer {
      id: countdown
      interval: 1000
      repeat: true
      onTriggered: {
        confirmDialog.remaining -= 1;
        if (confirmDialog.remaining <= 0)
          confirmDialog.revert();
      }
    }

    background: NBox {}

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
                        "seconds": confirmDialog.remaining
                      })
      }
      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Style.marginM
        NButton {
          text: I18n.tr("panels.display.confirm-revert")
          outlined: true
          onClicked: confirmDialog.revert()
        }
        NButton {
          text: I18n.tr("panels.display.confirm-keep")
          onClicked: confirmDialog.keep()
        }
      }
    }
  }

  // ---- Per-monitor card ----
  component MonitorCard: NBox {
    id: card
    required property var mon
    required property var allMonitors

    // Pending selections (initialised from the live values).
    property bool pendingEnabled: !mon.disabled
    property string pendingRes: mon.width + "x" + mon.height
    property string pendingRate: String(root.roundRate(mon.refresh_rate))
    property real pendingScale: mon.scale
    property int pendingTransform: mon.transform
    property string pendingMirror: mon.mirrorOf || "none"
    property int pendingX: mon.x
    property int pendingY: mon.y

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

    // Suggest a scale from the physical DPI (physical size in mm + selected resolution).
    function suggestScale() {
      var pw = mon.physicalWidth || 0;
      var ph = mon.physicalHeight || 0;
      var parts = String(pendingRes).split("x");
      var w = parseInt(parts[0]);
      var h = parseInt(parts[1]);
      if (pw <= 0 || ph <= 0 || !w || !h)
        return 1.0;
      var diagIn = Math.sqrt(pw * pw + ph * ph) / 25.4;
      var dpi = Math.sqrt(w * w + h * h) / diagIn;
      if (dpi <= 120)
        return 1.0;
      if (dpi <= 160)
        return 1.25;
      if (dpi <= 200)
        return 1.5;
      return 2.0;
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
          model: [
            {
              "key": "1",
              "name": "100%"
            },
            {
              "key": "1.25",
              "name": "125%"
            },
            {
              "key": "1.5",
              "name": "150%"
            },
            {
              "key": "1.75",
              "name": "175%"
            },
            {
              "key": "2",
              "name": "200%"
            }
          ]
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
            var newSpec = root.buildSpec(card.mon.name, card.pendingEnabled, card.pendingRes, card.pendingRate, card.pendingX, card.pendingY, card.pendingScale, card.pendingTransform, card.pendingMirror);
            root.applyWithConfirm(card.mon.name, newSpec, root.currentSpecOf(card.mon));
          }
        }
      }
    }
  }
}
