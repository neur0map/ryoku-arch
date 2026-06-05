import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // RYOKU: create/manage user-defined desktop widgets via the CustomWidgets service
  // (qs.services). Stored under ~/.config/ryoku-shell/desktop-widgets/<id>/.

  property string formType: "text"
  property string editId: ""
  property string confirmDeleteId: ""

  function resetForm() {
    root.editId = "";
    nameInput.text = "";
    root.formType = "text";
    textInput.text = "Hello";
    cmdInput.text = "date +%H:%M";
    fontSpin.value = 24;
    intervalSpin.value = 5;
    colorInput.text = "#ffffff";
    bgToggle.checked = true;
    qmlEditor.text = CustomWidgets.starterQml();
  }

  function loadForEdit(cfg) {
    root.editId = cfg.cwId;
    nameInput.text = cfg.cwName;
    root.formType = cfg.cwType;
    bgToggle.checked = cfg.background;
    const p = cfg.params || ({});
    textInput.text = p.text !== undefined ? p.text : "Hello";
    cmdInput.text = p.command !== undefined ? p.command : "date +%H:%M";
    fontSpin.value = p.fontSize !== undefined ? p.fontSize : (root.formType === "command" ? 18 : 24);
    intervalSpin.value = p.intervalSec !== undefined ? p.intervalSec : 5;
    colorInput.text = p.color !== undefined ? p.color : "#ffffff";
    if (cfg.cwType === "qml")
      qmlEditor.text = CustomWidgets.starterQml(); // raw QML is edited in the file; show starter
    formCard.expanded = true;
  }

  function submit() {
    if (nameInput.text.trim().length === 0)
      return;
    var params = ({});
    if (root.formType === "text")
      params = {
        "text": textInput.text,
        "fontSize": fontSpin.value,
        "color": colorInput.text
      };
    else if (root.formType === "command")
      params = {
        "command": cmdInput.text,
        "intervalSec": intervalSpin.value,
        "fontSize": fontSpin.value,
        "color": colorInput.text
      };
    const opts = {
      "name": nameInput.text.trim(),
      "type": root.formType,
      "background": bgToggle.checked,
      "params": params,
      "qml": root.formType === "qml" ? qmlEditor.text : undefined
    };
    if (root.editId.length > 0)
      CustomWidgets.update(root.editId, opts);
    else
      CustomWidgets.create(opts);
    root.resetForm();
  }

  NText {
    text: qsTr("Your widgets")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NText {
    visible: !CustomWidgets.list || CustomWidgets.list.length === 0
    text: qsTr("No custom widgets yet. Create one below.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    Layout.fillWidth: true
  }

  Repeater {
    model: CustomWidgets.list

    delegate: NBox {
      id: itemCard
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: itemRow.implicitHeight + Style.marginL
      color: Color.mSurface

      RowLayout {
        id: itemRow
        anchors.fill: parent
        anchors.margins: Style.marginS
        spacing: Style.marginS

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          NText {
            text: itemCard.modelData.cwName
            color: Color.mOnSurface
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          NText {
            text: itemCard.modelData.cwType
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }
        }

        NToggle {
          checked: itemCard.modelData.enabled
          onToggled: checked => CustomWidgets.setEnabled(itemCard.modelData.cwId, checked)
        }

        NIconButton {
          icon: "edit"
          tooltipText: qsTr("Edit")
          baseSize: Style.baseWidgetSize * 0.8
          visible: root.confirmDeleteId !== itemCard.modelData.cwId
          onClicked: root.loadForEdit(itemCard.modelData)
        }

        NIconButton {
          icon: "trash"
          tooltipText: qsTr("Delete")
          baseSize: Style.baseWidgetSize * 0.8
          colorFg: Color.mError
          visible: root.confirmDeleteId !== itemCard.modelData.cwId
          onClicked: root.confirmDeleteId = itemCard.modelData.cwId
        }

        NButton {
          visible: root.confirmDeleteId === itemCard.modelData.cwId
          text: qsTr("Delete?")
          backgroundColor: Color.mError
          onClicked: {
            CustomWidgets.remove(itemCard.modelData.cwId);
            root.confirmDeleteId = "";
          }
        }
        NIconButton {
          icon: "x"
          tooltipText: qsTr("Cancel")
          baseSize: Style.baseWidgetSize * 0.8
          visible: root.confirmDeleteId === itemCard.modelData.cwId
          onClicked: root.confirmDeleteId = ""
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NCollapsible {
    id: formCard
    Layout.fillWidth: true
    label: root.editId.length > 0 ? qsTr("Edit widget") : qsTr("Create widget")
    description: qsTr("Custom widgets run as part of the shell with full access. Only add widgets you trust.")
    expanded: false

    NTextInput {
      id: nameInput
      Layout.fillWidth: true
      label: qsTr("Name")
      placeholderText: qsTr("My widget")
    }

    NComboBox {
      id: typeCombo
      Layout.fillWidth: true
      label: qsTr("Type")
      model: [
        {
          "key": "text",
          "name": qsTr("Text / label")
        },
        {
          "key": "command",
          "name": qsTr("Command output")
        },
        {
          "key": "qml",
          "name": qsTr("Custom QML (advanced)")
        }
      ]
      currentKey: root.formType
      onSelected: key => root.formType = key
    }

    NTextInput {
      id: textInput
      visible: root.formType === "text"
      Layout.fillWidth: true
      label: qsTr("Text")
      text: "Hello"
    }

    NTextInput {
      id: cmdInput
      visible: root.formType === "command"
      Layout.fillWidth: true
      label: qsTr("Command")
      placeholderText: "date +%H:%M"
      text: "date +%H:%M"
    }
    NSpinBox {
      id: intervalSpin
      visible: root.formType === "command"
      Layout.fillWidth: true
      label: qsTr("Refresh interval")
      from: 1
      to: 3600
      stepSize: 1
      suffix: "s"
      value: 5
    }

    NSpinBox {
      id: fontSpin
      visible: root.formType !== "qml"
      Layout.fillWidth: true
      label: qsTr("Font size")
      from: 6
      to: 96
      stepSize: 1
      value: 24
    }
    NTextInput {
      id: colorInput
      visible: root.formType !== "qml"
      Layout.fillWidth: true
      label: qsTr("Text color")
      placeholderText: "#ffffff"
      text: "#ffffff"
    }
    NToggle {
      id: bgToggle
      visible: root.formType !== "qml"
      Layout.fillWidth: true
      label: qsTr("Show background card")
      checked: true
    }

    NText {
      visible: root.formType === "qml"
      Layout.fillWidth: true
      text: qsTr("widget.qml — root should size itself (implicitWidth/Height). Imports: QtQuick, Quickshell.Io, qs.components, qs.services.")
      pointSize: Style.fontSizeXS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
    }
    Rectangle {
      visible: root.formType === "qml"
      Layout.fillWidth: true
      Layout.preferredHeight: 280
      radius: Style.iRadiusM
      color: Color.mSurfaceVariant
      border.width: Style.borderS
      border.color: Color.mOutline

      ScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginS
        clip: true

        TextArea {
          id: qmlEditor
          text: CustomWidgets.starterQml()
          wrapMode: TextEdit.NoWrap
          font.family: "monospace"
          font.pointSize: Style.fontSizeS
          color: Color.mOnSurface
          selectByMouse: true
          background: null
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: Style.marginM
      spacing: Style.marginM

      NButton {
        text: root.editId.length > 0 ? qsTr("Save changes") : qsTr("Create widget")
        icon: "check"
        enabled: nameInput.text.trim().length > 0
        onClicked: root.submit()
      }
      NButton {
        visible: root.editId.length > 0
        text: qsTr("Cancel")
        outlined: true
        onClicked: root.resetForm()
      }
    }
  }
}
