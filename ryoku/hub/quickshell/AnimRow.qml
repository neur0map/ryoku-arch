pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One animation leaf in the Animations list: an enable switch, a speed stepper,
// and a bezier picker, laid out compactly so the whole tree reads as a table. The
// page owns the values and persists the change.
Rectangle {
    id: row

    property string leaf: ""
    property bool on: true
    property real speed: 1.0
    property string bezier: ""
    property var curveNames: []
    signal toggled(bool v)
    signal speedEdited(real v)
    signal bezierPicked(string b)

    height: 46
    radius: 10
    color: Theme.surfaceLo
    border.width: 1
    border.color: Theme.line

    Text {
        id: name
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 150
        elide: Text.ElideRight
        text: row.leaf
        color: row.on ? Theme.bright : Theme.dim
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        // enable switch
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 22
            radius: 11
            color: row.on ? Theme.ember : Theme.keyTop
            border.width: 1
            border.color: row.on ? Theme.ember : Theme.line
            Behavior on color { ColorAnimation { duration: Theme.quick } }

            Rectangle {
                width: 16
                height: 16
                radius: 8
                y: 3
                x: row.on ? parent.width - width - 3 : 3
                color: row.on ? Theme.onAccent : Theme.dim
                Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: row.toggled(!row.on) }
        }

        // speed stepper
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            component Step: Rectangle {
                id: st
                property string glyph: ""
                signal hit()
                width: 24
                height: 26
                radius: 7
                color: stHov.hovered ? Theme.keyTop : Theme.surface
                border.width: 1
                border.color: Theme.line
                Text {
                    anchors.centerIn: parent
                    text: st.glyph
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                HoverHandler { id: stHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: st.hit() }
            }

            Step { glyph: "\u2212"; onHit: row.speedEdited(Math.max(0.1, Math.round((row.speed - 0.1) * 10) / 10)) }
            Text {
                width: 44
                height: 26
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: row.speed.toFixed(1)
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Step { glyph: "+"; onHit: row.speedEdited(Math.min(10, Math.round((row.speed + 0.1) * 10) / 10)) }
        }

        Dropdown {
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            fieldWidth: 150
            label: ""
            options: row.curveNames
            current: row.bezier
            placeholder: "curve"
            onChosen: (k) => row.bezierPicked(k)
        }
    }
}
