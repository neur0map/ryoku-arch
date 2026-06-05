import QtQuick

// pragma ComponentBehavior: Bound

import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.ambxst.modules.globals
import qs.ambxst.modules.theme
import qs.ambxst.modules.services
import qs.ambxst.modules.components
import qs.ambxst.config

Item {
    id: root

    required property int workspaceId
    required property real workspaceWidth
    required property real workspaceHeight
    required property real workspacePadding
    required property real scale_
    required property int monitorId
    required property var monitorData
    required property string barPosition
    required property int barReserved
    required property var windowList
    required property bool isActive
    required property color activeBorderColor
    property string focusedWindowAddress: ""
    property string searchQuery: ""
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property Item dragOverlay: null
    property Item overviewRoot: null

    property var checkWindowMatched: function (addr) {
        return false;
    }
    property var checkWindowSelected: function (addr) {
        return false;
    }

    implicitWidth: workspaceWidth
    implicitHeight: workspaceHeight

    readonly property real viewportWidth: workspaceWidth / 3
    readonly property real viewportOffset: viewportWidth

    readonly property var workspaceWindows: {
        return windowList.filter(win => {
            return (win && win.workspace ? win.workspace.id : null) === workspaceId && win.monitor === monitorId;
        });
    }

    // Calculate content bounds based on actual window positions
    // Windows are positioned relative to monitor, scaled, then offset by viewportOffset
    readonly property var contentBounds: {
        if (workspaceWindows.length === 0) {
            return {
                minX: 0,
                maxX: 0,
                hasOverflow: false
            };
        }

        let minX = Infinity;
        let maxX = -Infinity;

        for (const win of workspaceWindows) {
            let baseX = ((win && win.at && win.at[0] !== undefined ? win.at[0] : 0) || 0) - ((monitorData && monitorData.x !== undefined ? monitorData.x : 0) || 0);
            if (barPosition === "left")
                baseX -= barReserved;
            const scaledX = baseX * scale_;
            const winWidth = ((win && win.size && win.size[0] !== undefined ? win.size[0] : 100) || 100) * scale_;

            minX = Math.min(minX, scaledX);
            maxX = Math.max(maxX, scaledX + winWidth);
        }

        const hasOverflow = minX < -viewportWidth || maxX > (viewportWidth * 2);

        return {
            minX,
            maxX,
            hasOverflow
        };
    }

    // Calculate scroll limits based on content
    // We want to allow scrolling so that all content can be brought into view
    readonly property real maxHorizontalScroll: {
        if (!contentBounds.hasOverflow)
            return 0;
        return Math.max(0, -contentBounds.minX);
    }
    readonly property real minHorizontalScroll: {
        if (!contentBounds.hasOverflow)
            return 0;
        return Math.min(0, viewportWidth - contentBounds.maxX);
    }

    property real horizontalScrollOffset: 0
    property bool isScrollDragging: false
    property bool isWheelScrolling: false

    Timer {
        id: wheelScrollTimer
        interval: 150
        onTriggered: root.isWheelScrolling = false
    }

    onWorkspaceWindowsChanged: resetScroll()
    onContentBoundsChanged: {
        if (!contentBounds.hasOverflow && horizontalScrollOffset !== 0) {
            horizontalScrollOffset = 0;
        }
    }

    function resetScroll() {
        horizontalScrollOffset = 0;
    }

    Behavior on horizontalScrollOffset {
        enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0 && !root.isScrollDragging && !root.isWheelScrolling
        NumberAnimation {
            duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
            easing.type: Easing.OutQuart
        }
    }

    function clampHorizontalScroll(value) {
        if (!contentBounds.hasOverflow)
            return 0;
        return Math.max(minHorizontalScroll, Math.min(maxHorizontalScroll, value));
    }

    Item {
        id: workspaceContainer
        anchors.fill: parent

        Item {
            id: backgroundLayer
            anchors.fill: parent
            clip: true

            TintedWallpaper {
                id: workspaceWallpaper
                anchors.fill: parent
                radius: Styling.radius(1)
                tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false

                property string lockscreenFramePath: {
                    if (!GlobalStates.wallpaperManager)
                        return "";
                    return GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper);
                }
                source: lockscreenFramePath ? "file://" + lockscreenFramePath : ""
            }

            Rectangle {
                anchors.fill: parent
                radius: Styling.radius(1)
                color: Colors.background
                opacity: 0.3
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: Styling.radius(1)
            border.width: root.draggingTargetWorkspace === root.workspaceId && root.draggingFromWorkspace !== root.workspaceId ? 2 : 0
            border.color: Colors.outline
            z: 100
        }

        Item {
            id: windowsContainer
            anchors.fill: parent
            anchors.margins: root.workspacePadding

            MouseArea {
                id: scrollArea
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                propagateComposedEvents: true

                property real dragStartX: 0
                property real scrollStartOffset: 0

                onPressed: mouse => {
                    if (mouse.button === Qt.RightButton && root.contentBounds.hasOverflow) {
                        dragStartX = mouse.x;
                        scrollStartOffset = root.horizontalScrollOffset;
                        root.isScrollDragging = true;
                        mouse.accepted = true;
                    } else {
                        mouse.accepted = false;
                    }
                }

                onPositionChanged: mouse => {
                    if (root.isScrollDragging && (mouse.buttons & Qt.RightButton)) {
                        const delta = mouse.x - dragStartX;
                        root.horizontalScrollOffset = root.clampHorizontalScroll(scrollStartOffset + delta);
                    }
                }

                onReleased: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.isScrollDragging = false;
                    }
                }

                onCanceled: {
                    root.isScrollDragging = false;
                }

                onClicked: mouse => mouse.accepted = false
            }

            WheelHandler {
                id: wheelHandler
                acceptedModifiers: Qt.ShiftModifier
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (!root.contentBounds.hasOverflow)
                        return;
                    root.isWheelScrolling = true;
                    wheelScrollTimer.restart();
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                    root.horizontalScrollOffset = root.clampHorizontalScroll(root.horizontalScrollOffset + delta);
                    event.accepted = true;
                }
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onDoubleTapped: {
                    AxctlService.dispatch(`workspace ${root.workspaceId}`);
                    Visibilities.setActiveModule("", true);
                }
            }

            Repeater {
                model: root.workspaceWindows

                delegate: Item {
                    id: windowDelegate
                    required property var modelData

                    readonly property var windowData: modelData
                    readonly property var toplevel: {
                        const toplevels = ToplevelManager.toplevels.values;
                        const cls = windowData.class || "";
                        if (!cls) return null;
                        const candidates = toplevels.filter(t => t.appId === cls);
                        if (candidates.length <= 1) return candidates[0] || null;
                        return candidates.find(t => t.title === (windowData.title || "")) || candidates[0];
                    }

                    property real overrideBaseX: -1
                    property real overrideBaseY: -1
                    property bool useOverridePosition: false

                    readonly property real baseX: {
                        if (useOverridePosition && overrideBaseX >= 0)
                            return overrideBaseX;
                        let base = ((windowData && windowData.at && windowData.at[0] !== undefined ? windowData.at[0] : 0) || 0) - ((monitorData && monitorData.x !== undefined ? monitorData.x : 0) || 0);
                        if (barPosition === "left")
                            base -= barReserved;
                        return (base * scale_) + root.viewportOffset + root.horizontalScrollOffset;
                    }
                    readonly property real baseY: {
                        if (useOverridePosition && overrideBaseY >= 0)
                            return overrideBaseY;
                        let base = ((windowData && windowData.at && windowData.at[1] !== undefined ? windowData.at[1] : 0) || 0) - ((monitorData && monitorData.y !== undefined ? monitorData.y : 0) || 0);
                        if (barPosition === "top")
                            base -= barReserved;
                        return Math.max(base * scale_, 0);
                    }
                    readonly property real targetWidth: Math.round(((windowData && windowData.size && windowData.size[0] !== undefined ? windowData.size[0] : 100) || 100) * scale_)
                    readonly property real targetHeight: Math.round(((windowData && windowData.size && windowData.size[1] !== undefined ? windowData.size[1] : 100) || 100) * scale_)
                    readonly property bool compactMode: targetHeight < 60 || targetWidth < 60
                    readonly property string iconPath: AppSearch.guessIcon((windowData && windowData.class !== undefined ? windowData.class : "") || "")
                    readonly property int calculatedRadius: Styling.radius(-2)
                    readonly property bool isMatched: root.checkWindowMatched((windowData && windowData.address !== undefined ? windowData.address : undefined))
                    readonly property bool isSelected: root.checkWindowSelected((windowData && windowData.address !== undefined ? windowData.address : undefined))

                    x: baseX
                    y: baseY
                    width: targetWidth
                    height: targetHeight
                    z: dragging ? 1000 : 1

                    property bool hovered: false
                    property bool dragging: false
                    property real initX: baseX
                    property real initY: baseY
                    property Item originalParent: null
                    property point pressPos: Qt.point(0, 0)
                    readonly property real dragThreshold: 5

                    Drag.active: dragging
                    Drag.source: windowDelegate
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    // Timer to reset override position after AxctlService update
                    Timer {
                        id: resetOverrideTimer
                        interval: 200
                        onTriggered: {
                            windowDelegate.useOverridePosition = false;
                        }
                    }

                    onWindowDataChanged: {
                        if (useOverridePosition) {
                            resetOverrideTimer.restart();
                        }
                    }

                    Behavior on x {
                        enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0 && !windowDelegate.dragging && !windowDelegate.useOverridePosition
                        NumberAnimation {
                            duration: (Config.animDuration !== undefined ? Config.animDuration : 0)
                            easing.type: Easing.OutQuart
                        }
                    }
                    Behavior on y {
                        enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0 && !windowDelegate.dragging && !windowDelegate.useOverridePosition
                        NumberAnimation {
                            duration: (Config.animDuration !== undefined ? Config.animDuration : 0)
                            easing.type: Easing.OutQuart
                        }
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: windowDelegate.calculatedRadius
                        antialiasing: true
                        color: "transparent"
                        border.color: Colors.background
                        border.width: 0

                        ScreencopyView {
                            id: windowPreview
                            anchors.fill: parent
                            captureSource: Config.performance.windowPreview && GlobalStates.overviewOpen ? windowDelegate.toplevel : null
                            live: GlobalStates.overviewOpen
                            visible: Config.performance.windowPreview
                        }
                    }

                    Rectangle {
                        id: previewBackground
                        anchors.fill: parent
                        radius: windowDelegate.calculatedRadius
                        color: windowDelegate.dragging ? Colors.surfaceBright : windowDelegate.hovered ? Colors.surface : Colors.background
                        border.color: windowDelegate.isSelected ? Colors.tertiary : windowDelegate.isMatched ? Styling.srItem("overprimary") : Styling.srItem("overprimary")
                        border.width: windowDelegate.isSelected ? 3 : windowDelegate.isMatched ? 2 : (windowDelegate.hovered ? 2 : 0)
                        visible: !Config.performance.windowPreview

                        Behavior on color {
                            enabled: (Config.animDuration !== undefined ? Config.animDuration : 0) > 0
                            ColorAnimation {
                                duration: (Config.animDuration !== undefined ? Config.animDuration : 0) / 2
                            }
                        }
                    }

                    Image {
                        mipmap: true
                        id: windowIcon
                        readonly property real iconSize: Math.round(Math.min(windowDelegate.targetWidth, windowDelegate.targetHeight) * (windowDelegate.compactMode ? 0.6 : 0.35))
                        anchors.centerIn: parent
                        width: iconSize
                        height: iconSize
                        source: Quickshell.iconPath(windowDelegate.iconPath, "image-missing")
                        sourceSize: Qt.size(iconSize, iconSize)
                        asynchronous: true
                        visible: !Config.performance.windowPreview
                        z: 10
                    }

                    Rectangle {
                        id: previewOverlay
                        anchors.fill: parent
                        radius: windowDelegate.calculatedRadius
                        color: windowDelegate.dragging ? Qt.rgba(Colors.surfaceContainerHighest.r, Colors.surfaceContainerHighest.g, Colors.surfaceContainerHighest.b, 0.5) : windowDelegate.hovered ? Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.2) : "transparent"
                        border.color: windowDelegate.isSelected ? Colors.tertiary : windowDelegate.isMatched ? Styling.srItem("overprimary") : Styling.srItem("overprimary")
                        border.width: windowDelegate.isSelected ? 3 : windowDelegate.isMatched ? 2 : (windowDelegate.hovered ? 2 : 0)
                        visible: Config.performance.windowPreview && (windowDelegate.hovered || windowDelegate.dragging || windowDelegate.isMatched || windowDelegate.isSelected)
                        z: 5
                    }

                    Image {
                        mipmap: true
                        visible: windowPreview.hasContent && !windowDelegate.compactMode && Config.performance.windowPreview
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 4
                        width: 16
                        height: 16
                        source: Quickshell.iconPath(windowDelegate.iconPath, "image-missing")
                        sourceSize: Qt.size(16, 16)
                        asynchronous: true
                        opacity: 0.8
                        z: 10
                    }

                    // XWayland indicator
                    Rectangle {
                        visible: (windowDelegate.windowData && windowDelegate.windowData.xwayland !== undefined ? windowDelegate.windowData.xwayland : false) || false
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 2
                        width: 6
                        height: 6
                        radius: 3
                        color: Colors.error
                        z: 10
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        drag.target: windowDelegate.dragging ? windowDelegate : null
                        drag.threshold: 0

                        property real rightDragStartX: 0
                        property real rightScrollStartOffset: 0

                        onEntered: windowDelegate.hovered = true
                        onExited: windowDelegate.hovered = false

                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                windowDelegate.pressPos = Qt.point(mouse.x, mouse.y);
                                windowDelegate.initX = windowDelegate.x;
                                windowDelegate.initY = windowDelegate.y;
                            } else if (mouse.button === Qt.RightButton && root.contentBounds.hasOverflow) {
                                rightDragStartX = mouse.x;
                                rightScrollStartOffset = root.horizontalScrollOffset;
                                root.isScrollDragging = true;
                            }
                        }

                        onPositionChanged: mouse => {
                            if (root.isScrollDragging && (mouse.buttons & Qt.RightButton) && root.contentBounds.hasOverflow) {
                                const delta = mouse.x - rightDragStartX;
                                root.horizontalScrollOffset = root.clampHorizontalScroll(rightScrollStartOffset + delta);
                                return;
                            }

                            if (!(mouse.buttons & Qt.LeftButton))
                                return;

                            if (!windowDelegate.dragging) {
                                const dx = mouse.x - windowDelegate.pressPos.x;
                                const dy = mouse.y - windowDelegate.pressPos.y;
                                const distance = Math.sqrt(dx * dx + dy * dy);

                                if (distance > windowDelegate.dragThreshold) {
                                    windowDelegate.dragging = true;
                                    root.draggingFromWorkspace = root.workspaceId;

                                    if (root.dragOverlay) {
                                        windowDelegate.originalParent = windowDelegate.parent;
                                        const globalPos = windowDelegate.mapToItem(root.dragOverlay, 0, 0);
                                        windowDelegate.parent = root.dragOverlay;
                                        windowDelegate.x = globalPos.x;
                                        windowDelegate.y = globalPos.y;
                                    }
                                }
                            } else {
                                if (root.overviewRoot && root.overviewRoot.getWorkspaceAtY) {
                                    const globalPos = dragArea.mapToItem(null, mouse.x, mouse.y);
                                    const targetWs = root.overviewRoot.getWorkspaceAtY(globalPos.y);
                                    if (targetWs !== -1 && targetWs !== root.workspaceId) {
                                        root.draggingTargetWorkspace = targetWs;
                                    } else {
                                        root.draggingTargetWorkspace = -1;
                                    }
                                }
                            }
                        }

                        onReleased: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (windowDelegate.dragging) {
                                    windowDelegate.dragging = false;

                                    let targetWs = root.workspaceId;
                                    if (root.overviewRoot && root.overviewRoot.getWorkspaceAtY) {
                                        const globalPos = dragArea.mapToItem(null, mouse.x, mouse.y);
                                        const calculatedWs = root.overviewRoot.getWorkspaceAtY(globalPos.y);
                                        if (calculatedWs !== -1) {
                                            targetWs = calculatedWs;
                                        }
                                    }

                                    if (targetWs !== root.workspaceId) {
                                        if ((windowDelegate.windowData && windowDelegate.windowData.floating !== undefined ? windowDelegate.windowData.floating : false)) {
                                            const draggedX = windowDelegate.x;
                                            const draggedY = windowDelegate.y;
                                            
                                            const workspaceGlobalPos = windowsContainer.mapToItem(root.dragOverlay, 0, 0);
                                            const relativeX = draggedX - workspaceGlobalPos.x;
                                            const relativeY = draggedY - workspaceGlobalPos.y;
                                            
                                            const workspaceX = relativeX - root.horizontalScrollOffset - root.viewportOffset;
                                            const workspaceY = relativeY;
                                            
                                            const monitorWidth = ((monitorData && monitorData.width !== undefined ? monitorData.width : 1920) || 1920) / ((monitorData && monitorData.scale !== undefined ? monitorData.scale : 1.0) || 1.0);
                                            const monitorHeight = ((monitorData && monitorData.height !== undefined ? monitorData.height : 1080) || 1080) / ((monitorData && monitorData.scale !== undefined ? monitorData.scale : 1.0) || 1.0);
                                            
                                            let adjustedMonitorWidth = monitorWidth;
                                            let adjustedMonitorHeight = monitorHeight;
                                            if (barPosition === "left" || barPosition === "right") {
                                                adjustedMonitorWidth -= barReserved;
                                            }
                                            if (barPosition === "top" || barPosition === "bottom") {
                                                adjustedMonitorHeight -= barReserved;
                                            }
                                            
                                            const actualX = workspaceX / scale_;
                                            const actualY = workspaceY / scale_;
                                            
                                            const percentageX = Math.round((actualX / adjustedMonitorWidth) * 100);
                                            const percentageY = Math.round((actualY / adjustedMonitorHeight) * 100);
                                            
                                            AxctlService.dispatch(`movetoworkspacesilent ${targetWs}, address:${(windowDelegate.windowData && windowDelegate.windowData.address !== undefined ? windowDelegate.windowData.address : "")}`);
                                            AxctlService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${(windowDelegate.windowData && windowDelegate.windowData.address !== undefined ? windowDelegate.windowData.address : "")}`);
                                            
                                            CompositorData.updateWindowList();
                                        } else {
                                            AxctlService.dispatch(`movetoworkspacesilent ${targetWs}, address:${(windowDelegate.windowData && windowDelegate.windowData.address !== undefined ? windowDelegate.windowData.address : "")}`);
                                            
                                            CompositorData.updateWindowList();
                                        }
                                        
                                        if (windowDelegate.originalParent) {
                                            windowDelegate.parent = windowDelegate.originalParent;
                                            windowDelegate.originalParent = null;
                                        }
                                        windowDelegate.x = windowDelegate.initX;
                                        windowDelegate.y = windowDelegate.initY;
                                        
                                    } else if ((windowDelegate.windowData && windowDelegate.windowData.floating !== undefined ? windowDelegate.windowData.floating : false) && (windowDelegate.x !== windowDelegate.initX || windowDelegate.y !== windowDelegate.initY)) {
                                        
                                        const draggedX = windowDelegate.x;
                                        const draggedY = windowDelegate.y;
                                        
                                        const workspaceGlobalPos = windowsContainer.mapToItem(root.dragOverlay, 0, 0);
                                        
                                        const relativeX = draggedX - workspaceGlobalPos.x;
                                        const relativeY = draggedY - workspaceGlobalPos.y;
                                        
                                        const workspaceX = relativeX - root.horizontalScrollOffset - root.viewportOffset;
                                        const workspaceY = relativeY;
                                        
                                        const monitorWidth = ((monitorData && monitorData.width !== undefined ? monitorData.width : 1920) || 1920) / ((monitorData && monitorData.scale !== undefined ? monitorData.scale : 1.0) || 1.0);
                                        const monitorHeight = ((monitorData && monitorData.height !== undefined ? monitorData.height : 1080) || 1080) / ((monitorData && monitorData.scale !== undefined ? monitorData.scale : 1.0) || 1.0);
                                        
                                        let adjustedMonitorWidth = monitorWidth;
                                        let adjustedMonitorHeight = monitorHeight;
                                        if (barPosition === "left" || barPosition === "right") {
                                            adjustedMonitorWidth -= barReserved;
                                        }
                                        if (barPosition === "top" || barPosition === "bottom") {
                                            adjustedMonitorHeight -= barReserved;
                                        }
                                        
                                        const actualX = workspaceX / scale_;
                                        const actualY = workspaceY / scale_;
                                        
                                        const percentageX = Math.round((actualX / adjustedMonitorWidth) * 100);
                                        const percentageY = Math.round((actualY / adjustedMonitorHeight) * 100);
                                        
                                        AxctlService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${(windowDelegate.windowData && windowDelegate.windowData.address !== undefined ? windowDelegate.windowData.address : "")}`);
                                        
                                        CompositorData.updateWindowList();
                                        
                                        if (windowDelegate.originalParent) {
                                            windowDelegate.parent = windowDelegate.originalParent;
                                            windowDelegate.originalParent = null;
                                        }
                                        
                                        windowDelegate.overrideBaseX = relativeX;
                                        windowDelegate.overrideBaseY = relativeY;
                                        windowDelegate.useOverridePosition = true;
                                        
                                        windowDelegate.x = relativeX;
                                        windowDelegate.y = relativeY;
                                        
                                        resetOverrideTimer.restart();
                                    } else {
                                        if (windowDelegate.originalParent) {
                                            windowDelegate.parent = windowDelegate.originalParent;
                                            windowDelegate.originalParent = null;
                                        }
                                        windowDelegate.x = windowDelegate.initX;
                                        windowDelegate.y = windowDelegate.initY;
                                    }

                                    root.draggingFromWorkspace = -1;
                                    root.draggingTargetWorkspace = -1;
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                root.isScrollDragging = false;
                            }
                        }

                        onClicked: mouse => {
                            if (!windowDelegate.windowData)
                                return;
                            if (mouse.button === Qt.LeftButton && !windowDelegate.dragging) {
                                AxctlService.dispatch(`focuswindow address:${windowDelegate.windowData.address}`);
                            } else if (mouse.button === Qt.MiddleButton) {
                                AxctlService.dispatch(`closewindow address:${windowDelegate.windowData.address}`);
                            }
                        }

                        onDoubleClicked: mouse => {
                            if (!windowDelegate.windowData)
                                return;
                            if (mouse.button === Qt.LeftButton) {
                                Visibilities.setActiveModule("", true);
                                Qt.callLater(() => {
                                    AxctlService.dispatch(`focuswindow address:${windowDelegate.windowData.address}`);
                                });
                            }
                        }
                    }

                    Rectangle {
                        visible: dragArea.containsMouse && !windowDelegate.dragging && windowDelegate.windowData
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tooltipText.implicitWidth + 16
                        height: tooltipText.implicitHeight + 8
                        color: Colors.inverseSurface
                        radius: Styling.radius(0) / 2
                        opacity: 0.9
                        z: 1000

                        Text {
                            id: tooltipText
                            anchors.centerIn: parent
                            text: `${(windowDelegate.windowData && windowDelegate.windowData.title !== undefined ? windowDelegate.windowData.title : "") || ""}\n[${(windowDelegate.windowData && windowDelegate.windowData.class !== undefined ? windowDelegate.windowData.class : "") || ""}]${(windowDelegate.windowData && windowDelegate.windowData.xwayland !== undefined ? windowDelegate.windowData.xwayland : false) ? " [XWayland]" : ""}`
                            font.family: Config.theme.font
                            font.pixelSize: 10
                            color: Colors.inverseOnSurface
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
