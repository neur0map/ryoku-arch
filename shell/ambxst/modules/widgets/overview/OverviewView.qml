import QtQuick
import qs.ambxst.modules.widgets.overview
import qs.ambxst.modules.services
import qs.ambxst.modules.globals
import qs.ambxst.config

Item {
    id: root
    property var currentScreen

    readonly property bool isScrollingLayout: GlobalStates.compositorLayout === "scrolling"

    implicitWidth: overviewLoader.item ? overviewLoader.item.implicitWidth : 400
    implicitHeight: overviewLoader.item ? overviewLoader.item.implicitHeight : 300

    readonly property var flickable: isScrollingLayout && overviewLoader.item ? overviewLoader.item.flickable : null
    readonly property bool needsScrollbar: isScrollingLayout && overviewLoader.item ? overviewLoader.item.needsScrollbar : false

    // Manual scrolling state - passed through to ScrollingOverview
    property bool isManualScrolling: false
    onIsManualScrollingChanged: {
        if (isScrollingLayout && overviewLoader.item) {
            overviewLoader.item.isManualScrolling = isManualScrolling;
        }
    }

    Behavior on implicitWidth {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutQuart
        }
    }

    Loader {
        id: overviewLoader
        anchors.centerIn: parent
        active: true
        
        sourceComponent: isScrollingLayout ? scrollingOverviewComponent : standardOverviewComponent
    }

    Component {
        id: standardOverviewComponent
        Overview {
            currentScreen: root.currentScreen

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Visibilities.setActiveModule("");
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                forceActiveFocus();
            }
        }
    }

    Component {
        id: scrollingOverviewComponent
        ScrollingOverview {
            currentScreen: root.currentScreen

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    Visibilities.setActiveModule("");
                    event.accepted = true;
                }
            }

            Component.onCompleted: {
                forceActiveFocus();
            }
        }
    }

    readonly property var matchingWindows: overviewLoader.item ? overviewLoader.item.matchingWindows : []
    readonly property int selectedMatchIndex: overviewLoader.item ? overviewLoader.item.selectedMatchIndex : 0

    property string searchQuery: ""
    onSearchQueryChanged: {
        if (overviewLoader.item) {
            overviewLoader.item.searchQuery = searchQuery;
        }
    }

    function resetSearch() {
        searchQuery = "";
        if (overviewLoader.item && overviewLoader.item.resetSearch) {
            overviewLoader.item.resetSearch();
        }
    }

    function navigateToSelectedWindow() {
        if (overviewLoader.item && overviewLoader.item.navigateToSelectedWindow) {
            overviewLoader.item.navigateToSelectedWindow();
        }
    }

    function selectNextMatch() {
        if (overviewLoader.item && overviewLoader.item.selectNextMatch) {
            overviewLoader.item.selectNextMatch();
        }
    }

    function selectPrevMatch() {
        if (overviewLoader.item && overviewLoader.item.selectPrevMatch) {
            overviewLoader.item.selectPrevMatch();
        }
    }
}
