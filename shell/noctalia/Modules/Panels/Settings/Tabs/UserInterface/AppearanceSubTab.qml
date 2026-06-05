import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Widgets

// RYOKU: shell appearance, wired to GlobalConfig.appearance.* (Ryoku.Config).
// Demonstrates the toggle->intensity disclosure: the transparency opacity sliders
// only appear when the Transparency toggle is on.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    Layout.fillWidth: true
    label: "Transparency"
    description: "Translucent panel and surface backgrounds (compositor blur)"
    checked: GlobalConfig.appearance.transparency.enabled
    onToggled: checked => {
      GlobalConfig.appearance.transparency.enabled = checked;
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    visible: GlobalConfig.appearance.transparency.enabled
    label: "Panel opacity"
    description: "Opacity of panel backgrounds"
    from: 0.4
    to: 1.0
    stepSize: 0.01
    value: GlobalConfig.appearance.transparency.base
    text: Math.round(GlobalConfig.appearance.transparency.base * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.transparency.base = value;
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    visible: GlobalConfig.appearance.transparency.enabled
    label: "Surface opacity"
    description: "Opacity of inner surfaces / layers"
    from: 0.2
    to: 1.0
    stepSize: 0.01
    value: GlobalConfig.appearance.transparency.layers
    text: Math.round(GlobalConfig.appearance.transparency.layers * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.transparency.layers = value;
      GlobalConfig.save();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "UI scale"
    description: "Overall scale of shell UI geometry"
    from: 0.8
    to: 1.3
    stepSize: 0.01
    value: GlobalConfig.appearance.deformScale
    text: Math.round(GlobalConfig.appearance.deformScale * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.deformScale = value;
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Corner rounding"
    description: "Roundness of panels, cards and controls"
    from: 0
    to: 1.6
    stepSize: 0.01
    value: GlobalConfig.appearance.rounding.scale
    text: Math.round(GlobalConfig.appearance.rounding.scale * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.rounding.scale = value;
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Spacing"
    description: "Gaps between elements"
    from: 0.5
    to: 1.5
    stepSize: 0.01
    value: GlobalConfig.appearance.spacing.scale
    text: Math.round(GlobalConfig.appearance.spacing.scale * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.spacing.scale = value;
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Padding"
    description: "Inner padding of panels and controls"
    from: 0.5
    to: 1.5
    stepSize: 0.01
    value: GlobalConfig.appearance.padding.scale
    text: Math.round(GlobalConfig.appearance.padding.scale * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.padding.scale = value;
      GlobalConfig.save();
    }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Font size"
    description: "Text size across the shell"
    from: 0.7
    to: 1.5
    stepSize: 0.01
    value: GlobalConfig.appearance.font.size.scale
    text: Math.round(GlobalConfig.appearance.font.size.scale * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.font.size.scale = value;
      GlobalConfig.save();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NValueSlider {
    Layout.fillWidth: true
    label: "Animation speed"
    description: "Duration of shell animations (0 = instant)"
    from: 0
    to: 2.0
    stepSize: 0.01
    value: GlobalConfig.appearance.anim.durations.scale
    text: Math.round(GlobalConfig.appearance.anim.durations.scale * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.anim.durations.scale = value;
      GlobalConfig.save();
    }
  }
}
