pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

// Adapted from Ambxst modules/widgets/dashboard/widgets/NotificationHistory.qml.
StyledRect {
  id: root

  required property var props
  required property DrawerVisibilities visibilities

  readonly property list<var> notifications: Notifs.notClosed

  color: Colours.palette.m3surfaceContainerLow
  radius: 18
  clip: true

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 4
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: 32
      spacing: 4

      StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 14
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        Text {
          anchors.centerIn: parent
          text: qsTr("Notifications")
          color: Colours.palette.m3onSurface
          font.pixelSize: Tokens.font.size.normal
          font.weight: Font.Bold
          horizontalAlignment: Text.AlignHCenter
        }
      }

      ControlButton {
        Layout.preferredWidth: 32
        Layout.fillHeight: true
        iconName: Notifs.dnd ? "notifications_off" : "notifications"
        isActive: Notifs.dnd
        onClicked: Notifs.dnd = !Notifs.dnd
      }

      ControlButton {
        Layout.preferredWidth: 32
        Layout.fillHeight: true
        iconName: "cleaning_services"
        isActive: false
        onClicked: {
          for (const notif of Notifs.notClosed.slice())
            notif.close();
        }
      }
    }

    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      ListView {
        id: notificationList

        anchors.fill: parent
        spacing: 4
        model: root.notifications
        clip: true

        delegate: StyledRect {
          id: notificationItem

          required property var modelData
          required property int index

          width: notificationList.width
          implicitHeight: Math.max(58, notificationContent.implicitHeight + 18)
          radius: 14
          color: closeHover.hovered ? Colours.palette.m3surfaceContainerHighest : Colours.layer(Colours.palette.m3surfaceContainer, 2)

          RowLayout {
            id: notificationContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 10
            spacing: 10

            StyledRect {
              Layout.preferredWidth: 34
              Layout.preferredHeight: 34
              radius: 17
              color: Colours.palette.m3secondaryContainer

              MaterialIcon {
                anchors.centerIn: parent
                text: "notifications"
                color: Colours.palette.m3onSecondaryContainer
                font.pointSize: Tokens.font.size.large
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                Layout.fillWidth: true
                text: notificationItem.modelData?.appName || qsTr("App")
                color: Colours.palette.m3outline
                font.pixelSize: Tokens.font.size.small
                elide: Text.ElideRight
                maximumLineCount: 1
              }

              Text {
                Layout.fillWidth: true
                text: notificationItem.modelData?.summary || qsTr("Notification")
                color: Colours.palette.m3onSurface
                font.pixelSize: Tokens.font.size.normal
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
              }

              Text {
                Layout.fillWidth: true
                text: notificationItem.modelData?.body || ""
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: Tokens.font.size.small
                elide: Text.ElideRight
                maximumLineCount: 1
                visible: text.length > 0
              }
            }

            Text {
              text: notificationItem.modelData?.timeStr || ""
              color: Colours.palette.m3outline
              font.pixelSize: Tokens.font.size.small
            }
          }

          HoverHandler {
            id: closeHover
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: notificationItem.modelData?.close()
          }
        }
      }

      ColumnLayout {
        anchors.centerIn: parent
        visible: root.notifications.length === 0
        spacing: 12

        MaterialIcon {
          Layout.alignment: Qt.AlignHCenter
          text: "notifications"
          color: Qt.alpha(Colours.palette.m3outline, 0.45)
          font.pointSize: 46
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: qsTr("No Notifications")
          color: Qt.alpha(Colours.palette.m3outline, 0.7)
          font.pixelSize: Tokens.font.size.normal
          font.weight: Font.Bold
        }
      }
    }
  }
}
