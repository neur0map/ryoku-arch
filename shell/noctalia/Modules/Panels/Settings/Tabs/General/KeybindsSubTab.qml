import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  width: parent.width
  enabled: false
  opacity: 0.45

  // TODO: wire keybinds to ryoku (no keybinds config in ryoku; NKeybindRecorder requires Settings.data.general.keybinds.*)

  NLabel {
    label: I18n.tr("panels.general.keybinds-title")
    description: I18n.tr("panels.general.keybinds-description")
    Layout.fillWidth: true
  }

  NKeybindRecorder {
    Layout.fillWidth: true
    label: I18n.tr("panels.general.keybinds-up")
    currentKeybinds: ["Up"]
    defaultKeybind: "Up"
    settingsPath: ""
    onKeybindsChanged: newKeybinds => {}
  }

  NKeybindRecorder {
    Layout.fillWidth: true
    label: I18n.tr("panels.general.keybinds-down")
    currentKeybinds: ["Down"]
    defaultKeybind: "Down"
    settingsPath: ""
    onKeybindsChanged: newKeybinds => {}
  }

  NKeybindRecorder {
    Layout.fillWidth: true
    label: I18n.tr("panels.general.keybinds-left")
    currentKeybinds: ["Left"]
    defaultKeybind: "Left"
    settingsPath: ""
    onKeybindsChanged: newKeybinds => {}
  }

  NKeybindRecorder {
    Layout.fillWidth: true
    label: I18n.tr("panels.general.keybinds-right")
    currentKeybinds: ["Right"]
    defaultKeybind: "Right"
    settingsPath: ""
    onKeybindsChanged: newKeybinds => {}
  }

  NKeybindRecorder {
    Layout.fillWidth: true
    label: I18n.tr("panels.general.keybinds-enter")
    currentKeybinds: ["Return"]
    defaultKeybind: "Return"
    settingsPath: ""
    onKeybindsChanged: newKeybinds => {}
  }

  NKeybindRecorder {
    Layout.fillWidth: true
    label: I18n.tr("panels.general.keybinds-escape")
    currentKeybinds: ["Esc"]
    defaultKeybind: "Esc"
    settingsPath: ""
    onKeybindsChanged: newKeybinds => {}
  }

  NKeybindRecorder {
    Layout.fillWidth: true
    label: I18n.tr("panels.general.keybinds-remove")
    currentKeybinds: ["Del"]
    defaultKeybind: "Del"
    settingsPath: ""
    onKeybindsChanged: newKeybinds => {}
  }
}
