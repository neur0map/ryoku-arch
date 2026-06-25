pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * Plugins section: every installed shell plugin, each a card the user enables and
 * places. Placement is the contract the shell reads: enable, then pick a host
 * (frame popout / desktop widget / topbar glyph), and the running shell retunes
 * live because the plugin runtime watches plugins.json. Data comes from
 * discover.sh --all (scan plugin dirs + merge plugins.json); writes go through
 * ryoku-plugins-place, the same helper the desktop drag uses.
 */
Flickable {
    id: page

    property var plugins: []
    contentHeight: col.implicitHeight + 40
    clip: true

    readonly property string shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string script: (shellDir && shellDir.length > 0)
        ? shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/discover.sh"

    function refresh() { listProc.running = false; listProc.running = true; }
    function place(id, field, a, b, c, d) {
        var args = ["ryoku-plugins-place", id, field];
        for (var v of [a, b, c, d]) if (v !== undefined) args.push("" + v);
        placeProc.command = args;
        placeProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: listProc
        command: ["bash", page.script, "--all"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.plugins = JSON.parse(text || "[]"); }
                catch (e) { page.plugins = []; }
            }
        }
    }
    Process { id: placeProc; onExited: page.refresh() }

    Column {
        id: col
        width: page.width - 30
        spacing: 16

        // Empty state when nothing is installed yet.
        Rectangle {
            width: parent.width
            visible: page.plugins.length === 0
            implicitHeight: 120
            radius: 16
            color: "transparent"
            border.width: 1
            border.color: Theme.line
            Text {
                anchors.centerIn: parent
                width: parent.width - 60
                horizontalAlignment: Text.AlignHCenter
                text: "No plugins installed yet. Browse the catalogue in Extras, or drop a plugin into ~/.local/share/ryoku/plugins."
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }

        Repeater {
            model: page.plugins
            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var man: modelData.manifest
                readonly property var place: modelData.placement
                readonly property bool on: place && place.enabled === true
                readonly property string host: (place && place.host) ? place.host
                    : ((man.defaults && man.defaults.host) ? man.defaults.host : "framePopout")

                width: col.width
                implicitHeight: body.implicitHeight + 36
                radius: 16
                color: "transparent"
                border.width: 1
                border.color: cardHov.hovered ? Theme.ember : Theme.line
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                HoverHandler { id: cardHov }

                Column {
                    id: body
                    x: 20; y: 18
                    width: parent.width - 40
                    spacing: 14

                    // Title row: name + official tag + enable toggle.
                    Item {
                        width: parent.width
                        height: 30
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: card.man.name || card.modelData.id
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: (card.man.description || "") + (card.man.official ? "  ·  OFFICIAL" : "")
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }
                        // Enable toggle (reuses the hub switch idiom inline).
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46; height: 26; radius: 13
                            color: card.on ? Theme.ember : Theme.surfaceLo
                            border.width: 1
                            border.color: card.on ? Theme.ember : Theme.line
                            Behavior on color { ColorAnimation { duration: Theme.quick } }
                            Rectangle {
                                width: 20; height: 20; radius: 10; y: 3
                                x: card.on ? parent.width - width - 3 : 3
                                color: card.on ? Theme.onAccent : Theme.cream
                                Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
                            }
                            TapHandler { onTapped: page.place(card.modelData.id, "enabled", card.on ? "false" : "true") }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // Host selector (only the hosts the manifest allows).
                    Item {
                        width: parent.width
                        height: 30
                        visible: card.on
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Show as"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Repeater {
                                model: (card.man.hosts || ["framePopout"]).filter(h => h === "framePopout" || h === "desktopWidget")
                                delegate: Rectangle {
                                    id: hostCell
                                    required property var modelData
                                    readonly property bool active: card.host === hostCell.modelData
                                    readonly property string nice: hostCell.modelData === "framePopout" ? "Frame popout"
                                        : hostCell.modelData === "desktopWidget" ? "Desktop widget"
                                        : hostCell.modelData
                                    width: hcText.implicitWidth + 22; height: 28; radius: 8
                                    color: active ? Theme.ember : Theme.surfaceLo
                                    border.width: 1
                                    border.color: active ? Theme.ember : Theme.line
                                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                                    Text {
                                        id: hcText
                                        anchors.centerIn: parent
                                        text: hostCell.nice
                                        color: hostCell.active ? Theme.onAccent : Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                        font.weight: hostCell.active ? Font.DemiBold : Font.Medium
                                    }
                                    TapHandler { onTapped: page.place(card.modelData.id, "host", hostCell.modelData) }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                    }

                    // Interactive placement editor (preview + drag-box), shown for
                    // the active host when enabled.
                    PluginPlacementEditor {
                        width: parent.width
                        visible: card.on && (card.host === "framePopout" || card.host === "desktopWidget")
                        pluginId: card.modelData.id
                        host: card.host
                        place: card.place
                        onChanged: (field, args) => page.place(card.modelData.id, field, args[0], args[1], args[2], args[3])
                    }
                }
            }
        }
    }
}
