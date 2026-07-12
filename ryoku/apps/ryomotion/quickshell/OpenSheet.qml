pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Singletons"

// In-app clip picker: a sheet over the editor listing recent recordings + videos
// (newest first), so opening a clip stays inside Ryoku Motion instead of a bare
// native dialog. A "Browse…" escape hatch covers anywhere else on disk.
Item {
    id: sheet
    anchors.fill: parent
    visible: open
    property bool open: false

    property var items: []

    function refresh() {
        scanProc.command = ["sh", "-c",
            "for d in \"$HOME/Videos/Ryoku Motion\" \"$HOME/Videos/Recordings\" \"$HOME/Videos\"; do " +
            "[ -d \"$d\" ] && find \"$d\" -maxdepth 2 -type f \\( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \\) -printf '%T@\\t%s\\t%p\\n'; " +
            "done 2>/dev/null | sort -rn -k1 | awk '!seen[$3]++' | head -40"];
        scanProc.running = true;
    }
    onOpenChanged: if (open) refresh()

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t");
                    if (parts.length < 3 || !parts[2]) continue;
                    out.push({ path: parts[2], name: parts[2].split("/").pop(), size: parseInt(parts[1]) });
                }
                sheet.items = out;
            }
        }
    }
    Process {
        id: browseProc
        command: ["sh", "-c", "zenity --file-selection --title='Open clip' --filename=\"$HOME/Videos/\" --file-filter='Video | *.mp4 *.mkv *.mov *.webm' 2>/dev/null || true"]
        stdout: StdioCollector { onStreamFinished: { var p = this.text.trim(); if (p) { Project.openClip(p); sheet.open = false; } } }
    }

    // scrim
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        MouseArea { anchors.fill: parent; onClicked: sheet.open = false }
    }

    Rectangle {
        width: Math.min(560, parent.width - 80)
        height: Math.min(520, parent.height - 100)
        anchors.centerIn: parent
        radius: Theme.radiusLg
        color: Theme.bgTop
        border.width: 1
        border.color: Theme.hair

        Item {
            id: head
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56
            Text {
                anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter
                text: "Open a clip"; color: Theme.bright; font.family: Theme.display; font.pixelSize: 19; font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                width: 30; height: 30; radius: 15
                color: xma.containsMouse ? Theme.field : "transparent"
                Icon { anchors.centerIn: parent; name: "close"; size: 16; tint: Theme.dim }
                MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sheet.open = false }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.hair }
        }

        ListView {
            id: list
            anchors.top: head.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: foot.top
            anchors.margins: 8
            model: sheet.items
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 46
                radius: Theme.radiusSm
                color: rma.containsMouse ? Theme.field : "transparent"
                Icon { id: fic; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: "film"; size: 18; tint: Theme.ember }
                Text {
                    anchors.left: fic.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.name; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; elide: Text.ElideMiddle
                }
                MouseArea {
                    id: rma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Project.openClip(parent.modelData.path); sheet.open = false; }
                }
            }
        }
        Text {
            anchors.centerIn: list
            visible: sheet.items.length === 0
            text: "No clips in ~/Videos yet.\nRecord one, or browse below."
            horizontalAlignment: Text.AlignHCenter
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 13
        }

        Item {
            id: foot
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 54
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.hair }
            TopBtn {
                anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                label: "Browse files…"
                onTapped: browseProc.running = true
            }
        }
    }
}
