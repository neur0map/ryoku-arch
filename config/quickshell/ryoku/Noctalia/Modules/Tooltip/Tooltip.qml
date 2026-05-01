import QtQuick

Item {
  id: root

  property var targetItem: null
  property var content: null
  property string direction: "auto"
  property string fontFamily: ""

  visible: false

  function show(target, nextContent, nextDirection, delay, nextFontFamily) {
    targetItem = target;
    content = nextContent;
    direction = nextDirection || "auto";
    fontFamily = nextFontFamily || "";
    visible = true;
  }

  function hide() {
    visible = false;
  }

  function hideImmediately() {
    visible = false;
  }

  function updateContent(nextContent) {
    content = nextContent;
  }
}
