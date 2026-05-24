pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

Item {
  id: root

  required property Session session

  function percent(value) {
    return qsTr("%1%").arg(Math.round((value || 0) * 100));
  }

  function deviceName(device) {
    return device?.description || device?.name || qsTr("Unknown");
  }

  anchors.fill: parent

  ClippingRectangle {
    id: audioClippingRect

    anchors.fill: parent
    anchors.margins: Tokens.padding.normal
    anchors.leftMargin: 0
    anchors.rightMargin: Tokens.padding.normal

    radius: audioBorder.innerRadius
    color: "transparent"

    Loader {
      anchors.fill: parent
      anchors.margins: Tokens.padding.large + Tokens.padding.normal
      anchors.leftMargin: Tokens.padding.large
      anchors.rightMargin: Tokens.padding.large
      sourceComponent: audioContentComponent
    }
  }

  InnerBorder {
    id: audioBorder

    leftThickness: 0
    rightThickness: Tokens.padding.normal
  }

  Component {
    id: audioContentComponent

    StyledFlickable {
      id: flickable

      anchors.fill: parent
      clip: true
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
      contentWidth: width
      contentHeight: content.implicitHeight

      StyledScrollBar.vertical: StyledScrollBar {
        flickable: flickable
      }

      ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.normal

        RowLayout {
          Layout.fillWidth: true
          spacing: Tokens.spacing.small

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Audio")
            font.pointSize: Tokens.font.size.large
            font.weight: 700
            elide: Text.ElideRight
          }

          ModeBadge {
            icon: Audio.muted ? "volume_off" : "volume_up"
            title: Audio.muted ? qsTr("Muted") : root.percent(Audio.volume)
            active: !Audio.muted
          }
        }

        AudioWorkbench {
          Layout.fillWidth: true
        }
      }
    }
  }

  component AudioWorkbench: StyledRect {
    id: audioWorkbench

    implicitHeight: workbenchLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    GridLayout {
      id: workbenchLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      columns: root.width > 620 ? 2 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      DeviceMatrix {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
      }

      MixerDeck {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
      }
    }
  }

  component MixerDeck: StyledRect {
    id: mixerDeck

    implicitHeight: mixerLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      id: mixerLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
          text: "equalizer"
          color: Colours.palette.m3primary
          fill: 1
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Mixer")
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Device and app levels")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      VolumeStrip {
        Layout.fillWidth: true
        icon: Audio.muted ? "volume_off" : "volume_up"
        title: qsTr("Output")
        detail: root.deviceName(Audio.sink)
        level: Audio.volume
        muted: Audio.muted

        onMoved: value => {
          Audio.setVolume(value);
        }

        onMuteClicked: {
          if (Audio.sink?.audio) {
            Audio.sink.audio.muted = !Audio.sink.audio.muted;
          }
        }
      }

      VolumeStrip {
        Layout.fillWidth: true
        icon: Audio.sourceMuted ? "mic_off" : "mic"
        title: qsTr("Input")
        detail: root.deviceName(Audio.source)
        level: Audio.sourceVolume
        muted: Audio.sourceMuted

        onMoved: value => {
          Audio.setSourceVolume(value);
        }

        onMuteClicked: {
          if (Audio.source?.audio) {
            Audio.source.audio.muted = !Audio.source.audio.muted;
          }
        }
      }

      StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.smaller
        text: qsTr("Applications")
        font.weight: 700
        elide: Text.ElideRight
      }

      Repeater {
        model: Audio.streams

        delegate: StreamStrip {
          required property var modelData

          Layout.fillWidth: true
          stream: modelData

          onMoved: value => {
            Audio.setStreamVolume(modelData, value);
          }

          onMuteClicked: {
            Audio.setStreamMuted(modelData, !Audio.getStreamMuted(modelData));
          }
        }
      }

      EmptyStreamNotice {
        Layout.fillWidth: true
        visible: Audio.streams.length === 0
      }
    }
  }

  component DeviceMatrix: StyledRect {
    id: deviceMatrix

    implicitHeight: deviceMatrixLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      id: deviceMatrixLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
          text: "hub"
          color: Colours.palette.m3primary
          fill: 1
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: qsTr("Devices")
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            text: qsTr("%1 outputs, %2 inputs").arg(Audio.sinks.length).arg(Audio.sources.length)
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      StyledText {
        Layout.fillWidth: true
        text: qsTr("Outputs")
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        font.weight: 700
        elide: Text.ElideRight
      }

      GridLayout {
        id: deviceGrid

        Layout.fillWidth: true
        columns: deviceGrid.width > 360 ? 2 : 1
        columnSpacing: Tokens.spacing.smaller
        rowSpacing: Tokens.spacing.smaller

        Repeater {
          model: Audio.sinks

          delegate: DeviceToken {
            required property var modelData

            Layout.fillWidth: true
            icon: "speaker"
            title: root.deviceName(modelData)
            detail: Audio.sink?.id === modelData.id ? qsTr("Active") : qsTr("Available")
            selected: Audio.sink?.id === modelData.id

            onClicked: {
              Audio.setAudioSink(modelData);
            }
          }
        }
      }

      StyledText {
        Layout.fillWidth: true
        visible: Audio.sinks.length === 0
        text: qsTr("No output devices detected")
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }

      StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.smaller
        text: qsTr("Inputs")
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        font.weight: 700
        elide: Text.ElideRight
      }

      GridLayout {
        id: inputDeviceGrid

        Layout.fillWidth: true
        columns: inputDeviceGrid.width > 360 ? 2 : 1
        columnSpacing: Tokens.spacing.smaller
        rowSpacing: Tokens.spacing.smaller

        Repeater {
          model: Audio.sources

          delegate: DeviceToken {
            required property var modelData

            Layout.fillWidth: true
            icon: "mic"
            title: root.deviceName(modelData)
            detail: Audio.source?.id === modelData.id ? qsTr("Active") : qsTr("Available")
            selected: Audio.source?.id === modelData.id

            onClicked: {
              Audio.setAudioSource(modelData);
            }
          }
        }
      }

      StyledText {
        Layout.fillWidth: true
        visible: Audio.sources.length === 0
        text: qsTr("No input devices detected")
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }

  component DeviceToken: StyledRect {
    id: deviceToken

    property string icon
    property string title
    property string detail
    property bool selected
    signal clicked()

    implicitHeight: 42
    radius: Tokens.rounding.small
    color: selected ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    StateLayer {
      color: deviceToken.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface

      onClicked: {
        deviceToken.clicked();
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: deviceToken.icon
        color: deviceToken.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        fill: deviceToken.selected ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: deviceToken.title
          color: deviceToken.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
          font.weight: deviceToken.selected ? 700 : 500
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        StyledText {
          Layout.fillWidth: true
          text: deviceToken.detail
          color: deviceToken.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
          opacity: deviceToken.selected ? 0.78 : 1
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }
  }

  component VolumeStrip: StyledRect {
    id: volumeStrip

    property string icon
    property string title
    property string detail
    property real level
    property bool muted
    signal moved(real value)
    signal muteClicked()

    implicitHeight: stripLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      id: stripLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: volumeStrip.icon
          color: volumeStrip.muted ? Colours.palette.m3outline : Colours.palette.m3primary
          fill: volumeStrip.muted ? 0 : 1
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: volumeStrip.title
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            text: volumeStrip.detail
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
            maximumLineCount: 1
          }
        }

        LevelBadge {
          value: root.percent(volumeStrip.level)
          muted: volumeStrip.muted
        }

        MuteButton {
          muted: volumeStrip.muted
          offIcon: volumeStrip.title === qsTr("Input") ? "mic" : "volume_up"
          onIcon: volumeStrip.title === qsTr("Input") ? "mic_off" : "volume_off"

          onClicked: {
            volumeStrip.muteClicked();
          }
        }
      }

      StyledSlider {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.normal * 3
        value: volumeStrip.level
        enabled: !volumeStrip.muted
        opacity: enabled ? 1 : 0.42

        onMoved: {
          volumeStrip.moved(value);
        }
      }
    }
  }

  component StreamStrip: StyledRect {
    id: streamStrip

    property var stream
    signal moved(real value)
    signal muteClicked()

    implicitHeight: streamLayout.implicitHeight + Tokens.padding.normal * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      id: streamLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.normal
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: "apps"
          color: Audio.getStreamMuted(streamStrip.stream) ? Colours.palette.m3outline : Colours.palette.m3tertiary
        }

        StyledText {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: Audio.getStreamName(streamStrip.stream)
          font.weight: 600
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        LevelBadge {
          value: root.percent(Audio.getStreamVolume(streamStrip.stream))
          muted: Audio.getStreamMuted(streamStrip.stream)
        }

        MuteButton {
          muted: Audio.getStreamMuted(streamStrip.stream)
          offIcon: "volume_up"
          onIcon: "volume_off"

          onClicked: {
            streamStrip.muteClicked();
          }
        }
      }

      StyledSlider {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.normal * 3
        value: Audio.getStreamVolume(streamStrip.stream)
        enabled: !Audio.getStreamMuted(streamStrip.stream)
        opacity: enabled ? 1 : 0.42

        onMoved: {
          streamStrip.moved(value);
        }
      }
    }
  }

  component MuteButton: StyledRect {
    id: muteButton

    property bool muted
    property string offIcon
    property string onIcon
    signal clicked()

    implicitWidth: 42
    implicitHeight: 34
    radius: Tokens.rounding.full
    color: muted ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer
    clip: true

    StateLayer {
      color: muteButton.muted ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer

      onClicked: {
        muteButton.clicked();
      }
    }

    MaterialIcon {
      anchors.centerIn: parent
      text: muteButton.muted ? muteButton.onIcon : muteButton.offIcon
      color: muteButton.muted ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
      font.pointSize: Tokens.font.size.normal
    }
  }

  component LevelBadge: StyledRect {
    id: levelBadge

    property string value
    property bool muted

    implicitWidth: 58
    implicitHeight: 30
    radius: Tokens.rounding.full
    color: muted ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3primaryContainer

    StyledText {
      anchors.centerIn: parent
      text: levelBadge.muted ? qsTr("Muted") : levelBadge.value
      color: levelBadge.muted ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onPrimaryContainer
      font.pointSize: Tokens.font.size.small
      font.weight: 700
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      maximumLineCount: 1
      width: parent.width - Tokens.padding.small
    }
  }

  component EmptyStreamNotice: StyledRect {
    implicitHeight: 42
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.normal
      spacing: Tokens.spacing.small

      MaterialIcon {
        text: "volume_mute"
        color: Colours.palette.m3onSurfaceVariant
      }

      StyledText {
        Layout.fillWidth: true
        text: qsTr("No application streams")
        color: Colours.palette.m3onSurfaceVariant
        elide: Text.ElideRight
      }
    }
  }

  component ModeBadge: StyledRect {
    id: modeBadge

    property string icon
    property string title
    property bool active

    implicitWidth: modeBadgeLayout.implicitWidth + Tokens.padding.normal * 2
    implicitHeight: 34
    radius: Tokens.rounding.full
    color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh

    RowLayout {
      id: modeBadgeLayout

      anchors.centerIn: parent
      spacing: Tokens.spacing.smaller

      MaterialIcon {
        text: modeBadge.icon
        color: modeBadge.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
      }

      StyledText {
        text: modeBadge.title
        color: modeBadge.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        font.weight: 700
      }
    }
  }
}
