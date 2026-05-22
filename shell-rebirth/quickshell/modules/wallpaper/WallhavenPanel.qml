import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import qs.services
import "../../colors" as ColorsModule
import qs.settings

Rectangle {
    anchors.fill: parent
    topLeftRadius: 12
    topRightRadius: 20
    color: ColorsModule.Colors.surface
    implicitHeight: 600

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: timer
        interval: 300
        running: true
        onTriggered: colLoader.active = true
    }

    Loader {
        id: colLoader
        active: false
        visible: active
        anchors.fill: parent
        sourceComponent: ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            NumberAnimation on opacity {
                from: 0; to: 1; duration: 100; running: col.visible
            }
            NumberAnimation on scale {
                from: 0.8; to: 1; duration: 100; running: col.visible
            }

            // ── Top bar ───────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                clip: true
                radius: 20
                color: ColorsModule.Colors.surface_container

                RowLayout {
                    id: onlineConfigCol
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6

                    property var sortOpts: [
                        ["Recent",   "date_added"], ["Hot",      "toplist"],
                        ["Views",    "views"],      ["Fav",      "favorites"],
                        ["Random",   "random"],     ["Relevant", "relevance"]
                    ]
                    property var rangeOpts: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]

                    function toggleCat(pos) {
                        let c = SettingsConfig.wallhavenCategories.split("")
                        c[pos] = c[pos] === "1" ? "0" : "1"
                        if (!c.includes("1")) return
                        SettingsConfig.wallhavenCategories = c.join("")
                    }
                    function togglePur(pos) {
                        let p = SettingsConfig.wallhavenPurity.split("")
                        p[pos] = p[pos] === "1" ? "0" : "1"
                        if (!p.includes("1")) return
                        SettingsConfig.wallhavenPurity = p.join("")
                    }

                    // Search bar
                    Rectangle {
                        Layout.preferredHeight: 35
                        Layout.preferredWidth: 220
                        radius: 20
                        color: ColorsModule.Colors.surface_container_highest

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            anchors.leftMargin: 10
                            spacing: 10

                            Text {
                                text: "⌕"
                                font.pixelSize: 18
                                color: ColorsModule.Colors.on_surface_variant
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                font.pixelSize: 14
                                font.weight: Font.ExtraBold
                                color: ColorsModule.Colors.inverse_surface
                                verticalAlignment: TextInput.AlignVCenter
                                Keys.onReturnPressed: Wallhaven.updateSearch(text)
                                Keys.onEscapePressed: {
                                    text = ""
                                    Wallhaven.updateSearch("")
                                }

                                Text {
                                    anchors.fill: parent
                                    text: "search wallhaven…"
                                    font: parent.font
                                    color: ColorsModule.Colors.on_surface_variant
                                    opacity: 0.4
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !parent.text && !parent.activeFocus
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Sorting group
                    Rectangle {
                        height: 28
                        radius: 14
                        color: ColorsModule.Colors.surface_container_highest
                        implicitWidth: _sortRow.implicitWidth + 6

                        RowLayout {
                            id: _sortRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: onlineConfigCol.sortOpts.length
                                delegate: Rectangle {
                                    required property int index
                                    readonly property string val: onlineConfigCol.sortOpts[index][1]
                                    readonly property string lbl: onlineConfigCol.sortOpts[index][0]
                                    property bool active: SettingsConfig.wallhavenSorting === val
                                    height: 24
                                    radius: 12
                                    implicitWidth: _sLbl.implicitWidth + 14
                                    color: active ? ColorsModule.Colors.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        id: _sLbl
                                        anchors.centerIn: parent
                                        text: parent.lbl
                                        font.pixelSize: 11
                                        color: parent.active ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: SettingsConfig.wallhavenSorting = parent.val
                                    }
                                }
                            }
                        }
                    }

                    // TopRange group (only when sorting=toplist)
                    Rectangle {
                        height: 28
                        radius: 14
                        color: ColorsModule.Colors.surface_container_highest
                        implicitWidth: _rangeRow.implicitWidth + 6
                        visible: SettingsConfig.wallhavenSorting === "toplist"

                        RowLayout {
                            id: _rangeRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: onlineConfigCol.rangeOpts.length
                                delegate: Rectangle {
                                    required property int index
                                    readonly property string val: onlineConfigCol.rangeOpts[index]
                                    property bool active: SettingsConfig.wallhavenTopRange === val
                                    height: 24
                                    radius: 12
                                    implicitWidth: _rLbl.implicitWidth + 14
                                    color: active ? ColorsModule.Colors.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        id: _rLbl
                                        anchors.centerIn: parent
                                        text: parent.val
                                        font.pixelSize: 11
                                        color: parent.active ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: SettingsConfig.wallhavenTopRange = parent.val
                                    }
                                }
                            }
                        }
                    }

                    // Order group (↓ ↑)
                    Rectangle {
                        height: 28
                        radius: 14
                        color: ColorsModule.Colors.surface_container_highest
                        implicitWidth: _orderRow.implicitWidth + 6

                        RowLayout {
                            id: _orderRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: [["↓", "desc"], ["↑", "asc"]]
                                delegate: Rectangle {
                                    required property var modelData
                                    property bool active: SettingsConfig.wallhavenOrder === modelData[1]
                                    height: 24
                                    width: 28
                                    radius: 12
                                    color: active ? ColorsModule.Colors.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData[0]
                                        font.pixelSize: 14
                                        color: parent.active ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: SettingsConfig.wallhavenOrder = parent.modelData[1]
                                    }
                                }
                            }
                        }
                    }

                    // Categories group
                    Rectangle {
                        height: 28
                        radius: 14
                        color: ColorsModule.Colors.surface_container_highest
                        implicitWidth: _catRow.implicitWidth + 6

                        RowLayout {
                            id: _catRow
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: [["General", 0], ["Anime", 1], ["People", 2]]
                                delegate: Rectangle {
                                    required property var modelData
                                    property bool active: SettingsConfig.wallhavenCategories[modelData[1]] === "1"
                                    height: 24
                                    radius: 12
                                    implicitWidth: _catLbl.implicitWidth + 14
                                    color: active ? ColorsModule.Colors.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        id: _catLbl
                                        anchors.centerIn: parent
                                        text: parent.modelData[0]
                                        font.pixelSize: 11
                                        color: parent.active ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: onlineConfigCol.toggleCat(parent.modelData[1])
                                    }
                                }
                            }
                        }
                    }

                    // Purity group
                    Rectangle {
                        height: 28
                        radius: 14
                        color: ColorsModule.Colors.surface_container_highest
                        implicitWidth: _purRow.implicitWidth + 6

                        RowLayout {
                            id: _purRow
                            anchors.centerIn: parent
                            spacing: 2

                            Rectangle {
                                property bool active: SettingsConfig.wallhavenPurity[0] === "1"
                                height: 24; radius: 12; implicitWidth: _ps.implicitWidth + 14
                                color: active ? ColorsModule.Colors.primary : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { id: _ps; anchors.centerIn: parent; text: "SFW"; font.pixelSize: 11; color: parent.active ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: onlineConfigCol.togglePur(0) }
                            }

                            Rectangle {
                                property bool active: SettingsConfig.wallhavenPurity[1] === "1"
                                height: 24; radius: 12; implicitWidth: _pk.implicitWidth + 14
                                color: active ? ColorsModule.Colors.primary : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { id: _pk; anchors.centerIn: parent; text: "Sketchy"; font.pixelSize: 11; color: parent.active ? ColorsModule.Colors.on_primary : ColorsModule.Colors.on_surface }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: onlineConfigCol.togglePur(1) }
                            }

                            Rectangle {
                                visible: SettingsConfig.wallhavenApiKey.length > 0
                                property bool active: SettingsConfig.wallhavenPurity[2] === "1"
                                height: 24; radius: 12; implicitWidth: _pn.implicitWidth + 14
                                color: active ? ColorsModule.Colors.error : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { id: _pn; anchors.centerIn: parent; text: "NSFW"; font.pixelSize: 11; color: parent.active ? ColorsModule.Colors.on_error : ColorsModule.Colors.on_surface }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: onlineConfigCol.togglePur(2) }
                            }
                        }
                    }

                    // Fetch button
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: Wallhaven.isFetchingOnline ? ColorsModule.Colors.surface_container_highest : ColorsModule.Colors.primary
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: Wallhaven.isFetchingOnline ? "…" : "⌕"
                            font.pixelSize: 16
                            color: Wallhaven.isFetchingOnline ? ColorsModule.Colors.on_surface : ColorsModule.Colors.on_primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!Wallhaven.isFetchingOnline) Wallhaven.fetchWallhaven(true)
                        }
                    }
                }
            }
            // ── End top bar ───────────────────────────────────────────────────

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true

                // Centered fetch / error overlay
                Rectangle {
                    anchors.centerIn: parent
                    visible: Wallhaven.isFetchingOnline || Wallhaven.onlineError.length > 0
                    z: 1
                    implicitWidth: _overlayRow.implicitWidth + 32
                    implicitHeight: _overlayRow.implicitHeight + 20
                    radius: 14
                    color: ColorsModule.Colors.surface_container

                    RowLayout {
                        id: _overlayRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: Wallhaven.onlineError.length > 0 ? "⚠" : "⬇"
                            font.pixelSize: 18
                            color: Wallhaven.onlineError.length > 0 ? ColorsModule.Colors.error : ColorsModule.Colors.on_surface
                        }

                        Text {
                            text: Wallhaven.onlineError.length > 0
                                ? Wallhaven.onlineError
                                : "Fetching wallpapers…"
                            font.pixelSize: 13
                            color: Wallhaven.onlineError.length > 0 ? ColorsModule.Colors.error : ColorsModule.Colors.on_surface
                        }
                    }
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    cellWidth: width / 4
                    cellHeight: height / (4 / 2)
                    model: ScriptModel {
                        values: Wallhaven.onlineWallpapers
                    }
                    clip: true
                    interactive: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: ColorsModule.Colors.outline_variant
                            opacity: 0.7
                        }
                    }

                    onAtYEndChanged: {
                        if (atYEnd) Wallhaven.fetchNextPage()
                    }

                    delegate: Rectangle {
                        id: wallpaperItemImageContainer
                        required property var modelData
                        width: grid.cellWidth
                        height: grid.cellHeight
                        radius: 10
                        color: area.containsMouse ? ColorsModule.Colors.primary : "transparent"

                        Image {
                            id: thumbnail
                            anchors.fill: parent
                            anchors.margins: 5
                            sourceSize: Qt.size(width, height)
                            asynchronous: true
                            smooth: true
                            cache: true
                            source: wallpaperItemImageContainer.modelData.thumbUrl
                            fillMode: Image.PreserveAspectCrop

                            Behavior on anchors.margins {
                                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                            }

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: thumbnail.width
                                    height: thumbnail.height
                                    radius: 10
                                }
                            }
                        }

                        // Loading indicator while thumbnail fetches
                        Rectangle {
                            anchors.centerIn: parent
                            width: 28; height: 28; radius: 14
                            color: ColorsModule.Colors.surface_container
                            visible: thumbnail.status === Image.Loading

                            Text {
                                anchors.centerIn: parent
                                text: "…"
                                font.pixelSize: 14
                                color: ColorsModule.Colors.on_surface
                            }
                        }

                        // Download in progress overlay
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 10
                            color: ColorsModule.Colors.surface
                            opacity: 0.85
                            visible: Wallhaven.downloadingWallpaperId === wallpaperItemImageContainer.modelData.id

                            Column {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "⬇"
                                    font.pixelSize: 22
                                    color: ColorsModule.Colors.primary

                                    SequentialAnimation on opacity {
                                        running: Wallhaven.downloadingWallpaperId === wallpaperItemImageContainer.modelData.id
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                                        NumberAnimation { from: 0.3; to: 1; duration: 600; easing.type: Easing.InOutQuad }
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Downloading…"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: ColorsModule.Colors.on_surface
                                }
                            }
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallhaven.downloadAndSetWallpaper(wallpaperItemImageContainer.modelData)
                        }
                    }
                } // GridView
            } // Item
        }
    }
}
