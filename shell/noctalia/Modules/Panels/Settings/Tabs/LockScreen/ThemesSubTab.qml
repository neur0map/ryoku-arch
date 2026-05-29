import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Widgets
import qs.services

// RYOKU: gallery of installed qylock themes. Each tile is the theme's preview.png;
// clicking sets the active theme (~/.config/qylock/theme), Refresh git-pulls the
// qylock repo for newly published themes, Lock now triggers a live lock to try it.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      NText {
        text: qsTr("Lock screen themes")
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }
      NText {
        Layout.fillWidth: true
        text: LockThemes.active.length > 0 ? qsTr("Active: %1").arg(LockThemes.active) : qsTr("Using the qylock default theme")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
      }
    }

    NButton {
      text: LockThemes.refreshing ? qsTr("Refreshing...") : qsTr("Refresh")
      icon: "refresh"
      enabled: !LockThemes.refreshing
      onClicked: LockThemes.refresh()
    }
    NButton {
      text: qsTr("Lock now")
      icon: "lock"
      outlined: true
      onClicked: Quickshell.execDetached(["sh", "-lc", "$HOME/.local/bin/ryoku-shell ipc lock lock"])
    }
  }

  NText {
    Layout.fillWidth: true
    text: qsTr("Pick a lock screen from the qylock collection. Selecting one applies on the next lock; use \"Lock now\" to try it. Refresh pulls newly published themes from upstream.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  NText {
    Layout.fillWidth: true
    visible: LockThemes.themes.length === 0
    text: qsTr("No qylock themes found in ~/.local/share/qylock/themes. Try Refresh, or reinstall qylock.")
    pointSize: Style.fontSizeS
    color: Color.mOnSurfaceVariant
    wrapMode: Text.WordWrap
  }

  GridLayout {
    id: grid
    Layout.fillWidth: true
    visible: LockThemes.themes.length > 0
    columns: Math.max(2, Math.floor(width / 200))
    columnSpacing: Style.marginM
    rowSpacing: Style.marginM

    Repeater {
      model: LockThemes.themes

      delegate: Rectangle {
        id: tile
        required property var modelData
        readonly property bool isActive: modelData.name === LockThemes.active

        Layout.fillWidth: true
        Layout.preferredHeight: Math.round((grid.width / grid.columns) * 0.62)
        radius: 10
        clip: true
        color: Color.mSurface
        border.width: isActive ? 3 : 1
        border.color: isActive ? Color.mPrimary : Color.mOutline

        Image {
          id: previewImg
          anchors.fill: parent
          anchors.margins: tile.isActive ? 3 : 1
          source: tile.modelData.preview ? "file://" + tile.modelData.preview : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          sourceSize.width: 480
        }

        // Placeholder when the theme ships no preview.png (qylock does not track
        // preview images in git, so freshly pulled themes can lack one).
        NText {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -8
          visible: !tile.modelData.preview || previewImg.status === Image.Error
          text: qsTr("No preview")
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        // Name bar
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: tile.isActive ? 3 : 1
          height: 26
          color: Qt.rgba(0, 0, 0, 0.55)

          NText {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            text: tile.modelData.name
            color: "white"
            pointSize: Style.fontSizeXS
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
          }
        }

        // Active badge
        Rectangle {
          visible: tile.isActive
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: 6
          width: 22
          height: 22
          radius: 11
          color: Color.mPrimary

          NIcon {
            anchors.centerIn: parent
            icon: "check"
            pointSize: Style.fontSizeS
            color: Color.mOnPrimary
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: LockThemes.setTheme(tile.modelData.name)
        }
      }
    }
  }
}
