import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../shapes"
import "../components"
import "../services"
import "../"

PanelWindow {
    id: root

    anchors.left:   true
    anchors.right:  true
    anchors.bottom: true

    implicitHeight: root.panelHeight + Theme.borderWidth

    exclusionMode: ExclusionMode.Ignore
    color:         "transparent"

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property int panelWidth:  980
    readonly property int panelHeight: 420
    readonly property int fw:          Theme.notchRadius
    readonly property int fh:          Theme.notchRadius

    mask: Region { item: maskProxy }
    Item {
        id: maskProxy
        x:      (root.width - sizer.width) / 2
        y:      root.height - sizer.height - Theme.borderWidth
        width:  sizer.width
        height: sizer.height
    }

    property bool windowVisible: false
    visible: windowVisible

    // ── Self-hover tracking ───────────────────────────────────────────────────
    property bool selfHovered: true
    
    property bool allowHover: false

    // ── Hover close timer ─────────────────────────────────────────────────────
    // Fires when both the trigger region and the popup itself are no longer hovered.
    Timer {
        id: hoverCloseTimer
        interval: Popups.hoverCloseDelay * 2
        onTriggered: {
            if (!Popups.wallpaperTriggerHovered && !root.selfHovered) {
                Popups.wallpaperOpen = false
            }
        }
    }

    onSelfHoveredChanged: {
        if (!selfHovered && !Popups.wallpaperTriggerHovered) {
            hoverCloseTimer.restart()
        } else {
            hoverCloseTimer.stop()
        }
    }

    // ── Trigger hover — open on hover, schedule close on leave ───────────────
    Connections {
        target: Popups
        function onWallpaperTriggerHoveredChanged() {
            if (Popups.wallpaperTriggerHovered && root.allowHover) {
                hoverCloseTimer.stop()
                if (!Popups.wallpaperOpen) {
                    closeTimer.stop()
                    root.windowVisible       = true
                    Popups.wallpaperOpen     = true
                    WallpaperService.refresh()
                    WallpaperService.previewWall   = ""
                    content.schemePopupOpen        = false
                    content.folderMode             = false
                    content.appliedScheme          = WallpaperService.scheme
                    searchInput.text               = ""
                    searchInput.forceActiveFocus()
                }
            } else if (!root.selfHovered) {
                hoverCloseTimer.restart()
            }
        }

        function onWallpaperOpenChanged() {
            if (Popups.wallpaperOpen) {
                closeTimer.stop()
                hoverCloseTimer.stop()
                root.windowVisible             = true
                WallpaperService.refresh()
                WallpaperService.previewWall   = ""
                content.schemePopupOpen        = false
                content.folderMode             = false
                content.appliedScheme          = WallpaperService.scheme
                searchInput.text               = ""
                searchInput.forceActiveFocus()
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.animDuration + 20
        onTriggered: {
            if (!Popups.wallpaperOpen) root.windowVisible = false
        }
    }

    Connections {
        target: WallpaperService
        function onWallpapersChanged() {
            if (!Popups.wallpaperOpen) return
            var walls = WallpaperService.wallpapers
            if (!walls || walls.length === 0) return
            var target = WallpaperService.currentWall
            for (var i = 0; i < walls.length; i++) {
                if (walls[i] === target) {
                    WallpaperService.previewWall = target
                    wallGrid.positionViewAtIndex(i, ListView.Center)
                    return
                }
            }
        }
    }

    Item {
        id: sizer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     Theme.borderWidth
        clip: true

        width:  Popups.wallpaperOpen
                    ? root.panelWidth  + 2 * root.fw
                    : Theme.cNotchMinWidth + 2 * root.fw

        height: Popups.wallpaperOpen ? root.panelHeight : 0

        Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

        // Track whether user is hovering inside the popup itself
        HoverHandler {
            onHoveredChanged: root.selfHovered = hovered
        }

        PopupShape {
            anchors.fill: parent
            attachedEdge: "bottom"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        Item {
            id: content
            anchors {
                fill:         parent
                topMargin:    16
                bottomMargin: root.fh + 8
                leftMargin:   root.fw + 16
                rightMargin:  root.fw + 16
            }

            property string searchQuery:     ""
            property bool   schemePopupOpen: false
            property bool   folderMode:      false
            property string appliedScheme:   WallpaperService.scheme

            readonly property var filteredWallpapers: {
                var q = searchQuery.toLowerCase()
                if (q === "") return WallpaperService.wallpapers
                return WallpaperService.wallpapers.filter(function(p) {
                    return p.split("/").pop().toLowerCase().indexOf(q) !== -1
                })
            }

            readonly property bool applyActive:
                WallpaperService.previewWall !== "" ||
                (WallpaperService.currentWall !== "" &&
                 WallpaperService.scheme !== content.appliedScheme)

            opacity: Popups.wallpaperOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.wallpaperOpen
                        ? Theme.animDuration * 0.5
                        : Theme.animDuration * 0.15
                }
            }

            ListView {
                id: wallGrid
                anchors.top:          parent.top
                anchors.left:         parent.left
                anchors.right:        parent.right
                anchors.bottom:       divider.top
                anchors.bottomMargin: 8

                orientation:    ListView.Horizontal
                spacing:        14
                clip:           true
                boundsBehavior: Flickable.StopAtBounds
                interactive:    false

                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    height: 6
                }

                model: content.filteredWallpapers

                Text {
                    anchors.centerIn: parent
                    visible:        wallGrid.count === 0
                    text:           "No wallpapers found in " + WallpaperService.wallpaperDir
                    color:          Qt.rgba(1,1,1,0.25)
                    font.pixelSize: 13
                }

                delegate: Item {
                    id: cardDelegate
                    width:  isPreview? (130*1.2) : 130
                    height: isPreview? wallGrid.height : wallGrid.height - 14

                    Behavior on width  { NumberAnimation { duration: 120; easing.type: Easing.InOutCubic } }
			        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.InOutCubic } }
                    
                    required property string modelData
                    required property int    index

                    property bool isPreview: WallpaperService.previewWall === modelData
                    property bool isCurrent: WallpaperService.currentWall === modelData

                    readonly property int labelH: 30

                    Item {
                        id: cardContent
                        anchors.fill: parent
                        visible: false

                        Image {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            anchors.top:    parent.top
                            height:         parent.height - cardDelegate.labelH
                            source:         "file://" + modelData
                            fillMode:       Image.PreserveAspectCrop
                            asynchronous:   true
                            cache:          true
                        }

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            anchors.bottom: parent.bottom
                            height:         cardDelegate.labelH
                            color: isPreview
                                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
                                : Qt.rgba(1, 1, 1, 0.09)

                            Text {
                                anchors.centerIn:    parent
                                width:               parent.width - 10
                                text:                modelData.split("/").pop().replace(/\.[^/.]+$/, "")
                                color:               isPreview ? Theme.active : Qt.rgba(1,1,1,0.65)
                                font.pixelSize:      10
                                font.weight:         isPreview ? Font.Medium : Font.Normal
                                elide:               Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Rectangle {
                        id: cardMask
                        anchors.fill:  parent
                        radius:        10
                        visible:       false
                        layer.enabled: true
                    }

                    MultiEffect {
                        source:           cardContent
                        anchors.fill:     parent
                        maskEnabled:      true
                        maskSource:       cardMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin:  1.0
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius:       10
                        color:        "transparent"
                        border.width: isPreview ? 2 : 1
                        border.color: isPreview
                            ? Theme.active
                            : isCurrent
                                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
                                : Qt.rgba(1,1,1,0.15)
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on border.width { NumberAnimation { duration: 120 } }
                    }

                    TapHandler {
                        onTapped: {
                            content.schemePopupOpen = false
                            WallpaperService.previewWall = cardDelegate.isPreview
                                ? "" : cardDelegate.modelData
                        }
                    }
                }
            }

            MouseArea {
                anchors.top:          parent.top
                anchors.left:         parent.left
                anchors.right:        parent.right
                anchors.bottom:       divider.top
                anchors.bottomMargin: 8
                z:                    wallGrid.z + 1
                acceptedButtons:      Qt.NoButton
                onWheel: function(wheel) {
                    wallGrid.contentX = Math.max(0,
                        Math.min(wallGrid.contentWidth - wallGrid.width,
                            wallGrid.contentX - wheel.angleDelta.y))
                }
            }

            Rectangle {
                id: divider
                anchors.bottom:       utilBar.top
                anchors.bottomMargin: 8
                anchors.left:         parent.left
                anchors.right:        parent.right
                height: 1
                color:  Qt.rgba(1,1,1,0.07)
            }

            Item {
                id: utilBar
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottomMargin: -20
                height: 32

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        id: folderBtn
                        width:  32; height: 32; radius: 8
                        color: content.folderMode
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                            : folderHov.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                        border.color: content.folderMode
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
                            : Qt.rgba(1,1,1,0.09)
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text:           "󰉋"
                            font.pixelSize: 15
                            color: content.folderMode ? Theme.active : Qt.rgba(1,1,1,0.5)
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        HoverHandler { id: folderHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                content.folderMode = !content.folderMode
                                if (content.folderMode) {
                                    dirInput.text = WallpaperService.wallpaperDir
                                    dirInput.forceActiveFocus()
                                    dirInput.selectAll()
                                } else {
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width:  300; height: 32; radius: 8
                        color:        Qt.rgba(1,1,1,0.06)
                        border.color: (searchInput.activeFocus || dirInput.activeFocus)
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5)
                            : Qt.rgba(1,1,1,0.1)
                        border.width: 1

                        Item {
                            anchors.fill:        parent
                            anchors.leftMargin:  10
                            anchors.rightMargin: 10
                            visible: !content.folderMode

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text:           "Search wallpapers…"
                                color:          Qt.rgba(1,1,1,0.28)
                                font.pixelSize: 12
                                visible:        searchInput.text === ""
                            }

                            TextInput {
                                id: searchInput
                                anchors.fill:       parent
                                verticalAlignment:  TextInput.AlignVCenter
                                color:              Theme.text
                                font.pixelSize:     12
                                selectionColor:     Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                                clip: true
                                onTextChanged: content.searchQuery = text

                                Keys.onReturnPressed: {
                                    var walls = content.filteredWallpapers
                                    if (!walls || walls.length === 0) return
                                    var target = walls.length === 1
                                        ? walls[0]
                                        : WallpaperService.previewWall
                                    if (target === "") return
                                    content.appliedScheme = WallpaperService.scheme
                                    WallpaperService.apply(target)
                                    Popups.wallpaperOpen = false
                                }

                                Keys.onLeftPressed: {
                                    var walls = content.filteredWallpapers
                                    if (!walls || walls.length === 0) return
                                    var cur = WallpaperService.previewWall
                                    var idx = -1
                                    for (var i = 0; i < walls.length; i++) {
                                        if (walls[i] === cur) { idx = i; break }
                                    }
                                    idx = (idx <= 0) ? walls.length - 1 : idx - 1
                                    WallpaperService.previewWall = walls[idx]
                                    wallGrid.positionViewAtIndex(idx, ListView.Center)
                                }

                                Keys.onRightPressed: {
                                    var walls = content.filteredWallpapers
                                    if (!walls || walls.length === 0) return
                                    var cur = WallpaperService.previewWall
                                    var idx = -1
                                    for (var i = 0; i < walls.length; i++) {
                                        if (walls[i] === cur) { idx = i; break }
                                    }
                                    idx = (idx < 0 || idx >= walls.length - 1) ? 0 : idx + 1
                                    WallpaperService.previewWall = walls[idx]
                                    wallGrid.positionViewAtIndex(idx, ListView.Center)
                                }
                            }
                        }

                        Item {
                            anchors.fill:        parent
                            anchors.leftMargin:  10
                            anchors.rightMargin: 10
                            visible: content.folderMode

                            Text {
                                id: pathLbl
                                anchors.left:           parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text:           "Path: "
                                color:          Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7)
                                font.pixelSize: 11
                            }

                            TextInput {
                                id: dirInput
                                anchors.left:       pathLbl.right
                                anchors.right:      parent.right
                                anchors.top:        parent.top
                                anchors.bottom:     parent.bottom
                                verticalAlignment:  TextInput.AlignVCenter
                                color:              Theme.text
                                font.pixelSize:     12
                                font.family:        "JetBrains Mono"
                                selectionColor:     Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
                                clip: true

                                Keys.onReturnPressed: {
                                    WallpaperService.wallpaperDir = dirInput.text
                                    WallpaperService.refresh()
                                    content.folderMode = false
                                    searchInput.forceActiveFocus()
                                }
                                Keys.onEscapePressed: {
                                    content.folderMode = false
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: schemeBtn
                        width:  schemeBtnRow.implicitWidth + 20
                        height: 32; radius: 8
                        color: content.schemePopupOpen
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                            : schemeBtnHov.hovered ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04)
                        border.color: content.schemePopupOpen
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
                            : Qt.rgba(1,1,1,0.09)
                        border.width: 1
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        Row {
                            id: schemeBtnRow
                            anchors.centerIn: parent
                            spacing: 7

                            Text {
                                text: "󰏘"
                                font.pixelSize: 14
                                color: content.schemePopupOpen ? Theme.active : Qt.rgba(1,1,1,0.55)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                text: WallpaperService.scheme
                                font.pixelSize: 12
                                color: content.schemePopupOpen ? Theme.active : Qt.rgba(1,1,1,0.7)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                text: content.schemePopupOpen ? "▴" : "▾"
                                font.pixelSize: 8
                                color: Qt.rgba(1,1,1,0.35)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        HoverHandler { id: schemeBtnHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: content.schemePopupOpen = !content.schemePopupOpen
                        }

                        Rectangle {
                            visible: content.schemePopupOpen
                            z:       20

                            anchors.left:         parent.left
                            anchors.bottom:       parent.top
                            anchors.bottomMargin: 6

                            width:  schemeCol.implicitWidth + 24
                            height: schemeCol.implicitHeight + 16
                            radius: Theme.cornerRadius
                            color:  Qt.rgba(
                                Math.min(1, Theme.background.r + 0.06),
                                Math.min(1, Theme.background.g + 0.08),
                                Math.min(1, Theme.background.b + 0.06),
                                0.98)
                            border.color: Qt.rgba(1,1,1,0.1)
                            border.width: 1

                            opacity: content.schemePopupOpen ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            Column {
                                id: schemeCol
                                anchors.centerIn: parent
                                spacing: 2

                                Repeater {
                                    model: WallpaperService.schemes
                                    delegate: Rectangle {
                                        required property string modelData
                                        property bool sel: WallpaperService.scheme === modelData

                                        width:  schemeItemLbl.implicitWidth + 32
                                        height: 28
                                        radius: 6
                                        color: sel
                                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
                                            : itemHov.hovered ? Qt.rgba(1,1,1,0.07) : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 10
                                            Text {
                                                text:           sel ? "●" : "○"
                                                font.pixelSize: 9
                                                color: sel ? Theme.active : Qt.rgba(1,1,1,0.3)
                                                anchors.verticalCenter: parent.verticalCenter
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }
                                            Text {
                                                id: schemeItemLbl
                                                text:           modelData
                                                font.pixelSize: 12
                                                color: sel ? Theme.active : Qt.rgba(1,1,1,0.65)
                                                anchors.verticalCenter: parent.verticalCenter
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }
                                        }

                                        HoverHandler { id: itemHov; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                WallpaperService.scheme = modelData
                                                content.schemePopupOpen = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: applyBtn
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    property bool active: content.applyActive
                    width:   active ? 90 : 0
                    height:  32; radius: 8
                    opacity: active ? 1 : 0
                    clip:    true

                    color:        Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
                    border.width: 1

                    Behavior on width   { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Text {
                        anchors.centerIn: parent
                        text:           WallpaperService.applying ? "…" : "Apply"
                        font.pixelSize: 12
                        font.weight:    Font.Medium
                        color:          Theme.active
                        opacity:        applyBtn.active ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: applyBtn.active && !WallpaperService.applying
                        onTapped: {
                            var target = WallpaperService.previewWall !== ""
                                ? WallpaperService.previewWall
                                : WallpaperService.currentWall
                            content.appliedScheme = WallpaperService.scheme
                            WallpaperService.apply(target)
                            Popups.wallpaperOpen = false
                        }
                    }
                }
            }

            TapHandler {
                enabled: content.schemePopupOpen
                onTapped: content.schemePopupOpen = false
            }
        }
    }
}
