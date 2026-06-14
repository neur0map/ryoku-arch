import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: GlobalConfig.launcher.* (launcherconfig.hpp). ryoku's launcher is a
// prefix-driven drawer (apps + >actions + @field-search + scheme/variant/wallpaper).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Use Vicinae launcher")
    description: qsTr("On by default. When off, Super+Space opens the built-in Ryoku launcher (configured below) and the Vicinae server is stopped.")
    checked: GlobalConfig.launcher.useVicinae
    onToggled: checked => {
                 GlobalConfig.launcher.useVicinae = checked;
                 GlobalConfig.save();
                 // Reconcile the server now; pass the chosen backend so it does
                 // not depend on the save having flushed to disk yet.
                 Quickshell.execDetached(["ryoku-launch-app", "apply", checked ? "vicinae" : "quickshell"]);
               }
  }

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Enable launcher")
    description: qsTr("Master switch for the built-in launcher — when off, the built-in launcher won't open at all (only relevant when Vicinae is off above).")
    checked: GlobalConfig.launcher.enabled
    onToggled: checked => {
                 GlobalConfig.launcher.enabled = checked;
                 GlobalConfig.save();
               }
  }

  NSpinBox {
    Layout.fillWidth: true
    label: qsTr("Results shown")
    description: qsTr("How many results are visible before the list scrolls.")
    from: 1
    to: 20
    stepSize: 1
    value: GlobalConfig.launcher.maxShown
    onValueChanged: {
      if (GlobalConfig.launcher.maxShown !== value) {
        GlobalConfig.launcher.maxShown = value;
        GlobalConfig.save();
      }
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Vim keybindings")
    description: qsTr("Navigate results with Ctrl+J / Ctrl+K (and Ctrl+N/P, Tab) as well as the arrow keys.")
    checked: GlobalConfig.launcher.vimKeybinds
    onToggled: checked => {
                 GlobalConfig.launcher.vimKeybinds = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Show dangerous actions")
    description: qsTr("Show launcher actions flagged as dangerous (e.g. power off, reset). Off hides them so they can't be triggered by accident.")
    checked: GlobalConfig.launcher.enableDangerousActions
    onToggled: checked => {
                 GlobalConfig.launcher.enableDangerousActions = checked;
                 GlobalConfig.save();
               }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: qsTr("Search prefixes")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NTextInput {
    Layout.fillWidth: true
    label: qsTr("Action prefix")
    description: qsTr("Type this to switch the search into commands mode (scheme, wallpaper, calc, custom actions).")
    text: GlobalConfig.launcher.actionPrefix
    onEditingFinished: {
      if (text.length > 0 && text !== GlobalConfig.launcher.actionPrefix) {
        GlobalConfig.launcher.actionPrefix = text;
        GlobalConfig.save();
      }
    }
  }

  NTextInput {
    Layout.fillWidth: true
    label: qsTr("Advanced-search prefix")
    description: qsTr("Prefix for field-filtered app search: e.g. @c category, @k keyword, @d description, @e exec, @w window class, @t terminal apps.")
    text: GlobalConfig.launcher.specialPrefix
    onEditingFinished: {
      if (text.length > 0 && text !== GlobalConfig.launcher.specialPrefix) {
        GlobalConfig.launcher.specialPrefix = text;
        GlobalConfig.save();
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: qsTr("Fuzzy search")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }
  NText {
    Layout.fillWidth: true
    text: qsTr("Fuzzy matching is typo-tolerant (“frfx” → Firefox); off uses stricter matching.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Apps")
    checked: GlobalConfig.launcher.useFuzzy.apps
    onToggled: checked => {
                 GlobalConfig.launcher.useFuzzy.apps = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Actions")
    checked: GlobalConfig.launcher.useFuzzy.actions
    onToggled: checked => {
                 GlobalConfig.launcher.useFuzzy.actions = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Color schemes")
    checked: GlobalConfig.launcher.useFuzzy.schemes
    onToggled: checked => {
                 GlobalConfig.launcher.useFuzzy.schemes = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Scheme variants")
    checked: GlobalConfig.launcher.useFuzzy.variants
    onToggled: checked => {
                 GlobalConfig.launcher.useFuzzy.variants = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Wallpapers")
    checked: GlobalConfig.launcher.useFuzzy.wallpapers
    onToggled: checked => {
                 GlobalConfig.launcher.useFuzzy.wallpapers = checked;
                 GlobalConfig.save();
               }
  }
}
