pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// labelled select for lists too long for a segmented control (resolutions,
// cursor themes, keyboard layouts). field shows the current label; tap drops a
// scrollable list. `options` = [{ key, label, hint? }] or plain strings; the
// optional hint renders dim and right-aligned in the list (a code, a size),
// keeping the label itself clean. reports chosen(key).
Item {
    id: root

    property string label: ""
    property var options: []
    property string current: ""
    property string placeholder: "Select\u2026"
    property real fieldWidth: 220
    signal chosen(string key)

    implicitWidth: 320
    implicitHeight: 38

    function norm(o) { return (typeof o === "string") ? { "key": o, "label": o } : o; }
    function labelFor(k) {
        for (var i = 0; i < root.options.length; i++) {
            var o = root.norm(root.options[i]);
            if (o.key === k)
                return o.label;
        }
        return root.placeholder;
    }

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - field.width - 14
        elide: Text.ElideRight
        text: root.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Rectangle {
        id: field
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.fieldWidth
        height: 30
        radius: Theme.radius
        color: Theme.surfaceLo
        border.width: 1
        border.color: (popup.opened || hov.hovered) ? Theme.ember : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: chev.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.labelFor(root.current)
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Icon {
            id: chev
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron"
            size: 14
            tint: Theme.dim
            rotation: popup.opened ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
        }

        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: popup.opened ? popup.close() : popup.open() }
    }

    Popup {
        id: popup
        y: field.y + field.height + 6
        x: field.x + field.width - width
        width: Math.max(root.fieldWidth, 200)
        height: Math.min(list.contentHeight + 12, 300)
        padding: 6
        modal: false
        focus: true
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.quick } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.quick } }

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radius
            border.width: 1
            border.color: Theme.line
        }

        contentItem: ListView {
            id: list
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { width: 6 }

            delegate: Rectangle {
                id: opt
                required property var modelData
                readonly property var n: root.norm(opt.modelData)
                readonly property bool active: root.current === opt.n.key
                width: ListView.view.width
                height: 32
                radius: Theme.radius
                color: optHov.hovered ? Theme.keyTop : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: optHint.visible ? optHint.left : parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: opt.n.label
                    color: opt.active ? Theme.ember : (optHov.hovered ? Theme.bright : Theme.cream)
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: opt.active ? Font.DemiBold : Font.Medium
                }

                Text {
                    id: optHint
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text.length > 0
                    text: opt.n.hint || ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 11
                }

                HoverHandler { id: optHov; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        root.chosen(opt.n.key);
                        popup.close();
                    }
                }
            }
        }
    }
}
