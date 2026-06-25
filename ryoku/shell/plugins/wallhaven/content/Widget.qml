pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

/**
 * Wallhaven, as one adaptive view. The host sets `density` (glyph | compact |
 * full), `s`, `widthBudget`, `active`, and `pluginApi`; the content lays out for
 * that density at an explicit content width and reports its intrinsic size back,
 * so the same plugin reads as a frame popout, a desktop tile, or a topbar glyph
 * without collapsing. Built in the deck dialect (PluginKit Theme/Motion +
 * GlyphIcon/MicroLabel/Card), so it looks native in every host.
 *
 * Sizing model: `contentW` is the one resolved width. Every child binds to it
 * directly (never `parent.width` through nested layouts, which left width-derived
 * heights at zero). The root's implicit size is read from the active body.
 */
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active
    property string density: "full"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    // The one content width. Fixed per density; `full` may stretch to the host's
    // budget. Everything sizes from this, so nothing depends on a parent width
    // that has not resolved yet.
    readonly property real contentW: density === "glyph" ? 26 * s
        : density === "compact" ? 360 * s
        : Math.max(560 * s, widthBudget)

    implicitWidth: contentW
    implicitHeight: density === "glyph" ? 26 * s
        : density === "compact" ? compactBody.implicitHeight
        : fullBody.implicitHeight

    function _autoSearch() {
        if (active && service && (service.results?.length ?? 0) === 0 && !service.searching)
            service.searchLatest("");
    }
    onActiveChanged: {
        if (active && service)
            service.resultsExpanded = (density === "full");
        _autoSearch();
    }
    onServiceChanged: _autoSearch()
    Component.onCompleted: Qt.callLater(_autoSearch)

    // ---- glyph: a single wallpaper mark with a running-download dot -----------
    GlyphIcon {
        visible: root.density === "glyph"
        anchors.fill: parent
        name: "image"
        color: root.service?.downloading ? Theme.brand : Theme.iconDim
        stroke: 1.6
        Rectangle {
            visible: root.service?.downloading ?? false
            width: 5 * root.s; height: width; radius: width / 2
            color: Theme.brand
            anchors.right: parent.right
            anchors.top: parent.top
        }
    }

    // ---- compact: header + search + chips + a 3-up thumbnail row -------------
    Column {
        id: compactBody
        visible: root.density === "compact"
        width: root.contentW
        spacing: 12 * root.s

        WhHeader { width: root.contentW; s: root.s; service: root.service }
        WhSearch { width: root.contentW; s: root.s; service: root.service }
        WhChips { width: root.contentW; s: root.s; service: root.service }
        WhGrid {
            width: root.contentW; s: root.s; service: root.service
            columns: 3; maxRows: 2
            onApply: (item) => root.service?.setAsWallpaper(item)
        }
    }

    // ---- full: header + search + chips + result grid -------------------------
    Column {
        id: fullBody
        visible: root.density === "full"
        width: root.contentW
        spacing: 14 * root.s

        WhHeader { width: root.contentW; s: root.s; service: root.service }
        WhSearch { width: root.contentW; s: root.s; service: root.service }
        WhChips { width: root.contentW; s: root.s; service: root.service }
        WhGrid {
            width: root.contentW; s: root.s; service: root.service
            columns: 3; maxRows: 4
            onApply: (item) => root.service?.setAsWallpaper(item)
            onWeb: (item) => root.service?.openInWeb(item)
        }
    }

    // ---- components (deck idiom) ---------------------------------------------

    component WhHeader: Item {
        id: hdr
        property real s: 1
        property var service
        implicitHeight: 22 * s
        MicroLabel {
            label: qsTr("Wallhaven"); s: hdr.s
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component WhSearch: Rectangle {
        id: sb
        property real s: 1
        property var service
        implicitHeight: 44 * s
        radius: Motion.rSmall * s
        color: Theme.tileBg
        border.width: 1
        border.color: inner.input.activeFocus ? Theme.brand : Theme.border
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        SearchField {
            id: inner
            anchors.fill: parent
            anchors.leftMargin: 12 * sb.s
            anchors.rightMargin: 12 * sb.s
            s: sb.s
            kanji: "力"
            placeholder: qsTr("Search Wallhaven")
            text: sb.service?.query ?? ""
            onAccepted: sb.service?.searchLatest(inner.text)
        }
    }

    component WhChips: Item {
        id: chips
        property real s: 1
        property var service
        implicitHeight: 30 * s
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * chips.s
            WhChip {
                s: chips.s; text: qsTr("Latest")
                on: (chips.service?.topRange ?? "") === "" && (chips.service?.query ?? "") === ""
                onClicked: chips.service?.searchLatest("")
            }
            WhChip { s: chips.s; text: qsTr("Top week"); on: chips.service?.topRange === "1w"; onClicked: chips.service?.searchTop("1w") }
            WhChip { s: chips.s; text: qsTr("Top month"); on: chips.service?.topRange === "1M"; onClicked: chips.service?.searchTop("1M") }
        }
        // Pager in the trailing space: page number + previous/next.
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * chips.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${chips.service?.page ?? 1}`
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11 * chips.s
            }
            WhIconBtn {
                s: chips.s; glyph: "prev"
                onClicked: chips.service?.previousPage()
            }
            WhIconBtn {
                s: chips.s; glyph: "next"
                onClicked: chips.service?.nextPage()
            }
        }
    }

    component WhGrid: Item {
        id: g
        property real s: 1
        property var service
        property int columns: 3
        property int maxRows: 4
        signal apply(var item)
        signal web(var item)

        readonly property var items: {
            var r = g.service?.results ?? [];
            var max = g.columns * g.maxRows;
            return r.length > max ? r.slice(0, max) : r;
        }
        readonly property real gap: 8 * s
        readonly property real cellW: (width - gap * (columns - 1)) / columns
        readonly property real cellH: Math.round(cellW * 0.62)
        readonly property int rows: Math.ceil(items.length / columns)
        readonly property bool empty: items.length === 0

        implicitHeight: empty ? 120 * s
            : rows * cellH + (rows - 1) * gap

        // Result grid.
        Grid {
            anchors.fill: parent
            visible: !g.empty
            columns: g.columns
            rowSpacing: g.gap
            columnSpacing: g.gap
            Repeater {
                model: g.items
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    width: g.cellW
                    height: g.cellH
                    radius: Motion.rSmall * g.s
                    color: Theme.tileBg
                    border.width: 1
                    border.color: cma.containsMouse ? Theme.brand : Theme.border
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    Image {
                        anchors.fill: parent
                        anchors.margins: 1
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(Math.ceil(cell.width * 2), Math.ceil(cell.height * 2))
                        source: cell.modelData && cell.modelData.thumb ? cell.modelData.thumb : ""
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: cma.containsMouse
                        color: Qt.rgba(0, 0, 0, 0.35)
                    }
                    GlyphIcon {
                        visible: cma.containsMouse
                        anchors.centerIn: parent
                        width: 18 * g.s; height: width
                        name: "image"
                        color: Theme.cream
                    }
                    MouseArea {
                        id: cma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (e) => { if (e.button === Qt.RightButton) g.web(cell.modelData); else g.apply(cell.modelData); }
                    }
                }
            }
        }

        // Empty / busy / error state.
        Rectangle {
            anchors.fill: parent
            visible: g.empty
            radius: 16 * g.s
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            Column {
                anchors.centerIn: parent
                spacing: 8 * g.s
                GlyphIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 22 * g.s; height: width
                    name: g.service?.searching ? "sun" : "image"
                    color: Theme.faint
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: g.service?.searching ? qsTr("Searching")
                        : (g.service?.error || qsTr("No wallpapers"))
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12 * g.s
                }
            }
        }
    }

    component WhChip: Rectangle {
        id: chip
        property real s: 1
        property string text: ""
        property bool on: false
        signal clicked()
        implicitWidth: chipText.implicitWidth + 20 * s
        implicitHeight: 30 * s
        radius: height / 2
        color: on ? Theme.brand : Theme.tileBg
        border.width: 1
        border.color: on ? Theme.brand : Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.text
            color: chip.on ? "#1a1b26" : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12 * chip.s
            font.weight: Font.DemiBold
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    component WhIconBtn: Rectangle {
        id: ib
        property real s: 1
        property string glyph: ""
        signal clicked()
        implicitWidth: 30 * s; implicitHeight: 30 * s
        radius: Motion.rSmall * s
        color: ibMa.containsMouse ? Theme.frameBg : "transparent"
        border.width: 1
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        GlyphIcon {
            anchors.centerIn: parent
            width: 14 * ib.s; height: width
            name: ib.glyph
            color: ibMa.containsMouse ? Theme.cream : Theme.iconDim
        }
        MouseArea { id: ibMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    }
}
