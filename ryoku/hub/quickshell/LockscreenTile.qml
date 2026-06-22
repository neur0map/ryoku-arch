pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// One lock-skin tile in the catalogue, in the Extras/Themes style: a looping
// preview of the lockscreen as the hero (a local gif for the vendored skins, the
// upstream Assets gif for the rest), then a monospace ordinal with a state mark,
// the theme tag, the skin name, and a one-line summary, over a flat warm surface
// whose hairline warms to ember on hover. Clicking an installed skin selects it;
// clicking one that isn't installed downloads it first (the install size is shown
// up front). Previews load and animate only while the tile is near the viewport,
// so a long grid of remote gifs stays light. The live Preview chip is offered
// only for installed skins, since the lock needs the theme's files on disk.
Rectangle {
    id: tile

    property var skin: ({})
    property int ordinal: 0
    property bool active: false
    property bool installed: false
    property bool busy: false       // a set or install is in flight for this skin
    property bool installing: false // the in-flight op is a download
    property Flickable viewport: null
    signal applied()
    signal previewed()

    // Near-viewport test: map the tile into the Flickable's visible area and keep
    // a 600px margin so scrolling preloads just before a tile appears. Reading
    // contentY/height makes the binding re-evaluate as the list scrolls.
    readonly property bool onScreen: {
        if (!viewport)
            return true;
        viewport.contentY;
        viewport.height;
        var top = tile.mapToItem(viewport, 0, 0).y;
        return top < viewport.height + 600 && top + tile.height > -600;
    }

    readonly property string sizeText: {
        var kb = tile.skin.sizeKB || 0;
        if (kb <= 0)
            return "";
        return kb >= 1024 ? (Math.round(kb / 1024) + " MB") : (kb + " KB");
    }
    readonly property string badgeText: tile.busy ? (tile.installing ? "INSTALLING\u2026" : "APPLYING")
        : tile.active ? "ACTIVE"
        : tile.installed ? "INSTALLED"
        : (tile.sizeText !== "" ? "\u2193  " + tile.sizeText : "")
    readonly property bool badgeAccent: tile.busy || tile.active

    implicitHeight: body.implicitHeight + 34
    radius: 16
    color: hover.hovered ? Theme.surface : Theme.surfaceLo
    border.width: tile.active ? 2 : 1
    border.color: (tile.active || hover.hovered) ? Theme.ember : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.quick } }
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 0

        // --- preview hero ---
        Rectangle {
            id: media
            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: 8
            color: Theme.keyBot
            border.width: 1
            border.color: (tile.active || hover.hovered) ? Theme.ember : Theme.line
            clip: true
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            AnimatedImage {
                id: gif
                anchors.fill: parent
                anchors.margins: 1
                source: tile.onScreen ? (tile.skin.preview || "") : ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                playing: tile.onScreen
            }

            // placeholder while the gif loads, or when none resolved
            Icon {
                anchors.centerIn: parent
                visible: gif.status !== AnimatedImage.Ready
                name: "lock"
                size: 30
                tint: Theme.faint
            }

            // live preview chip: installed skins only (the lock needs the files)
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: pvRow.implicitWidth + 20
                height: 28
                radius: 14
                visible: tile.installed && !tile.busy
                color: Qt.rgba(0, 0, 0, 0.55)
                border.width: 1
                border.color: pvArea.containsMouse ? Theme.ember : Qt.rgba(1, 1, 1, 0.18)
                opacity: (hover.hovered || pvArea.containsMouse) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                Row {
                    id: pvRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "play"; size: 11; weight: 2; tint: Theme.bright }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Preview"
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: pvArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.previewed()
                }
            }

            // download / apply overlay
            Rectangle {
                anchors.fill: parent
                visible: tile.busy
                color: Qt.rgba(0, 0, 0, 0.6)
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Spinner { anchors.horizontalCenter: parent.horizontalCenter; size: 24 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.installing ? ("Downloading\u2026 " + tile.sizeText) : "Applying\u2026"
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Item { width: 1; height: 16 }

        // --- ordinal + state mark ---
        Item {
            width: parent.width
            height: number.implicitHeight

            Text {
                id: number
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: (tile.ordinal < 10 ? "0" : "") + tile.ordinal
                color: (tile.active || hover.hovered) ? Theme.ember : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 26
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                visible: tile.badgeText !== ""

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 3.5
                    visible: tile.busy || tile.active || tile.installed
                    color: tile.badgeAccent ? Theme.ember : Theme.faint
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tile.badgeText
                    color: tile.badgeAccent ? Theme.ember : (tile.installed ? Theme.subtle : Theme.faint)
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.5
                }
            }
        }

        Text {
            width: parent.width
            topPadding: 14
            visible: (tile.skin.tags || []).length > 0
            text: (tile.skin.tags || []).join("  \u00b7  ")
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
            font.capitalization: Font.AllUppercase
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: (tile.skin.tags || []).length > 0 ? 8 : 14
            text: tile.skin.name || ""
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 18
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 4
            visible: (tile.skin.summary || "") !== ""
            text: tile.skin.summary || ""
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            topPadding: 10
            visible: (tile.skin.blurb || "") !== ""
            text: tile.skin.blurb || ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.32
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18
        anchors.bottomMargin: 16
        name: "chevron"
        size: 15
        weight: 2
        rotation: -90
        tint: Theme.ember
        opacity: (hover.hovered && !tile.active && !tile.busy) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (!tile.active && !tile.busy) tile.applied() }
}
