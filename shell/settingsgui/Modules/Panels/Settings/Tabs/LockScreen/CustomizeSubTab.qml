import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

// RYOKU: per-theme customisation for the ACTIVE qylock theme. qylock has no global
// config — each theme's options live in its theme.conf [General] section, and the keys
// vary per theme. We only surface controls for keys the active theme actually declares
// (read via LockThemes.activeOptions), writing back with LockThemes.setOption().
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property var opts: LockThemes.activeOptions
  readonly property bool hasAny: opts.themeMode !== undefined
                                 || opts.background_mode !== undefined
                                 || opts.gameMode !== undefined
                                 || opts.enableWindup !== undefined
                                 || opts.fontSize !== undefined

  NText {
    Layout.fillWidth: true
    text: LockThemes.active.length > 0 ? qsTr("Customising: %1").arg(LockThemes.active) : qsTr("No theme selected")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }

  NText {
    Layout.fillWidth: true
    text: qsTr("These options come from the theme itself and differ per theme. Changes apply on the next lock.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NText {
    Layout.fillWidth: true
    visible: !root.hasAny
    text: LockThemes.active.length > 0 ? qsTr("This theme has no adjustable options.") : qsTr("Pick a theme in the Themes tab to customise it.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NComboBox {
    visible: root.opts.themeMode !== undefined
    Layout.fillWidth: true
    label: qsTr("Theme mode")
    description: qsTr("Light or dark variant of this theme.")
    model: [
      { "key": "dark", "name": qsTr("Dark") },
      { "key": "light", "name": qsTr("Light") }
    ]
    currentKey: root.opts.themeMode || "dark"
    onSelected: key => LockThemes.setOption("themeMode", key)
  }

  NComboBox {
    visible: root.opts.background_mode !== undefined
    Layout.fillWidth: true
    label: qsTr("Background")
    description: qsTr("How this theme picks its background image.")
    model: [
      { "key": "time", "name": qsTr("By time of day") },
      { "key": "random", "name": qsTr("Random") },
      { "key": "static", "name": qsTr("Fixed") }
    ]
    currentKey: root.opts.background_mode || "time"
    onSelected: key => LockThemes.setOption("background_mode", key)
  }

  NSpinBox {
    visible: root.opts.background_index !== undefined && root.opts.background_mode === "static"
    Layout.fillWidth: true
    label: qsTr("Background number")
    description: qsTr("Which of the theme's backgrounds to use when fixed.")
    from: 1
    to: 9
    stepSize: 1
    value: parseInt(root.opts.background_index || "1", 10)
    onValueChanged: {
      if (parseInt(root.opts.background_index || "1", 10) !== value)
        LockThemes.setOption("background_index", value);
    }
  }

  NComboBox {
    visible: root.opts.gameMode !== undefined
    Layout.fillWidth: true
    label: qsTr("Unlock mode")
    description: qsTr("Menu-only goes straight to the password; game adds the rhythm-game gate.")
    model: [
      { "key": "menu", "name": qsTr("Menu only") },
      { "key": "game", "name": qsTr("Rhythm game") }
    ]
    currentKey: root.opts.gameMode || "game"
    onSelected: key => LockThemes.setOption("gameMode", key)
  }

  NToggle {
    visible: root.opts.enableWindup !== undefined
    Layout.fillWidth: true
    label: qsTr("Windup clock animation")
    description: qsTr("Play the clock windup animation when unlocking.")
    checked: root.opts.enableWindup === "true"
    onToggled: checked => LockThemes.setOption("enableWindup", checked ? "true" : "false")
  }

  NSpinBox {
    visible: root.opts.fontSize !== undefined
    Layout.fillWidth: true
    label: qsTr("Font size")
    from: 8
    to: 48
    stepSize: 1
    value: parseInt(root.opts.fontSize || "12", 10)
    onValueChanged: {
      if (parseInt(root.opts.fontSize || "12", 10) !== value)
        LockThemes.setOption("fontSize", value);
    }
  }
}
