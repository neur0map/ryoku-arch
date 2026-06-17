import QtQuick
import QtQuick.Controls
import Quickshell

Item {
    id: box

    property var entries: []
    property int total: 0
    property int selectedIndex: 0

    signal launch(var entry)
    signal quit()

    width: 540
    implicitHeight: frame.implicitHeight

    readonly property color bgTop: Qt.rgba(43 / 255, 33 / 255, 28 / 255, 0.97)
    readonly property color bgBot: Qt.rgba(29 / 255, 18 / 255, 14 / 255, 0.97)
    readonly property color hair: Qt.rgba(150 / 255, 172 / 255, 212 / 255, 0.10)
    readonly property color verm: "#c0442b"
    readonly property color cream: "#e6d6cb"
    readonly property color dim: "#7e8794"
    readonly property color dim2: "#565e6a"

    function moveSelection(delta) {
        if (entries.length === 0) return;
        var n = selectedIndex + delta;
        if (n < 0) n = 0;
        if (n > entries.length - 1) n = entries.length - 1;
        selectedIndex = n;
        list.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activate() {
        if (entries.length > 0 && selectedIndex >= 0 && selectedIndex < entries.length)
            box.launch(entries[selectedIndex]);
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 22
        gradient: Gradient {
            GradientStop { position: 0.0; color: box.bgTop }
            GradientStop { position: 1.0; color: box.bgBot }
        }
        border.width: 1
        border.color: box.hair
        clip: true
        implicitHeight: input.height + list.implicitHeight

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Item {
            id: input
            width: parent.width
            height: 60

            Rectangle {
                id: dot
                anchors.verticalCenter: parent.verticalCenter
                x: 21
                width: 9
                height: 9
                radius: 4.5
                color: box.verm
            }

            TextField {
                id: field
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: dot.right
                anchors.leftMargin: 13
                anchors.right: counter.left
                anchors.rightMargin: 13
                background: null
                color: box.cream
                font.family: "Inter"
                font.pixelSize: 16
                placeholderText: "Search"
                placeholderTextColor: box.dim
                selectByMouse: true
                focus: true
                cursorDelegate: Rectangle {
                    width: 2
                    color: box.verm
                    visible: field.cursorVisible
                }
                Keys.onUpPressed: box.moveSelection(-1)
                Keys.onDownPressed: box.moveSelection(1)
                Keys.onPressed: (e) => {
                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { box.activate(); e.accepted = true; }
                    else if (e.key === Qt.Key_Escape) { box.quit(); e.accepted = true; }
                }
            }

            Text {
                id: counter
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 21
                text: box.entries.length + " / " + box.total
                color: box.dim2
                font.family: "Inter"
                font.pixelSize: 11
            }
        }

        Rectangle {
            id: divider
            anchors.top: input.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            height: 1
            color: box.hair
        }

        ListView {
            id: list
            width: parent.width
            anchors.top: divider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            leftMargin: 14
            rightMargin: 14
            topMargin: 8
            bottomMargin: 14
            spacing: 4
            implicitHeight: Math.min(contentHeight + topMargin + bottomMargin, 8 * 54 + topMargin + bottomMargin)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: box.entries.length

            delegate: AppRow {
                required property int index
                width: ListView.view.width - 28
                entry: box.entries[index]
                selected: index === box.selectedIndex
                onActivated: { box.selectedIndex = index; box.activate(); }
                onEntered: box.selectedIndex = index
            }
        }
    }

    function focusField() { field.forceActiveFocus(); }
    property alias query: field.text
}
