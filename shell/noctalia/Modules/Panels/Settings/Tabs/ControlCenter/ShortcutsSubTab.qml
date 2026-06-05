import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.System
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  Layout.fillHeight: true

  required property var availableWidgets

  signal addWidgetToSection(string widgetId, string section)
  signal removeWidgetFromSection(string section, int index)
  signal reorderWidgetInSection(string section, int fromIndex, int toIndex)
  signal updateWidgetSettingsInSection(string section, int index, var settings)
  signal moveWidgetBetweenSections(string fromSection, int index, string toSection)
  signal openPluginSettingsRequested(var manifest)

  function getSectionIcons() {
    return {
      "left": "arrow-bar-to-up",
      "right": "arrow-bar-to-down"
    };
  }

  ColumnLayout {
    spacing: Style.marginXXS
    Layout.fillWidth: true

    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.topMargin: Style.marginM
      spacing: Style.marginM

      NSectionEditor {
        sectionName: I18n.tr("positions.left")
        sectionId: "left"
        settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/noctalia" + "/Modules/Panels/Settings/ControlCenter/ControlCenterWidgetSettingsDialog.qml")
        maxWidgets: Settings.data.controlCenter.shortcuts["right"].length > 5 ? 0 : (Settings.data.controlCenter.shortcuts["right"].length > 0 ? 5 : 10)
        widgetRegistry: ControlCenterWidgetRegistry
        widgetModel: Settings.data.controlCenter.shortcuts["left"]
        sectionIcons: root.getSectionIcons()
        availableWidgets: root.availableWidgets
        availableSections: ["left", "right"]
        onAddWidget: (widgetId, section) => root.addWidgetToSection(widgetId, section)
        onRemoveWidget: (section, index) => root.removeWidgetFromSection(section, index)
        onReorderWidget: (section, fromIndex, toIndex) => root.reorderWidgetInSection(section, fromIndex, toIndex)
        onUpdateWidgetSettings: (section, index, settings) => root.updateWidgetSettingsInSection(section, index, settings)
        onMoveWidget: (fromSection, index, toSection) => root.moveWidgetBetweenSections(fromSection, index, toSection)
        onOpenPluginSettingsRequested: manifest => root.openPluginSettingsRequested(manifest)
      }

      NSectionEditor {
        sectionName: I18n.tr("positions.right")
        sectionId: "right"
        settingsDialogComponent: Qt.resolvedUrl(Quickshell.shellDir + "/noctalia" + "/Modules/Panels/Settings/ControlCenter/ControlCenterWidgetSettingsDialog.qml")
        maxWidgets: Settings.data.controlCenter.shortcuts["left"].length > 5 ? 0 : (Settings.data.controlCenter.shortcuts["left"].length > 0 ? 5 : 10)
        widgetRegistry: ControlCenterWidgetRegistry
        widgetModel: Settings.data.controlCenter.shortcuts["right"]
        sectionIcons: root.getSectionIcons()
        availableWidgets: root.availableWidgets
        availableSections: ["left", "right"]
        onAddWidget: (widgetId, section) => root.addWidgetToSection(widgetId, section)
        onRemoveWidget: (section, index) => root.removeWidgetFromSection(section, index)
        onReorderWidget: (section, fromIndex, toIndex) => root.reorderWidgetInSection(section, fromIndex, toIndex)
        onUpdateWidgetSettings: (section, index, settings) => root.updateWidgetSettingsInSection(section, index, settings)
        onMoveWidget: (fromSection, index, toSection) => root.moveWidgetBetweenSections(fromSection, index, toSection)
        onOpenPluginSettingsRequested: manifest => root.openPluginSettingsRequested(manifest)
      }
    }
  }

  Rectangle {
    Layout.fillHeight: true
  }
}
