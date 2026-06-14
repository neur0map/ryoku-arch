import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU: friendly Hyprland keybind manager.
// Lists every keyboard shortcut with a plain-language description (never the raw
// command), and offers an assisted builder: pick what the shortcut should do from
// a list of common actions, fill in only the field that action needs, and choose
// the keys. Power users can pick "Custom command" to type a full Hyprland
// dispatcher. Mutations go through `ryoku-keybinds`, which applies them instantly
// (`hyprctl keyword`) and persists to a dedicated overlay (ryoku-keybinds.lua in
// Lua mode, ryoku-keybinds.conf otherwise) loaded from the main config, so the
// shipped hyprland.lua is never hand-edited.
ColumnLayout {
  id: root
  spacing: Style.marginL
  width: parent.width

  property var allBinds: []
  property string filterText: ""
  property bool busy: false

  property bool editing: false
  property string editOrigMods: ""
  property string editOrigKey: ""
  property string actionKey: "app"
  property string directionKey: "l"
  readonly property string param: root.presetParam(root.actionKey)
  property var modsOn: [false, false, false, false]
  readonly property var modNames: ["Super", "Ctrl", "Alt", "Shift"]
  readonly property var modFlags: ["SUPER", "CTRL", "ALT", "SHIFT"]

  readonly property var actionPresets: [
    {
      "key": "app",
      "name": "Launch an application"
    },
    {
      "key": "killactive",
      "name": "Close active window"
    },
    {
      "key": "fullscreen",
      "name": "Toggle fullscreen"
    },
    {
      "key": "togglefloating",
      "name": "Toggle floating window"
    },
    {
      "key": "workspace",
      "name": "Go to workspace…"
    },
    {
      "key": "movetoworkspace",
      "name": "Move window to workspace…"
    },
    {
      "key": "movefocus",
      "name": "Move focus to another window…"
    },
    {
      "key": "movewindow",
      "name": "Move window…"
    },
    {
      "key": "custom",
      "name": "Custom command (advanced)"
    }
  ]
  readonly property var directionModel: [
    {
      "key": "l",
      "name": "Left"
    },
    {
      "key": "r",
      "name": "Right"
    },
    {
      "key": "u",
      "name": "Up"
    },
    {
      "key": "d",
      "name": "Down"
    }
  ]

  function presetParam(k) {
    switch (k) {
    case "app":
      return "command";
    case "workspace":
    case "movetoworkspace":
      return "workspace";
    case "movefocus":
    case "movewindow":
      return "direction";
    case "custom":
      return "raw";
    default:
      return "none";
    }
  }

  function presetDispatcher(k) {
    switch (k) {
    case "app":
      return "exec";
    case "custom":
      return "";
    default:
      return k;
    }
  }

  function titleCase(s) {
    return (s || "").split(/[\s-]+/).filter(function (w) {
      return w.length > 0;
    }).map(function (w) {
      return w.charAt(0).toUpperCase() + w.slice(1);
    }).join(" ");
  }

  function dirName(a) {
    switch (a) {
    case "l":
      return "left";
    case "r":
      return "right";
    case "u":
      return "up";
    case "d":
      return "down";
    default:
      return a || "";
    }
  }

  function knownApp(base) {
    var known = {
      "kitty": "Open terminal",
      "foot": "Open terminal",
      "alacritty": "Open terminal",
      "wezterm": "Open terminal",
      "ghostty": "Open terminal",
      "firefox": "Open browser",
      "chromium": "Open browser",
      "google-chrome": "Open browser",
      "brave": "Open browser",
      "helium": "Open browser",
      "zen": "Open browser",
      "nautilus": "Open file manager",
      "thunar": "Open file manager",
      "dolphin": "Open file manager",
      "nemo": "Open file manager",
      "yazi": "Open file manager",
      "nvim": "Open editor",
      "code": "Open editor",
      "obsidian": "Open notes",
      "wpctl": "Volume control",
      "pactl": "Volume control",
      "pamixer": "Volume control",
      "playerctl": "Media control",
      "brightnessctl": "Adjust brightness",
      "grim": "Take screenshot",
      "grimblast": "Take screenshot",
      "hyprshot": "Take screenshot",
      "hyprlock": "Lock screen",
      "wlogout": "Power menu",
      "rofi": "App launcher",
      "wofi": "App launcher",
      "fuzzel": "App launcher",
      "launcher": "App launcher",
      "cliphist": "Clipboard history"
    };
    return known[base] || "";
  }

  function friendlyExec(arg) {
    if (!arg || arg.length === 0)
      return "Run a command";
    // unwrap a shell wrapper: sh -c / sh -lc / bash -c '…'
    var inner = arg;
    var shm = arg.match(/^\S*sh\s+-[a-z]*c\s+(.*)$/i);
    if (shm)
      inner = shm[1];
    inner = inner.replace(/^['"]/, "").replace(/['"]$/, "").trim();

    // ryoku-launch-tui <app> — the meaningful app is the argument
    var tui = inner.match(/ryoku-launch-tui\s+(\S+)/i);
    if (tui) {
      var ta = tui[1].split("/").pop();
      return root.knownApp(ta) || ("Launch " + root.titleCase(ta));
    }
    var launch = inner.match(/ryoku-launch-([a-z0-9-]+)/i);
    if (launch)
      return "Launch " + root.titleCase(launch[1]);
    // ryoku-shell <verb> (e.g. ryoku-shell launcher)
    var rshell = inner.match(/ryoku-shell\s+(\S+)/i);
    if (rshell)
      return rshell[1] === "launcher" ? "App launcher" : root.titleCase(rshell[1]);
    var ryoku = inner.match(/ryoku-([a-z0-9-]+)/i);
    if (ryoku)
      return root.titleCase(ryoku[1]);

    var first = inner.split(/\s+/)[0];
    var base = first.split("/").pop().replace(/['"]/g, "");
    return root.knownApp(base) || ("Launch " + root.titleCase(base.replace(/\.(sh|desktop)$/, "")));
  }

  function friendlyAction(disp, arg) {
    arg = arg || "";
    switch (disp) {
    case "exec":
      return root.friendlyExec(arg);
    case "killactive":
      return "Close active window";
    case "fullscreen":
      return "Toggle fullscreen";
    case "fakefullscreen":
      return "Toggle fake fullscreen";
    case "togglefloating":
      return "Toggle floating window";
    case "pin":
      return "Pin window on top";
    case "workspace":
      if (arg === "e+1")
        return "Go to next workspace";
      if (arg === "e-1")
        return "Go to previous workspace";
      if (arg === "previous")
        return "Go to last workspace";
      return "Go to workspace " + arg;
    case "movetoworkspace":
      return "Move window to workspace " + arg;
    case "movetoworkspacesilent":
      return "Move window to workspace " + arg + " (silent)";
    case "movefocus":
      return "Move focus " + root.dirName(arg);
    case "movewindow":
      return "Move window " + root.dirName(arg);
    case "resizeactive":
      return "Resize active window";
    case "togglespecialworkspace":
      return "Toggle scratchpad" + (arg ? (": " + arg) : "");
    case "togglesplit":
      return "Toggle split direction";
    case "pseudo":
      return "Toggle pseudo-tiling";
    case "exit":
      return "Exit Hyprland session";
    case "forcerendererreload":
      return "Reload renderer";
    default:
      return root.titleCase(disp) + (arg ? (" " + arg) : "");
    }
  }

  function decodeMods(m) {
    var parts = [];
    if (m & 64)
      parts.push("SUPER");
    if (m & 4)
      parts.push("CTRL");
    if (m & 8)
      parts.push("ALT");
    if (m & 1)
      parts.push("SHIFT");
    return parts.join(" ");
  }

  function setMod(i, val) {
    var a = root.modsOn.slice();
    a[i] = val;
    root.modsOn = a;
  }

  function formMods() {
    var parts = [];
    for (var i = 0; i < 4; i++) {
      if (root.modsOn[i])
        parts.push(root.modFlags[i]);
    }
    return parts.join(" ");
  }

  function comboLabel(mods, key) {
    var p = mods.length > 0 ? mods.split(" ") : [];
    p.push(key);
    return p.join(" + ");
  }

  function resetForm() {
    root.editing = false;
    root.editOrigMods = "";
    root.editOrigKey = "";
    root.actionKey = "app";
    root.directionKey = "l";
    commandField.text = "";
    workspaceField.text = "";
    rawField.text = "";
    root.modsOn = [false, false, false, false];
    keyField.text = "";
  }

  function startEdit(b) {
    var mods = root.decodeMods(b.modmask);
    root.editing = true;
    root.editOrigMods = mods;
    root.editOrigKey = b.key;
    root.modsOn = [mods.indexOf("SUPER") >= 0, mods.indexOf("CTRL") >= 0, mods.indexOf("ALT") >= 0, mods.indexOf("SHIFT") >= 0];
    keyField.text = b.key;

    // Map the bind back onto the assisted builder; fall back to advanced.
    var disp = b.dispatcher;
    var arg = b.arg || "";
    commandField.text = "";
    workspaceField.text = "";
    rawField.text = "";
    if (disp === "killactive" || disp === "fullscreen" || disp === "togglefloating") {
      root.actionKey = disp;
    } else if (disp === "workspace" || disp === "movetoworkspace") {
      root.actionKey = disp;
      workspaceField.text = arg;
    } else if (disp === "movefocus" || disp === "movewindow") {
      root.actionKey = disp;
      root.directionKey = (arg === "r" || arg === "u" || arg === "d") ? arg : "l";
    } else if (disp === "exec") {
      root.actionKey = "app";
      commandField.text = arg;
    } else {
      root.actionKey = "custom";
      rawField.text = disp + (arg ? (" " + arg) : "");
    }
  }

  function buildAction() {
    // returns [dispatcher, arg] from the current form, or null if invalid
    if (root.actionKey === "custom") {
      var raw = rawField.text.trim();
      if (raw.length === 0)
        return null;
      var sp = raw.indexOf(" ");
      return sp < 0 ? [raw, ""] : [raw.substring(0, sp), raw.substring(sp + 1).trim()];
    }
    var disp = root.presetDispatcher(root.actionKey);
    if (root.param === "command") {
      var c = commandField.text.trim();
      return c.length === 0 ? null : ["exec", c];
    }
    if (root.param === "workspace") {
      var w = workspaceField.text.trim();
      return w.length === 0 ? null : [disp, w];
    }
    if (root.param === "direction")
      return [disp, root.directionKey];
    return [disp, ""];
  }

  function saveForm() {
    var key = keyField.text.trim();
    if (key.length === 0)
      return;
    var act = root.buildAction();
    if (act === null)
      return;
    var mods = root.formMods();
    var queue = [];
    if (root.editing)
      queue.push(["remove", root.editOrigMods, root.editOrigKey]);
    queue.push(["add", mods, key, act[0], act[1]]);
    root.runActions(queue);
    root.resetForm();
  }

  function refresh() {
    listProc.running = true;
  }

  function runActions(queue) {
    if (queue.length === 0)
      return;
    root.busy = true;
    actionProc.queue = queue;
    actionProc.qi = 0;
    actionProc.startNext();
  }

  Component.onCompleted: root.refresh()

  Process {
    id: listProc
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = [];
        var seen = ({});
        try {
          var data = JSON.parse(text);
          for (var i = 0; i < data.length; i++) {
            var b = data[i];
            // keyboard binds only; skip shell-internal global shortcuts
            // (dispatcher "global", e.g. Caps_Lock device refresh) and dupes
            if (b.mouse || !b.key || b.key.length === 0 || b.dispatcher === "global")
              continue;
            var sig = b.modmask + "|" + b.key + "|" + b.dispatcher + "|" + (b.arg || "");
            if (seen[sig])
              continue;
            seen[sig] = true;
            out.push(b);
          }
        } catch (e) {
          out = [];
        }
        root.allBinds = out;
      }
    }
  }

  Process {
    id: actionProc
    property var queue: []
    property int qi: 0
    function startNext() {
      if (qi < queue.length) {
        command = ["ryoku-keybinds"].concat(queue[qi]);
        running = true;
      } else {
        root.busy = false;
        root.refresh();
      }
    }
    stdout: StdioCollector {}
    onExited: (code, status) => {
      actionProc.qi++;
      actionProc.startNext();
    }
  }

  NHeader {
    Layout.fillWidth: true
    label: "Keyboard shortcuts"
    description: "Add, edit or remove shortcuts — changes apply instantly."
  }

  NBox {
    Layout.fillWidth: true
    implicitHeight: formColumn.implicitHeight + Style.margin2L

    ColumnLayout {
      id: formColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NText {
        visible: root.editing
        text: "Editing " + root.comboLabel(root.editOrigMods, root.editOrigKey)
        pointSize: Style.fontSizeS
        color: Color.mPrimary
      }

      // 1 — what it does
      NComboBox {
        id: actionCombo
        Layout.fillWidth: true
        label: "What should it do?"
        model: root.actionPresets
        currentKey: root.actionKey
        onSelected: k => root.actionKey = k
      }

      // parameter for the chosen action (only the relevant one shows)
      NTextInput {
        id: commandField
        Layout.fillWidth: true
        visible: root.param === "command"
        label: "Application or command"
        placeholderText: "e.g. firefox · kitty · obsidian"
      }
      RowLayout {
        Layout.fillWidth: true
        visible: root.param === "workspace"
        NTextInput {
          id: workspaceField
          Layout.preferredWidth: 160 * Style.uiScaleRatio
          label: "Workspace number"
          placeholderText: "1 – 10"
          inputMethodHints: Qt.ImhDigitsOnly
        }
        Item {
          Layout.fillWidth: true
        }
      }
      NComboBox {
        id: directionCombo
        Layout.fillWidth: true
        visible: root.param === "direction"
        label: "Direction"
        model: root.directionModel
        currentKey: root.directionKey
        onSelected: k => root.directionKey = k
      }
      NTextInput {
        id: rawField
        Layout.fillWidth: true
        visible: root.param === "raw"
        label: "Hyprland dispatcher + arguments"
        placeholderText: "e.g. exec wpctl set-volume @DEFAULT_SINK@ 5%+"
      }

      NDivider {
        Layout.fillWidth: true
        Layout.topMargin: Style.marginXS
        Layout.bottomMargin: Style.marginXS
      }

      // 2 — which keys (modifiers on their own row so labels never clip)
      NText {
        text: "Shortcut keys"
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
      }
      RowLayout {
        spacing: Style.marginS
        Layout.fillWidth: true

        Repeater {
          model: 4

          delegate: Rectangle {
            id: pill

            required property int index
            readonly property bool on: root.modsOn[index]
            implicitWidth: pillText.implicitWidth + Style.marginL * 2
            implicitHeight: Math.round(Style.baseWidgetSize * Style.uiScaleRatio)
            radius: Style.iRadiusS
            color: pill.on ? Color.mPrimary : "transparent"
            border.color: pill.on ? Color.mPrimary : Color.mOutline
            border.width: Style.borderS

            NText {
              id: pillText
              anchors.centerIn: parent
              text: root.modNames[pill.index]
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightMedium
              color: pill.on ? Color.mOnPrimary : Color.mOnSurface
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setMod(pill.index, !pill.on)
            }
          }
        }

        NText {
          Layout.leftMargin: Style.marginS
          text: "+ key"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        Item {
          Layout.fillWidth: true
        }
      }
      NTextInput {
        id: keyField
        Layout.fillWidth: true
        label: ""
        placeholderText: "Key — e.g. B, Return, F1, Space"
      }

      RowLayout {
        spacing: Style.marginM
        Layout.topMargin: Style.marginXS
        Layout.fillWidth: true
        NButton {
          icon: root.editing ? "check" : "plus"
          text: root.editing ? "Save shortcut" : "Add shortcut"
          enabled: !root.busy && keyField.text.trim().length > 0 && (root.param === "command" ? commandField.text.trim().length > 0 : root.param === "workspace" ? workspaceField.text.trim().length > 0 : root.param === "raw" ? rawField.text.trim().length > 0 : root.param === "direction" ? root.directionKey.length > 0 : true)
          onClicked: root.saveForm()
        }
        NButton {
          icon: "x"
          text: "Cancel"
          outlined: true
          visible: root.editing
          onClicked: root.resetForm()
        }
        Item {
          Layout.fillWidth: true
        }
        NButton {
          icon: "refresh"
          text: "Reload Hyprland"
          outlined: true
          tooltipText: "Re-read Hyprland's config files"
          enabled: !root.busy
          onClicked: root.runActions([["reload"]])
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginL
    NTextInput {
      Layout.fillWidth: true
      inputIconName: "search"
      placeholderText: "Search shortcuts…"
      onTextChanged: root.filterText = text
    }
    NText {
      text: root.allBinds.length + " shortcuts"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
    }
  }

  Repeater {
    model: {
      if (root.filterText.trim().length === 0)
        return root.allBinds;
      var q = root.filterText.trim().toLowerCase();
      return root.allBinds.filter(function (b) {
        var hay = (root.decodeMods(b.modmask) + " " + b.key + " " + root.friendlyAction(b.dispatcher, b.arg)).toLowerCase();
        return hay.indexOf(q) >= 0;
      });
    }

    delegate: Rectangle {
      id: row
      required property var modelData
      readonly property string mods: root.decodeMods(modelData.modmask)
      Layout.fillWidth: true
      Layout.preferredHeight: rowLayout.implicitHeight + Style.marginM * 2
      radius: Style.iRadiusM
      color: rowHover.containsMouse ? Color.mSurfaceVariant : Color.mSurface

      MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
      }

      RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: Style.marginL
        anchors.rightMargin: Style.marginM
        anchors.topMargin: Style.marginM
        anchors.bottomMargin: Style.marginM
        spacing: Style.marginL

        Rectangle {
          Layout.preferredWidth: 190 * Style.uiScaleRatio
          Layout.alignment: Qt.AlignVCenter
          implicitHeight: comboText.implicitHeight + Style.marginS * 2
          radius: Style.iRadiusS
          color: Color.mPrimary
          NText {
            id: comboText
            anchors.centerIn: parent
            width: parent.width - Style.marginM * 2
            text: root.comboLabel(row.mods, row.modelData.key)
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightSemiBold
            color: Color.mOnPrimary
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
          }
        }

        NText {
          Layout.fillWidth: true
          text: root.friendlyAction(row.modelData.dispatcher, row.modelData.arg)
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
          elide: Text.ElideRight
        }

        NIconButton {
          icon: "edit"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: "Edit"
          enabled: !root.busy
          onClicked: root.startEdit(row.modelData)
        }
        NIconButton {
          icon: "trash"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: "Delete"
          colorFg: Color.mError
          enabled: !root.busy
          onClicked: root.runActions([["remove", row.mods, row.modelData.key]])
        }
      }
    }
  }
}
