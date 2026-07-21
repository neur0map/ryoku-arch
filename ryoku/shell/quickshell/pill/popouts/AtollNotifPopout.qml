pragma ComponentBehavior: Bound

import QtQuick
import "../Singletons"
import ".."

// atoll notification centre: a port of ilyamiro's NotificationPopups card stack
// into Ryoku's bone-on-black frame. instead of transient toasts this is the full
// centre, one card per (coalesced) notification, grouped by app via Notifs.groups.
// each card carries the app header, the bold summary, a wrapped body, inline
// action chips and a per-card dismiss. the outer window/panel fill is dropped
// (the frame blob IS the surface); only the inner cards and controls are drawn.
// verm is reserved: it marks a critical notification's hairline, nothing else.
Item {
    id: root

    property real s: 1
    property bool open: false
    // pointer-only surface: activating a card (or a chip) closes the popout,
    // mirroring stock notification-centre behaviour. the shell wires this.
    signal closeRequested()

    anchors.fill: parent
    implicitWidth: 360 * root.s
    implicitHeight: body.implicitHeight + 26 * root.s

    // one notification card: app header row (icon + name + count + age/dismiss),
    // the bold summary, a wrapped body, then bone action chips. history entries
    // carry no live `actions`, so the chip list guards for that.
    component NotifCard: Rectangle {
        id: card

        required property var entry
        property bool critical: false
        property string appLabel: "System"
        readonly property var n: entry.n

        // only explicit actions become chips; the "default" action is what the
        // card body click invokes, so it is filtered out here.
        readonly property var chips: {
            var out = [];
            var a = (card.n && card.n.actions) ? card.n.actions : [];
            for (var i = 0; i < a.length; i++) {
                var act = a[i];
                if (act.identifier !== "default" && act.text && act.text.length)
                    out.push(act);
            }
            return out;
        }

        width: parent ? parent.width : 0
        implicitHeight: cardCol.implicitHeight + 20 * root.s
        radius: Theme.radius
        color: Theme.cardTop
        border.width: 1
        border.color: card.critical ? Theme.verm : Theme.border
        clip: true

        HoverHandler { id: cardHover }

        // hover lift over the card body (chips/dismiss sit above via z).
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: Theme.frameBg
            opacity: cardHover.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.hover } }
        }

        // critical hairline down the left edge (the one reserved verm accent).
        Rectangle {
            visible: card.critical
            anchors.left: parent.left
            anchors.leftMargin: 1 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 2 * root.s
            height: parent.height - 12 * root.s
            radius: Theme.radius
            color: Theme.verm
        }

        // card body click -> invoke default action + focus the app + dismiss.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Notifs.activateEntry(card.entry);
                root.closeRequested();
            }
        }

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            anchors.topMargin: 10 * root.s
            spacing: 6 * root.s

            // ---- header: icon tile, app name, ×N badge, age <-> dismiss ----
            Item {
                width: parent.width
                height: 18 * root.s

                Rectangle {
                    id: cardTile
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * root.s
                    height: 18 * root.s
                    radius: Theme.radius
                    color: Theme.tileBg
                    border.width: 1
                    border.color: Theme.border
                    clip: true

                    Image {
                        id: cardImg
                        anchors.fill: parent
                        anchors.margins: card.n && card.n.image ? 0 : 2 * root.s
                        source: Notifs.iconFor(card.n)
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: source.toString().length > 0
                    }

                    // diamond fallback when the app ships no icon.
                    Rectangle {
                        anchors.centerIn: parent
                        visible: !cardImg.visible
                        width: 6 * root.s
                        height: 6 * root.s
                        radius: Theme.radius
                        rotation: 45
                        color: card.critical ? Theme.vermLit : Theme.verm
                    }
                }

                Text {
                    id: cardApp
                    anchors.left: cardTile.right
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - cardTile.width - cardCount.width - cardMeta.width - 40 * root.s)
                    text: card.appLabel
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.2 * root.s
                    elide: Text.ElideRight
                }

                Text {
                    id: cardCount
                    anchors.left: cardApp.right
                    anchors.leftMargin: 6 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.entry.count > 1
                    text: visible ? "×" + card.entry.count : ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                }

                // age label that cross-fades into a dismiss glyph on card hover.
                Item {
                    id: cardMeta
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(cardAge.implicitWidth, cardX.implicitWidth)
                    height: Math.max(cardAge.implicitHeight, cardX.implicitHeight)

                    Text {
                        id: cardAge
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: cardHover.hovered ? 0 : 1
                        text: Notifs.ageLabel(card.n)
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 9 * root.s
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }

                    Text {
                        id: cardX
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: cardHover.hovered ? 1 : 0
                        text: "✕"
                        color: cardXArea.containsMouse ? Theme.cream : Theme.dim
                        font.pixelSize: 11 * root.s
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                        MouseArea {
                            id: cardXArea
                            anchors.fill: parent
                            anchors.margins: -6 * root.s
                            enabled: cardHover.hovered
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.dismissEntry(card.entry)
                        }
                    }
                }
            }

            // ---- summary (title) ----
            Text {
                width: parent.width
                visible: text.length > 0
                text: (card.n && card.n.summary) ? card.n.summary : ""
                color: card.critical ? Theme.bright : Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            // ---- body ----
            Text {
                width: parent.width
                visible: text.length > 0
                text: (card.n && card.n.body) ? card.n.body : ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                // notification bodies may ship Pango-ish markup; StyledText
                // renders the common bits and strips the rest gracefully.
                textFormat: Text.StyledText
                onLinkActivated: (url) => Qt.openUrlExternally(url)
            }

            // ---- inline action chips (bone; primary is the bone-inverted fill) ----
            Flow {
                width: parent.width
                visible: card.chips.length > 0
                spacing: 6 * root.s

                Repeater {
                    model: card.chips

                    Rectangle {
                        id: chip
                        required property var modelData
                        required property int index
                        readonly property bool primary: index === 0

                        implicitWidth: chipLabel.implicitWidth + 20 * root.s
                        height: 26 * root.s
                        radius: Theme.radius
                        color: chip.primary
                            ? (chipArea.containsMouse ? Theme.bright : Theme.cream)
                            : (chipArea.containsMouse ? Theme.tileBg : "transparent")
                        border.width: 1
                        border.color: chip.primary ? "transparent" : Theme.border
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData.text || "Action"
                            color: chip.primary ? Theme.cardBot : Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof chip.modelData.invoke === "function")
                                    chip.modelData.invoke();
                                Notifs.dismissEntry(card.entry);
                                root.closeRequested();
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 8 * root.s

        // ---- header: eyebrow + bell/DND toggle + CLEAR ----
        Item {
            width: parent.width
            height: 24 * root.s

            Eyebrow {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: "Notifications"
                s: root.s
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * root.s

                // bell / do-not-disturb toggle. bone-bright when DND is armed
                // (Notifs.dnd suppresses non-critical toasts), dim otherwise.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * root.s
                    height: 18 * root.s

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Notifs.dnd ? "notifications_off" : "notifications"
                        fill: Notifs.dnd ? 1 : 0
                        color: Notifs.dnd ? Theme.bright
                             : (dndArea.containsMouse ? Theme.cream : Theme.dim)
                        font.pixelSize: 16 * root.s
                        Behavior on color { ColorAnimation { duration: Motion.hover } }
                    }

                    MouseArea {
                        id: dndArea
                        anchors.fill: parent
                        anchors.margins: -4 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }

                // CLEAR: wipe every notification. bone control, hover to bright.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.count > 0
                    width: clearLabel.implicitWidth
                    height: 20 * root.s

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "CLEAR"
                        color: clearArea.containsMouse ? Theme.bright : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4 * root.s
                        Behavior on color { ColorAnimation { duration: Motion.hover } }
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -5 * root.s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clearAll()
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        // ---- scrollable grouped card list ----
        Item {
            visible: Notifs.count > 0
            width: parent.width
            height: notifFlick.height

            Flickable {
                id: notifFlick
                width: parent.width
                height: Math.min(notifCol.implicitHeight, 420 * root.s)
                contentHeight: notifCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                onContentHeightChanged: returnToBounds()

                Column {
                    id: notifCol
                    width: notifFlick.width
                    spacing: 10 * root.s

                    // one block per app: criticals first (each its own card),
                    // then the coalesced non-critical entries.
                    Repeater {
                        model: Notifs.groups

                        Column {
                            id: group
                            required property var modelData
                            width: notifCol.width
                            spacing: 8 * root.s

                            Repeater {
                                model: group.modelData.criticals

                                NotifCard {
                                    required property var modelData
                                    entry: modelData
                                    critical: true
                                    appLabel: group.modelData.app
                                }
                            }

                            Repeater {
                                model: group.modelData.entries

                                NotifCard {
                                    required property var modelData
                                    entry: modelData
                                    appLabel: group.modelData.app
                                }
                            }
                        }
                    }
                }
            }

            WheelScroller {
                anchors.fill: parent
                s: root.s
                flick: notifFlick
            }
        }

        // ---- empty state ----
        Column {
            visible: Notifs.count === 0
            width: parent.width
            topPadding: 20 * root.s
            bottomPadding: 20 * root.s
            spacing: 6 * root.s

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "notifications_off"
                fill: 0
                color: Theme.ghost
                opacity: 0.6
                font.pixelSize: 30 * root.s
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ALL CLEAR"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
                font.letterSpacing: 2.2 * root.s
            }
        }
    }
}
