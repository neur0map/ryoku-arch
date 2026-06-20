import QtQuick
import "Singletons"

// A pill action button. `primary` fills it with the ember gradient; otherwise it
// is a hairline-outlined ghost. Hover brightens, press dips. Disabled fades.
Item {
    id: btn

    property string label: ""
    property string icon: ""
    property bool primary: false
    signal clicked()

    implicitWidth: row.implicitWidth + 34
    implicitHeight: 38

    opacity: enabled ? 1 : 0.4
    scale: tap.pressed && btn.enabled ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

    // Filled (primary) face.
    Rectangle {
        anchors.fill: parent
        visible: btn.primary
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: hover.hovered ? Qt.lighter(Theme.ember, 1.08) : Theme.ember }
            GradientStop { position: 1.0; color: Theme.emberDeep }
        }
    }

    // Ghost (secondary) face.
    Rectangle {
        anchors.fill: parent
        visible: !btn.primary
        radius: height / 2
        color: hover.hovered ? Theme.keyTop : "transparent"
        border.width: 1
        border.color: hover.hovered ? Theme.ember : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Icon {
            visible: btn.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: btn.icon
            size: 16
            weight: 1.8
            tint: btn.primary ? Theme.onAccent : (hover.hovered ? Theme.bright : Theme.cream)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.label
            color: btn.primary ? Theme.onAccent : (hover.hovered ? Theme.bright : Theme.cream)
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
    }

    HoverHandler { id: hover; enabled: btn.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: btn.enabled; onTapped: btn.clicked() }
}
