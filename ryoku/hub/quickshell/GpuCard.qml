pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The GPU specimen card: the machine's two GPUs and the passthrough verdict, in the
// Profile idiom (warm carbon gradient, hairline border). Read-only; driven by the
// `caps` object from `ryoku-hub gpu caps`.
Item {
    id: root

    property var caps: ({})
    property real cardWidth: 360
    width: cardWidth
    implicitWidth: cardWidth
    implicitHeight: card.height

    readonly property var verdictMeta: ({
        "ready":         { "label": "PASSTHROUGH READY", "color": Theme.ok },
        "needs-relogin": { "label": "RELOGIN TO ENABLE",  "color": Theme.ember },
        "needs-reboot":  { "label": "REBOOT TO ENABLE",   "color": Theme.ember },
        "needs-setup":   { "label": "SETUP NEEDED",       "color": Theme.ember },
        "incapable":     { "label": "NOT CAPABLE",        "color": Theme.bad }
    })
    readonly property var verdict: root.verdictMeta[root.caps.verdict] || ({ "label": "DETECTING", "color": Theme.dim })

    component GpuLine: Row {
        id: line
        property string tag: ""
        property var gpu: null
        visible: line.gpu !== null && line.gpu !== undefined
        width: parent ? parent.width : 0
        spacing: 11

        Rectangle {
            width: 46
            height: 20
            radius: 5
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceLo
            border.width: 1
            border.color: Theme.line
            Text {
                anchors.centerIn: parent
                text: line.tag
                color: Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }
        }
        Column {
            width: line.width - 57
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: line.gpu ? line.gpu.model : ""
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                text: line.gpu ? (line.gpu.vramMb + " MB · " + line.gpu.driver + (line.gpu.drivesDisplay ? " · display" : "")) : ""
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: content.implicitHeight + 36
        radius: 16
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.line

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 16

            Text {
                text: "力  GRAPHICS"
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 2.4
            }

            Rectangle {
                width: parent.width
                height: 54
                radius: 10
                color: Qt.rgba(root.verdict.color.r, root.verdict.color.g, root.verdict.color.b, 0.10)
                border.width: 1
                border.color: Qt.rgba(root.verdict.color.r, root.verdict.color.g, root.verdict.color.b, 0.5)
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        color: root.verdict.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: root.verdict.label
                        color: root.verdict.color
                        font.family: Theme.mono
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            Column {
                width: parent.width
                spacing: 12
                GpuLine { tag: "iGPU"; gpu: root.caps.host }
                GpuLine { tag: "dGPU"; gpu: root.caps.passthrough }
            }

            Text {
                width: parent.width
                visible: root.caps.chassis !== undefined
                text: (root.caps.chassis === "laptop" ? "Laptop" : "Desktop")
                      + (root.caps.cpu ? " · " + root.caps.cpu : "")
                      + (root.caps.mux && root.caps.mux !== "none" ? " · MUX " + root.caps.mux.replace("present-", "") : "")
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10
                font.letterSpacing: 1
                font.capitalization: Font.AllUppercase
            }
        }
    }
}
