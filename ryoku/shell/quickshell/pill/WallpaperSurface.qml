pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// washi wallpaper surface: a horizontal strip of the wallpapers in
// ~/Pictures/Wallpapers; clicking one rethemes the desktop through Ryoku's own
// backend (`ryoku-shell wallpaper set`), the same path Settings uses -- no
// switcher of its own, just Ryoku's.
PillSurface {
    id: root

    mTop: 14
    mLeft: 16
    mRight: 16
    mBottom: 14
    implicitWidth: 660 * s
    implicitHeight: 172 * s

    ameForm: "off"

    readonly property string wallDir: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    property var walls: []

    function refresh() { listProc.running = true; }
    onOpenChanged: if (open) refresh()
    Component.onCompleted: refresh()

    Process {
        id: listProc
        command: ["sh", "-c", "find '" + root.wallDir + "' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++)
                    if (lines[i].trim().length > 0)
                        out.push(lines[i].trim());
                root.walls = out;
            }
        }
    }

    Process { id: setProc }
    function setWall(p) {
        setProc.command = ["ryoku-shell", "wallpaper", "set", p];
        setProc.running = true;
    }

    ListView {
        id: strip
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: 10 * root.s
        clip: true
        model: root.walls

        Text {
            anchors.centerIn: parent
            visible: root.walls.length === 0
            text: "No wallpapers in ~/Pictures/Wallpapers"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        delegate: Item {
            id: tile
            required property string modelData
            width: 210 * root.s
            height: strip.height

            Rectangle {
                anchors.fill: parent
                radius: Motion.rTile * root.s
                color: Theme.tileBg
                border.width: 1
                border.color: ma.containsMouse ? Theme.verm : Theme.border
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file://" + tile.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 320
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.setWall(tile.modelData);
                        root.requestClose();
                    }
                }
            }
        }
    }
}
