import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

/*
 * Established outbound connections: own-process TCP sockets in ESTAB state.
 * Click any row to copy the bare remote IP (no port) to the clipboard.
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 6

    required property color colAccent

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MaterialSymbol {
            text: "arrow_outward"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: "Outbound"
            color: Appearance.colors.colOnLayer1
            font.weight: Font.Bold
            font.pixelSize: Appearance.font.pixelSize.normal
        }
        StyledText {
            text: "(" + RyokuNetMon.connections.length + ")"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.fillWidth: true }
    }

    StyledText {
        visible: RyokuNetMon.connections.length === 0
        text: "No outbound connections"
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
        Layout.leftMargin: 4
    }

    Repeater {
        model: RyokuNetMon.connections
        delegate: Rectangle {
            id: row
            required property var modelData
            property bool justCopied: false
            Layout.fillWidth: true
            Layout.preferredHeight: rowLayout.implicitHeight + 10
            color: rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
            radius: Appearance.rounding.small
            Behavior on color { ColorAnimation { duration: 100 } }

            Timer {
                id: copyResetTimer
                interval: 1500
                onTriggered: row.justCopied = false
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10

                StyledText {
                    text: row.modelData.process
                    color: Appearance.colors.colOnLayer2
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.preferredWidth: 110
                    elide: Text.ElideRight
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: row.justCopied
                          ? "Copied!"
                          : (row.modelData.remoteAddress + ":" + row.modelData.remotePort)
                    color: row.justCopied ? root.colAccent : Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideMiddle
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !row.justCopied
                onClicked: {
                    Quickshell.clipboardText = row.modelData.remoteAddress
                    row.justCopied = true
                    copyResetTimer.restart()
                }
            }
        }
    }
}
