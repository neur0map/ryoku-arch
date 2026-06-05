import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: default applications -> GlobalConfig.general.apps.{terminal,explorer,
// playback,audio} (consumed shell-wide) plus the xdg default browser / file-manager /
// media handlers via the `ryoku-default-apps` helper. Favourite / hidden apps ->
// GlobalConfig.launcher.{favouriteApps,hiddenApps} (regex pattern lists).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Installed candidates per category, shaped {cat: [{key, name}, ...]}.
  property var catalog: ({})
  // The current xdg default browser binary (browser has no GlobalConfig key).
  property string currentBrowser: ""

  Process {
    id: listProc
    command: ["ryoku-default-apps", "list"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.catalog = JSON.parse(text || "{}");
        } catch (e) {
          root.catalog = {};
        }
      }
    }
  }

  Process {
    id: browserProc
    command: ["ryoku-default-apps", "get-browser"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.currentBrowser = (text || "").trim()
    }
  }

  function setDefaultApp(configKey, value) {
    GlobalConfig.general.apps[configKey] = [value];
    GlobalConfig.save();
  }

  function addPattern(isFav, pattern) {
    const cur = (isFav ? GlobalConfig.launcher.favouriteApps : GlobalConfig.launcher.hiddenApps) || [];
    const arr = cur.slice();
    if (arr.indexOf(pattern) !== -1)
      return;
    arr.push(pattern);
    if (isFav)
      GlobalConfig.launcher.favouriteApps = arr;
    else
      GlobalConfig.launcher.hiddenApps = arr;
    GlobalConfig.save();
  }

  function removePattern(isFav, index) {
    const arr = (isFav ? GlobalConfig.launcher.favouriteApps : GlobalConfig.launcher.hiddenApps).slice();
    arr.splice(index, 1);
    if (isFav)
      GlobalConfig.launcher.favouriteApps = arr;
    else
      GlobalConfig.launcher.hiddenApps = arr;
    GlobalConfig.save();
  }

  NText {
    text: qsTr("Default applications")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
  }
  NText {
    Layout.fillWidth: true
    text: qsTr("Pick which installed app handles each role. Install another one (e.g. a different terminal or browser) and it shows up here automatically.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  DefaultAppRow {
    category: "terminal"
    label: qsTr("Terminal")
    currentKey: (GlobalConfig.general.apps.terminal || [])[0] || ""
    onSelected: key => root.setDefaultApp("terminal", key)
  }
  DefaultAppRow {
    category: "browser"
    label: qsTr("Web browser")
    currentKey: root.currentBrowser
    onSelected: key => {
      Quickshell.execDetached(["ryoku-default-apps", "set-browser", key]);
      root.currentBrowser = key;
    }
  }
  DefaultAppRow {
    category: "filemanager"
    label: qsTr("File manager")
    currentKey: (GlobalConfig.general.apps.explorer || [])[0] || ""
    onSelected: key => {
      root.setDefaultApp("explorer", key);
      Quickshell.execDetached(["ryoku-default-apps", "set-filemanager", key]);
    }
  }
  DefaultAppRow {
    category: "media"
    label: qsTr("Media player")
    currentKey: (GlobalConfig.general.apps.playback || [])[0] || ""
    onSelected: key => {
      root.setDefaultApp("playback", key);
      Quickshell.execDetached(["ryoku-default-apps", "set-media", key]);
    }
  }
  DefaultAppRow {
    category: "mixer"
    label: qsTr("Volume mixer")
    currentKey: (GlobalConfig.general.apps.audio || [])[0] || ""
    onSelected: key => root.setDefaultApp("audio", key)
  }

  NDivider {
    Layout.fillWidth: true
  }

  PatternEditor {
    isFav: true
    title: qsTr("Favourite apps")
    desc: qsTr("Apps whose id matches a pattern are pinned to the top of the launcher and shown with a star.")
    patterns: GlobalConfig.launcher.favouriteApps
  }

  NDivider {
    Layout.fillWidth: true
  }

  PatternEditor {
    isFav: false
    title: qsTr("Hidden apps")
    desc: qsTr("Apps whose id matches a pattern are removed from the launcher entirely.")
    patterns: GlobalConfig.launcher.hiddenApps
  }

  component DefaultAppRow: NComboBox {
    id: dar
    required property string category

    Layout.fillWidth: true
    minimumWidth: 240
    placeholder: qsTr("Not set")
    // Always show the current pick, even if it is not a curated candidate.
    model: {
      var base = (root.catalog[dar.category] || []).slice();
      if (dar.currentKey && !base.some(i => i.key === dar.currentKey))
        base.unshift({
          "key": dar.currentKey,
          "name": dar.currentKey
        });
      return base;
    }
  }

  component PatternEditor: ColumnLayout {
    id: pe
    required property bool isFav
    required property string title
    required property string desc
    required property var patterns

    Layout.fillWidth: true
    spacing: Style.marginM

    NText {
      text: pe.title
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
    }
    NText {
      Layout.fillWidth: true
      text: pe.desc
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }

    NTextInputButton {
      id: input
      Layout.fillWidth: true
      placeholderText: qsTr("Pattern (regex), e.g. firefox or org\\.gnome\\..*")
      buttonIcon: "add"
      onButtonClicked: {
        const t = input.text.trim();
        if (t.length > 0) {
          root.addPattern(pe.isFav, t);
          input.text = "";
        }
      }
    }

    NText {
      visible: !pe.patterns || pe.patterns.length === 0
      text: qsTr("None yet.")
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
    }

    Repeater {
      model: pe.patterns
      delegate: NBox {
        id: row
        required property int index
        required property string modelData
        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + Style.marginM
        color: Color.mSurface

        RowLayout {
          id: rowLayout
          anchors.fill: parent
          anchors.leftMargin: Style.marginM
          anchors.rightMargin: Style.marginS
          spacing: Style.marginS

          NText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: row.modelData
            color: Color.mOnSurface
            elide: Text.ElideRight
          }
          NIconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "trash"
            tooltipText: qsTr("Remove")
            baseSize: Style.baseWidgetSize * 0.8
            colorFg: Color.mError
            onClicked: root.removePattern(pe.isFav, row.index)
          }
        }
      }
    }
  }
}
