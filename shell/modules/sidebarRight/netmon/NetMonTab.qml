import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * Network Monitor sidebar tab. Shows public IP / default route / VPN
 * status / DNS leak warning / proxychain config / per-interface cards
 * with live RX/TX rate. Polling lives in RyokuNetMon and is gated on
 * sidebar+tab open; this widget is purely a view.
 */
Item {
    id: root
    anchors.fill: parent

    readonly property color colAccent:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimary
        : Appearance.colors.colPrimary

    readonly property var activeIfaces:
        (RyokuNetMon.interfaces || []).filter(i =>
            (i.state === "UP" || (i.isVpnTunnel && i.ipv4.length > 0))
            && i.name !== "lo")

    function formatRate(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec < 1) return "0 B/s"
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        if (bytesPerSec < 1024 * 1024 * 1024) return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
        return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(2) + " GB/s"
    }

    function typeIcon(type) {
        if (type === "wifi") return "signal_wifi_4_bar"
        if (type === "ether") return "lan"
        if (type === "vpn") return "vpn_key"
        if (type === "bridge") return "hub"
        if (type === "loopback") return "repeat"
        return "device_hub"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Egress strip.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: egressCol.implicitHeight + 24
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal

            ColumnLayout {
                id: egressCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol {
                        text: "public"
                        iconSize: Appearance.font.pixelSize.larger
                        color: root.colAccent
                    }
                    ColumnLayout {
                        id: publicIpCol
                        Layout.fillWidth: true
                        spacing: 0
                        property bool justCopied: false
                        Timer {
                            id: publicIpCopyResetTimer
                            interval: 1500
                            onTriggered: publicIpCol.justCopied = false
                        }
                        StyledText {
                            id: publicIpText
                            text: publicIpCol.justCopied
                                  ? "Copied!"
                                  : (RyokuNetMon.publicIpFetching
                                     ? "Fetching public IP..."
                                     : (RyokuNetMon.publicIp.length > 0
                                        ? "Public IP: " + RyokuNetMon.publicIp
                                        : (RyokuNetMon.publicIpError.length > 0
                                           ? "Public IP: " + RyokuNetMon.publicIpError
                                           : "Public IP: not yet fetched")))
                            color: publicIpCol.justCopied
                                   ? root.colAccent
                                   : Appearance.colors.colOnLayer2
                            font.weight: Font.Bold
                            font.family: Appearance.font.family.monospace ?? "monospace"
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: RyokuNetMon.publicIp.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: RyokuNetMon.publicIp.length > 0 && !publicIpCol.justCopied
                                onClicked: {
                                    Quickshell.clipboardText = RyokuNetMon.publicIp
                                    publicIpCol.justCopied = true
                                    publicIpCopyResetTimer.restart()
                                }
                            }
                        }
                        StyledText {
                            visible: RyokuNetMon.defaultRouteIface.length > 0
                            text: "via " + RyokuNetMon.defaultRouteIface
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                    Rectangle {
                        implicitWidth: 32; implicitHeight: 32
                        radius: Appearance.rounding.small
                        color: refreshMouse.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !RyokuNetMon.publicIpFetching
                            onClicked: RyokuNetMon.refreshPublicIp()
                        }
                    }
                }

                LatencyStrip { colAccent: root.colAccent }

                // DNS-leak banner.
                Rectangle {
                    visible: RyokuNetMon.dnsLeak
                    Layout.fillWidth: true
                    Layout.preferredHeight: leakRow.implicitHeight + 12
                    radius: Appearance.rounding.small
                    color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.85)
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.m3colors.m3error ?? "#fb4934", 0.5)
                    RowLayout {
                        id: leakRow
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8
                        MaterialSymbol {
                            text: "warning"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3error ?? "#fb4934"
                        }
                        StyledText {
                            text: RyokuNetMon.dnsLeakReason
                            color: Appearance.m3colors.m3error ?? "#fb4934"
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // Proxychain card.
        Rectangle {
            visible: RyokuNetMon.proxychain !== null
            Layout.fillWidth: true
            Layout.preferredHeight: pxCol.implicitHeight + 24
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal

            ColumnLayout {
                id: pxCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol {
                        text: "filter_alt"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.colAccent
                    }
                    StyledText {
                        text: "ProxyChain"
                        color: Appearance.colors.colOnLayer2
                        font.weight: Font.Bold
                    }
                    StyledText {
                        text: "(" + (RyokuNetMon.proxychain ? RyokuNetMon.proxychain.type : "") + ")"
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: RyokuNetMon.proxychain ? RyokuNetMon.proxychain.configPath : ""
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace ?? "monospace"
                        elide: Text.ElideLeft
                        Layout.maximumWidth: 200
                    }
                }
                Repeater {
                    model: RyokuNetMon.proxychain ? RyokuNetMon.proxychain.proxies : []
                    delegate: RowLayout {
                        required property var modelData
                        required property int index
                        spacing: 6
                        StyledText {
                            text: (index + 1) + "."
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.monospace ?? "monospace"
                        }
                        StyledText {
                            text: modelData.type
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                        StyledText {
                            text: modelData.host + ":" + modelData.port
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.family: Appearance.font.family.monospace ?? "monospace"
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // Active connections header.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "lan"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            StyledText {
                text: "Active connections"
                color: Appearance.colors.colOnLayer1
                font.weight: Font.Bold
                font.pixelSize: Appearance.font.pixelSize.normal
            }
            StyledText {
                text: "(" + root.activeIfaces.length + ")"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            Item { Layout.fillWidth: true }
        }

        // Cards.
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.activeIfaces
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        property bool justCopiedV4: false
                        property bool justCopiedV6: false
                        Layout.fillWidth: true
                        Layout.preferredHeight: cardCol.implicitHeight + 18
                        color: Appearance.colors.colLayer2
                        radius: Appearance.rounding.normal
                        border.width: modelData.isVpnTunnel ? 1 : 0
                        border.color: modelData.isVpnTunnel ? root.colAccent : "transparent"

                        Timer {
                            id: copyV4Reset
                            interval: 1500
                            onTriggered: card.justCopiedV4 = false
                        }
                        Timer {
                            id: copyV6Reset
                            interval: 1500
                            onTriggered: card.justCopiedV6 = false
                        }

                        ColumnLayout {
                            id: cardCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol {
                                    text: root.typeIcon(modelData.type)
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: modelData.isVpnTunnel ? root.colAccent : Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: modelData.connectionName.length > 0 ? modelData.connectionName : modelData.name
                                    color: Appearance.colors.colOnLayer2
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: modelData.isVpnTunnel
                                    implicitWidth: vpnLabel.implicitWidth + 12
                                    implicitHeight: vpnLabel.implicitHeight + 4
                                    radius: implicitHeight / 2
                                    color: ColorUtils.transparentize(root.colAccent, 0.85)
                                    StyledText {
                                        id: vpnLabel
                                        anchors.centerIn: parent
                                        text: "VPN"
                                        color: root.colAccent
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Bold
                                    }
                                }
                                StyledText {
                                    text: modelData.state
                                    color: modelData.state === "UP" ? root.colAccent : Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }
                            StyledText {
                                visible: modelData.ipv4.length > 0
                                text: card.justCopiedV4 ? "Copied!" : modelData.ipv4
                                color: card.justCopiedV4 ? root.colAccent : Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.monospace ?? "monospace"
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !card.justCopiedV4
                                    onClicked: {
                                        Quickshell.clipboardText = modelData.ipv4
                                        card.justCopiedV4 = true
                                        copyV4Reset.restart()
                                    }
                                }
                            }
                            StyledText {
                                visible: modelData.ipv6.length > 0
                                text: card.justCopiedV6 ? "Copied!" : modelData.ipv6
                                color: card.justCopiedV6 ? root.colAccent : Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.family: Appearance.font.family.monospace ?? "monospace"
                                elide: Text.ElideRight
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !card.justCopiedV6
                                    onClicked: {
                                        Quickshell.clipboardText = modelData.ipv6
                                        card.justCopiedV6 = true
                                        copyV6Reset.restart()
                                    }
                                }
                                Layout.fillWidth: true
                            }
                            StyledText {
                                visible: modelData.gateway.length > 0
                                text: "via " + modelData.gateway
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                            StyledText {
                                visible: modelData.dns && modelData.dns.length > 0
                                text: "DNS: " + (modelData.dns || []).join(", ")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 8
                                Layout.topMargin: 2
                                MaterialSymbol {
                                    text: "arrow_downward"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: root.formatRate(modelData.rxRate)
                                    color: Appearance.colors.colOnLayer2
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.monospace ?? "monospace"
                                }
                                MaterialSymbol {
                                    text: "arrow_upward"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: root.formatRate(modelData.txRate)
                                    color: Appearance.colors.colOnLayer2
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.monospace ?? "monospace"
                                }
                            }
                            StyledText {
                                visible: modelData.vnstatToday && modelData.vnstatToday.length > 0
                                text: "Today: " + modelData.vnstatToday + " | Month: " + modelData.vnstatMonth
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            StyledText {
                                visible: modelData.type === "wifi" && modelData.ssid && modelData.ssid.length > 0
                                text: modelData.ssid + " | " + modelData.signal + "%"
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }
                    }
                }
                ListenerSection { colAccent: root.colAccent }
                ConnectionsSection { colAccent: root.colAccent }
            }
        }
    }
}
