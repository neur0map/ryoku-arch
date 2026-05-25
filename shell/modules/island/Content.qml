import QtQuick
import Quickshell
import Ryoku.Config
import Ryoku.Services
import qs.components
import qs.services

Item {
  id: root

  required property DrawerVisibilities visibilities

  readonly property var player: Players.active
  readonly property bool hasPlayer: !!player
  readonly property bool hasMedia: hasPlayer && ((player.trackTitle ?? "") !== "")
  readonly property bool isPlaying: player?.isPlaying ?? false
  readonly property string artUrl: Players.getArtUrl(player)
  readonly property string primaryText: hasMedia ? (player.trackTitle || qsTr("Unknown title")) : Time.timeStr
  readonly property string secondaryText: hasMedia ? (player.trackArtist || qsTr("Unknown artist")) : `${Weather.temp}  ${Weather.description}`
  readonly property int cavaBarCount: 56

  function focusActivePlayerWindow() {
    Quickshell.execDetached(["bash", "-lc", "$HOME/.local/bin/ryoku-focus-media-window"]);
  }

  function cavaValue(index: int): real {
    if (!root.isPlaying)
      return 0.06;

    const values = Audio.cava.values;
    const count = values?.length ?? 0;
    if (count <= 0)
      return 0.06;

    const sampleIndex = Math.min(count - 1, Math.round(index * (count - 1) / Math.max(1, root.cavaBarCount - 1)));
    const raw = Math.max(0, Math.min(1, values[sampleIndex] ?? 0));
    return Math.max(0.08, Math.min(1, 0.08 + Math.pow(raw, 0.72) * 1.85));
  }

  implicitWidth: 700
  implicitHeight: 68
  clip: true

  Component.onCompleted: Weather.reload()

  ServiceRef {
    service: Audio.cava
  }

  Item {
    id: cavaBackdrop

    z: 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    anchors.bottomMargin: 7
    height: Math.min(root.implicitHeight / 2, 34)
    opacity: root.isPlaying ? 0.36 : 0.12

    Repeater {
      model: root.cavaBarCount

      Rectangle {
        readonly property real slotWidth: cavaBackdrop.width / root.cavaBarCount
        readonly property real value: root.cavaValue(index)
        readonly property color barColor: index % 4 === 0 ? Colours.palette.m3tertiary
          : index % 4 === 1 ? Colours.palette.m3primary
          : index % 4 === 2 ? Colours.palette.m3secondary
          : Colours.palette.m3primary
        readonly property real barHeight: Math.max(2, cavaBackdrop.height * value)

        x: index * slotWidth + (slotWidth - width) / 2
        y: cavaBackdrop.height - barHeight
        width: Math.max(2, Math.min(5, slotWidth * 0.52))
        height: barHeight
        radius: width / 2
        color: barColor

        Behavior on height {
          NumberAnimation {
            duration: root.isPlaying ? 70 : 220
            easing.type: Easing.Linear
          }
        }

        Behavior on y {
          NumberAnimation {
            duration: root.isPlaying ? 70 : 220
            easing.type: Easing.Linear
          }
        }
      }
    }

    Behavior on opacity {
      NumberAnimation {
        duration: 180
      }
    }
  }

  MouseArea {
    z: 1
    anchors.fill: parent
    hoverEnabled: true
    onWheel: event => {
      if (event.angleDelta.y > 0)
        Players.active?.previous();
      else
        Players.active?.next();
      event.accepted = true;
    }
  }

  Item {
    id: contentArea

    z: 2
    anchors.fill: parent
    anchors.leftMargin: 24
    anchors.rightMargin: 24
    anchors.topMargin: 8
    anchors.bottomMargin: 8

    Rectangle {
      id: cover

      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 52
      height: 52
      radius: Tokens.rounding.normal
      clip: true
      color: Qt.alpha(Colours.palette.m3surfaceVariant, 0.28)
      visible: root.hasMedia && root.artUrl.length > 0

      Image {
        anchors.fill: parent
        source: root.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }

      MouseArea {
        anchors.fill: parent
        enabled: root.hasPlayer
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.focusActivePlayerWindow()
      }
    }

    Row {
      id: controls

      z: 3
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Tokens.spacing.small
      opacity: root.hasPlayer ? 1 : 0.38

      ControlButton {
        size: 42
        icon: "skip_previous"
        enabled: root.player?.canGoPrevious ?? false
        onClicked: root.player?.previous()
      }

      ControlButton {
        size: 52
        icon: root.isPlaying ? "pause" : "play_arrow"
        filled: true
        enabled: root.player?.canTogglePlaying ?? false
        onClicked: root.player?.togglePlaying()
      }

      ControlButton {
        size: 42
        icon: "skip_next"
        enabled: root.player?.canGoNext ?? false
        onClicked: root.player?.next()
      }
    }

    Pet {
      id: pixelPet

      // Decorative only: it floats in the existing blank area and does not reserve layout space.
      z: 1
      anchors.right: controls.left
      anchors.rightMargin: Tokens.spacing.normal
      anchors.verticalCenter: parent.verticalCenter
      width: 84
      height: 48
      opacity: 0.82
    }

    Item {
      id: metadata

      z: 2
      anchors.left: cover.visible ? cover.right : parent.left
      anchors.leftMargin: cover.visible ? Tokens.spacing.normal : 0
      anchors.right: controls.left
      anchors.rightMargin: Tokens.spacing.large
      anchors.verticalCenter: parent.verticalCenter
      height: 45

      Column {
        anchors.fill: parent
        spacing: -2

        StyledText {
          width: parent.width
          text: root.primaryText
          color: Colours.palette.m3onSurface
          font.pointSize: Tokens.font.size.small
          font.weight: 680
          elide: Text.ElideRight
          animate: true
        }

        StyledText {
          width: parent.width
          text: root.secondaryText
          color: Colours.palette.m3outline
          font.pointSize: Tokens.font.size.smaller
          font.weight: 500
          elide: Text.ElideRight
          animate: true
        }
      }
    }
  }

  component ControlButton: Rectangle {
    id: button

    property alias icon: icon.text
    property int size: 42
    property bool filled
    signal clicked

    width: size
    height: size
    radius: size / 2
    color: filled ? Qt.alpha(Colours.palette.m3primary, mouse.containsMouse ? 0.32 : 0.22)
      : mouse.containsMouse ? Qt.alpha(Colours.palette.m3surfaceVariant, 0.66) : Qt.alpha(Colours.palette.m3surfaceVariant, 0.08)
    opacity: enabled ? 1 : 0.35

    Behavior on color {
      CAnim {}
    }

    MaterialIcon {
      id: icon

      anchors.centerIn: parent
      color: button.filled ? Colours.palette.m3primary : Colours.palette.m3outline
      font.pointSize: button.filled ? Tokens.font.size.extraLarge : Tokens.font.size.large
      fill: button.filled ? 1 : 0
    }

    MouseArea {
      id: mouse

      anchors.fill: parent
      enabled: button.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: event => {
        button.clicked();
        event.accepted = true;
      }
    }
  }
}
