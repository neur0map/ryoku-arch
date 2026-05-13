import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

/*
 * Listener overview: own-process TCP LISTEN sockets. Click the port number
 * to open http://localhost:<port> in the default browser; click the trailing
 * X icon to SIGTERM the listener. Bound address is color-coded (yellow for
 * 0.0.0.0/::/*, subtext for loopback) so the security signal is visible at a
 * glance.
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

    readonly property color colWarn: Appearance.m3colors.m3warning ?? "#fabd2f"

    function isExposed(addr) {
        // Wildcard binds: 0.0.0.0 (any IPv4), :: (any IPv6), * (some ss output formats).
        return addr === "0.0.0.0" || addr === "::" || addr === "*"
    }

    // Section header.
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
            visible: RyokuNetMon.listeners.length > 0
            text: RyokuNetMon.listeners.length === 1
                  ? "1 port"
                  : RyokuNetMon.listeners.length + " ports"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        Item { Layout.fillWidth: true }
    }

    // List body: a single rounded surface containing simple list-item rows.
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: bodyCol.implicitHeight + 16
        color: RyokuNetMon.listeners.length === 0 ? "transparent" : Appearance.colors.colLayer2
        radius: Appearance.rounding.normal
        border.width: RyokuNetMon.listeners.length === 0 ? 1 : 0
        border.color: RyokuNetMon.listeners.length === 0
                      ? ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)
                      : "transparent"

        ColumnLayout {
            id: bodyCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 8
            spacing: 4

            // Empty state (centered subtext when no rows).
            StyledText {
                visible: RyokuNetMon.listeners.length === 0
                text: "No listening ports"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 8
            }

            Repeater {
                model: RyokuNetMon.listeners
                delegate: RowLayout {
                    id: row
                    required property var modelData
                    property bool dimming: false
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    spacing: 12
                    opacity: dimming ? 0.5 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Timer {
                        id: dimResetTimer
                        interval: 3000
                        onTriggered: row.dimming = false
                    }

                    // Port: monospace number, clickable, accent color.
                    StyledText {
                        text: row.modelData.port
                        color: root.colAccent
                        font.weight: Font.Bold
                        font.family: Appearance.font.family.monospace ?? "monospace"
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.preferredWidth: 56
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["xdg-open", "http://localhost:" + row.modelData.port])
                        }
                        StyledToolTip {
                            extraVisibleCondition: parent.children[0].containsMouse
                            text: "Open in browser"
                        }
                    }

                    // Process name: flexes to fill.
                    StyledText {
                        text: row.modelData.process
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // Bound address: monospace, color-coded for security signal.
                    StyledText {
                        text: row.modelData.address
                        color: root.isExposed(row.modelData.address) ? root.colWarn : Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace ?? "monospace"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }

                    // Kill (trailing icon button) - matches HostsTab remove button.
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Appearance.rounding.small
                        color: killMouse.containsPress ? ColorUtils.transparentize(root.colAccent, 0.7)
                               : killMouse.containsMouse ? Appearance.colors.colLayer2Hover
                               : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: killMouse.containsMouse ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
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
                        StyledToolTip {
                            extraVisibleCondition: killMouse.containsMouse
                            text: "Stop listener (SIGTERM)"
                        }
                    }
                }
            }
        }
    }
}
