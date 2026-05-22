import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: barWindow
        required property var modelData
        screen: modelData
        anchors { top: true; left: true; right: true }
        implicitHeight: 64
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Normal

        visible: {
            const activeWs = Hyprland.focusedMonitor?.activeWorkspace
            return activeWs ? activeWs.id > 0 : true
        }

        readonly property bool hasMusic: {
            var players = Mpris.players.values
            if (!players || players.length === 0) return false
            for (var i = 0; i < players.length; i++) {
                if (players[i].playbackState === MprisPlaybackState.Playing ||
                    players[i].playbackState === MprisPlaybackState.Paused) return true
            }
            return false
        }

        readonly property var activePlayer: {
            var players = Mpris.players.values
            if (!players || players.length === 0) return null
            for (var i = 0; i < players.length; i++) {
                if (players[i].playbackState === MprisPlaybackState.Playing) return players[i]
            }
            return players.length > 0 ? players[0] : null
        }

        Rectangle {
            id: barRect
            anchors.fill: parent
            anchors.margins: 6
            color: zyuTheme.bar_bg
            radius: 18
            border.color: Qt.rgba(1,1,1,0.04)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4
                    Text {
                        id: hourText
                        color: zyuTheme.bar_fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13; font.bold: true
                        function updateTime() { text = new Date().getHours().toString().padStart(2, '0') }
                        Component.onCompleted: updateTime()
                    }
                    Text { text: ":"; color: zyuTheme.accent; font.bold: true; font.pixelSize: 13 }
                    Text {
                        id: minText
                        color: zyuTheme.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13; font.bold: true
                        function updateTime() { text = new Date().getMinutes().toString().padStart(2, '0') }
                        Component.onCompleted: updateTime()
                    }
                    Timer {
                        interval: 30000; running: true; repeat: true
                        onTriggered: { hourText.updateTime(); minText.updateTime() }
                    }
                }

                Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.07); Layout.alignment: Qt.AlignVCenter }

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 10
                    Repeater {
                        model: Hyprland.workspaces
                        delegate: Item {
                            width: 24; height: 24
                            visible: modelData.id > 0
                            property bool isActive: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id

                            Rectangle {
                                anchors.centerIn: parent
                                width: isActive ? 12 : 0; height: width; radius: 3
                                color: "transparent"; border.width: 2; border.color: zyuTheme.accent
                                rotation: 45; opacity: isActive ? 1.0 : 0.0
                                Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: isActive ? 0 : 4; height: width; radius: 2
                                color: zyuTheme.bar_fg; opacity: isActive ? 0.0 : 0.28
                                Behavior on width { NumberAnimation { duration: 250 } }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    Layout.alignment: Qt.AlignVCenter
                    visible: barWindow.hasMusic
                    spacing: 8

                    Rectangle {
                        width: 32; height: 32; radius: 8
                        color: Qt.rgba(zyuTheme.accent.r, zyuTheme.accent.g, zyuTheme.accent.b, 0.1)
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: barWindow.activePlayer ? (barWindow.activePlayer.trackArtUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.musicVisible = !root.musicVisible }
                    }

                    Column {
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: barWindow.activePlayer ? (barWindow.activePlayer.trackTitle || "") : ""
                            color: zyuTheme.bar_fg; font.pixelSize: 11; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            text: barWindow.activePlayer ? (barWindow.activePlayer.trackArtist || "") : ""
                            color: zyuTheme.bar_fg; font.pixelSize: 9; opacity: 0.4
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    // Wifi
                    Item {
                        width: 36; height: 36
                        Rectangle {
                            anchors.centerIn: parent
                            width: wifiMa.containsMouse || root.wifiVisible ? 32 : 0; height: width; radius: 8
                            color: root.wifiVisible ? Qt.rgba(zyuTheme.accent.r, zyuTheme.accent.g, zyuTheme.accent.b, 0.18) : Qt.rgba(1,1,1,0.07)
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                        Text {
                            anchors.centerIn: parent; text: "󰤨"; font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                            color: root.wifiVisible ? zyuTheme.accent : Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, wifiMa.containsMouse ? 0.8 : 0.4)
                        }
                        MouseArea { id: wifiMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.wifiVisible = !root.wifiVisible }
                    }

                    // Dashboard
                    Item {
                        width: 36; height: 36
                        Rectangle {
                            anchors.centerIn: parent
                            width: dashMa.containsMouse ? 32 : 0; height: width; radius: 8
                            color: Qt.rgba(1,1,1,0.07)
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                        Text {
                            anchors.centerIn: parent; text: "󰕮"; font.pixelSize: 17
                            font.family: "JetBrainsMono Nerd Font"
                            color: Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, dashMa.containsMouse ? 0.8 : 0.4)
                        }
                        MouseArea { id: dashMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: if (typeof dashboardState !== 'undefined') dashboardState.show = !dashboardState.show }
                    }

                    // Bluetooth
                    Item {
                        width: 36; height: 36
                        Rectangle {
                            anchors.centerIn: parent
                            width: btMa.containsMouse || root.btVisible ? 32 : 0; height: width; radius: 8
                            color: root.btVisible ? Qt.rgba(zyuTheme.accent.r, zyuTheme.accent.g, zyuTheme.accent.b, 0.18) : Qt.rgba(1,1,1,0.07)
                            Behavior on width { NumberAnimation { duration: 180 } }
                            Behavior on color { ColorAnimation  { duration: 150 } }
                        }
                        Text {
                            anchors.centerIn: parent; text: "󰂯"; font.pixelSize: 16
                            font.family: "JetBrainsMono Nerd Font"
                            color: root.btVisible ? zyuTheme.accent : Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, btMa.containsMouse ? 0.8 : 0.4)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        MouseArea { id: btMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root.btVisible = !root.btVisible }
                    }
                }
            }
        }
    }
}
