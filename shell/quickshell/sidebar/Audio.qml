import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import "Singletons"

Card {
    id: root
    eyebrow: "Audio"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    component SinkRow: Item {
        id: sinkRow
        property string label: ""
        property string device: ""
        property string chip: ""
        property var candidates: []
        property bool menuOpen: false
        signal selected(var node)
        width: parent ? parent.width : 0
        implicitHeight: 24 * root.s
        z: menuOpen ? 100 : 0

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: sinkRow.label + " · "
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.Medium
            }
            Text {
                text: sinkRow.device
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.DemiBold
            }
        }
        Rectangle {
            id: chipRect
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            radius: 9 * root.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.border
            implicitHeight: 24 * root.s
            width: chipRow.implicitWidth + 20 * root.s
            height: implicitHeight
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6 * root.s
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13 * root.s; height: 13 * root.s
                    Image {
                        id: chevIcon
                        anchors.fill: parent
                        source: Qt.resolvedUrl("assets/icons/chevron.svg")
                        sourceSize.width: 64; sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        smooth: true; mipmap: true; visible: false
                    }
                    MultiEffect {
                        anchors.fill: chevIcon
                        source: chevIcon
                        colorization: 1.0
                        colorizationColor: Theme.subtle
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sinkRow.chip
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: sinkRow.candidates.length > 0
                onClicked: sinkRow.menuOpen = !sinkRow.menuOpen
            }
        }
        Rectangle {
            id: menu
            visible: sinkRow.menuOpen
            anchors.right: chipRect.right
            anchors.top: chipRect.bottom
            anchors.topMargin: 6 * root.s
            radius: 10 * root.s
            color: Theme.panelTop
            border.width: 1
            border.color: Theme.border
            width: Math.max(chipRect.width, 180 * root.s)
            height: menuCol.implicitHeight + 12 * root.s
            z: 200
            Column {
                id: menuCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6 * root.s
                spacing: 2 * root.s
                Repeater {
                    model: sinkRow.candidates
                    delegate: Rectangle {
                        required property var modelData
                        width: menuCol.width
                        height: 22 * root.s
                        radius: 7 * root.s
                        color: rowHover.containsMouse ? Theme.tileBg : "transparent"
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 8 * root.s
                            anchors.right: parent.right
                            anchors.rightMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData && modelData.description ? modelData.description : (modelData && modelData.name ? modelData.name : "")
                            elide: Text.ElideRight
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sinkRow.selected(modelData);
                                sinkRow.menuOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }

    component VolRow: Item {
        id: volRow
        property string icon: ""
        property real value: 0.5
        property string valueLabel: ""
        property bool hasMic: false
        property bool micMuted: false
        signal moved(real v)
        signal micToggled()
        width: parent ? parent.width : 0
        implicitHeight: 26 * root.s

        Item {
            id: vicon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 19 * root.s; height: 19 * root.s
            Image {
                id: vIconImg
                anchors.fill: parent
                source: Qt.resolvedUrl("assets/icons/" + volRow.icon + ".svg")
                sourceSize.width: 64; sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true; visible: false
            }
            MultiEffect {
                anchors.fill: vIconImg
                source: vIconImg
                colorization: 1.0
                colorizationColor: Theme.vermLit
            }
        }
        Text {
            id: vval
            anchors.right: volRow.hasMic ? micbtn.left : parent.right
            anchors.rightMargin: volRow.hasMic ? 10 * root.s : 0
            anchors.verticalCenter: parent.verticalCenter
            width: 34 * root.s
            horizontalAlignment: Text.AlignRight
            text: volRow.valueLabel
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
        }
        Slider {
            s: root.s
            value: volRow.value
            anchors.left: vicon.right
            anchors.leftMargin: 12 * root.s
            anchors.right: vval.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            onMoved: (v) => volRow.moved(v)
        }
        Rectangle {
            id: micbtn
            visible: volRow.hasMic
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * root.s; height: 26 * root.s; radius: 8 * root.s
            color: volRow.micMuted ? Theme.accent16 : Theme.tileBg
            border.width: 1
            border.color: volRow.micMuted ? Theme.accent45 : Theme.border
            Image {
                id: micOffImg
                anchors.centerIn: parent
                width: 14 * root.s; height: 14 * root.s
                source: Qt.resolvedUrl("assets/icons/" + (volRow.micMuted ? "mic-off" : "mic") + ".svg")
                sourceSize.width: 64; sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true; visible: false
            }
            MultiEffect {
                anchors.fill: micOffImg
                source: micOffImg
                colorization: 1.0
                colorizationColor: volRow.micMuted ? Theme.vermLit : Theme.subtle
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: volRow.micToggled()
            }
        }
    }

    SinkRow {
        label: "Output"
        device: root.sink ? (root.sink.description ? root.sink.description : root.sink.name) : ""
        chip: "Switch"
        candidates: Pipewire.nodes.values.filter(n => n.isSink && n.audio)
        onSelected: (node) => { if (node) Pipewire.preferredDefaultAudioSink = node; }
    }
    VolRow {
        icon: "speaker"
        value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
        valueLabel: Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
        onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.hair
    }

    SinkRow {
        label: "Input"
        device: root.source ? (root.source.description ? root.source.description : root.source.name) : ""
        chip: "Switch"
        candidates: Pipewire.nodes.values.filter(n => !n.isSink && n.audio && n.isStream === false)
        onSelected: (node) => { if (node) Pipewire.preferredDefaultAudioSource = node; }
    }
    VolRow {
        icon: "mic"
        value: root.source && root.source.audio ? root.source.audio.volume : 0
        valueLabel: Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%"
        hasMic: true
        micMuted: root.source && root.source.audio ? root.source.audio.muted : false
        onMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }
        onMicToggled: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
    }
}
