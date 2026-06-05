import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: GlobalConfig.launcher.actions — the entries shown in `>` command mode.
// command runs as: "autocomplete <mode>" (switch mode), "setMode light|dark", or any
// other list is exec'd directly (Actions.qml:37).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  function readActions() {
    const out = [];
    const src = GlobalConfig.launcher.actions || [];
    for (var i = 0; i < src.length; i++) {
      const a = src[i] || {};
      const cmd = a.command || [];
      const cmdArr = [];
      for (var j = 0; j < cmd.length; j++)
        cmdArr.push(String(cmd[j]));
      out.push({
                 "name": a.name || "",
                 "icon": a.icon || "help_outline",
                 "description": a.description || "",
                 "command": cmdArr,
                 "enabled": a.enabled !== false,
                 "dangerous": a.dangerous === true
               });
    }
    return out;
  }
  function writeActions(arr) {
    GlobalConfig.launcher.actions = arr;
    GlobalConfig.save();
  }
  function moveAction(index, delta) {
    const arr = readActions();
    const j = index + delta;
    if (j < 0 || j >= arr.length)
      return;
    const t = arr[index];
    arr[index] = arr[j];
    arr[j] = t;
    writeActions(arr);
  }
  function toggleAction(index) {
    const arr = readActions();
    arr[index].enabled = !arr[index].enabled;
    writeActions(arr);
  }
  function removeAction(index) {
    const arr = readActions();
    arr.splice(index, 1);
    writeActions(arr);
  }
  function addAction(obj) {
    const arr = readActions();
    arr.push(obj);
    writeActions(arr);
  }

  NText {
    Layout.fillWidth: true
    text: qsTr("Actions shown when you type the action prefix (default >). Reorder, enable/disable, remove, or add your own.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: GlobalConfig.launcher.actions

    delegate: NBox {
      id: actionCard
      required property int index
      required property var modelData
      readonly property bool isLast: index === ((GlobalConfig.launcher.actions || []).length - 1)

      Layout.fillWidth: true
      implicitHeight: actionRow.implicitHeight + Style.marginM
      color: Color.mSurface

      RowLayout {
        id: actionRow
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        NIconButton {
          icon: "chevron-up"
          tooltipText: qsTr("Move up")
          baseSize: Style.baseWidgetSize * 0.8
          enabled: actionCard.index > 0
          onClicked: root.moveAction(actionCard.index, -1)
        }
        NIconButton {
          icon: "chevron-down"
          tooltipText: qsTr("Move down")
          baseSize: Style.baseWidgetSize * 0.8
          enabled: !actionCard.isLast
          onClicked: root.moveAction(actionCard.index, 1)
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0
          NText {
            Layout.fillWidth: true
            text: (actionCard.modelData.name || qsTr("Unnamed")) + (actionCard.modelData.dangerous === true ? "  ⚠" : "")
            color: actionCard.modelData.enabled !== false ? Color.mOnSurface : Color.mOnSurfaceVariant
            elide: Text.ElideRight
          }
          NText {
            Layout.fillWidth: true
            text: actionCard.modelData.description || ""
            visible: text.length > 0
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
            elide: Text.ElideRight
          }
        }

        NToggle {
          Layout.alignment: Qt.AlignVCenter
          checked: actionCard.modelData.enabled !== false
          onToggled: root.toggleAction(actionCard.index)
        }
        NIconButton {
          Layout.alignment: Qt.AlignVCenter
          icon: "trash"
          tooltipText: qsTr("Remove")
          baseSize: Style.baseWidgetSize * 0.8
          colorFg: Color.mError
          onClicked: root.removeAction(actionCard.index)
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NCollapsible {
    id: addForm
    Layout.fillWidth: true
    label: qsTr("Add custom action")
    description: qsTr("Runs a command, or use 'autocomplete <mode>' / 'setMode light|dark'.")

    NTextInput {
      id: nameInput
      Layout.fillWidth: true
      label: qsTr("Name")
      placeholderText: qsTr("My action")
    }
    NTextInput {
      id: cmdInput
      Layout.fillWidth: true
      label: qsTr("Command")
      placeholderText: qsTr("e.g. ryoku wallpaper -r")
    }
    NTextInput {
      id: descInput
      Layout.fillWidth: true
      label: qsTr("Description (optional)")
    }
    NTextInput {
      id: iconInput
      Layout.fillWidth: true
      label: qsTr("Icon (optional)")
      placeholderText: "bolt"
    }
    NToggle {
      id: dangerToggle
      Layout.fillWidth: true
      label: qsTr("Mark as dangerous")
      description: qsTr("Hidden unless 'Show dangerous actions' is on.")
      checked: false
    }
    NButton {
      text: qsTr("Add action")
      icon: "add"
      enabled: nameInput.text.trim().length > 0 && cmdInput.text.trim().length > 0
      onClicked: {
        const parts = cmdInput.text.trim().split(/\s+/);
        root.addAction({
                         "name": nameInput.text.trim(),
                         "icon": iconInput.text.trim().length > 0 ? iconInput.text.trim() : "bolt",
                         "description": descInput.text.trim(),
                         "command": parts,
                         "enabled": true,
                         "dangerous": dangerToggle.checked
                       });
        nameInput.text = "";
        cmdInput.text = "";
        descInput.text = "";
        iconInput.text = "";
        dangerToggle.checked = false;
      }
    }
  }
}
