import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Avoid writing compiled defaults back as overrides while bindings settle.
  property bool ready: false
  Component.onCompleted: ready = true

  NText {
    Layout.fillWidth: true
    text: "Controls the wallpaper audio visualizer. cava settings (bars/smoothing/sensitivity) apply globally to every visualizer surface."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
  }

  NToggle {
    Layout.fillWidth: true
    label: "Enable visualizer"
    description: "Show the audio spectrum over the wallpaper."
    checked: GlobalConfig.background.visualiser.enabled
    onToggled: checked => {
      GlobalConfig.background.visualiser.enabled = checked;
      GlobalConfig.save();
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginL
    enabled: GlobalConfig.background.visualiser.enabled

    NComboBox {
      Layout.fillWidth: true
      label: "Style"
      description: "Visualizer variation."
      // TODO: add "wave" and "radial" once VisualiserBars (visualiserbars.cpp) draws them.
      model: [
        {
          "key": "bars",
          "name": "Bars"
        },
        {
          "key": "mirrored",
          "name": "Mirrored"
        },
        {
          "key": "dots",
          "name": "Dots"
        },
        {
          "key": "skyline",
          "name": "Skyline"
        }
      ]
      currentKey: GlobalConfig.background.visualiser.style || "bars"
      onSelected: key => {
        GlobalConfig.background.visualiser.style = key;
        GlobalConfig.save();
      }
    }

    NToggle {
      Layout.fillWidth: true
      label: "Auto-hide"
      description: "Hide the visualizer when a window is focused (not floating)."
      checked: GlobalConfig.background.visualiser.autoHide
      onToggled: checked => {
        GlobalConfig.background.visualiser.autoHide = checked;
        GlobalConfig.save();
      }
    }

    NToggle {
      Layout.fillWidth: true
      label: "Blur under bars"
      description: "Blur the wallpaper behind the visualizer."
      checked: GlobalConfig.background.visualiser.blur
      onToggled: checked => {
        GlobalConfig.background.visualiser.blur = checked;
        GlobalConfig.save();
      }
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Spacing"
      description: "Gap between bands."
      from: 0
      to: 10
      stepSize: 0.5
      value: GlobalConfig.background.visualiser.spacing
      text: (Math.round(GlobalConfig.background.visualiser.spacing * 10) / 10).toFixed(1)
      onMoved: value => {
        GlobalConfig.background.visualiser.spacing = value;
        GlobalConfig.save();
      }
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Rounding"
      description: "Corner rounding of the bands."
      from: 0
      to: 20
      stepSize: 1
      value: GlobalConfig.background.visualiser.rounding
      text: String(Math.round(GlobalConfig.background.visualiser.rounding))
      onMoved: value => {
        GlobalConfig.background.visualiser.rounding = value;
        GlobalConfig.save();
      }
    }

    NDivider {
      Layout.fillWidth: true
    }

    NText {
      Layout.fillWidth: true
      text: "cava engine (global)"
      color: Color.mOnSurfaceVariant
    }

    NSpinBox {
      Layout.fillWidth: true
      label: "Bar count"
      description: "Number of frequency bands."
      from: 8
      to: 120
      stepSize: 1
      value: GlobalConfig.services.visualiserBars
      onValueChanged: {
        if (root.ready && value !== GlobalConfig.services.visualiserBars) {
          GlobalConfig.services.visualiserBars = value;
          GlobalConfig.save();
        }
      }
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Smoothing"
      description: "Higher = smoother, slower bars. Lower = snappier."
      from: 0
      to: 1
      stepSize: 0.05
      value: GlobalConfig.services.visualiserSmoothing
      text: Math.round(GlobalConfig.services.visualiserSmoothing * 100) + "%"
      onMoved: value => {
        GlobalConfig.services.visualiserSmoothing = value;
        GlobalConfig.save();
      }
    }

    NToggle {
      Layout.fillWidth: true
      label: "Auto sensitivity"
      description: "Auto-scale levels so quiet audio still moves the bars."
      checked: GlobalConfig.services.visualiserAutoSens
      onToggled: checked => {
        GlobalConfig.services.visualiserAutoSens = checked;
        GlobalConfig.save();
      }
    }
  }
}
