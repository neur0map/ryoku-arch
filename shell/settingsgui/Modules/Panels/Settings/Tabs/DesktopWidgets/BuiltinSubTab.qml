import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // RYOKU WIRED: GlobalConfig.background.* (backgroundconfig.hpp). These are the
  // real built-in desktop widgets rendered by shell/modules/background/Background.qml.

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Enable desktop widgets")
    description: qsTr("Show draggable widgets on the desktop background.")
    checked: GlobalConfig.background.widgets.enabled
    onToggled: checked => {
                 GlobalConfig.background.widgets.enabled = checked;
                 GlobalConfig.save();
               }
  }

  NButton {
    Layout.fillWidth: true
    enabled: GlobalConfig.background.widgets.enabled
    text: Visibilities.widgetEditMode ? qsTr("Stop editing widgets") : qsTr("Edit widgets (drag, resize, lock)")
    icon: "edit"
    onClicked: {
      Visibilities.widgetEditMode = !Visibilities.widgetEditMode;
      if (Visibilities.widgetEditMode) {
        const v = Visibilities.getForActive();
        if (v)
          v.settings = false;
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    enabled: GlobalConfig.background.widgets.enabled
    spacing: Style.marginM

    NButton {
      text: qsTr("Add sticky note")
      icon: "note"
      onClicked: Notes.create()
    }
    NText {
      Layout.fillWidth: true
      text: Notes.list.length === 1 ? qsTr("1 note") : qsTr("%1 notes").arg(Notes.list.length)
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      verticalAlignment: Text.AlignVCenter
    }
  }

  RowLayout {
    Layout.fillWidth: true
    enabled: GlobalConfig.background.widgets.enabled
    spacing: Style.marginL

    NToggle {
      label: qsTr("Snap to grid")
      checked: GlobalConfig.background.widgets.snap
      onToggled: checked => {
                   GlobalConfig.background.widgets.snap = checked;
                   GlobalConfig.save();
                 }
    }

    NSpinBox {
      label: qsTr("Grid size")
      from: 4
      to: 64
      stepSize: 4
      suffix: "px"
      value: GlobalConfig.background.widgets.gridSize
      onValueChanged: {
        if (GlobalConfig.background.widgets.gridSize !== value) {
          GlobalConfig.background.widgets.gridSize = value;
          GlobalConfig.save();
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginL
    enabled: GlobalConfig.background.widgets.enabled

    // Clock — background is a sub-object (desktopClock.background.enabled).
    NBox {
      Layout.fillWidth: true
      implicitHeight: clockCol.implicitHeight + Style.margin2L
      color: Color.mSurface

      ColumnLayout {
        id: clockCol
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
          text: qsTr("Clock")
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
        }
        NToggle {
          Layout.fillWidth: true
          label: qsTr("Enabled")
          checked: GlobalConfig.background.desktopClock.enabled
          onToggled: checked => {
                       GlobalConfig.background.desktopClock.enabled = checked;
                       GlobalConfig.save();
                     }
        }
        NToggle {
          Layout.fillWidth: true
          label: qsTr("Background")
          checked: GlobalConfig.background.desktopClock.background.enabled
          onToggled: checked => {
                       GlobalConfig.background.desktopClock.background.enabled = checked;
                       GlobalConfig.save();
                     }
        }
        NValueSlider {
          Layout.fillWidth: true
          label: qsTr("Scale")
          from: 0.4
          to: 2.5
          stepSize: 0.05
          value: GlobalConfig.background.desktopClock.scale
          text: Math.round(GlobalConfig.background.desktopClock.scale * 100) + "%"
          onMoved: value => {
                     GlobalConfig.background.desktopClock.scale = value;
                     GlobalConfig.save();
                   }
        }
        NComboBox {
          Layout.fillWidth: true
          label: qsTr("Style")
          model: [
            { "key": "modern", "name": qsTr("Modern") },
            { "key": "minimal", "name": qsTr("Minimal") },
            { "key": "stacked", "name": qsTr("Stacked") },
            { "key": "compact", "name": qsTr("Compact") }
          ]
          currentKey: GlobalConfig.background.desktopClock.style
          onSelected: key => {
                        GlobalConfig.background.desktopClock.style = key;
                        GlobalConfig.save();
                      }
        }
      }
    }

    StdWidgetCard {
      title: qsTr("Media")
      cfg: GlobalConfig.background.widgets.media
    }
    StdWidgetCard {
      title: qsTr("Resources")
      cfg: GlobalConfig.background.widgets.resources
      styleOptions: [
        { "key": "default", "name": qsTr("Rings") },
        { "key": "bars", "name": qsTr("Bars") },
        { "key": "compact", "name": qsTr("Compact") }
      ]
    }
    StdWidgetCard {
      title: qsTr("Weather")
      cfg: GlobalConfig.background.widgets.weather
      styleOptions: [
        { "key": "default", "name": qsTr("Card") },
        { "key": "minimal", "name": qsTr("Minimal") },
        { "key": "detailed", "name": qsTr("Detailed") }
      ]
    }
    StdWidgetCard {
      title: qsTr("Battery")
      cfg: GlobalConfig.background.widgets.battery
      note: qsTr("Only shown on laptops.")
    }
  }

  component StdWidgetCard: NBox {
    id: card
    required property string title
    required property var cfg
    property string note: ""
    property var styleOptions: []

    Layout.fillWidth: true
    implicitHeight: cardCol.implicitHeight + Style.margin2L
    color: Color.mSurface

    ColumnLayout {
      id: cardCol
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NText {
        text: card.title
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }
      NText {
        visible: card.note.length > 0
        text: card.note
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }
      NToggle {
        Layout.fillWidth: true
        label: qsTr("Enabled")
        checked: card.cfg.enabled
        onToggled: checked => {
                     card.cfg.enabled = checked;
                     GlobalConfig.save();
                   }
      }
      NToggle {
        Layout.fillWidth: true
        label: qsTr("Background")
        checked: card.cfg.background
        onToggled: checked => {
                     card.cfg.background = checked;
                     GlobalConfig.save();
                   }
      }
      NValueSlider {
        Layout.fillWidth: true
        label: qsTr("Scale")
        from: 0.4
        to: 2.5
        stepSize: 0.05
        value: card.cfg.scale
        text: Math.round(card.cfg.scale * 100) + "%"
        onMoved: value => {
                   card.cfg.scale = value;
                   GlobalConfig.save();
                 }
      }
      NComboBox {
        Layout.fillWidth: true
        visible: card.styleOptions.length > 0
        label: qsTr("Style")
        model: card.styleOptions
        currentKey: card.cfg.style
        onSelected: key => {
                      card.cfg.style = key;
                      GlobalConfig.save();
                    }
      }
    }
  }
}
