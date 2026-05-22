import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import "."
import "../../colors" as ColorsModule

PanelWindow {
    id: root

    property bool liveCapture: false
    property bool moveCursorToActiveWindow: false

    property bool isActive: false
    property bool specialActive: false

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: isActive
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: isActive ? 1 : 0
    WlrLayershell.namespace: "quickshell:expose"

    Rectangle {
        anchors.fill: parent
        color: ColorsModule.Colors.surface_dim
        opacity: 0.85

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blurMultiplier: 1.0
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.3) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.2) }
        }
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 3
        color: ColorsModule.Colors.primary
        opacity: 0.7
    }

    IpcHandler {
        target: "expose"
        function toggle() { root.toggleExpose() }
        function open()   { if (!root.isActive) root.toggleExpose() }
        function close()  { if (root.isActive)  root.toggleExpose() }
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!root.isActive && ev.name !== "activespecial") return
            switch (ev.name) {
                case "openwindow":
                case "closewindow":
                case "changefloatingmode":
                case "movewindow":
                    Hyprland.refreshToplevels()
                    refreshThumbs()
                    return
                case "activespecial":
                    var dataStr = String(ev.data)
                    root.specialActive = (dataStr.split(",")[0].length > 0)
                    return
            }
        }
    }

    Timer {
        id: screencopyTimer
        interval: 125
        repeat: true
        running: !root.liveCapture && root.isActive
        onTriggered: root.refreshThumbs()
    }

    
    QtObject {
        id: dragState

        property bool   active:          false   
        property int    winIndex:        -1       
        property string winAddress:      ""       
        property int    sourceWorkspace: -1       
        property int    hoverCardIndex:  -1       

        property real ghostX: 0
        property real ghostY: 0
        property real ghostW: 0
        property real ghostH: 0
        property string ghostLabel: ""
    }

    Process {
        id: hyprctlProc
    }

    function moveWindowToWorkspace(winAddress, targetWorkspaceId) {
        hyprctlProc.command = [
            "hyprctl", "dispatch",
            "movetoworkspacesilent",
            String(targetWorkspaceId) + ",address:0x" + winAddress
        ]
        hyprctlProc.running = true
    }

    function toggleExpose() {
        root.isActive = !root.isActive
        if (root.isActive) {
            exposeArea.currentIndex = -1
            searchBox.reset()
            Hyprland.refreshToplevels()
            refreshThumbs()
        }
    }

    function refreshThumbs() {
        if (!root.isActive) return
        for (var i = 0; i < winRepeater.count; ++i) {
            var it = winRepeater.itemAt(i)
            if (it && it.visible && it.refreshThumb) it.refreshThumb()
        }
    }

    function computeGroupedLayout(windowList, areaW, areaH) {
        if (windowList.length === 0) return []

        var groups = {}          // workspaceId -> [item, ...]
        var groupOrder = []      // insertion order of workspaceIds

        for (var i = 0; i < windowList.length; i++) {
            var item = windowList[i]
            var wid  = item.workspaceId
            if (!groups[wid]) {
                groups[wid] = []
                groupOrder.push(wid)
            }
            groups[wid].push(item)
        }

        var numGroups = groupOrder.length

        var cardCols = Math.ceil(Math.sqrt(numGroups))
        var cardRows = Math.ceil(numGroups / cardCols)

        var outerPad  = 24   
        var cardGap   = 28  
        var innerPad  = 10  
        var winGap    = 8    

        var cardW = (areaW - outerPad * 2 - cardGap * (cardCols - 1)) / cardCols
        var cardH = (areaH - outerPad * 2 - cardGap * (cardRows - 1)) / cardRows

        var result = []
        var flatIndex = 0   

  
        var layoutMap = {}  

        for (var g = 0; g < numGroups; g++) {
            var wid2    = groupOrder[g]
            var members = groups[wid2]
            var count   = members.length

            var cardCol = g % cardCols
            var cardRow = Math.floor(g / cardCols)
            var cardX   = outerPad + cardCol * (cardW + cardGap)
            var cardY   = outerPad + cardRow * (cardH + cardGap)

            var innerW = cardW - innerPad * 2
            var innerH = cardH - innerPad * 2

            var subCols = Math.ceil(Math.sqrt(count))
            var subRows = Math.ceil(count / subCols)

            var cellW = (innerW - winGap * (subCols - 1)) / subCols
            var cellH = (innerH - winGap * (subRows - 1)) / subRows

            for (var m = 0; m < count; m++) {
                var mem     = members[m]
                var subCol  = m % subCols
                var subRow  = Math.floor(m / subCols)

                var winW   = mem.width  > 0 ? mem.width  : cellW
                var winH   = mem.height > 0 ? mem.height : cellH
                var scale  = Math.min(cellW / winW, cellH / winH)
                var scaledW = winW * scale
                var scaledH = winH * scale

                var cellOriginX = cardX + innerPad + subCol * (cellW + winGap)
                var cellOriginY = cardY + innerPad + subRow * (cellH + winGap)

                layoutMap[mem.originalIndex] = {
                    win:            mem.win,
                    clientInfo:     mem.clientInfo,
                    workspaceId:    wid2,
                    workspaceGroup: g,
                    cardX:          cardX,
                    cardY:          cardY,
                    cardW:          cardW,
                    cardH:          cardH,
                    x:              cellOriginX + (cellW - scaledW) / 2,
                    y:              cellOriginY + (cellH - scaledH) / 2,
                    width:          scaledW,
                    height:         scaledH,
                    zIndex:         0,
                    rotation:       0
                }
            }
        }

        for (var j = 0; j < windowList.length; j++) {
            result.push(layoutMap[windowList[j].originalIndex])
        }
        return result
    }

    function computeCardRegions(windowList, areaW, areaH) {
        if (windowList.length === 0) return []

        var groups    = {}
        var groupOrder = []
        for (var i = 0; i < windowList.length; i++) {
            var item = windowList[i]
            var wid  = item.workspaceId
            if (!groups[wid]) { groups[wid] = []; groupOrder.push(wid) }
            groups[wid].push(item)
        }

        var numGroups = groupOrder.length
        var cardCols  = Math.ceil(Math.sqrt(numGroups))
        var cardRows  = Math.ceil(numGroups / cardCols)
        var outerPad  = 24
        var cardGap   = 28
        var cardW     = (areaW - outerPad * 2 - cardGap * (cardCols - 1)) / cardCols
        var cardH     = (areaH - outerPad * 2 - cardGap * (cardRows - 1)) / cardRows

        var cards = []
        for (var g = 0; g < numGroups; g++) {
            var cardCol = g % cardCols
            var cardRow = Math.floor(g / cardCols)
            cards.push({
                workspaceId: groupOrder[g],
                x: outerPad + cardCol * (cardW + cardGap),
                y: outerPad + cardRow * (cardH + cardGap),
                width:  cardW,
                height: cardH
            })
        }
        return cards
    }

    FocusScope {
        id: mainScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (!root.isActive) return

            if (event.key === Qt.Key_Escape) {
                root.toggleExpose()
                event.accepted = true
                return
            }

            const total = winRepeater.count
            if (total <= 0) return

            function moveSelectionHorizontal(delta) {
                var start = exposeArea.currentIndex
                for (var step = 1; step <= total; ++step) {
                    var candidate = (start + delta * step + total) % total
                    var it = winRepeater.itemAt(candidate)
                    if (it && it.visible) { exposeArea.currentIndex = candidate; return }
                }
            }

            function moveSelectionVertical(dir) {
                var startIndex   = exposeArea.currentIndex
                var currentItem  = winRepeater.itemAt(startIndex)
                if (!currentItem || !currentItem.visible) {
                    moveSelectionHorizontal(dir > 0 ? 1 : -1); return
                }
                var curCx = currentItem.x + currentItem.width  / 2
                var curCy = currentItem.y + currentItem.height / 2
                var bestIndex = -1, bestDy = 99999999, bestDx = 99999999
                for (var i = 0; i < total; ++i) {
                    var it = winRepeater.itemAt(i)
                    if (!it || !it.visible || i === startIndex) continue
                    var cx = it.x + it.width  / 2
                    var cy = it.y + it.height / 2
                    var dy = cy - curCy
                    if (dir > 0 && dy <= 0) continue
                    if (dir < 0 && dy >= 0) continue
                    var absDy = Math.abs(dy), absDx = Math.abs(cx - curCx)
                    if (absDy < bestDy || (absDy === bestDy && absDx < bestDx)) {
                        bestDy = absDy; bestDx = absDx; bestIndex = i
                    }
                }
                if (bestIndex >= 0) exposeArea.currentIndex = bestIndex
            }

            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                moveSelectionHorizontal(1); event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                moveSelectionHorizontal(-1); event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                moveSelectionVertical(1); event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                moveSelectionVertical(-1); event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var item = winRepeater.itemAt(exposeArea.currentIndex)
                if (item && item.activateWindow) { item.activateWindow(); event.accepted = true }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            z: -1
            onClicked: root.toggleExpose()
        }

        Item {
            id: layoutContainer
            anchors.fill: parent
            anchors.margins: 40

            Column {
                id: layoutRoot
                anchors.fill: parent
                anchors.margins: 32
                spacing: 24

                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6; height: 6; radius: 3
                            color: ColorsModule.Colors.primary
                            opacity: 0.9
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var wc = winRepeater.count
                                var gc = exposeArea.cardList.length
                                if (wc === 0) return "No windows"
                                return wc + (wc === 1 ? " window" : " windows") +
                                    (gc > 1 ? "  ·  " + gc + " workspaces" : "")
                            }
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            font.letterSpacing: 0.2
                            color: ColorsModule.Colors.on_surface_variant
                            opacity: 0.75
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 16

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "↵ focus  ·  esc close"
                            font.pixelSize: 11
                            color: ColorsModule.Colors.on_surface_variant
                            opacity: 0.4
                        }
                    }
                }

                Item {
                    id: exposeArea
                    width: layoutRoot.width
                    height: layoutRoot.height - searchBox.implicitHeight - layoutRoot.spacing - 40

                    property int currentIndex: 0
                    property string searchText: ""

                    onSearchTextChanged: {
                        currentIndex = (windowList.length > 0) ? 0 : -1
                    }

                    property var rawWindowList: {
                        var q = (searchText || "").toLowerCase()
                        var list = []
                        var idx = 0
                        var toplevels = Hyprland.toplevels.values
                        if (!toplevels) return []

                        for (var it of toplevels) {
                            var w = it
                            var clientInfo = w && w.lastIpcObject ? w.lastIpcObject : {}
                            var workspace = clientInfo && clientInfo.workspace ? clientInfo.workspace : null
                            var workspaceId = workspace && workspace.id !== undefined ? workspace.id : undefined
                            if (workspaceId === undefined || workspaceId === null) continue

                            var size = clientInfo && clientInfo.size ? clientInfo.size : [0, 0]
                            var at   = clientInfo && clientInfo.at   ? clientInfo.at   : [-1000, -1000]
                            if (at[1] + size[1] <= 0) continue

                            var title = (w.title || clientInfo.title || "").toLowerCase()
                            var clazz = (clientInfo["class"] || "").toLowerCase()
                            var ic    = (clientInfo.initialClass || "").toLowerCase()

                            if (q.length > 0) {
                                if (title.indexOf(q) === -1 && clazz.indexOf(q) === -1 && ic.indexOf(q) === -1)
                                    continue
                            }

                            list.push({
                                win: w,
                                clientInfo: clientInfo,
                                workspaceId: workspaceId,
                                width:  size[0],
                                height: size[1],
                                originalIndex: idx++
                            })
                        }

                        list.sort(function(a, b) {
                            if (a.workspaceId !== b.workspaceId) return a.workspaceId - b.workspaceId
                            return a.originalIndex - b.originalIndex
                        })
                        return list
                    }

                    property var windowList: {
                        if (exposeArea.width <= 0 || exposeArea.height <= 0) return []
                        return root.computeGroupedLayout(rawWindowList, exposeArea.width, exposeArea.height)
                    }

                    // Card regions for background rendering
                    property var cardList: {
                        if (exposeArea.width <= 0 || exposeArea.height <= 0) return []
                        return root.computeCardRegions(rawWindowList, exposeArea.width, exposeArea.height)
                    }


                    Repeater {
                        model: exposeArea.windowList

                        delegate: Item {
                            x: modelData.x - 6
                            y: modelData.y - 6
                            width:  modelData.width  + 12
                            height: modelData.height + 12
                            visible: exposeArea.currentIndex === index

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: "transparent"
                                border.width: 2
                                border.color: ColorsModule.Colors.primary
                                opacity: 0.9

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: ColorsModule.Colors.primary
                                    opacity: 0.1
                                }
                            }
                        }
                    }

                    Repeater {
                        id: winRepeater
                        model: exposeArea.windowList

                        delegate: Item {
                            id: thumbWrapper
                            x: modelData.x
                            y: modelData.y
                            width:  modelData.width
                            height: modelData.height
                            visible: true
                            opacity: (dragState.active && dragState.winIndex === index) ? 0.25 : 1.0
                            z: (exposeArea.currentIndex === index) ? 1000 : modelData.zIndex || 0

                            function activateWindow() { if (thumb.activateWindow) thumb.activateWindow() }

                            WindowThumbnail {
                                id: thumb
                                hWin:       modelData.win
                                wHandle:    hWin.wayland
                                winKey:     String(hWin.address)
                                thumbW:     modelData.width
                                thumbH:     modelData.height
                                clientInfo: hWin.lastIpcObject

                                targetX:        0
                                targetY:        0
                                targetZ:        0
                                targetRotation: modelData.rotation || 0

                                hovered:                  thumbWrapper.activeFocus || (exposeArea.currentIndex === index && !dragState.active)
                                moveCursorToActiveWindow: root.moveCursorToActiveWindow

                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor:           ColorsModule.Colors.shadow
                                    shadowOpacity:         0.35
                                    shadowBlur:            0.5
                                    shadowHorizontalOffset: 2
                                    shadowVerticalOffset:   2
                                }
                            }

                            // Workspace number badge — top-right of thumbnail
                            Rectangle {
                                z: 200
                                anchors.top:   parent.top
                                anchors.right: parent.right
                                anchors.topMargin:   6
                                anchors.rightMargin: 6
                                width:  wsNumText.implicitWidth + 12
                                height: 20
                                radius: 10
                                color:  Qt.rgba(0, 0, 0, 0.55)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.15)

                                Text {
                                    id: wsNumText
                                    anchors.centerIn: parent
                                    text: modelData.workspaceId
                                    font.pixelSize: 10
                                    font.weight: Font.SemiBold
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            MouseArea {
                                id: dragCapture
                                anchors.fill: parent
                                drag.threshold: 8
                                preventStealing: dragState.active

                                property real pressX: 0
                                property real pressY: 0
                                property bool dragStarted: false

                                onPressed: (mouse) => {
                                    pressX = mouse.x
                                    pressY = mouse.y
                                    dragStarted = false
                                    exposeArea.currentIndex = index
                                }

                                onPositionChanged: (mouse) => {
                                    var dx = mouse.x - pressX
                                    var dy = mouse.y - pressY
                                    if (!dragStarted && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
                                        dragStarted = true
                                        var data = exposeArea.windowList[index]
                                        dragState.winIndex        = index
                                        dragState.winAddress      = String(data.win.address)
                                        dragState.sourceWorkspace = data.workspaceId
                                        dragState.ghostW          = data.width
                                        dragState.ghostH          = data.height
                                        dragState.ghostLabel      = data.win.title || ""
                                        dragState.active          = true
                                    }
                                    if (dragState.active) {
                                        var pt = mapToItem(exposeArea,
                                            mouse.x - dragState.ghostW / 2,
                                            mouse.y - dragState.ghostH / 2)
                                        dragState.ghostX = pt.x
                                        dragState.ghostY = pt.y

                                        var cx = pt.x + dragState.ghostW / 2
                                        var cy = pt.y + dragState.ghostH / 2
                                        var found = -1
                                        for (var ci = 0; ci < exposeArea.cardList.length; ci++) {
                                            var c = exposeArea.cardList[ci]
                                            if (cx >= c.x && cx <= c.x + c.width &&
                                                cy >= c.y && cy <= c.y + c.height) {
                                                found = ci
                                                break
                                            }
                                        }
                                        dragState.hoverCardIndex = found
                                    }
                                }

                                onReleased: (mouse) => {
                                    if (dragState.active) {
                                        var hci = dragState.hoverCardIndex
                                        if (hci >= 0 && hci < exposeArea.cardList.length) {
                                            var targetWs = exposeArea.cardList[hci].workspaceId
                                            if (targetWs !== dragState.sourceWorkspace) {
                                                root.moveWindowToWorkspace(dragState.winAddress, targetWs)
                                                Qt.callLater(function() {
                                                    Hyprland.refreshToplevels()
                                                    root.refreshThumbs()
                                                })
                                            }
                                        }
                                        dragState.active         = false
                                        dragState.winIndex       = -1
                                        dragState.hoverCardIndex = -1
                                    } else if (!dragStarted) {
                                        if (thumb.activateWindow) thumb.activateWindow()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: dragGhost
                        visible: dragState.active
                        x: dragState.ghostX
                        y: dragState.ghostY
                        width:  dragState.ghostW
                        height: dragState.ghostH
                        radius: 10
                        color:  Qt.rgba(
                            ColorsModule.Colors.primary.r,
                            ColorsModule.Colors.primary.g,
                            ColorsModule.Colors.primary.b, 0.18)
                        border.width: 2
                        border.color: ColorsModule.Colors.primary
                        z: 9999

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            text: dragState.ghostLabel
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: ColorsModule.Colors.on_surface
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }

                        layer.enabled: dragState.active
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor:   ColorsModule.Colors.primary
                            shadowOpacity: 0.55
                            shadowBlur:    0.8
                        }

                        Behavior on x { SmoothedAnimation { velocity: 800 } }
                        Behavior on y { SmoothedAnimation { velocity: 800 } }
                    }
                }

                Item {
                    width: parent.width
                    height: 60

                    SearchBox {
                        id: searchBox
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.55, 520)

                        onTextChanged: function(text) {
                            exposeArea.searchText = text
                        }
                    }
                }
            }
        }
    }

    OpacityAnimator {
        target: root
        from: 0; to: 1
        duration: 200
        running: root.isActive
    }
}
