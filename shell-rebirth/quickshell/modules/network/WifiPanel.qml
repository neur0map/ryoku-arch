import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import qs.services as Services
import "../../colors" as ColorsModule

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "󰖩"
                font.family: "Material Design Icons"
                font.pixelSize: 24
                color: Services.Network.wifiEnabled
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.on_surface_variant
            }

            Text {
                text: "Wi-Fi Networks"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
                color: ColorsModule.Colors.on_surface
            }

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 26
                radius: height / 2
                color: Services.Network.wifiEnabled
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.surface_container_high

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    y: 3
                    x: Services.Network.wifiEnabled
                        ? parent.width - width - 3
                        : 3
                    color: ColorsModule.Colors.surface

                    Behavior on x { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Network.toggleWifi()
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 8

                color: refreshMouseArea.containsMouse
                    ? ColorsModule.Colors.surface_container_highest
                    : ColorsModule.Colors.surface_container_high

                Text {
                    id: wifiScanIcon
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "Material Design Icons"
                    font.pixelSize: 20
                    color: Services.Network.scanning
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.on_surface

                    RotationAnimator on rotation {
                        from: 0; to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: Services.Network.scanning
                    }
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Network.rescan()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: messageText.visible ? 40 : 0
            visible: messageText.visible
            radius: 8

            color: Services.Network.lastErrorMessage !== ""
                ? ColorsModule.Colors.error_container
                : ColorsModule.Colors.primary_container

            border.color: Services.Network.lastErrorMessage !== ""
                ? ColorsModule.Colors.error
                : ColorsModule.Colors.primary

            border.width: 1

            Text {
                id: messageText
                anchors.centerIn: parent

                text: Services.Network.lastErrorMessage !== ""
                    ? Services.Network.lastErrorMessage
                    : (Services.Network.message === "ok"
                        ? "Connected successfully!"
                        : "")

                visible: text !== ""

                color: Services.Network.lastErrorMessage !== ""
                    ? ColorsModule.Colors.on_error_container
                    : ColorsModule.Colors.on_primary_container

                font.pixelSize: 13
            }

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 150 }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Services.Network.active ? 70 : 0
            visible: Services.Network.active
            radius: 10

            color: ColorsModule.Colors.surface_container_high
            border.color: ColorsModule.Colors.primary
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                    text: Services.Network.icon
                    font.family: "Material Design Icons"
                    font.pixelSize: 26
                    color: ColorsModule.Colors.primary
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    Text {
                        text: Services.Network.active
                            ? Services.Network.active.name
                            : ""
                        font.bold: true
                        color: ColorsModule.Colors.on_surface
                    }

                    Text {
                        text: "Connected"
                        font.pixelSize: 12
                        color: ColorsModule.Colors.primary
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 32
                    radius: 6

                    color: disconnectMouseArea.containsMouse
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.surface_container

                    border.color: ColorsModule.Colors.primary
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Disconnect"
                        color: disconnectMouseArea.containsMouse
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.primary
                    }

                    MouseArea {
                        id: disconnectMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Services.Network.disconnect()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: ColorsModule.Colors.surface_container_high

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: Services.Network.connections
                            .filter(c => c.type === "wifi")
                            .sort((a, b) => {
                            if (a.active && !b.active) return -1
                            if (!a.active && b.active) return 1
                            return b.strength - a.strength
                        })

                        delegate: Rectangle {
                            id: netItem
                            Layout.fillWidth: true
                            Layout.preferredHeight: isConnecting ? 64 : 56
                            radius: 8

                            property bool isConnecting: Services.Network.connecting
                                && modelData.name === Services.Network.lastNetworkAttempt

                            color: networkMouseArea.containsMouse
                                ? ColorsModule.Colors.surface_container_highest
                                : "transparent"

                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: 150 }
                            }

                            MouseArea {
                                id: networkMouseArea
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: {
                                    if (!modelData.active && !isConnecting) {
                                        passwordDialog.targetNetwork = modelData
                                        if (modelData.isSecure && !modelData.saved)
                                            passwordDialog.visible = true
                                        else
                                            Services.Network.connect(modelData, "")
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                Item {
                                    width: 28
                                    height: 28

                                    Text {
                                        id: netIcon
                                        anchors.centerIn: parent
                                        font.family: "Material Design Icons"
                                        font.pixelSize: 22
                                        text: {
                                            if (isConnecting) return "󰑐"
                                            if (modelData.active) return "󰄬"
                                            const s = modelData.strength
                                            if (s >= 75) return "󰤨"
                                            if (s >= 50) return "󰤥"
                                            if (s >= 25) return "󰤢"
                                            return "󰤟"
                                        }
                                        color: (isConnecting || modelData.active)
                                            ? ColorsModule.Colors.primary
                                            : ColorsModule.Colors.on_surface_variant

                                        RotationAnimator on rotation {
                                            from: 0; to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                            running: isConnecting
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        color: ColorsModule.Colors.on_surface
                                    }

                                    Text {
                                        visible: isConnecting
                                        text: "Connecting..."
                                        font.pixelSize: 11
                                        color: ColorsModule.Colors.primary
                                    }
                                }

                                Rectangle {
                                    visible: modelData.saved && !isConnecting
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: 6
                                    z: 1
                                    color: forgetMouseArea.containsMouse
                                        ? ColorsModule.Colors.error_container
                                        : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰺝"
                                        font.family: "Material Design Icons"
                                        font.pixelSize: 16
                                        color: forgetMouseArea.containsMouse
                                            ? ColorsModule.Colors.on_error_container
                                            : ColorsModule.Colors.on_surface_variant
                                    }

                                    MouseArea {
                                        id: forgetMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            mouse.accepted = true
                                            Services.Network.forget(modelData.name)
                                        }
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: passwordDialog
        anchors.fill: parent
        visible: false

        color: ColorsModule.Colors.scrim
        opacity: 0.85

        property var targetNetwork: null

        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 220
            radius: 12
            color: ColorsModule.Colors.surface_container_highest
            border.color: ColorsModule.Colors.primary
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                Text {
                    text: "Enter Password"
                    font.bold: true
                    font.pixelSize: 16
                    color: ColorsModule.Colors.on_surface
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: ColorsModule.Colors.surface_container
                    border.color: passwordInput.activeFocus
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.outline
                    border.width: passwordInput.activeFocus ? 2 : 1

                    FocusScope {
                        focus: passwordDialog.visible
                        id: inputScope
                        anchors.fill: parent
                        TextField {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.margins: 10
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Normal
                            color: ColorsModule.Colors.background
                            selectionColor: ColorsModule.Colors.primary
                            selectedTextColor: ColorsModule.Colors.on_primary
                            font.pixelSize: 14
                            placeholderText: "Enter Password"
                            focus: true
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: cancelMouseArea.containsMouse
                            ? ColorsModule.Colors.surface_container_highest
                            : ColorsModule.Colors.surface_container
                        border.color: ColorsModule.Colors.outline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: ColorsModule.Colors.on_surface
                        }

                        MouseArea {
                            id: cancelMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                passwordDialog.visible = false
                                passwordInput.text = ""
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 8
                        color: ColorsModule.Colors.primary

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: ColorsModule.Colors.on_primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Services.Network.connect(
                                    passwordDialog.targetNetwork,
                                    passwordInput.text
                                )
                                passwordDialog.visible = false
                                passwordInput.text = ""
                            }
                        }
                    }
                }
            }
        }
    }
}