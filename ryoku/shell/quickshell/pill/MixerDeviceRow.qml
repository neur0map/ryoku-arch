pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// one audio endpoint in the mixer: a header (device-type glyph, name, a chevron
// that expands the picker), the endpoint's HFader, and, for a Bluetooth sink, a
// chip line with battery, codec, and a profile toggle. picking from the list
// switches the default through Audio. used for both output and input.
Item {
    id: root

    property real s: 1
    property string kind: "output"          // "output" | "input"
    property var node: null
    property var candidates: []
    property bool peakEnabled: false

    width: parent ? parent.width : 0
    implicitHeight: col.implicitHeight

    readonly property var au: (node && node.audio) ? node.audio : null
    readonly property bool isOutput: kind === "output"
    readonly property bool isBt: Audio.isBluez(node)
    readonly property int battery: Audio.batteryOf(node)
    readonly property string codec: root.isOutput ? Audio.btCodec : ""
    readonly property string profile: root.isOutput ? Audio.profileLabel() : ""

    property bool expanded: false

    HoverHandler { id: rowHover }

    function pick(n) {
        if (root.isOutput)
            Audio.setOutput(n);
        else
            Audio.setInput(n);
        root.expanded = false;
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6 * root.s

        // header: device type + name + picker chevron
        Item {
            width: parent.width
            height: 20 * root.s

            Row {
                anchors.left: parent.left
                anchors.right: chev.left
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15 * root.s
                    height: 15 * root.s
                    name: Audio.nodeIcon(root.node)
                    color: root.expanded ? Theme.cream : Theme.iconDim
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.width - 70 * root.s)
                    text: Audio.nodeLabel(root.node) || (root.isOutput ? "No output" : "No input")
                    color: root.expanded ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            Row {
                id: chev
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.candidates.length > 1
                    text: root.candidates.length + ""
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                }
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * root.s
                    height: 14 * root.s
                    name: "chevron-down"
                    color: root.expanded ? Theme.cream : Theme.iconDim
                    stroke: 1.8
                    rotation: root.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Motion.fast } }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.candidates.length > 0
                onClicked: root.expanded = !root.expanded
            }
        }

        HFader {
            id: fader
            width: parent.width
            s: root.s
            icon: root.isOutput ? "speaker" : "mic"
            lit: rowHover.hovered
            peakEnabled: root.peakEnabled
            peakNode: root.node
            muted: root.au ? root.au.muted : false
            value: root.au ? root.au.volume : 0
            valueLabel: !root.au ? "" : (root.au.muted ? "off" : (Math.round(root.au.volume * 100) + "%"))
            onMoved: (v) => { if (root.au) root.au.volume = v; }
            onIconTapped: { if (root.au) root.au.muted = !root.au.muted; }
        }

        // bluetooth chip: battery, codec, profile toggle.
        Item {
            width: parent.width
            height: 16 * root.s
            visible: root.isOutput && root.isBt && (root.battery >= 0 || root.codec.length > 0 || root.profile.length > 0)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 31 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Row {
                    visible: root.battery >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 * root.s
                    Filament {
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        kind: "battery"
                        level: Math.max(0, root.battery) / 100
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.battery + "%"
                        color: Theme.vermLit
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    visible: root.codec.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.codec
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4 * root.s
                }

                Rectangle {
                    visible: root.profile.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 999
                    color: profHover.hovered ? Theme.frameBg : Theme.tileBg
                    border.width: 1
                    border.color: Theme.border
                    height: 15 * root.s
                    width: profText.implicitWidth + 14 * root.s

                    Text {
                        id: profText
                        anchors.centerIn: parent
                        text: root.profile
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.weight: Font.DemiBold
                    }

                    HoverHandler { id: profHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleProfile()
                    }
                }
            }
        }

        // device picker, in-flow so the popout melts open to fit.
        Column {
            width: parent.width
            spacing: 2 * root.s
            visible: root.expanded

            Repeater {
                model: root.expanded ? root.candidates : []

                delegate: Rectangle {
                    id: cand
                    required property var modelData
                    readonly property bool current: root.node && modelData && modelData.id === root.node.id
                    width: parent.width
                    height: 26 * root.s
                    radius: 8 * root.s
                    color: candHover.hovered ? Theme.frameBg : "transparent"

                    HoverHandler { id: candHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(cand.modelData)
                    }

                    GlyphIcon {
                        id: candIco
                        anchors.left: parent.left
                        anchors.leftMargin: 9 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: Audio.nodeIcon(cand.modelData)
                        color: cand.current ? Theme.vermLit : Theme.iconDim
                        stroke: 1.6
                    }
                    Text {
                        anchors.left: candIco.right
                        anchors.leftMargin: 9 * root.s
                        anchors.right: dot.left
                        anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: Audio.nodeLabel(cand.modelData)
                        color: cand.current ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: cand.current ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        id: dot
                        anchors.right: parent.right
                        anchors.rightMargin: 11 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cand.current
                        width: 5 * root.s
                        height: 5 * root.s
                        radius: width / 2
                        color: Theme.vermLit
                    }
                }
            }
        }
    }
}
