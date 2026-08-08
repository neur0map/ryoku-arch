import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import shell.services
import "../modules"

PanelWindow {
    id: volPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-volume"

    readonly property int barBottom: 35
    readonly property int gap: 8

    AudioData { id: audio }
    readonly property int    volume:   audio.volume
    readonly property bool   muted:    audio.muted
    readonly property bool   micMuted: Audio.source && Audio.source.audio ? Audio.source.audio.muted : false
    property real   micLevel: 0
    readonly property real micNoiseFloorDb: -55
    readonly property bool micMeterAvailable: micPeakLoader.status === Loader.Ready
        && micPeakLoader.item !== null
    readonly property real micPeakValue: micMeterAvailable ? micPeakLoader.item.peak : 0

    Loader {
        id: micPeakLoader
        active: true
        source: "MicrophonePeakMonitor.qml"
        onLoaded: {
            item.panelOpen = Qt.binding(function() { return root.volVisible })
            item.muted = Qt.binding(function() { return volPanel.micMuted })
        }
    }

    function peakToMeter(peak) {
        if (!isFinite(peak) || peak <= 0) return 0
        // PwNodePeakMonitor exposes the cube root of linear amplitude.
        var amplitude = peak * peak * peak
        var db = 20 * Math.log(amplitude) / Math.LN10
        if (db <= micNoiseFloorDb) return 0
        return Math.max(0, Math.min(1, (db - micNoiseFloorDb) / -micNoiseFloorDb))
    }

    Timer {
        interval: 45
        repeat: true
        running: root.volVisible && volPanel.micMeterAvailable
        onTriggered: {
            var sample = volPanel.micMuted ? 0 : volPanel.peakToMeter(volPanel.micPeakValue)
            volPanel.micLevel = sample >= volPanel.micLevel
                ? sample : Math.max(sample, volPanel.micLevel * 0.78)
        }
        onRunningChanged: if (!running) volPanel.micLevel = 0
    }

    property real reveal: root.volVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.volVisible ? 160 : 120
            easing.type: root.volVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.volVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.volVisible = false
    }

    Rectangle {
        id: card
        width: 280
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.volumeBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: volPanel.reveal
        focus: root.volVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.volVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Volume"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.volVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── volume bar ──
            UiText {
                text: "OUTPUT"
                color: root.sumiHi
                font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }

            Item {
                width: parent.width
                height: 30
                UiText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    text: volPanel.muted ? "Muted" : volPanel.volume + "%"
                    color: volPanel.muted
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.4)
                        : root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: 8; radius: 4
                    color: root.fillActive
                    Rectangle {
                        width: parent.width * (volPanel.muted ? 0 : Math.min(volPanel.volume / 100, 1))
                        height: parent.height; radius: 4
                        color: root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            // ── output device switcher ──
            UiText {
                text: "OUTPUT DEVICE"
                color: root.sumiHi
                font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Column {
                width: parent.width
                spacing: 4
                Repeater {
                    model: Audio.outputs
                    delegate: Rectangle {
                        id: devTile
                        required property var modelData
                        readonly property bool isDef:   Audio.sink && devTile.modelData.name === Audio.sink.name
                        readonly property bool hovered: devMa.containsMouse
                        width: parent.width
                        height: 26; radius: root.tileRadius
                        color: isDef     ? root.fillActive
                             : hovered ? root.fillHover : root.fillIdle
                        border.color: (isDef || hovered) ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 6
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: devTile.isDef ? "●" : "○"
                                color: devTile.isDef ? root.seal : root.sumi
                                font.family: root.mono; font.pixelSize: 10
                            }
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 22
                                text: Audio.nodeLabel(devTile.modelData)
                                color: (devTile.isDef || devTile.hovered) ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: devMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Audio.setOutput(devTile.modelData)
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── mute toggle ──
            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                color: volPanel.muted ? root.fillActive
                    : muteMa.containsMouse ? root.fillHover
                    : root.fillIdle
                border.color: (muteMa.containsMouse || volPanel.muted) ? root.seal : root.sep
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: volPanel.muted ? "Unmute volume" : "Mute volume"
                    color: (muteMa.containsMouse || volPanel.muted) ? root.seal : root.sumi
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: muteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Audio.sink && Audio.sink.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                    }
                }
            }

            // ── per-app mixer ──
            Rectangle { width: parent.width; height: 1; color: root.sep; visible: Audio.streams.length > 0 }
            UiText {
                visible: Audio.streams.length > 0
                text: "APPS"
                color: root.sumiHi
                font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Column {
                width: parent.width
                spacing: 8
                Repeater {
                    model: Audio.streams
                    delegate: Item {
                        id: appRow
                        required property var modelData
                        width: parent.width
                        height: 32
                        readonly property bool appMuted: modelData.audio ? modelData.audio.muted : false
                        property int liveVol: modelData.audio ? Math.round(modelData.audio.volume * 100) : 0

                        // mute glyph
                        IconText {
                            id: appMute
                            anchors.left: parent.left
                            anchors.top: parent.top
                            text: appRow.appMuted ? String.fromCodePoint(0xE04F) : String.fromCodePoint(0xE050)
                            font.pixelSize: 15
                            color: appRow.appMuted ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4) : root.seal
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (appRow.modelData.audio) appRow.modelData.audio.muted = !appRow.modelData.audio.muted
                                }
                            }
                        }
                        UiText {
                            anchors.left: appMute.right; anchors.leftMargin: 6
                            anchors.verticalCenter: appMute.verticalCenter
                            anchors.verticalCenterOffset: 1
                            anchors.right: appPct.left; anchors.rightMargin: 6
                            text: Audio.streamName(appRow.modelData)
                            color: appRow.appMuted ? root.sumi : root.ink
                            font.family: root.mono; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        UiText {
                            id: appPct
                            anchors.right: parent.right
                            anchors.verticalCenter: appMute.verticalCenter
                            anchors.verticalCenterOffset: 1
                            text: appRow.liveVol + "%"
                            color: root.seal
                            font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                        }

                        // draggable volume bar
                        Rectangle {
                            id: appTrack
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 8; radius: 4
                            color: root.fillActive
                            Rectangle {
                                width: parent.width * Math.min(appRow.liveVol / 100, 1)
                                height: parent.height; radius: 4
                                color: appRow.appMuted ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.4) : root.seal
                            }
                            MouseArea {
                                anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -4
                                cursorShape: Qt.PointingHandCursor
                                function setFromX(x) {
                                    appRow.liveVol = Math.max(0, Math.min(100, Math.round(x / appTrack.width * 100)))
                                }
                                onPressed:          function(m) { setFromX(m.x) }
                                onPositionChanged:  function(m) { if (pressed) setFromX(m.x) }
                                onReleased: function(m) {
                                    if (appRow.modelData.audio)
                                        appRow.modelData.audio.volume = Math.max(0, Math.min(1, m.x / appTrack.width))
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── mic section ──
            UiText {
                text: "INPUT"
                color: root.sumiHi
                font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }

            Column {
                width: parent.width
                spacing: 4
                Repeater {
                    model: Audio.inputs
                    delegate: Rectangle {
                        id: inTile
                        required property var modelData
                        readonly property bool isDef:   Audio.source && inTile.modelData.name === Audio.source.name
                        readonly property bool hovered: inMa.containsMouse
                        width: parent.width
                        height: 26; radius: root.tileRadius
                        color: isDef     ? root.fillActive
                             : hovered ? root.fillHover : root.fillIdle
                        border.color: (isDef || hovered) ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 6
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: inTile.isDef ? "●" : "○"
                                color: inTile.isDef ? root.seal : root.sumi
                                font.family: root.mono; font.pixelSize: 10
                            }
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 22
                                text: Audio.nodeLabel(inTile.modelData)
                                color: (inTile.isDef || inTile.hovered) ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: inMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Audio.setInput(inTile.modelData)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                UiText {
                    text: "Microphone"
                    color: root.sumiHi
                    font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.5
                }
                UiText {
                    text: volPanel.micMuted ? "Muted" : "Active"
                    color: volPanel.micMuted
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.5)
                        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                    font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.5
                    horizontalAlignment: Text.AlignRight
                }
            }

            Item {
                width: parent.width
                height: visible ? 8 : 0
                visible: volPanel.micMeterAvailable

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4
                    radius: 2
                    color: root.fillIdle
                    border.color: root.sep
                    border.width: 1

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * volPanel.micLevel
                        radius: parent.radius
                        color: volPanel.micMuted
                            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                            : root.seal
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                color: volPanel.micMuted ? root.fillActive
                    : micMuteMa.containsMouse ? root.fillHover
                    : root.fillIdle
                border.color: (micMuteMa.containsMouse || volPanel.micMuted) ? root.seal : root.sep
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: volPanel.micMuted ? "Unmute mic" : "Mute mic"
                    color: (micMuteMa.containsMouse || volPanel.micMuted) ? root.seal : root.sumi
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: micMuteMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Audio.source && Audio.source.audio) Audio.source.audio.muted = !Audio.source.audio.muted
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── open audio ──
            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                color: audioBtnMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open audio"
                    color: root.paper
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: audioBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.volVisible = false
                        audioRunner.running = false
                        audioRunner.running = true
                    }
                }
            }
        }
    }

    Process { id: audioRunner; command: ["bash", "-c", "command -v pavucontrol >/dev/null 2>&1 && exec pavucontrol || notify-send -a Ryoku 'Audio settings' 'pavucontrol is not installed'"] }
}
