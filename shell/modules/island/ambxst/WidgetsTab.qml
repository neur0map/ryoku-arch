pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services
import "calendar"

Rectangle {
  id: root

  required property DrawerVisibilities visibilities
  required property var props

  signal requestLens
  signal requestColorPicker
  signal requestRecord

  color: "transparent"
  implicitWidth: 884
  implicitHeight: 376

  RowLayout {
    anchors.fill: parent
    spacing: 8

    FullPlayer {
      Layout.preferredWidth: 216
      Layout.fillHeight: true
    }

    Item {
      id: widgetsContainer

      Layout.preferredWidth: 278
      Layout.fillHeight: true
      clip: true

      ColumnLayout {
        anchors.fill: parent
        spacing: 8

        QuickControls {
          Layout.fillWidth: true
          onRequestLens: root.requestLens()
          onRequestColorPicker: root.requestColorPicker()
          onRequestRecord: root.requestRecord()
        }

        Calendar {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: 210
        }
      }
    }

    NotificationHistory {
      Layout.fillWidth: true
      Layout.fillHeight: true
      props: root.props
      visibilities: root.visibilities
    }

    ColumnLayout {
      Layout.preferredWidth: 56
      Layout.minimumWidth: 56
      Layout.maximumWidth: 56
      Layout.fillHeight: true
      spacing: 8

      VerticalControl {
        Layout.fillWidth: true
        Layout.fillHeight: true
        vertical: true
        icon: "light_mode"
        value: Brightness.getMonitor("active")?.brightness ?? 0
        accentColor: Colours.palette.m3primary
        onValueEdited: newValue => {
          const monitor = Brightness.getMonitor("active");
          if (monitor)
            monitor.setBrightness(newValue);
        }
      }

      VerticalControl {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 52
        Layout.preferredHeight: 52
        icon: Audio.muted ? "volume_off" : Audio.volume < 0.01 ? "volume_mute" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
        value: Audio.volume
        muted: Audio.muted
        accentColor: Audio.muted ? Colours.palette.m3outline : Colours.palette.m3secondary
        onValueEdited: newValue => Audio.setVolume(newValue)
        onToggleRequested: {
          if (Audio.sink?.audio)
            Audio.sink.audio.muted = !Audio.sink.audio.muted;
        }
      }

      VerticalControl {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 52
        Layout.preferredHeight: 52
        icon: Audio.sourceMuted ? "mic_off" : "mic"
        value: Audio.sourceVolume
        muted: Audio.sourceMuted
        accentColor: Audio.sourceMuted ? Colours.palette.m3outline : Colours.palette.m3tertiary
        onValueEdited: newValue => Audio.setSourceVolume(newValue)
        onToggleRequested: {
          if (Audio.source?.audio)
            Audio.source.audio.muted = !Audio.source.audio.muted;
        }
      }
    }
  }
}
