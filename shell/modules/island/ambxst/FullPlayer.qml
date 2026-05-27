pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

// Adapted from Ambxst modules/widgets/dashboard/widgets/FullPlayer.qml.
StyledRect {
  id: player

  property real playerRadius: 18
  property bool playersListExpanded: false
  property bool isSeeking: false

  readonly property var activePlayer: Players.active
  readonly property bool isPlaying: activePlayer?.isPlaying ?? false
  readonly property real position: activePlayer?.position ?? 0
  readonly property real length: activePlayer?.length ?? 1
  readonly property string artUrl: Players.getArtUrl(activePlayer)
  readonly property bool hasArtwork: artUrl.length > 0
  readonly property bool hasActivePlayer: activePlayer !== null
  readonly property real progress: hasActivePlayer && length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

  function formatTime(seconds: real): string {
    const totalSeconds = Math.max(0, Math.floor(seconds));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const secs = totalSeconds % 60;

    if (hours > 0)
      return `${hours}:${minutes.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
    return `${minutes}:${secs.toString().padStart(2, "0")}`;
  }

  function getPlayerIcon(mprisPlayer): string {
    if (!mprisPlayer)
      return "music_note";

    const identity = `${mprisPlayer.identity || ""} ${mprisPlayer.desktopEntry || ""} ${mprisPlayer.dbusName || ""}`.toLowerCase();
    if (identity.includes("spotify"))
      return "graphic_eq";
    if (identity.includes("chromium") || identity.includes("chrome"))
      return "language";
    if (identity.includes("firefox"))
      return "travel_explore";
    if (identity.includes("telegram"))
      return "send";
    return "album";
  }

  radius: playerRadius
  color: Colours.palette.m3surfaceContainerLow
  clip: true
  implicitHeight: 400

  Timer {
    id: seekUnlockTimer

    interval: 1000
    repeat: false
    onTriggered: player.isSeeking = false
  }

  Timer {
    running: player.isPlaying && player.visible
    interval: 1000
    repeat: true
    onTriggered: player.activePlayer?.positionChanged()
  }

  Image {
    id: backgroundArtBlurred

    anchors.fill: parent
    source: player.artUrl
    sourceSize: Qt.size(64, 64)
    fillMode: Image.PreserveAspectCrop
    visible: false
    asynchronous: true
  }

  MultiEffect {
    anchors.fill: parent
    source: backgroundArtBlurred
    blurEnabled: true
    blurMax: 32
    blur: 1
    saturation: 0.85
    opacity: player.hasArtwork ? 0.38 : 0
    visible: player.hasArtwork
  }

  StyledRect {
    anchors.fill: parent
    color: Qt.alpha(Colours.palette.m3surface, player.hasArtwork ? 0.48 : 0.22)
    radius: player.radius
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 8

    Item {
      id: discArea

      Layout.alignment: Qt.AlignHCenter
      Layout.preferredWidth: 178
      Layout.preferredHeight: 178
      Layout.topMargin: -4
      Layout.bottomMargin: -16

      CircularProgress {
        id: realSeekBar

        anchors.fill: parent
        value: player.progress
        strokeWidth: 6
        padding: 6
        fgColour: Colours.palette.m3primary
        bgColour: Qt.alpha(Colours.palette.m3outline, 0.28)
      }

      StyledRect {
        id: coverDiscContainer

        anchors.centerIn: parent
        width: parent.width - 52
        height: width
        radius: width / 2
        color: Colours.palette.m3surfaceContainerHighest
        clip: true
        NumberAnimation on rotation {
          from: 0
          to: 360
          duration: 8000
          loops: Animation.Infinite
          running: player.isPlaying && player.visible
        }

        Image {
          anchors.fill: parent
          source: player.artUrl
          sourceSize: Qt.size(256, 256)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          visible: player.hasArtwork
        }

        MaterialIcon {
          anchors.centerIn: parent
          text: player.hasActivePlayer ? "album" : "music_off"
          color: Colours.palette.m3outline
          font.pointSize: 42
          visible: !player.hasArtwork
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: player.hasActivePlayer && (player.activePlayer?.canSeek ?? false)
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
          const ratio = Math.max(0, Math.min(1, mouse.x / width));
          player.isSeeking = true;
          seekUnlockTimer.restart();
          player.activePlayer.position = ratio * player.length;
        }
      }
    }

    ColumnLayout {
      id: playerMetadata

      Layout.fillWidth: true
      Layout.alignment: Qt.AlignHCenter
      spacing: 2

      Text {
        Layout.fillWidth: true
        text: player.hasActivePlayer ? (player.activePlayer?.trackTitle || qsTr("Unknown title")) : qsTr("Nothing Playing")
        color: Colours.palette.m3onSurface
        font.pixelSize: Tokens.font.size.large
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        Layout.fillWidth: true
        text: player.hasActivePlayer ? (player.activePlayer?.trackAlbum || qsTr("Unknown album")) : qsTr("Enjoy the silence")
        color: Colours.palette.m3onSurfaceVariant
        font.pixelSize: Tokens.font.size.normal
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      Text {
        Layout.fillWidth: true
        text: player.hasActivePlayer ? (player.activePlayer?.trackArtist || qsTr("Unknown artist")) : qsTr("No active player")
        color: Colours.palette.m3outline
        font.pixelSize: Tokens.font.size.small
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
      }
    }

    RowLayout {
      id: playerControls

      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      MediaIconButton {
        icon: player.getPlayerIcon(player.activePlayer)
        opacity: player.hasActivePlayer ? 1 : 0.5
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) {
            player.playersListExpanded = !player.playersListExpanded;
            return;
          }

          if (Players.list.length > 0) {
            const currentIndex = Math.max(0, Players.list.indexOf(player.activePlayer));
            Players.manualActive = Players.list[(currentIndex + 1) % Players.list.length];
          }
        }
      }

      MediaIconButton {
        icon: "skip_previous"
        enabled: player.activePlayer?.canGoPrevious ?? false
        opacity: player.hasActivePlayer ? (enabled ? 1 : 0.3) : 0.5
        onClicked: player.activePlayer?.previous()
      }

      StyledRect {
        id: playPauseBtn

        Layout.preferredWidth: 44
        Layout.preferredHeight: 44
        radius: player.isPlaying && player.hasActivePlayer ? 14 : 22
        color: Colours.palette.m3primary
        opacity: player.hasActivePlayer ? 1 : 0.5

        MaterialIcon {
          anchors.centerIn: parent
          text: !player.hasActivePlayer ? "stop" : player.isPlaying ? "pause" : "play_arrow"
          color: Colours.palette.m3onPrimary
          font.pointSize: 24
          fill: 1
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: player.hasActivePlayer && (player.activePlayer?.canTogglePlaying ?? true)
          onClicked: player.activePlayer?.togglePlaying()
        }

        Behavior on radius {
          Anim {
            type: Anim.FastSpatial
          }
        }
      }

      MediaIconButton {
        icon: "skip_next"
        enabled: player.activePlayer?.canGoNext ?? false
        opacity: player.hasActivePlayer ? (enabled ? 1 : 0.3) : 0.5
        onClicked: player.activePlayer?.next()
      }

      MediaIconButton {
        icon: player.activePlayer?.shuffle ? "shuffle_on" : "shuffle"
        enabled: player.activePlayer?.shuffleSupported ?? false
        opacity: player.hasActivePlayer ? (enabled ? 1 : 0.3) : 0.5
        onClicked: player.activePlayer.shuffle = !player.activePlayer?.shuffle
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: player.hasActivePlayer ? `${player.formatTime(player.position)} / ${player.formatTime(player.length)}` : "--:-- / --:--"
      color: Colours.palette.m3outline
      font.pixelSize: Tokens.font.size.small
      opacity: 0.8
    }
  }

  Item {
    id: overlayLayer

    anchors.fill: parent
    visible: player.playersListExpanded
    z: 100

    Rectangle {
      anchors.fill: parent
      color: "black"
      opacity: 0.42
      radius: player.radius

      MouseArea {
        anchors.fill: parent
        onClicked: player.playersListExpanded = false
      }
    }

    StyledRect {
      id: playersListContainer

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 6
      implicitHeight: Math.min(160, playersListView.contentHeight + 8)
      color: Colours.palette.m3surfaceContainer
      radius: Math.max(6, player.radius - 6)
      clip: true

      ListView {
        id: playersListView

        anchors.fill: parent
        anchors.margins: 4
        clip: true
        model: Players.list

        delegate: StyledRect {
          id: playerItem

          required property var modelData
          required property int index

          width: playersListView.width
          height: 40
          radius: 8
          color: delegateMouseArea.containsMouse ? Colours.palette.m3surfaceContainerHighest : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            MaterialIcon {
              text: player.getPlayerIcon(playerItem.modelData)
              color: Colours.palette.m3onSurfaceVariant
              font.pointSize: Tokens.font.size.large
            }

            Text {
              Layout.fillWidth: true
              text: (playerItem.modelData?.trackTitle || Players.getIdentity(playerItem.modelData) || qsTr("Unknown Player"))
              color: Colours.palette.m3onSurface
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: delegateMouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Players.manualActive = playerItem.modelData;
              player.playersListExpanded = false;
            }
          }
        }
      }
    }
  }

  component MediaIconButton: MaterialIcon {
    property string icon: ""

    signal clicked(var mouse)

    text: icon
    color: mouseArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
    font.pointSize: Tokens.font.size.large

    MouseArea {
      id: mouseArea

      anchors.fill: parent
      anchors.margins: -6
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: parent.enabled
      hoverEnabled: true
      onClicked: mouse => parent.clicked(mouse)
    }

    Behavior on color {
      Anim {}
    }
  }
}
