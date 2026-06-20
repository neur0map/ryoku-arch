import QtQuick
import "Singletons"

// The surface colour picker: a live swatch, a manual hex field, and a strip of
// tasteful dark presets for one click. Reports through modified(color); the owner
// holds the value. The frame, the pill and the island all read this one colour,
// so it is the single surface of the shell.
Item {
    id: cf

    property string label: ""
    property color value: "#1a1b26"
    signal modified(color value)

    readonly property var presets: [
        "#1a1b26", "#16161e", "#1b1612", "#1e1e2e",
        "#181825", "#11111b", "#0f1115", "#232136"
    ]

    function hex(c) {
        function h(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    implicitWidth: 420
    implicitHeight: 76

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.top: parent.top
        text: cf.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Row {
        anchors.left: parent.left
        anchors.top: lbl.bottom
        anchors.topMargin: 10
        spacing: 10

        Rectangle {
            id: swatch
            width: 30
            height: 30
            radius: 9
            color: cf.value
            border.width: 1
            border.color: Theme.line
        }

        Rectangle {
            width: 132
            height: 30
            radius: 9
            color: Theme.surfaceLo
            border.width: 1
            border.color: hexInput.activeFocus ? Theme.ember : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            TextInput {
                id: hexInput
                anchors.fill: parent
                anchors.leftMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: cf.hex(cf.value)
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 13
                font.weight: Font.DemiBold
                selectByMouse: true
                clip: true
                validator: RegularExpressionValidator { regularExpression: /#?[0-9A-Fa-f]{6}/ }
                onActiveFocusChanged: {
                    if (activeFocus)
                        selectAll();
                    else
                        text = Qt.binding(() => cf.hex(cf.value));
                }
                onEditingFinished: {
                    var t = text.charAt(0) === "#" ? text : "#" + text;
                    if (/^#[0-9A-Fa-f]{6}$/.test(t)) {
                        cf.modified(t);
                        text = t.toLowerCase();
                    }
                }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: cf.presets

                delegate: Rectangle {
                    required property var modelData
                    width: 22
                    height: 22
                    radius: 7
                    color: modelData
                    border.width: cf.hex(cf.value) === modelData ? 2 : 1
                    border.color: cf.hex(cf.value) === modelData ? Theme.ember : Theme.line

                    HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: cf.modified(parent.modelData) }

                    scale: ph.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
                }
            }
        }
    }
}
