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
        anchors { top: true; left: true; bottom: true }
        implicitWidth: 52
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

        readonly property bool isPlaying: {
            var players = Mpris.players.values
            if (!players || players.length === 0) return false
            for (var i = 0; i < players.length; i++) {
                if (players[i].playbackState === MprisPlaybackState.Playing) return true
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
            anchors.rightMargin: 0
            color: zyuTheme.bar_bg
            radius: 18
            border.color: Qt.rgba(1,1,1,0.04)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                spacing: 0

                Column {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 1
                    Text {
                        id: hourText
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: zyuTheme.bar_fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13; font.bold: true
                        function updateTime() { text = new Date().getHours().toString().padStart(2, '0') }
                        Component.onCompleted: updateTime()
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 3; height: 3; radius: 1.5
                        color: zyuTheme.accent; opacity: 0.5
                    }
                    Text {
                        id: minText
                        anchors.horizontalCenter: parent.horizontalCenter
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

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8; Layout.bottomMargin: 8
                    width: barRect.width - 16; height: 1; radius: 1
                    color: Qt.rgba(1,1,1,0.07)
                }

                Column {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    Repeater {
                        model: Hyprland.workspaces
                        delegate: Item {
                            width: 24; height: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: modelData.id > 0
                            property bool isActive: modelData.id === Hyprland.focusedMonitor?.activeWorkspace?.id

                            Rectangle {
                                anchors.centerIn: parent
                                width: isActive ? 12 : 0; height: isActive ? 12 : 0; radius: 3
                                color: "transparent"; border.width: 2; border.color: zyuTheme.accent
                                rotation: 45; opacity: isActive ? 1.0 : 0.0
                                Behavior on width   { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                                Behavior on height  { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: isActive ? 0 : 4; height: isActive ? 0 : 4; radius: 2
                                color: zyuTheme.bar_fg; opacity: isActive ? 0.0 : 0.28
                                Behavior on width   { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on height  { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + modelData.id)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8; Layout.bottomMargin: 8
                    width: barRect.width - 16; height: 1; radius: 1
                    color: Qt.rgba(1,1,1,0.07)
                }

                Item { Layout.fillHeight: true }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: barWindow.hasMusic ? 38 : 0
                    opacity: barWindow.hasMusic ? 1.0 : 0.0
                    clip: true
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 36; radius: 10
                        color: Qt.rgba(zyuTheme.accent.r, zyuTheme.accent.g, zyuTheme.accent.b, 0.12)
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: barWindow.activePlayer ? (barWindow.activePlayer.trackArtUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; smooth: true
                            sourceSize.width: 72; sourceSize.height: 72
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.musicVisible = !root.musicVisible
                        }
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: barWindow.hasMusic ? 8 : 0
                    Layout.preferredWidth: barRect.width
                    Layout.preferredHeight: barWindow.hasMusic ? musicTextCol.implicitWidth + 24 : 0
                    opacity: barWindow.hasMusic ? 1.0 : 0.0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 280 } }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.musicVisible = !root.musicVisible
                    }
                    Column {
                        id: musicTextCol
                        anchors.centerIn: parent; spacing: 4
                        rotation: -90; transformOrigin: Item.Center
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: barWindow.activePlayer ? (barWindow.activePlayer.trackTitle || "") : ""
                            color: root.musicVisible ? zyuTheme.accent : zyuTheme.bar_fg
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.musicVisible ? 30 : 10; height: 1; radius: 1
                            color: zyuTheme.accent; opacity: 0.3
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: barWindow.activePlayer ? (barWindow.activePlayer.trackArtist || "") : ""
                            color: zyuTheme.bar_fg; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; opacity: 0.38
                            visible: (barWindow.activePlayer?.trackArtist || "") !== ""
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Wifi
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    Rectangle {
                        anchors.centerIn: parent
                        width: wifiMa.containsMouse || root.wifiVisible ? 32 : 0; height: width; radius: 8
                        color: root.wifiVisible ? Qt.rgba(zyuTheme.accent.r, zyuTheme.accent.g, zyuTheme.accent.b, 0.18) : Qt.rgba(1,1,1,0.07)
                        Behavior on width  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: 150 } }
                    }
                    Text {
                        anchors.centerIn: parent; text: "󰤨"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                        color: root.wifiVisible ? zyuTheme.accent : Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, wifiMa.containsMouse ? 0.8 : 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea { id: wifiMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.wifiVisible = !root.wifiVisible }
                }

                // Dashboard
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    Rectangle {
                        anchors.centerIn: parent
                        width: dashMa.containsMouse ? 32 : 0; height: width; radius: 8
                        color: Qt.rgba(1,1,1,0.07)
                        Behavior on width  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    Text {
                        anchors.centerIn: parent; text: "󰕮"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17
                        color: Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, dashMa.containsMouse ? 0.8 : 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea { id: dashMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof dashboardState !== 'undefined') dashboardState.show = !dashboardState.show }
                }

                // Bluetooth
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    Layout.bottomMargin: 2
                    Rectangle {
                        anchors.centerIn: parent
                        width: btMa.containsMouse || root.btVisible ? 32 : 0; height: width; radius: 8
                        color: root.btVisible
                            ? Qt.rgba(zyuTheme.accent.r, zyuTheme.accent.g, zyuTheme.accent.b, 0.18)
                            : Qt.rgba(1,1,1,0.07)
                        Behavior on width  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color  { ColorAnimation  { duration: 150 } }
                    }
                    Text {
                        anchors.centerIn: parent; text: "󰂯"
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16
                        color: root.btVisible ? zyuTheme.accent
                            : Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, btMa.containsMouse ? 0.8 : 0.4)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea { id: btMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.btVisible = !root.btVisible }
                }
            }
        }
    }
}
