import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NComboBox {
    // TODO: wire bar position to ryoku (set via Hyprland config, not runtime QML)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-position-label")
    description: I18n.tr("panels.bar.appearance-position-description")
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "top",
        "name": I18n.tr("positions.top")
      }
    ]
    currentKey: "top"
  }

  NComboBox {
    // TODO: wire bar density to ryoku (no density config in ryoku bar)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-density-label")
    description: I18n.tr("panels.bar.appearance-density-description")
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "default",
        "name": I18n.tr("options.bar.density-default")
      }
    ]
    currentKey: "default"
  }

  NComboBox {
    // TODO: wire barType to ryoku (ryoku bar is a single type, no floating/framed concept)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-type-label")
    description: I18n.tr("panels.bar.appearance-type-description")
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "simple",
        "name": I18n.tr("options.bar.type-simple")
      }
    ]
    currentKey: "simple"
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

  NToggle {
    // TODO: wire separate bar opacity to ryoku (GlobalConfig.appearance.transparency.base is global, not bar-specific)
    label: I18n.tr("panels.bar.appearance-use-separate-opacity-label")
    description: I18n.tr("panels.bar.appearance-use-separate-opacity-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  NValueSlider {
    // TODO: wire bar background opacity to ryoku (GlobalConfig.appearance.transparency.base — global, not bar-specific)
    Layout.fillWidth: true
    visible: false
    label: I18n.tr("panels.bar.appearance-background-opacity-label")
    description: I18n.tr("panels.bar.appearance-background-opacity-description")
    from: 0
    to: 1
    stepSize: 0.01
    value: 1.0
    text: "100%"
    enabled: false
    opacity: 0.45
  }

  NValueSlider {
    // TODO: wire bar font scale to ryoku (GlobalConfig.appearance.font.size.scale — global, not bar-specific)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-font-scale-label")
    description: I18n.tr("panels.bar.appearance-font-scale-description")
    from: 0.5
    to: 2.0
    stepSize: 0.01
    value: 1.0
    text: "100%"
    enabled: false
    opacity: 0.45
  }

  NValueSlider {
    // TODO: wire bar widget spacing to ryoku (GlobalConfig.appearance.spacing.* — global, not bar-specific)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-widget-spacing-label")
    description: I18n.tr("panels.bar.appearance-widget-spacing-description")
    from: 0
    to: 30
    stepSize: 1
    value: 8
    text: "8px"
    enabled: false
    opacity: 0.45
  }

  NValueSlider {
    // TODO: wire bar content padding to ryoku (GlobalConfig.appearance.padding.* — global, not bar-specific)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-content-padding-label")
    description: I18n.tr("panels.bar.appearance-content-padding-description")
    from: 0
    to: 30
    stepSize: 1
    value: 8
    text: "8px"
    enabled: false
    opacity: 0.45
  }

  NToggle {
    // TODO: wire show outline to ryoku (no showOutline config in ryoku bar)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-show-outline-label")
    description: I18n.tr("panels.bar.appearance-show-outline-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  NToggle {
    // TODO: wire show capsule to ryoku (no capsule concept in ryoku bar)
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-show-capsule-label")
    description: I18n.tr("panels.bar.appearance-show-capsule-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  // capsule color and opacity controls hidden (no capsule in ryoku)

  NToggle {
    // TODO: wire exclusion zone inset to ryoku
    Layout.fillWidth: true
    label: I18n.tr("panels.bar.appearance-enable-exclusion-zone-inset-label")
    description: I18n.tr("panels.bar.appearance-enable-exclusion-zone-inset-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  NToggle {
    // TODO: wire hide-on-overview to ryoku (no hideOnOverview in ryoku bar)
    Layout.fillWidth: true
    visible: CompositorService.isNiri
    label: I18n.tr("panels.bar.appearance-hide-on-overview-label")
    description: I18n.tr("panels.bar.appearance-hide-on-overview-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  // auto-hide delay/show controls hidden (no autoHideDelay/autoShowDelay config in ryoku)
  // TODO: wire autoHideDelay, autoShowDelay, showOnWorkspaceSwitch to ryoku GlobalConfig.bar
}
