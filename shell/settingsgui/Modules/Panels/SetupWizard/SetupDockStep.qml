import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Widgets

ColumnLayout {
  id: root

  spacing: Style.marginM

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Style.marginL
    spacing: Style.marginM

    Rectangle {
      width: 40
      height: 40
      radius: Style.radiusL
      color: Color.mSurfaceVariant
      opacity: 0.6

      NIcon {
        icon: "device-desktop"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
        anchors.centerIn: parent
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXS

      NText {
        text: I18n.tr("panels.dock.title") || "Dock"
        pointSize: Style.fontSizeXL
        font.weight: Style.fontWeightBold
        color: Color.mPrimary
      }

      NText {
        text: I18n.tr("panels.dock.monitors-desc")
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginL

    NToggle {
      Layout.fillWidth: true
      label: I18n.tr("panels.dock.enabled-label")
      description: I18n.tr("panels.dock.enabled-description")
      checked: GlobalConfig.dock.enabled
      onToggled: checked => {
        GlobalConfig.dock.enabled = checked;
        GlobalConfig.save();
      }
    }

    NComboBox {
      visible: GlobalConfig.dock.enabled
      Layout.fillWidth: true
      label: I18n.tr("panels.display.title")
      description: I18n.tr("panels.dock.appearance-display-description")
      model: [
        {
          "key": "always_visible",
          "name": I18n.tr("hide-modes.visible")
        },
        {
          "key": "auto_hide",
          "name": I18n.tr("panels.dock.appearance-display-auto-hide")
        },
        {
          "key": "exclusive",
          "name": I18n.tr("panels.dock.appearance-display-exclusive")
        }
      ]
      currentKey: GlobalConfig.dock.displayMode
      onSelected: key => {
        GlobalConfig.dock.displayMode = key;
        GlobalConfig.save();
      }
    }

    ColumnLayout {
      visible: GlobalConfig.dock.enabled
      spacing: Style.marginXXS
      Layout.fillWidth: true
      NLabel {
        label: I18n.tr("panels.osd.background-opacity-label")
        description: I18n.tr("panels.dock.appearance-background-opacity-description")
      }
      NValueSlider {
        Layout.fillWidth: true
        from: 0
        to: 1
        stepSize: 0.01
        value: GlobalConfig.dock.backgroundOpacity
        onMoved: value => {
          GlobalConfig.dock.backgroundOpacity = value;
          GlobalConfig.save();
        }
        text: Math.floor(GlobalConfig.dock.backgroundOpacity * 100) + "%"
      }
    }

    ColumnLayout {
      visible: GlobalConfig.dock.enabled
      spacing: Style.marginXXS
      Layout.fillWidth: true
      NLabel {
        label: I18n.tr("panels.dock.appearance-floating-distance-label")
        description: I18n.tr("panels.dock.appearance-floating-distance-description")
      }
      NValueSlider {
        Layout.fillWidth: true
        from: 0
        to: 4
        stepSize: 0.01
        value: GlobalConfig.dock.floatingRatio
        onMoved: value => {
          GlobalConfig.dock.floatingRatio = value;
          GlobalConfig.save();
        }
        text: Math.floor(GlobalConfig.dock.floatingRatio * 100) + "%"
      }
    }

    ColumnLayout {
      visible: GlobalConfig.dock.enabled
      spacing: Style.marginXXS
      Layout.fillWidth: true
      NLabel {
        label: I18n.tr("panels.dock.appearance-icon-size-label")
        description: I18n.tr("panels.dock.appearance-icon-size-description")
      }
      NValueSlider {
        Layout.fillWidth: true
        from: 0
        to: 2
        stepSize: 0.01
        value: GlobalConfig.dock.size
        onMoved: value => {
          GlobalConfig.dock.size = value;
          GlobalConfig.save();
        }
        text: Math.floor(GlobalConfig.dock.size * 100) + "%"
      }
    }

    NToggle {
      visible: GlobalConfig.dock.enabled
      Layout.fillWidth: true
      label: I18n.tr("panels.dock.monitors-only-same-monitor-label")
      description: I18n.tr("panels.dock.monitors-only-same-monitor-description")
      checked: GlobalConfig.dock.onlySameOutput
      onToggled: checked => {
        GlobalConfig.dock.onlySameOutput = checked;
        GlobalConfig.save();
      }
    }

    NToggle {
      visible: GlobalConfig.dock.enabled
      Layout.fillWidth: true
      label: I18n.tr("panels.dock.appearance-colorize-icons-label")
      description: I18n.tr("panels.dock.appearance-colorize-icons-description")
      checked: GlobalConfig.dock.colorizeIcons
      onToggled: checked => {
        GlobalConfig.dock.colorizeIcons = checked;
        GlobalConfig.save();
      }
    }

    NHeader {
      visible: GlobalConfig.dock.enabled
      label: I18n.tr("panels.dock.monitors-title")
      description: I18n.tr("panels.dock.monitors-desc")
    }

    Repeater {
      visible: GlobalConfig.dock.enabled
      model: Quickshell.screens || []
      delegate: NCheckbox {
        Layout.fillWidth: true
        readonly property real compositorScale: {
          const info = CompositorService.displayScales[modelData.name];
          return (info && info.scale) ? info.scale : 1.0;
        }
        label: modelData.name || "Unknown"
        visible: GlobalConfig.dock.enabled
        description: {
          I18n.tr("system.monitor-description", {
                    "model": modelData.model,
                    "width": modelData.width * compositorScale,
                    "height": modelData.height * compositorScale,
                    "scale": compositorScale
                  });
        }
        checked: (GlobalConfig.dock.monitors || []).indexOf(modelData.name) !== -1
        onToggled: checked => {
                     if (checked) {
                       const arr = (GlobalConfig.dock.monitors || []).slice();
                       if (arr.indexOf(modelData.name) === -1)
                       arr.push(modelData.name);
                       GlobalConfig.dock.monitors = arr;
                     } else {
                       GlobalConfig.dock.monitors = (GlobalConfig.dock.monitors || []).filter(function (n) {
                         return n !== modelData.name;
                       });
                     }
                     GlobalConfig.save();
                   }
      }
    }
  }
}
