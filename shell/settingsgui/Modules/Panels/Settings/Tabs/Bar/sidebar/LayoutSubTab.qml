import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  readonly property var allWidgetIds: ["logo", "workspaces", "spacer", "activeWindow", "tray", "clock", "statusIcons", "power"]

  function widgetName(id) {
    switch (id) {
    case "logo":
      return qsTr("Logo");
    case "workspaces":
      return qsTr("Workspaces");
    case "spacer":
      return qsTr("Spacer");
    case "activeWindow":
      return qsTr("Active window");
    case "tray":
      return qsTr("System tray");
    case "clock":
      return qsTr("Clock");
    case "statusIcons":
      return qsTr("Status icons");
    case "power":
      return qsTr("Power");
    }
    return id;
  }

  function readEntries() {
    const out = [];
    const src = GlobalConfig.bar.entries || [];
    for (var i = 0; i < src.length; i++)
      out.push({
                 "id": src[i].id,
                 "enabled": src[i].enabled !== false
               });
    return out;
  }
  function writeEntries(arr) {
    GlobalConfig.bar.entries = arr;
    GlobalConfig.save();
  }
  function moveEntry(index, delta) {
    const arr = readEntries();
    const j = index + delta;
    if (j < 0 || j >= arr.length)
      return;
    const tmp = arr[index];
    arr[index] = arr[j];
    arr[j] = tmp;
    writeEntries(arr);
  }
  function toggleEntry(index) {
    const arr = readEntries();
    arr[index].enabled = !arr[index].enabled;
    writeEntries(arr);
  }
  function removeEntry(index) {
    const arr = readEntries();
    arr.splice(index, 1);
    writeEntries(arr);
  }
  function addEntry(id) {
    const arr = readEntries();
    arr.push({
               "id": id,
               "enabled": true
             });
    writeEntries(arr);
  }

  NText {
    text: qsTr("Bar layout")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }
  NText {
    text: qsTr("Reorder, enable, add or remove the widgets shown on the bar. Use spacers to push widgets apart.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    Repeater {
      id: entriesRepeater
      model: GlobalConfig.bar.entries

      delegate: NBox {
        id: entryCard
        required property int index
        required property var modelData
        readonly property bool isLast: index === ((GlobalConfig.bar.entries || []).length - 1)

        Layout.fillWidth: true
        implicitHeight: entryRow.implicitHeight + Style.marginM
        color: Color.mSurface

        RowLayout {
          id: entryRow
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginS

          NIconButton {
            icon: "chevron-up"
            tooltipText: qsTr("Move up")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: entryCard.index > 0
            onClicked: root.moveEntry(entryCard.index, -1)
          }
          NIconButton {
            icon: "chevron-down"
            tooltipText: qsTr("Move down")
            baseSize: Style.baseWidgetSize * 0.8
            enabled: !entryCard.isLast
            onClicked: root.moveEntry(entryCard.index, 1)
          }

          NText {
            Layout.fillWidth: true
            text: root.widgetName(entryCard.modelData.id)
            color: entryCard.modelData.enabled !== false ? Color.mOnSurface : Color.mOnSurfaceVariant
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          NToggle {
            checked: entryCard.modelData.enabled !== false
            onToggled: root.toggleEntry(entryCard.index)
          }

          NIconButton {
            icon: "trash"
            tooltipText: qsTr("Remove")
            baseSize: Style.baseWidgetSize * 0.8
            colorFg: Color.mError
            onClicked: root.removeEntry(entryCard.index)
          }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NComboBox {
      id: addCombo
      Layout.fillWidth: true
      label: ""
      property string addId: "spacer"
      model: root.allWidgetIds.map(function (wid) {
        return {
          "key": wid,
          "name": root.widgetName(wid)
        };
      })
      currentKey: addId
      onSelected: key => addCombo.addId = key
    }

    NButton {
      text: qsTr("Add widget")
      icon: "add"
      onClicked: root.addEntry(addCombo.addId)
    }
  }
}
