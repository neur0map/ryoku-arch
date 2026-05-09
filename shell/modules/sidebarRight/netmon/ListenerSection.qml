import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

/*
 * Listener overview: own-process TCP LISTEN sockets. Click the port pill to
 * open http://localhost:<port> in the default browser; click the X icon to
 * SIGTERM the listener. Bound address is color-coded (yellow for 0.0.0.0/::,
 * subtext for loopback) so the security signal is visible at a glance.
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 6

    required property color colAccent

    readonly property color colWarn: Appearance.m3colors.m3warning ?? "#fabd2f"

    function isExposed(addr) {
        return addr === "0.0.0.0" || addr === "::"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MaterialSymbol {
            text: "wifi_tethering"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: "Listeners"
            color: Appearance.colors.colOnLayer1
            font.weight: Font.Bold
            font.pixelSize: Appearance.font.pixelSize.normal
        }
        StyledText {
            text: "(" + RyokuNetMon.listeners.length + ")"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.fillWidth: true }
    }

    StyledText {
        visible: RyokuNetMon.listeners.length === 0
        text: "No listening ports"
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.small
        Layout.leftMargin: 4
    }

    Repeater {
        model: RyokuNetMon.listeners
        delegate: Rectangle {
            id: row
            required property var modelData
            property bool dimming: false
            Layout.fillWidth: true
            Layout.preferredHeight: rowLayout.implicitHeight + 12
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small
            opacity: dimming ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Timer {
                id: dimResetTimer
                interval: 3000
                onTriggered: row.dimming = false
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10

                // Port pill: click opens http://localhost:<port>
                Rectangle {
                    implicitWidth: portText.implicitWidth + 16
                    implicitHeight: portText.implicitHeight + 6
                    radius: implicitHeight / 2
                    color: ColorUtils.transparentize(root.colAccent, 0.85)
                    border.width: 1
                    border.color: ColorUtils.transparentize(root.colAccent, 0.6)
                    StyledText {
                        id: portText
                        anchors.centerIn: parent
                        text: row.modelData.port
                        color: root.colAccent
                        font.weight: Font.Bold
                        font.family: Appearance.font.family.monospace ?? "monospace"
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", "http://localhost:" + row.modelData.port])
                    }
                }

                StyledText {
                    text: row.modelData.process
                    color: Appearance.colors.colOnLayer2
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.small
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                StyledText {
                    text: row.modelData.address
                    color: root.isExposed(row.modelData.address) ? root.colWarn : Appearance.colors.colSubtext
                    font.family: Appearance.font.family.monospace ?? "monospace"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                // Kill button
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28
                    radius: Appearance.rounding.small
                    color: killMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    MouseArea {
                        id: killMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !row.dimming
                        onClicked: {
                            RyokuNetMon.killListener(row.modelData.pid)
                            row.dimming = true
                            dimResetTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
