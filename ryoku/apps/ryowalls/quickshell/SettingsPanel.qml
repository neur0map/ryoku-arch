import QtQuick
import QtQuick.Controls
import Quickshell
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// In-app settings: the Wallhaven API key, the NSFW gate (only with a key), and
// where downloads land. An overlay in the standard grammar: paperLift fill,
// lineStrong border, radius 2, scrim at black 55%.
Item {
    id: sp
    property bool open: false
    signal closed()

    // re-probe on open so a just-installed upscaler flips Install to a live toggle.
    onOpenChanged: if (open) Wallhaven.refreshCaps()

    visible: opacity > 0
    opacity: open ? 1 : 0
    // claim keyboard focus while open so its fields (API key, add-library) can
    // take input; the app root holds focus otherwise and its key map eats typing.
    focus: open
    Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        // MouseArea, not TapHandler: a click on a field is consumed by the card
        // below instead of falling through here and closing the panel mid-type.
        MouseArea { anchors.fill: parent; onClicked: sp.closed() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 460
        height: col.implicitHeight + 2 * Tokens.s5
        radius: Tokens.radius
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineStrong
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.s5
            spacing: Tokens.s5

            Item {
                width: parent.width
                height: 26
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SETTINGS"
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackMark
                }
                IconBtn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "✕"
                    onAct: sp.closed()
                }
            }

            Column {
                width: parent.width
                spacing: Tokens.s2
                Text { text: "Wallhaven API key"; color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: 13; font.weight: Font.Medium }
                Field {
                    width: parent.width
                    tabular: true
                    placeholder: "paste your key"
                    text: Wallhaven.settings.apiKey
                    onEdited: (v) => Wallhaven.settings.apiKey = v
                    onCommitted: Wallhaven.saveSettings()
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Optional, from wallhaven.cc/settings/account. Raises rate limits and unlocks NSFW."
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 12
                }
            }

            Item {
                width: parent.width
                height: 24
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Show NSFW"; color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: 13; font.weight: Font.Medium }
                Sw {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: Wallhaven.apiKey.length > 0
                    opacity: Wallhaven.apiKey.length > 0 ? 1 : 0.3
                    on: Wallhaven.settings.nsfw
                    onToggled: (v) => {
                        Wallhaven.settings.nsfw = v;
                        Wallhaven.saveSettings();
                        if (!Wallhaven.searching) Wallhaven.searchTop(Wallhaven.topRange);
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Tokens.line }

            // Wallpaper libraries: add / remove the GitHub repos the SOURCE drawer
            // browses. This lives here (not in the drawer) because a modal text
            // field reliably takes focus in this panel.
            Column {
                width: parent.width
                spacing: Tokens.s2
                Text { text: "Wallpaper libraries"; color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: 13; font.weight: Font.Medium }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Add any GitHub repo of wallpapers, then pick it from the SOURCE drawer. Accepts owner/repo, owner/repo@branch, or a github.com URL."
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 12
                }
                Field {
                    id: addLib
                    width: parent.width
                    tabular: true
                    placeholder: "owner/repo@branch"
                    onCommitted: (v) => { if (v.trim().length > 0) { Wallhaven.addLibrary(v); addLib.clear(); } }
                }
                Flickable {
                    width: parent.width
                    height: Math.min(contentHeight, 132)
                    contentHeight: libCol.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    visible: Wallhaven.libraries.length > 0
                    ScrollBar.vertical: ScrollRail {}
                    Column {
                        id: libCol
                        width: parent.width
                        spacing: Tokens.s1
                        Repeater {
                            model: Wallhaven.libraries
                            delegate: Rectangle {
                                width: libCol.width
                                height: 36
                                radius: Tokens.radius
                                color: lh.hovered ? Tokens.tint5 : "transparent"
                                border.width: Tokens.border
                                border.color: Tokens.line
                                Column {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Tokens.s2
                                    anchors.right: rmB.left
                                    anchors.rightMargin: Tokens.s2
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0
                                    Text { width: parent.width; text: modelData.name || modelData.repo; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: 12; elide: Text.ElideRight }
                                    Text { width: parent.width; text: modelData.repo + (modelData.branch ? "@" + modelData.branch : ""); color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: 9; elide: Text.ElideRight }
                                }
                                Btn {
                                    id: rmB
                                    anchors.right: parent.right
                                    anchors.rightMargin: Tokens.s2
                                    anchors.verticalCenter: parent.verticalCenter
                                    compact: true
                                    text: "REMOVE"
                                    onAct: Wallhaven.removeLibrary(modelData.repo)
                                }
                                HoverHandler { id: lh }
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    visible: Wallhaven.libraries.length === 0
                    text: "No libraries added yet."
                    color: Tokens.inkFaint
                    font.family: Tokens.ui
                    font.pixelSize: 12
                }
            }

            Rectangle { width: parent.width; height: 1; color: Tokens.line }

            Item {
                width: parent.width
                height: 34
                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "Downloads"; color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: 13; font.weight: Font.Medium }
                    Text { text: "~/Pictures/Wallpapers"; color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: 11 }
                }
                Btn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "OPEN"
                    onAct: Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/Pictures/Wallpapers"])
                }
            }
        }
    }
}
