import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  enabled: false
  opacity: 0.45

  // Interface kept for BarTab.qml compatibility (greyed content doesn't use these).
  property var availableWidgets: []
  property var addWidgetToSection: null
  property var removeWidgetFromSection: null
  property var reorderWidgetInSection: null
  property var updateWidgetSettingsInSection: null
  property var moveWidgetBetweenSections: null
  signal openPluginSettings(var manifest)

  // TODO: wire bar widget registry to ryoku (ryoku bar uses GlobalConfig.bar.entries QVariantList;
  //   no BarWidgetRegistry / NSectionEditor equivalent in ryoku; widget ordering/toggle not yet configurable via settings)

  NText {
    text: I18n.tr("panels.bar.widgets-desc")
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  NLabel {
    label: I18n.tr("positions.left")
    Layout.fillWidth: true
  }

  NLabel {
    label: I18n.tr("positions.center")
    Layout.fillWidth: true
  }

  NLabel {
    label: I18n.tr("positions.right")
    Layout.fillWidth: true
  }
}
