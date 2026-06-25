pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * Right-click menu for a plugin desktop tile, in the same Ryoku carbon-dossier
 * idiom WidgetMenu uses for the shipped clock/weather (a 力 masthead, corner
 * registration ticks, hairline rules, mono uppercase spec rows with a vermilion
 * hover tick) so plugin tiles read as the same shell rather than a foreign
 * popup. Two actions for now: Lock/Unlock the tile (left-drag and resize freeze
 * when on) and Hide it (turns the plugin off in plugins.json). The host owns
 * persistence; the menu is a dumb dispatcher, so the same component fits any
 * plugin id without learning per-widget Config keys the way WidgetMenu does.
 * Fills the host window so its click-away catcher can dismiss the popup.
 */
Item {
    id: menu

    anchors.fill: parent
    visible: menu.open

    property bool open: false
    property string scope: ""        // plugin id the menu is bound to
    property bool locked: false
    property real px: 0
    property real py: 0

    signal hideRequested(string id)
    signal lockToggled(string id)

    function openFor(id, locked, x, y) {
        menu.scope = id;
        menu.locked = locked;
        menu.px = x;
        menu.py = y;
        menu.open = true;
    }
    function close() { menu.open = false; }

    // Click-away.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: menu.close()
    }

    MultiEffect {
        source: panel
        anchors.fill: panel
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.6)
        shadowBlur: 1.0
        shadowVerticalOffset: 10
        blurMax: 48
        autoPaddingEnabled: true
    }

    Rectangle {
        id: panel
        x: Math.max(8, Math.min(menu.px, menu.width - width - 8))
        y: Math.max(8, Math.min(menu.py, menu.height - height - 8))
        width: 234
        height: col.implicitHeight + 28
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.hair

        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.95
        opacity: menu.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 130 } }

        // Faint L-bracket registration ticks at the four corners, mirroring
        // WidgetMenu. Inlined (eight 1px rectangles) so this component doesn't
        // depend on the optional Ryoku.PluginKit import path.
        Item {
            anchors.fill: parent
            anchors.margins: 7
            property color tint: Theme.hair
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: 9; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 9; color: parent.tint }
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1; height: 9; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1; height: 9; color: parent.tint }
        }

        Column {
            id: col
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 0

            // Masthead: 力 + scope (plugin id).
            Item {
                width: parent.width
                height: 26
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u529b"
                        color: Theme.brand
                        font.family: Theme.fontJp
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: menu.scope.toUpperCase()
                        color: Theme.subtle
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2.4
                    }
                }
            }

            Rule {}

            // Lock keeps the menu open: toggling is a stateful affordance, and
            // the user often wants to see the row flip before committing.
            MenuRow {
                k: "Lock"
                v: menu.locked ? "On" : "Off"
                on: menu.locked
                closeOnTrigger: false
                onTriggered: {
                    menu.lockToggled(menu.scope);
                    menu.locked = !menu.locked;
                }
            }

            Rule {}

            // Hide closes the menu (the tile vanishes as the host re-reads
            // plugins.json, so there's nothing left to point the menu at).
            MenuRow {
                k: "Hide"
                onTriggered: menu.hideRequested(menu.scope)
            }
        }
    }

    component Rule: Item {
        width: parent ? parent.width : 0
        height: 11
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Theme.hair }
    }

    component MenuRow: Item {
        id: mi
        property string k: ""
        property string v: ""
        property bool on: false
        property bool accent: false
        property bool closeOnTrigger: true
        signal triggered()

        width: parent ? parent.width : 0
        height: 30

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            radius: 6
            color: miMa.containsMouse ? Qt.rgba(Theme.brand.r, Theme.brand.g, Theme.brand.b, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        // Vermilion registration tick on hover.
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: -6
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 14
            radius: 1
            color: Theme.brand
            opacity: miMa.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: mi.k
            color: mi.accent ? Theme.brand : (miMa.containsMouse ? Theme.cream : Theme.subtle)
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        Text {
            visible: mi.v.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: mi.v
            color: mi.on ? Theme.brand : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MouseArea {
            id: miMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                mi.triggered();
                if (mi.closeOnTrigger)
                    menu.close();
            }
        }
    }
}
