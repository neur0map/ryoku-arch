import QtQuick
import "../"
import "../services"

Item {
  id: root

  property bool open: false
  property var service: WallpaperService
  property var selectedTags: service ? service.selectedTags : []
  property var popularTags: service ? service.popularTags : []

  signal closeRequested()

  height: open ? Math.min(112, tagFlow.implicitHeight + 34) : 0
  opacity: open ? 1 : 0
  clip: true

  Behavior on height {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Behavior on opacity {
    NumberAnimation { duration: Theme.animDuration }
  }

  function tagActive(tag) {
    return root.service && root.service.selectedTags.indexOf(tag) !== -1
  }

  function toggleTag(tag) {
    if (!root.service) return
    var tags = root.service.selectedTags.slice()
    var idx = tags.indexOf(tag)
    if (idx >= 0) {
      tags.splice(idx, 1)
    } else {
      tags.push(tag)
    }
    root.service.selectedTags = tags
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.24)
  }

  Flickable {
    anchors.fill: parent
    anchors.margins: 12
    contentWidth: width
    contentHeight: tagFlow.implicitHeight
    clip: true

    Flow {
      id: tagFlow
      width: parent.width
      spacing: -4

      SkwdButton {
        label: "TAGS"
        active: root.selectedTags.length > 0
        interactive: false
      }

      SkwdButton {
        label: "Clear"
        visible: root.selectedTags.length > 0
        onClicked: root.service.selectedTags = []
      }

      Repeater {
        model: root.popularTags

        SkwdButton {
          label: modelData.tag + " " + modelData.count
          active: root.tagActive(modelData.tag)
          onClicked: root.toggleTag(modelData.tag)
        }
      }

      Text {
        width: parent.width
        height: root.popularTags.length === 0 ? 26 : 0
        visible: root.popularTags.length === 0
        text: "No tags yet"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.44)
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
