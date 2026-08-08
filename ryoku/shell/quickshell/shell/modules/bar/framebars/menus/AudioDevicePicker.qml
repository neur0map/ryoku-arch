pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// The device switcher shared by the audio output and input mixers: a header
// showing the current default device (icon + name + a chevron) that toggles a
// revealed list of the available devices, each selectable with a check on the
// current default. The host owns `listOpen` and switches the default on `picked`.
Column {
    id: root

    property real s: 1
    property var current: null
    property var devices: []
    property bool listOpen: false
    property string emptyLabel: ""
    property string fallbackIcon: "speaker"

    signal toggled()
    signal picked(var node)

    spacing: 2 * root.s

    MenuButton {
        id: header
        width: root.width
        minH: headRow.implicitHeight + header.pad * 2
        keepEnabledLook: true
        onClicked: root.toggled()

        Row {
            id: headRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                name: root.current ? Audio.nodeIcon(root.current) : root.fallbackIcon
                color: header.contentColor
                stroke: 1.7
            }
            Text {
                width: parent.width - (15 + 16 + 8 * 2) * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.current ? Audio.nodeLabel(root.current) : root.emptyLabel
                elide: Text.ElideRight
                color: header.contentColor
                font.family: Theme.fontPrimary
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-down"
                color: header.contentColor
                stroke: 1.7
                rotation: root.listOpen ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Motion.chevronRotate; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }
            }
        }
    }

    Item {
        width: root.width
        clip: true
        height: root.listOpen ? list.implicitHeight : 0
        Behavior on height { NumberAnimation { duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve } }

        Column {
            id: list
            width: parent.width
            spacing: 2 * root.s

            Repeater {
                model: root.listOpen ? root.devices : []
                delegate: MenuButton {
                    id: item
                    required property var modelData
                    readonly property bool isDefault: root.current && item.modelData && item.modelData.name === root.current.name
                    width: parent.width
                    minH: lbl.implicitHeight + item.pad * 2
                    selected: item.isDefault
                    onClicked: root.picked(item.modelData)
                    RevealerIconLabel {
                        id: lbl
                        anchors.fill: parent
                        iconName: item.isDefault ? "check_circle" : ""
                        label: Audio.nodeLabel(item.modelData)
                        iconColor: item.contentColor
                    }
                }
            }
        }
    }
}
