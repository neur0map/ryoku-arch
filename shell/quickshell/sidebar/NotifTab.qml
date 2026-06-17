pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "Singletons"

Column {
    id: root
    property real s: 1

    spacing: 12 * s

    Row {
        width: parent.width
        spacing: 10 * root.s

        component StripPill: Rectangle {
            id: pill
            property bool active: false
            property string label: ""
            property bool accent: false
            signal clicked()

            width: (parent.width - 10 * root.s) / 2
            radius: 13 * root.s
            height: 44 * root.s
            border.width: 1
            border.color: active ? Theme.vermLit : (accent ? Theme.accent45 : Theme.border)
            gradient: active ? onGrad : offGrad

            Gradient {
                id: onGrad
                GradientStop { position: 0.0; color: Theme.vermLit }
                GradientStop { position: 1.0; color: Theme.verm }
            }
            Gradient {
                id: offGrad
                GradientStop { position: 0.0; color: Theme.panelTop }
                GradientStop { position: 1.0; color: Theme.panelBot }
            }

            Text {
                anchors.centerIn: parent
                text: pill.label
                color: pill.active ? Theme.onAccent : (pill.accent ? Theme.vermLit : Theme.subtle)
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: pill.clicked()
            }
        }

        StripPill {
            active: Notifs.dnd
            label: "Do Not Disturb"
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        StripPill {
            accent: true
            label: "Clear All"
            onClicked: Notifs.clearAll()
        }
    }

    Card {
        visible: Notifs.count === 0
        s: root.s
        width: parent.width
        Text {
            text: "Nothing new"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
    }

    Repeater {
        model: Notifs.groups

        Card {
            id: groupCard
            required property var modelData
            readonly property bool collapsed: Notifs.collapsedApps[modelData.app] === true

            s: root.s
            width: parent.width

            Item {
                width: parent.width
                height: 14 * root.s

                Row {
                    spacing: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: groupCard.modelData.app
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.4 * root.s
                    }
                    Text {
                        text: "· " + groupCard.modelData.items.length
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: groupCard.collapsed ? "▸" : "▾"
                    color: Theme.faint
                    font.pixelSize: 9 * root.s
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.toggleCollapsed(groupCard.modelData.app)
                }
            }

            Column {
                visible: !groupCard.collapsed
                width: parent.width
                spacing: 11 * root.s

                Repeater {
                    model: groupCard.modelData.items

                    Column {
                        id: notifItem
                        required property var modelData
                        required property int index

                        readonly property var acts: notifItem.modelData.live
                            ? notifItem.modelData.n.actions.filter(function(a) { return a.text.length > 0; })
                            : []

                        width: parent.width
                        spacing: 11 * root.s

                        Rectangle {
                            visible: notifItem.index > 0
                            width: parent.width - 40 * root.s
                            anchors.right: parent.right
                            height: 1
                            color: Theme.border
                        }

                        Row {
                            id: notifRow
                            width: parent.width
                            spacing: 10 * root.s

                            property bool hovered: rowHover.hovered

                            HoverHandler { id: rowHover }

                            Rectangle {
                                width: 30 * root.s
                                height: 30 * root.s
                                radius: 9 * root.s
                                color: Theme.tileBg
                                border.width: 1
                                border.color: Theme.border

                                Image {
                                    id: tileImg
                                    anchors.fill: parent
                                    anchors.margins: notifItem.modelData.n.image ? 0 : 6 * root.s
                                    source: notifItem.modelData.n.image
                                        ? notifItem.modelData.n.image
                                        : (notifItem.modelData.n.appIcon
                                            ? Quickshell.iconPath(notifItem.modelData.n.appIcon, "")
                                            : "")
                                    sourceSize.width: 64
                                    sourceSize.height: 64
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    visible: source.toString().length > 0
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: !tileImg.visible
                                    width: 8 * root.s
                                    height: 8 * root.s
                                    radius: 2 * root.s
                                    rotation: 45
                                    color: notifItem.modelData.n.urgency === NotificationUrgency.Critical
                                        ? Theme.vermLit : Theme.verm
                                }
                            }

                            Column {
                                width: parent.width - 40 * root.s
                                spacing: 2 * root.s

                                Item {
                                    width: parent.width
                                    height: titleText.implicitHeight

                                    Text {
                                        id: titleText
                                        width: parent.width - 34 * root.s
                                        text: notifItem.modelData.n.summary
                                        color: Theme.cream
                                        font.family: Theme.font
                                        font.pixelSize: 12.5 * root.s
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        visible: !notifRow.hovered
                                        text: notifItem.modelData.live ? Notifs.ageLabel(notifItem.modelData.n) : ""
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 9.5 * root.s
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        visible: notifRow.hovered
                                        text: "✕"
                                        color: Theme.dim
                                        font.pixelSize: 11 * root.s

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -6 * root.s
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notifItem.modelData.live
                                                ? Notifs.dismissNotif(notifItem.modelData.n)
                                                : Notifs.removeHistory(notifItem.modelData.n.id)
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    visible: notifItem.modelData.n.body.length > 0
                                    text: notifItem.modelData.n.body
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 11.5 * root.s
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }

                                Rectangle {
                                    visible: notifItem.modelData.live && Notifs.progressOf(notifItem.modelData.n) >= 0
                                    width: parent.width
                                    height: 5 * root.s
                                    radius: 999
                                    color: Theme.trackBg

                                    Rectangle {
                                        width: parent.width * Math.max(0, Notifs.progressOf(notifItem.modelData.n)) / 100
                                        height: parent.height
                                        radius: 999
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: Theme.verm }
                                            GradientStop { position: 1.0; color: Theme.vermLit }
                                        }
                                    }
                                }

                                Row {
                                    visible: notifItem.acts.length > 0
                                    spacing: 7 * root.s
                                    topPadding: 5 * root.s

                                    Repeater {
                                        model: notifItem.acts

                                        Rectangle {
                                            id: actPill
                                            required property var modelData
                                            required property int index

                                            radius: 999
                                            color: Theme.tileBg
                                            border.width: 1
                                            border.color: actPill.index === 0 ? Theme.accent45 : Theme.border
                                            implicitHeight: 22 * root.s
                                            implicitWidth: actText.implicitWidth + 22 * root.s

                                            Text {
                                                id: actText
                                                anchors.centerIn: parent
                                                text: actPill.modelData.text
                                                color: actPill.index === 0 ? Theme.vermLit : Theme.dim
                                                font.family: Theme.font
                                                font.pixelSize: 10 * root.s
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: actPill.modelData.invoke()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
