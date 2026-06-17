import QtQuick
import "Singletons"

Item {
    id: sidebar
    required property real s
    property bool opened: false
    property int tab: 0
    signal requestClose()

    readonly property real panelWidth: 372 * s
    implicitWidth: panelWidth

    focus: opened
    onOpenedChanged: if (opened) forceActiveFocus()
    onTabChanged: if (tab === 1) Notifs.markAllSeen()
    Keys.onEscapePressed: sidebar.requestClose()

    Rectangle {
        id: card
        width: sidebar.panelWidth
        height: Math.min(stack.contentHeight + 28 * sidebar.s, parent.height)
        radius: 22 * sidebar.s
        color: "transparent"
        border.width: 1
        border.color: Theme.border

        opacity: sidebar.opened ? 1 : 0

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        MouseArea { anchors.fill: parent }

        Flickable {
            id: stack
            anchors.fill: parent
            anchors.margins: 14 * sidebar.s
            contentHeight: inner.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: inner
                width: stack.width
                spacing: 12 * sidebar.s

                Header {
                    s: sidebar.s
                    width: parent.width
                    opened: sidebar.opened
                    notif: sidebar.tab === 1
                    unread: Notifs.unread
                }

                Column {
                    visible: sidebar.tab === 0
                    width: parent.width
                    spacing: 12 * sidebar.s

                    QuickStrip { s: sidebar.s; width: parent.width; opened: sidebar.opened }
                    Network { s: sidebar.s; width: parent.width }
                    Bluetooth { s: sidebar.s; width: parent.width }
                    Audio { s: sidebar.s; width: parent.width }
                    Display { s: sidebar.s; width: parent.width; opened: sidebar.opened }
                    Media { s: sidebar.s; width: parent.width; opened: sidebar.opened }
                }

                NotifTab {
                    visible: sidebar.tab === 1
                    s: sidebar.s
                    width: parent.width
                }
            }
        }
    }

    EdgeTabs {
        s: sidebar.s
        x: -width + 1
        y: 26 * sidebar.s
        opacity: card.opacity
        visible: opacity > 0
        current: sidebar.tab
        showDot: Notifs.unread > 0
        onSelect: function(idx) { sidebar.tab = idx; }
    }
}
