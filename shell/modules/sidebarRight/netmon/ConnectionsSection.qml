import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

/*
 * Established outbound connections: own-process TCP sockets in ESTAB state.
 * Click any row to copy the bare remote IP (no port) to the clipboard.
 *
 * Layout follows the HostsTab minimalist Material 3 list pattern: one
 * rounded section background contains a vertical list of plain RowLayout
 * delegates (no per-row card chrome).
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8

    required property color colAccent

    // Section header.
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
            visible: RyokuNetMon.connections.length > 0
            text: RyokuNetMon.connections.length === 1
                  ? "1 connection"
                  : RyokuNetMon.connections.length + " connections"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.fillWidth: true }
    }

    // List body: single rounded surface, simple row delegates.
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: bodyCol.implicitHeight + 16
        color: RyokuNetMon.connections.length === 0 ? "transparent" : Appearance.colors.colLayer2
        radius: Appearance.rounding.normal
        border.width: RyokuNetMon.connections.length === 0 ? 1 : 0
        border.color: RyokuNetMon.connections.length === 0
                      ? ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)
                      : "transparent"

        ColumnLayout {
            id: bodyCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 8
            spacing: 4

            StyledText {
                visible: RyokuNetMon.connections.length === 0
                text: "No outbound connections"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }

            Repeater {
                model: RyokuNetMon.connections
                delegate: Item {
                    id: row
                    required property var modelData
                    property bool justCopied: false
                    Layout.fillWidth: true
                    implicitHeight: rowLayout.implicitHeight + 6

                    Timer {
                        id: copyResetTimer
                        interval: 1500
                        onTriggered: row.justCopied = false
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: rowMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    RowLayout {
                        id: rowLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        StyledText {
                            text: row.modelData.process
                            color: Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.small
                            Layout.preferredWidth: 110
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: row.justCopied
                                  ? "Copied!"
                                  : (row.modelData.remoteAddress + ":" + row.modelData.remotePort)
                            color: row.justCopied ? root.colAccent : Appearance.colors.colSubtext
                            font.family: Appearance.font.family.monospace ?? "monospace"
                            font.pixelSize: Appearance.font.pixelSize.small
                            Layout.fillWidth: true
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
                    StyledToolTip {
                        extraVisibleCondition: rowMouse.containsMouse
                        text: "Copy IP"
                    }
                }
            }
        }
    }
}
