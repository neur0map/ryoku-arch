import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.dashboard.modules.theme
import qs.dashboard.modules.components
import qs.dashboard.modules.globals
import qs.dashboard.modules.services
import qs.dashboard.modules.notch
import qs.dashboard.modules.widgets.dashboard.widgets
import qs.dashboard.modules.widgets.dashboard.metrics
import qs.dashboard.config

NotchAnimationBehavior {
    id: root

    property int leftPanelWidth

    property var state: QtObject {
        property int currentTab: GlobalStates.dashboardCurrentTab
    }

    readonly property var tabModel: [Icons.widgets, Icons.heartbeat]
    readonly property int tabCount: tabModel.length
    readonly property int tabSpacing: 8

    readonly property int tabWidth: 48
    readonly property real nonAnimWidth: (state.currentTab === 0 ? 600 : 400) + tabWidth + 16

    implicitWidth: nonAnimWidth
    implicitHeight: 430

    property var loadedTabs: ({0: true})

    property var lruAccessOrder: [0]
    property var lruTabsLoaded: ({0: true})

    function updateLRUAccess(tabIndex) {
        const idx = lruAccessOrder.indexOf(tabIndex);
        if (idx !== -1) {
            lruAccessOrder.splice(idx, 1);
        }
        lruAccessOrder.push(tabIndex);
        updateLoadedTabs();
    }

    // Determine which tabs should be loaded based on LRU and config
    function updateLoadedTabs() {
        let newLoadedTabs = {};
        
        // Always load tab 0 (WidgetsTab) to avoid "jumpy" opening
        newLoadedTabs[0] = true;
        
        newLoadedTabs[root.state.currentTab] = true;

        if (Config.performance.dashboardPersistTabs) {
            const maxTabs = Math.max(1, Config.performance.dashboardMaxPersistentTabs);
            const startIdx = Math.max(0, lruAccessOrder.length - maxTabs);
            for (let i = startIdx; i < lruAccessOrder.length; i++) {
                newLoadedTabs[lruAccessOrder[i]] = true;
            }
        }

        lruTabsLoaded = newLoadedTabs;
    }

    function shouldTabBeLoaded(tabIndex) {
        if (tabIndex === 0) return true;

        if (Config.performance.dashboardPersistTabs) {
            return lruTabsLoaded[tabIndex] === true;
        } else {
            return root.state.currentTab === tabIndex;
        }
    }

    focus: true

    // Usar el comportamiento estándar de animaciones del notch
    // GlobalStates.dashboardOpen is driven by ryoku's island-open state
    // (GlobalStates.ryokuDashboardOpen, set from shell/modules/island/Content.qml);
    // the axctl-based Visibilities path is not used here.
    isVisible: GlobalStates.dashboardOpen

    Component.onCompleted: {
        root.state.currentTab = GlobalStates.dashboardCurrentTab;
    }

    onIsVisibleChanged: {
        if (isVisible) {
            // Check if current item supports focus, otherwise default logic for launcher
            if (stack.currentItem && stack.currentItem.focusSearchInput) {
                focusUnifiedLauncherTimer.restart();
            } else if (GlobalStates.dashboardCurrentTab === 0) {
                Notifications.hideAllPopups();
                focusUnifiedLauncherTimer.restart();
            }
        } else {
            GlobalStates.clearLauncherState();
        }
    }

    Timer {
        id: focusUnifiedLauncherTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (stack.currentItem && stack.currentItem.focusSearchInput) {
                stack.currentItem.focusSearchInput();
            }
        }
    }

    Connections {
        target: GlobalStates
        function onDashboardCurrentTabChanged() {
            if (GlobalStates.dashboardCurrentTab !== root.state.currentTab) {
                stack.navigateToTab(GlobalStates.dashboardCurrentTab);
            }
        }

        function onLauncherSearchTextChanged() {
            if (isVisible && GlobalStates.dashboardCurrentTab === 0) {
                focusUnifiedLauncherTimer.restart();
            }
        }
    }

    Row {
        id: mainLayout
        anchors.fill: parent
        spacing: 8

        Item {
            id: tabsContainer
            width: root.tabWidth
            height: parent.height

            WheelHandler {
                id: wheelHandler
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    let scrollUp = event.angleDelta.y > 0;
                    let newIndex = root.state.currentTab;

                    if (scrollUp && newIndex > 0) {
                        newIndex = newIndex - 1;
                    } else if (!scrollUp && newIndex < root.tabCount - 1) {
                        newIndex = newIndex + 1;
                    }

                    if (newIndex !== root.state.currentTab) {
                        stack.navigateToTab(newIndex);
                    }
                }
            }

            StyledRect {
                id: tabHighlight
                variant: "primary"
                width: parent.width
                radius: Styling.radius(4)
                z: 0

                property real idx1: root.state.currentTab
                property real idx2: root.state.currentTab

                function getYForIndex(idx) {
                    if (idx <= 2) {
                        return idx * (width + root.tabSpacing);
                    } else {
                        return controlsButtonContainer.y;
                    }
                }

                property real targetY1: getYForIndex(idx1)
                property real targetY2: getYForIndex(idx2)

                property real animatedY1: targetY1
                property real animatedY2: targetY2

                x: 0
                y: Math.min(animatedY1, animatedY2)
                height: Math.abs(animatedY2 - animatedY1) + width

                Behavior on animatedY1 {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration / 3
                        easing.type: Easing.OutSine
                    }
                }
                Behavior on animatedY2 {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutSine
                    }
                }

                onTargetY1Changed: animatedY1 = targetY1
                onTargetY2Changed: animatedY2 = targetY2
            }

            Column {
                id: tabs
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: root.tabSpacing

                Repeater {
                    model: root.tabModel

                    Button {
                        required property int index
                        required property string modelData

                        text: modelData
                        flat: true
                        width: tabsContainer.width
                        height: width
                        // implicitHeight: (tabsContainer.height - root.tabSpacing * (root.tabCount - 1)) / root.tabCount

                        background: Rectangle {
                            color: "transparent"
                            radius: Styling.radius(4)
                        }

                        contentItem: Text {
                            text: parent.text
                            textFormat: Text.RichText
                            color: root.state.currentTab === index ? Styling.srItem("primary") : Colors.overBackground
                            // font.family: Config.theme.font
                            font.family: Icons.font
                            // font.pixelSize: Config.theme.fontSize
                            font.pixelSize: 20
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            Behavior on color {
                                enabled: Config.animDuration > 0
                                ColorAnimation {
                                    duration: Config.animDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        onClicked: stack.navigateToTab(index)
                    }
                }
            }

            StyledRect {
                id: controlsButtonContainer
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: width
                radius: Styling.radius(4)
                variant: controlsButton.hovered ? "focus" : "common"
                z: -1

                opacity: GlobalStates.settingsWindowVisible ? 0 : 1

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Config.animDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Button {
                id: controlsButton
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: width
                flat: true
                hoverEnabled: true
                z: 1

                background: Rectangle {
                    color: "transparent"
                }

                contentItem: Text {
                    text: Icons.gear
                    font.family: Icons.font
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    color: GlobalStates.settingsWindowVisible ? Styling.srItem("primary") : Colors.overBackground
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Open ryoku's settings panel. `ryoku-shell settings` -> controlCenter toggle.
                onClicked: Quickshell.execDetached(["ryoku-shell", "settings"])
            }
        }

        Separator {
            width: 2
            height: parent.height
            vert: true
        }

        Rectangle {
            id: viewWrapper

            color: "transparent"

            width: parent.width - root.tabWidth - 2 - 16
            height: parent.height

            clip: true

            Item {
                id: stack
                anchors.fill: parent

                property int currentIndex: GlobalStates.dashboardCurrentTab

                Connections {
                    target: GlobalStates
                    function onDashboardCurrentTabChanged() {
                        stack.navigateToTab(GlobalStates.dashboardCurrentTab);
                    }
                }

                function navigateToTab(index) {
                    if (index >= 0 && index < root.tabCount && index !== root.state.currentTab) {
                        if (root.state.currentTab === 0 && index !== 0) {
                            GlobalStates.clearLauncherState();
                        }

                        root.state.currentTab = index;
                        GlobalStates.dashboardCurrentTab = index;
                        
                        // Update LRU when tab is accessed
                        root.updateLRUAccess(index);

                        if (index === 0) {
                            Notifications.hideAllPopups();
                            focusUnifiedLauncherTimer.restart();
                        }
                    }
                }

                component TabLoader : Loader {
                    anchors.fill: parent
                    // Load based on LRU strategy or if currently active
                    active: root.shouldTabBeLoaded(index) || root.state.currentTab === index
                    
                    visible: root.state.currentTab === index
                    
                    opacity: visible ? 1 : 0
                    transform: Translate {
                        y: visible ? 0 : (root.state.currentTab > index ? -20 : 20)
                        Behavior on y {
                             enabled: Config.animDuration > 0
                             NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } 
                        }
                    }

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart }
                    }

                    onLoaded: {
                        if (visible && item && item.focusSearchInput) {
                            focusUnifiedLauncherTimer.restart();
                        }
                    }
                    
                    onVisibleChanged: {
                        if (visible && item && item.focusSearchInput) {
                            focusUnifiedLauncherTimer.restart();
                        }
                    }
                }

                TabLoader {
                    property int index: 0
                    sourceComponent: unifiedLauncherComponent
                    z: visible ? 1 : 0
                }

                TabLoader {
                    property int index: 1
                    sourceComponent: metricsComponent
                    z: visible ? 1 : 0
                }

                property var currentItem: {
                    switch(root.state.currentTab) {
                        case 0: return children[0].item;
                        case 1: return children[1].item;
                        default: return null;
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    property real startY: 0
                    property real startX: 0
                    property bool swiping: false
                    property real swipeThreshold: 50
                    
                    propagateComposedEvents: true
                    preventStealing: false

                    onPressed: mouse => {
                        startY = mouse.y;
                        startX = mouse.x;
                        swiping = false;
                        mouse.accepted = false;
                    }

                    onPositionChanged: mouse => {
                        let deltaY = mouse.y - startY;
                        let deltaX = Math.abs(mouse.x - startX);

                        if (Math.abs(deltaY) > 20 && deltaX < 30) {
                            swiping = true;
                        }
                    }

                    onReleased: mouse => {
                        if (swiping) {
                            let deltaY = mouse.y - startY;

                            if (deltaY < -swipeThreshold && root.state.currentTab < root.tabCount - 1) {
                                stack.navigateToTab(root.state.currentTab + 1);
                            } else if (deltaY > swipeThreshold && root.state.currentTab > 0) {
                                stack.navigateToTab(root.state.currentTab - 1);
                            }
                        }
                        swiping = false;
                        mouse.accepted = false;
                    }
                }
            }
        }
    }

    Shortcut {
        id: nextTabShortcut
        sequence: "Ctrl+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let nextIndex = (root.state.currentTab + 1) % root.tabCount;
            stack.navigateToTab(nextIndex);
        }
    }

    Shortcut {
        id: prevTabShortcut
        sequence: "Ctrl+Shift+Tab"
        enabled: GlobalStates.dashboardOpen

        onActivated: {
            let prevIndex = root.state.currentTab - 1;
            if (prevIndex < 0) {
                prevIndex = root.tabCount - 1;
            }
            stack.navigateToTab(prevIndex);
        }
    }

    property real animatedWidth: implicitWidth
    property real animatedHeight: implicitHeight

    width: animatedWidth
    height: animatedHeight

    onImplicitWidthChanged: animatedWidth = implicitWidth
    onImplicitHeightChanged: animatedHeight = implicitHeight

    Behavior on animatedWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Behavior on animatedHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }

    Component {
        id: unifiedLauncherComponent
        WidgetsTab {
            leftPanelWidth: root.leftPanelWidth
        }
    }

    Component {
        id: metricsComponent
        MetricsTab {}
    }
}
