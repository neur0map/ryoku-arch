import QtQuick
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Widgets

RowLayout {
  id: root

  property string label: ""
  property string description: ""
  property string placeholderText: ""
  property string text: ""
  property string actionButtonText: I18n.tr("common.test")
  property string actionButtonIcon: "media-play"
  property bool actionButtonEnabled: text !== ""

  signal editingFinished
  signal actionClicked

  spacing: Style.marginM

  NTextInput {
    id: textInput
    label: root.label
    description: root.description
    placeholderText: root.placeholderText
    text: root.text
    onTextChanged: root.text = text
    onEditingFinished: root.editingFinished()
    Layout.fillWidth: true
  }

  NButton {
    Layout.fillWidth: false
    Layout.alignment: Qt.AlignBottom

    text: root.actionButtonText
    icon: root.actionButtonIcon
    backgroundColor: Color.mSecondary
    textColor: Color.mOnSecondary
    hoverColor: Color.mHover
    enabled: root.actionButtonEnabled

    onClicked: {
      root.actionClicked();
    }
  }
}
