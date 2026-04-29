import QtQuick
import Quickshell.Services.Notifications
import "../"
import "../../"

// ─────────────────────────────────────────────────────────────
// NotificationList — content panel for NotificationsPopup
// ─────────────────────────────────────────────────────────────
Item {
    id: root

    width:  360

    // Total height: header + list area (or empty state)
    height: header.height
            + (NotificationService.count > 0 ? listArea.height : emptyState.height)

    // ── Header ─────────────────────────────────────────────────
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text:           "Notifications"
            color:          Theme.text
            font.pixelSize: 14
            font.bold:      true
        }

        // Clear-all — only visible when there are notifications
        Item {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width:   clearLabel.width + 16
            height:  26
            visible: NotificationService.count > 0

            Rectangle {
                anchors.fill: parent
                radius:       13
                color:        clearHover.containsMouse ? Qt.rgba(1,1,1,0.10) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Text {
                id:               clearLabel
                anchors.centerIn: parent
                text:             "Clear all"
                color:            Theme.subtext
                font.pixelSize:   12
            }
            HoverHandler { id: clearHover }
            TapHandler   { onTapped: NotificationService.dismissAll() }
        }
    }

    // Divider — only when list is non-empty
    Rectangle {
        id: divider
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        height:  1
        color:   Qt.rgba(1, 1, 1, 0.06)
        visible: NotificationService.count > 0
    }

    // ── Scrollable list ─────────────────────────────────────────
    Item {
        id:      listArea
        anchors { top: divider.bottom; left: parent.left; right: parent.right }
        // Clamp to maxListHeight — ListView scrolls inside
        height:  Math.min(contentList.contentHeight, maxListHeight)
        visible: NotificationService.count > 0

        readonly property int maxListHeight: 440

        ListView {
            id:             contentList
            anchors.fill:   parent
            model:          NotificationService.list
            clip:           true
            spacing:        1
            boundsBehavior: Flickable.StopAtBounds

            delegate: NotificationCard {
                required property var modelData
                width:        ListView.view.width
                notification: modelData
            }
        }

        // Fade overlay when clipped
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height:  28
            visible: contentList.contentHeight > listArea.maxListHeight
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0.09, 0.11, 0.13, 1.0) }
            }
        }
    }

    // ── Empty state ─────────────────────────────────────────────
    Item {
        id:      emptyState
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        height:  80
        visible: NotificationService.count === 0

        Column {
            anchors.centerIn: parent
            spacing:          6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "󰂚"
                color:          Qt.rgba(1, 1, 1, 0.15)
                font.pixelSize: 28
                font.family:    Theme.iconFont
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "No notifications"
                color:          Theme.subtext
                font.pixelSize: 12
            }
        }
    }

    // ── NotificationCard ── inline component ────────────────────
    component NotificationCard: Item {
        id: card

        // notification is required — guard every access with ?. and ?? fallback
        required property var notification

        // Urgency accent color — guard against undefined notification/urgency
        readonly property color urgencyColor: {
            if (!notification) return Theme.active
            switch (notification.urgency) {
                case NotificationUrgency.Critical: return "#e06c75"
                case NotificationUrgency.Low:      return Qt.rgba(1, 1, 1, 0.25)
                default:                           return Theme.active
            }
        }

        height: cardRow.height + 20

        // Hover background
        Rectangle {
            anchors.fill: parent
            color:        cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Left urgency accent bar
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width:   3
            color:   card.urgencyColor
            opacity: 0.85
        }

        // Content row
        Row {
            id: cardRow
            anchors {
                left:        parent.left; leftMargin:  12
                right:       parent.right; rightMargin:  8
                top:         parent.top;   topMargin:   10
            }
            spacing: 10
            height:  Math.max(iconArea.height, textCol.implicitHeight)

            // App icon
            Item {
                id:     iconArea
                width:  32
                height: 32

                Image {
                    id:        iconImg
                    anchors.fill: parent
                    source: {
                        var ic = card.notification?.appIcon ?? ""
                        if (ic === "") return ""
                        if (ic.startsWith("/")) return "file://" + ic
                        return "image://icon/" + ic
                    }
                    fillMode:          Image.PreserveAspectFit
                    smooth:            true
                    visible:           status === Image.Ready
                    sourceSize.width:  32
                    sourceSize.height: 32
                }

                // Letter fallback
                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        Qt.rgba(1, 1, 1, 0.08)
                    visible:      iconImg.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text:           (card.notification?.appName ?? "?").charAt(0).toUpperCase()
                        color:          Theme.text
                        font.pixelSize: 14
                        font.bold:      true
                    }
                }
            }

            // Text column
            Column {
                id:     textCol
                // Leave room for dismiss button
                width:  cardRow.width - iconArea.width - cardRow.spacing - dismissBtn.width - 4
                spacing: 3

                // App name
                Text {
                    width:          parent.width
                    text:           card.notification?.appName ?? ""
                    color:          Theme.subtext
                    font.pixelSize: 11
                    elide:          Text.ElideRight
                    visible:        text !== ""
                }

                // Summary
                Text {
                    width:            parent.width
                    text:             card.notification?.summary ?? ""
                    color:            Theme.text
                    font.pixelSize:   13
                    font.bold:        true
                    wrapMode:         Text.WordWrap
                    maximumLineCount: 2
                    elide:            Text.ElideRight
                    visible:          text !== ""
                }

                // Body
                Text {
                    width:            parent.width
                    text:             card.notification?.body ?? ""
                    color:            Theme.subtext
                    font.pixelSize:   12
                    wrapMode:         Text.WordWrap
                    maximumLineCount: 3
                    elide:            Text.ElideRight
                    textFormat:       Text.StyledText
                    visible:          text !== ""
                }

                // Action buttons
                Row {
                    spacing: 6
                    visible: (card.notification?.actions?.length ?? 0) > 0

                    Repeater {
                        model: card.notification?.actions ?? []
                        delegate: Item {
                            required property var modelData
                            width:  actionLbl.width + 20
                            height: 22

                            Rectangle {
                                anchors.fill: parent
                                radius:       3
                                color:        actHover.containsMouse
                                              ? Qt.rgba(1,1,1,0.15)
                                              : Qt.rgba(1,1,1,0.07)
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                id:               actionLbl
                                anchors.centerIn: parent
                                text:             modelData?.text ?? ""
                                color:            Theme.text
                                font.pixelSize:   11
                            }
                            HoverHandler { id: actHover }
                            TapHandler   { onTapped: modelData?.invoke() }
                        }
                    }
                }
            }

            // Dismiss ✕
            Item {
                id:     dismissBtn
                width:  24
                height: 24

                Rectangle {
                    anchors.fill: parent
                    radius:       width / 2
                    color:        xHover.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                Text {
                    anchors.centerIn: parent
                    text:             "✕"
                    color:            Theme.subtext
                    font.pixelSize:   10
                }
                HoverHandler { id: xHover }
                TapHandler   { onTapped: card.notification?.dismiss() }
            }
        }

        HoverHandler { id: cardHover }
    }
}
