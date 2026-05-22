import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../colors" as ColorsModule
import qs.services

Item {
    id: browseView

    readonly property var c: ColorsModule.Colors
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Passes the full show object so DetailView can seed itself immediately
    signal animeSelected(var show)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: c.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: c.surface_container_low
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 18; rightMargin: 10 }
                spacing: 8

                // Wordmark (hidden when search is open)
                Row {
                    spacing: 0
                    visible: !searchBar.visible
                    Layout.fillWidth: true

                    Text {
                        text: "A"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: c.primary
                    }
                    Text {
                        text: "nime"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: c.on_surface; opacity: 0.85
                    }
                }

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    height: 36; radius: 18
                    color: c.surface_container
                    visible: false
                    border.color: searchField.activeFocus ? c.primary : c.outline_variant
                    border.width: searchField.activeFocus ? 1.5 : 1
                    Behavior on border.width { NumberAnimation { duration: 120 } }

                    TextInput {
                        id: searchField
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left; right: clearBtn.left
                            leftMargin: 14; rightMargin: 6
                        }
                        color: c.on_surface
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: searchDebounce.restart()
                        Keys.onEscapePressed: {
                            searchBar.visible = false
                            text = ""
                            Anime.fetchPopular(true)
                        }
                    }

                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                        text: "Search anime…"
                        color: c.on_surface_variant
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        visible: searchField.text.length === 0
                        opacity: 0.6
                    }

                    Item {
                        id: clearBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                        width: 22; height: 22
                        visible: searchField.text.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18; height: 18; radius: 9
                            color: c.surface_container_highest
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: c.on_surface_variant
                            font.pixelSize: 9; font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: {
                        if (searchField.text.trim().length > 0)
                            Anime.searchAnime(searchField.text.trim(), true)
                        else
                            Anime.fetchPopular(true)
                    }
                }

                // Search toggle
                Item {
                    width: 38; height: 38

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 16
                        color: searchBar.visible ? c.primary_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "⌕"; font.pixelSize: 18
                        color: searchBar.visible ? c.on_primary_container : c.on_surface_variant
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchBar.visible = !searchBar.visible
                            if (searchBar.visible) searchField.forceActiveFocus()
                            else {
                                searchField.text = ""
                                Anime.fetchPopular(true)
                            }
                        }
                    }
                }

                // Sub / Dub toggle
                Rectangle {
                    height: 28
                    width: modeRow.implicitWidth + 16
                    radius: 14
                    color: c.surface_container
                    border.color: c.outline_variant; border.width: 1

                    Row {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: ["sub", "dub"]

                            delegate: Item {
                                width: modeText.implicitWidth + 16
                                height: 28
                                readonly property bool active: Anime.currentMode === modelData

                                Rectangle {
                                    anchors { fill: parent; margins: 3 }
                                    radius: 11
                                    color: active ? c.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                Text {
                                    id: modeText
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 10; font.letterSpacing: 1; font.bold: true
                                    color: active ? c.on_primary : c.on_surface_variant
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Anime.setMode(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Filter chips ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: c.surface_container_low
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.25
            }

            ListView {
                id: chipList
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                orientation: ListView.Horizontal
                spacing: 7; clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { label: "Popular"; view: "popular"; country: "ALL" }
                    ListElement { label: "Latest";  view: "latest";  country: "ALL" }
                    ListElement { label: "Japan";   view: "latest";  country: "JP"  }
                    ListElement { label: "China";   view: "latest";  country: "CN"  }
                    ListElement { label: "Korea";   view: "latest";  country: "KR"  }
                }

                delegate: Item {
                    width: chipRect.implicitWidth + 24
                    height: chipList.height

                    readonly property bool active:
                        Anime.currentView === view && Anime.currentCountry === country

                    Rectangle {
                        id: chipRect
                        anchors.centerIn: parent
                        implicitWidth: chipLbl.implicitWidth + 24
                        height: 28; radius: 14
                        color: active ? c.primary : c.surface_container
                        border.color: active ? c.primary : c.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Text {
                            id: chipLbl
                            anchors.centerIn: parent
                            text: label
                            font.family: browseView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.5
                            color: active ? c.on_primary : c.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchField.text = ""
                            searchBar.visible = false
                            Anime.currentCountry = country
                            if (view === "popular") Anime.fetchPopular(true)
                            else Anime.fetchLatest(true)
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.3
            }
        }

        // ── Content area ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading
            Rectangle {
                anchors.fill: parent; color: c.background
                visible: Anime.isFetchingAnime && Anime.animeList.length === 0
                z: 10

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"
                        border.color: c.primary; border.width: 2.5
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent.visible
                            easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "loading"
                        color: c.on_surface_variant
                        font.family: browseView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2.5; opacity: 0.7
                    }
                }
            }

            // Error
            Rectangle {
                anchors.fill: parent; color: c.background
                visible: Anime.animeError.length > 0 && !Anime.isFetchingAnime
                z: 9

                Column {
                    anchors.centerIn: parent; spacing: 10

                    Text {
                        text: "⚠"; font.pixelSize: 30; color: c.error
                        anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.8
                    }
                    Text {
                        text: Anime.animeError
                        color: c.on_surface_variant; font.pixelSize: 12
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap; width: 260
                        horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
                    }
                }
            }

            // Grid
            GridView {
                id: animeGrid
                anchors.fill: parent; anchors.margins: 10
                cellWidth: (width - 10) / 4
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Anime.animeList

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 3; color: c.primary; opacity: 0.45; radius: 2
                    }
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Anime.fetchNextPage()
                }

                delegate: Item {
                    width: animeGrid.cellWidth
                    height: animeGrid.cellHeight

                    Rectangle {
                        id: card
                        anchors { fill: parent; margins: 5 }
                        radius: 12; color: c.surface_container; clip: true

                        // Cover
                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - titleBar.height
                            source: modelData.thumbnail || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            Rectangle {
                                anchors.fill: parent; color: c.surface_container_high
                                visible: coverImg.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent; text: "◫"
                                    font.pixelSize: 32; color: c.outline; opacity: 0.25
                                }
                            }

                            // Score badge
                            Rectangle {
                                visible: modelData.score !== null && modelData.score !== undefined
                                anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 8 }
                                height: 20; radius: 10
                                width: scoreText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                Text {
                                    id: scoreText; anchors.centerIn: parent
                                    text: modelData.score !== null
                                        ? "★ " + (modelData.score || 0).toFixed(1) : ""
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.5
                                    color: "#f5c518"
                                }
                            }

                            // Type badge
                            Rectangle {
                                visible: modelData.type && modelData.type.length > 0
                                anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                                height: 20; radius: 10
                                width: typeText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.7)

                                Text {
                                    id: typeText; anchors.centerIn: parent
                                    text: (modelData.type || "").toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 1; font.bold: true
                                    color: c.primary_fixed_dim
                                }
                            }

                            // Episode count badge (bottom-right of cover)
                            Rectangle {
                                visible: modelData.availableEpisodes
                                    && (modelData.availableEpisodes.sub > 0
                                        || modelData.availableEpisodes.dub > 0)
                                anchors {
                                    bottom: parent.bottom; right: parent.right
                                    bottomMargin: 8; rightMargin: 8
                                }
                                height: 20; radius: 10
                                width: epText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                Text {
                                    id: epText; anchors.centerIn: parent
                                    text: {
                                        var avail = modelData.availableEpisodes
                                        var n = Anime.currentMode === "dub"
                                            ? avail.dub : avail.sub
                                        return n + " ep"
                                    }
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 0.5
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            // Gradient
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 48
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: c.surface_container }
                                }
                            }
                        }

                        // Title bar
                        Rectangle {
                            id: titleBar
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: titleText.implicitHeight + 16
                            color: c.surface_container; radius: 12

                            Text {
                                id: titleText
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                text: modelData.englishName || modelData.name || ""
                                font.family: browseView.fontBody
                                font.pixelSize: 11; font.letterSpacing: 0.2
                                color: c.on_surface
                                wrapMode: Text.Wrap; maximumLineCount: 2
                                elide: Text.ElideRight; lineHeight: 1.3
                            }
                        }

                        // Library bookmark dot
                        Rectangle {
                            visible: Anime.isInLibrary(modelData.id)
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
                            width: 7; height: 7; radius: 4
                            color: c.primary
                            opacity: 0.9
                        }

                        Rectangle {
                            anchors.fill: parent; radius: 12; color: c.primary
                            opacity: cardArea.pressed ? 0.16 : (cardArea.containsMouse ? 0.07 : 0)
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        transform: Scale {
                            origin.x: card.width / 2; origin.y: card.height / 2
                            xScale: cardArea.pressed ? 0.97 : 1.0
                            yScale: cardArea.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: browseView.animeSelected(modelData)
                        }
                    }
                }
            }
        }
    }
}
