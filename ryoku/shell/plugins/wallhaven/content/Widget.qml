pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

/**
 * Wallhaven, as one adaptive view. The host sets `density` (glyph | compact |
 * full), `s`, `widthBudget`, `active`, and `pluginApi`; the content lays out for
 * that density and reflows within the width the host gives it, so the same plugin
 * reads as a frame popout, a desktop tile, or a topbar glyph without misforming.
 * Built in the deck dialect (PluginKit Theme/Motion + GlyphIcon/MicroLabel/
 * SearchField/Card), so it looks native in every host.
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

    // Intrinsic size per density; the host reads these for its open envelope.
    implicitWidth: density === "glyph" ? 26 * s
                 : density === "compact" ? 320 * s
                 : Math.max(560 * s, widthBudget)
    implicitHeight: density === "glyph" ? 26 * s
                  : compactBody.visible ? compactBody.implicitHeight
                  : fullBody.implicitHeight

    onActiveChanged: {
        if (active && service) {
            service.resultsExpanded = (density === "full");
            if ((service.results?.length ?? 0) === 0 && !service.searching)
                service.searchLatest("");
        }
    }

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

    // ---- compact: search + a single thumbnail row + top chips ----------------
    ColumnLayout {
        id: compactBody
        visible: root.density === "compact"
        width: parent.width
        spacing: 12 * root.s

        WhHeader { s: root.s; service: root.service }

        SearchField {
            id: compactSearch
            Layout.fillWidth: true
            s: root.s
            text: root.service?.query ?? ""
            onAccepted: root.service?.searchLatest(text)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * root.s
            WhChip { s: root.s; text: qsTr("Week"); on: root.service?.topRange === "1w"; onClicked: root.service?.searchTop("1w") }
            WhChip { s: root.s; text: qsTr("Month"); on: root.service?.topRange === "1M"; onClicked: root.service?.searchTop("1M") }
            Item { Layout.fillWidth: true }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6 * root.s
            Repeater {
                model: (root.service?.results ?? []).slice(0, 3)
                delegate: WhThumb {
                    required property var modelData
                    s: root.s
                    w: (compactBody.width - 12 * root.s) / 3
                    data: modelData
                    onApply: root.service?.setAsWallpaper(modelData)
                }
            }
        }
    }

    // ---- full: masthead + search + chips + result grid + pager ---------------
    Column {
        id: fullBody
        visible: root.density === "full"
        width: parent.width
        spacing: 14 * root.s

        WhHeader {
            width: parent.width
            s: root.s; service: root.service
            pager: true
            onPrev: root.service?.previousPage()
            onNext: root.service?.nextPage()
        }

        SearchField {
            id: fullSearch
            width: parent.width
            s: root.s
            text: root.service?.query ?? ""
            onAccepted: root.service?.searchLatest(text)
        }

        Row {
            width: parent.width
            spacing: 8 * root.s
            WhChip { s: root.s; text: qsTr("Top week"); on: root.service?.topRange === "1w"; onClicked: root.service?.searchTop("1w") }
            WhChip { s: root.s; text: qsTr("Top month"); on: root.service?.topRange === "1M"; onClicked: root.service?.searchTop("1M") }
        }

        Grid {
            id: grid
            width: parent.width
            visible: (root.service?.results.length ?? 0) > 0
            columns: 3
            rowSpacing: 8 * root.s
            columnSpacing: 8 * root.s
            readonly property real cellW: (width - columnSpacing * (columns - 1)) / columns
            Repeater {
                model: root.service?.results ?? []
                delegate: WhThumb {
                    required property var modelData
                    s: root.s
                    w: grid.cellW
                    big: true
                    data: modelData
                    onApply: root.service?.setAsWallpaper(modelData)
                    onWeb: root.service?.openInWeb(modelData)
                }
            }
        }

        // Empty / busy / error state
        Rectangle {
            width: parent.width
            visible: (root.service?.results.length ?? 0) === 0
            implicitHeight: 120 * root.s
            radius: 16 * root.s
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            Column {
                anchors.centerIn: parent
                spacing: 8 * root.s
                GlyphIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 22 * root.s; height: width
                    name: root.service?.searching ? "sun" : "image"
                    color: Theme.faint
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.service?.searching ? qsTr("Searching") : (root.service?.error || qsTr("Search Wallhaven"))
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }
            }
        }
    }

    // ---- local components (deck idiom) ---------------------------------------
    component WhHeader: Item {
        id: hdr
        property real s: 1
        property var service
        property bool pager: false
        signal prev()
        signal next()
        implicitHeight: 30 * s
        MicroLabel {
            label: qsTr("Wallhaven"); s: hdr.s
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * hdr.s
            visible: hdr.pager
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${hdr.service?.page ?? 1}`
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11 * hdr.s
            }
            WhIconBtn { s: hdr.s; glyph: "prev"; onClicked: hdr.prev() }
            WhIconBtn { s: hdr.s; glyph: "next"; onClicked: hdr.next() }
        }
    }

    component WhChip: Rectangle {
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
            text: parent.text
            color: parent.on ? "#1a1b26" : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12 * parent.s
            font.weight: Font.DemiBold
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component WhIconBtn: Rectangle {
        property real s: 1
        property string glyph: ""
        property bool flip: false
        signal clicked()
        implicitWidth: 30 * s; implicitHeight: 30 * s
        radius: Motion.rSmall * s
        color: ma.containsMouse ? Theme.frameBg : "transparent"
        border.width: 1
        border.color: Theme.border
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        GlyphIcon {
            anchors.centerIn: parent
            width: 14 * parent.s; height: width
            name: parent.glyph
            color: ma.containsMouse ? Theme.cream : Theme.iconDim
            rotation: parent.flip ? 180 : 0
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component WhThumb: Rectangle {
        id: thumb
        property real s: 1
        property real w: 100
        property bool big: false
        property var data: null
        signal apply()
        signal web()
        implicitWidth: w
        implicitHeight: Math.round(w * 0.58)
        radius: Motion.rSmall * s
        color: Theme.tileBg
        border.width: 1
        border.color: tma.containsMouse ? Theme.brand : Theme.border
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        // ClippingRectangle is the scene-graph clipper the shell uses for images
        // in the blob overlay (see Media.qml); a plain Rectangle{clip:true} around
        // an Image does not composite the texture in this surface.
        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: thumb.radius
            color: "transparent"
            Image {
                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.ceil(thumb.width * 2), Math.ceil(thumb.height * 2))
                source: thumb.data && thumb.data.thumb ? thumb.data.thumb : ""
            }
        }
        Rectangle {
            visible: thumb.big && tma.containsMouse
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
        }
        Row {
            visible: thumb.big && tma.containsMouse
            anchors.centerIn: parent
            spacing: 8 * thumb.s
            WhIconBtn { s: thumb.s; glyph: "image"; onClicked: thumb.apply() }
        }
        MouseArea {
            id: tma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: thumb.apply()
        }
    }
}
