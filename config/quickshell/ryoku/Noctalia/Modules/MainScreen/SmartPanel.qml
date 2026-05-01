import QtQuick

Item {
  id: root

  property var screen: null
  property Component panelContent: null
  property var panelID: null
  property real preferredWidth: 700
  property real preferredHeight: 900
  property color panelBackgroundColor: "transparent"
  property color panelBorderColor: "transparent"
  property var buttonItem: null
  property bool forceAttachToBar: false
  property bool panelAnchorHorizontalCenter: false
  property bool panelAnchorVerticalCenter: false
  property bool panelAnchorTop: false
  property bool panelAnchorBottom: false
  property bool panelAnchorLeft: false
  property bool panelAnchorRight: false
  property bool useButtonPosition: false
  property point buttonPosition: Qt.point(0, 0)
  property int buttonWidth: 0
  property int buttonHeight: 0
  property bool isPanelOpen: false
  property bool closeWithEscape: true
  property bool exclusiveKeyboard: true

  signal opened()
  signal closed()

  visible: isPanelOpen
  implicitWidth: preferredWidth
  implicitHeight: preferredHeight

  onIsPanelOpenChanged: {
    if (isPanelOpen) {
      opened();
    } else {
      closed();
    }
  }

  Loader {
    anchors.fill: parent
    sourceComponent: root.panelContent
  }

  function toggle(buttonItem, buttonName) {
    if (isPanelOpen) {
      close();
    } else {
      open(buttonItem, buttonName);
    }
  }

  function open(buttonItem, buttonName) {
    isPanelOpen = true;
  }

  function close() {
    isPanelOpen = false;
  }

  function setPosition() {}

  function onEscapePressed() {
    if (closeWithEscape) {
      close();
    }
  }
}
