import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU: screen frame / border, wired to GlobalConfig.border.* (Ryoku.Config).
// (Repurposed from the upstream "Screen Corners" subtab — ryoku draws a screen-edge
// frame rather than rounded screen corners.)
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NValueSlider {
    Layout.fillWidth: true
    label: "Frame thickness"
    description: "Width of the screen border/frame"
    from: 2
    to: 30
    stepSize: 1
    value: GlobalConfig.border.thickness
    text: Math.round(GlobalConfig.border.thickness) + " px"
    onMoved: value => {
      GlobalConfig.border.thickness = Math.round(value);
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Corner rounding"
    description: "Radius of the screen frame corners"
    from: 0
    to: 40
    stepSize: 1
    value: GlobalConfig.border.rounding
    text: Math.round(GlobalConfig.border.rounding) + " px"
    onMoved: value => {
      GlobalConfig.border.rounding = Math.round(value);
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Corner smoothing"
    description: "Squircle smoothing of the frame corners"
    from: 0
    to: 64
    stepSize: 1
    value: GlobalConfig.border.smoothing
    text: "" + Math.round(GlobalConfig.border.smoothing)
    onMoved: value => {
      GlobalConfig.border.smoothing = Math.round(value);
      GlobalConfig.save();
    }
  }
}
