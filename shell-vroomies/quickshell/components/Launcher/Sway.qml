import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.LocalStorage
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: launcher
    visible: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true }
    margins {
        top: 76
        bottom: 8
        left: 8
    }
    implicitWidth: 280

    property string query: ""
    property var usageData: ({})

    property color clrBackground:  "#151218"
    property color clrSurface:     "#211e24"
    property color clrPrimary:     "#d5bbfc"
    property color clrOnSurface:   "#e7e0e8"
    property color clrOnSurfaceVar:"#cbc4cf"
    property color clrOutline:     "#49454e"
    property color clrSurfaceHigh: "#2c292f"

    Process {
        id: colorProc
        command: ["bash", "-c", "cat " + (Quickshell.env("RYOKU_VROOMIES_SHELL_DIR") || (Quickshell.env("HOME") + "/.config/quickshell/ryoku-vroomies-shell")) + "/Colors/colors.json"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var c = JSON.parse(data)
                    launcher.clrBackground   = c.background             || launcher.clrBackground
                    launcher.clrSurface      = c.surface_container      || launcher.clrSurface
                    launcher.clrPrimary      = c.primary                || launcher.clrPrimary
                    launcher.clrOnSurface    = c.on_surface             || launcher.clrOnSurface
                    launcher.clrOnSurfaceVar = c.on_surface_variant     || launcher.clrOnSurfaceVar
                    launcher.clrOutline      = c.outline_variant        || launcher.clrOutline
                    launcher.clrSurfaceHigh  = c.surface_container_high || launcher.clrSurfaceHigh
                } catch(e) {}
            }
        }
    }

    function getDb() {
        return LocalStorage.openDatabaseSync("launcher", "1.0", "Launcher Usage", 1000000)
    }

    function loadUsage() {
        try {
            var db = getDb()
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS usage (appId TEXT PRIMARY KEY, count INTEGER)")
                var result = tx.executeSql("SELECT appId, count FROM usage")
                var data = {}
                for (var i = 0; i < result.rows.length; i++)
                    data[result.rows.item(i).appId] = result.rows.item(i).count
                launcher.usageData = data
            })
        } catch(e) {}
    }

    function saveUsage(appId) {
        try {
            var db = getDb()
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS usage (appId TEXT PRIMARY KEY, count INTEGER)")
                tx.executeSql("INSERT OR REPLACE INTO usage (appId, count) VALUES (?, ?)",
                    [appId, (launcher.usageData[appId] || 0) + 1])
            })
        } catch(e) {}
    }

    function launchSelected() {
        if (list.currentItem && list.currentItem.modelData) {
            var app = list.currentItem.modelData
            var id  = app.id || app.name || ""
            var data = Object.assign({}, launcher.usageData)
            data[id] = (data[id] || 0) + 1
            launcher.usageData = data
            saveUsage(id)
            app.execute()
            Qt.quit()
        }
    }

    Component.onCompleted: {
        loadUsage()
        colorProc.running = true
        slideIn.start()
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }
    }

    Rectangle {
        id: mainPanel
        anchors.fill: parent
        radius: 14
        color: launcher.clrBackground
        opacity: 0

        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1; radius: 1
            color: launcher.clrPrimary
            opacity: 0.2
        }

        Behavior on color { ColorAnimation { duration: 300 } }

        transform: Translate { id: slideOffset; x: -mainPanel.width }

        NumberAnimation {
            id: slideIn
            target: slideOffset
            property: "x"
            from: -mainPanel.width
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
            onStarted: mainPanel.opacity = 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󱓞  Apps"
                    color: launcher.clrPrimary
                    font.pixelSize: 15; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Esc"
                    color: launcher.clrOutline
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 10
                color: launcher.clrSurface
                border.width: 1
                border.color: input.activeFocus ? launcher.clrPrimary : launcher.clrOutline
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on color        { ColorAnimation { duration: 300 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "󰍉"
                        color: launcher.clrPrimary
                        font.pixelSize: 17
                        font.family: "JetBrainsMono Nerd Font"
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    TextField {
                        id: input
                        Layout.fillWidth: true
                        placeholderText: "Search..."
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                        color: launcher.clrOnSurface
                        focus: true
                        leftPadding: 0; rightPadding: 0
                        topPadding: 0; bottomPadding: 0
                        placeholderTextColor: launcher.clrOnSurfaceVar
                        background: Rectangle { color: "transparent" }

                        onTextChanged: {
                            launcher.query = text
                            list.currentIndex = filtered.values.length > 0 ? 0 : -1
                        }

                        Keys.onEscapePressed: Qt.quit()
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && ctrl)) {
                                event.accepted = true
                                if (list.currentIndex > 0) list.currentIndex--
                            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && ctrl)) {
                                event.accepted = true
                                if (list.currentIndex < list.count - 1) list.currentIndex++
                            } else if ([Qt.Key_Return, Qt.Key_Enter].includes(event.key)) {
                                event.accepted = true
                                launcher.launchSelected()
                            } else if (event.key === Qt.Key_C && ctrl) {
                                event.accepted = true
                                Qt.quit()
                            }
                        }
                    }

                    Text {
                        visible: input.text.length > 0
                        text: "✕"
                        color: launcher.clrOnSurfaceVar
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        Behavior on color { ColorAnimation { duration: 300 } }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: input.text = ""
                        }
                    }
                }
            }

            Text {
                visible: input.text.length > 0
                text: filtered.values.length + " result" + (filtered.values.length !== 1 ? "s" : "")
                color: launcher.clrOnSurfaceVar
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                Layout.leftMargin: 2
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            ScriptModel {
                id: filtered
                values: {
                    var usage = launcher.usageData
                    const all = [...DesktopEntries.applications.values]
                        .sort((a, b) => {
                            var idA = a.id || a.name || ""
                            var idB = b.id || b.name || ""
                            var cntA = usage[idA] || 0
                            var cntB = usage[idB] || 0
                            if (cntB !== cntA) return cntB - cntA
                            return (a.name || "").localeCompare(b.name || "")
                        })
                    const q = launcher.query.trim().toLowerCase()
                    if (q === "") return all
                    return all.filter(d => d.name && d.name.toLowerCase().includes(q))
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: filtered.values
                currentIndex: filtered.values.length > 0 ? 0 : -1
                keyNavigationWraps: true
                spacing: 3
                highlightMoveDuration: 0

                highlight: Rectangle {
                    radius: 8
                    color: launcher.clrSurfaceHigh
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 50

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: list.currentIndex = entry.index
                        onDoubleClicked: launcher.launchSelected()

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: parent.containsMouse && list.currentIndex !== entry.index
                                ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Rectangle {
                            width: 34; height: 34
                            radius: 8
                            color: launcher.clrSurface
                            Behavior on color { ColorAnimation { duration: 300 } }
                            IconImage {
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(entry.modelData.icon, true)
                                width: 22; height: 22
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: entry.modelData.name || ""
                                color: list.currentIndex === entry.index
                                    ? launcher.clrPrimary : launcher.clrOnSurface
                                font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: list.currentIndex === entry.index
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                text: entry.modelData.comment || entry.modelData.genericName || ""
                                color: launcher.clrOnSurfaceVar
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text.length > 0
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        Text {
                            visible: list.currentIndex === entry.index
                            text: "↵"
                            color: launcher.clrPrimary
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }
                }

                Item {
                    anchors.centerIn: parent
                    visible: filtered.values.length === 0 && input.text.length > 0
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰍉"
                            color: launcher.clrOutline
                            font.pixelSize: 32
                            font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No results"
                            color: launcher.clrOnSurfaceVar
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }
                }
            }
        }
    }
}
