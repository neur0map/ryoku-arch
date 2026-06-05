import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.ambxst.modules.theme
import qs.ambxst.modules.components
import qs.ambxst.modules.globals
import qs.ambxst.modules.services
import qs.ambxst.config

FocusScope {
    id: wallpapersTabRoot

    property string searchText: ""
    property int selectedIndex: GlobalStates.wallpaperSelectedIndex

    function setSelectedIndex(newIndex: int) {
        GlobalStates.wallpaperSelectedIndex = newIndex;
        selectedIndex = newIndex;
    }

    readonly property string currentScreenName: AxctlService.focusedMonitor ? AxctlService.focusedMonitor.name : ""

    property bool isPerScreen: {
        if (!GlobalStates.wallpaperManager || currentScreenName === "") return false;
        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
        return perScreen[currentScreenName] !== undefined;
    }

    function togglePerScreenMode() {
        if (!GlobalStates.wallpaperManager || currentScreenName === "") return;
        
        if (isPerScreen) {
            GlobalStates.wallpaperManager.clearPerScreenWallpaper(currentScreenName);
        } else {
            let currentWall = GlobalStates.wallpaperManager.currentWallpaper;
            if (currentWall) {
                GlobalStates.wallpaperManager.setWallpaper(currentWall, currentScreenName);
            }
        }
    }

    property var activeFilters: []

    readonly property int gridColumns: 7
    readonly property int wallpaperMargin: 4

    property var focusableElements: [
        {
            id: "perScreenCheckbox",
            focusFunc: function () {
                perScreenCheckboxContainer.keyboardNavigationActive = true;
                perScreenCheckbox.forceActiveFocus();
            }
        },
        {
            id: "oledCheckbox",
            focusFunc: function () {
                oledCheckboxContainer.keyboardNavigationActive = true;
                oledCheckbox.forceActiveFocus();
            }
        },
        {
            id: "tintCheckbox",
            focusFunc: function () {
                tintCheckboxContainer.keyboardNavigationActive = true;
                tintCheckbox.forceActiveFocus();
            }
        },
        {
            id: "schemeSelector",
            focusFunc: function () {
                schemeSelector.openAndFocus();
            }
        },
        {
            id: "filters",
            focusFunc: function () {
                wallpapersFilterBar.focusFilters();
            }
        }
    ]

    property int currentFocusIndex: -1

    function focusSearch() {
        currentFocusIndex = -1;
        wallpaperSearchInput.focusInput();

        if (selectedIndex === -1 && filteredWallpapers.length > 0) {
            const currentIndex = findCurrentWallpaperIndex();
            setSelectedIndex(currentIndex !== -1 ? currentIndex : 0);
        }
    }

    function focusSearchInput() {
        focusSearch();
    }

    function focusFilters() {
        currentFocusIndex = 2;
        focusableElements[2].focusFunc();
    }

    function focusNextElement() {
        if (currentFocusIndex === -1) {
            currentFocusIndex = 0;
            focusableElements[currentFocusIndex].focusFunc();
        } else if (currentFocusIndex === focusableElements.length - 1) {
            focusSearch();
        } else {
            currentFocusIndex++;
            focusableElements[currentFocusIndex].focusFunc();
        }
    }

    function focusPreviousElement() {
        if (currentFocusIndex === -1 || currentFocusIndex === 0) {
            focusSearch();
        } else {
            currentFocusIndex--;
            focusableElements[currentFocusIndex].focusFunc();
        }
    }

    function centerCurrentWallpaper() {
        const currentIndex = findCurrentWallpaperIndex();
        if (currentIndex !== -1) {
            setSelectedIndex(currentIndex);

            const currentRow = Math.floor(currentIndex / wallpapersTabRoot.gridColumns);
            const rowStartIndex = currentRow * wallpapersTabRoot.gridColumns;

            wallpaperGrid.positionViewAtIndex(rowStartIndex, GridView.Center);
        }
    }

    function findCurrentWallpaperIndex() {
        if (!GlobalStates.wallpaperManager) {
            return -1;
        }

        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
        let currentWallpaper = "";
        
        if (currentScreenName !== "" && perScreen[currentScreenName] !== undefined) {
            currentWallpaper = perScreen[currentScreenName];
        } else {
            currentWallpaper = GlobalStates.wallpaperManager.currentWallpaper;
        }

        if (!currentWallpaper) {
            return -1;
        }

        return filteredWallpapers.indexOf(currentWallpaper);
    }

    // Llama a focusSearch una vez que el componente se ha completado.
    Component.onCompleted: {
        centerTimer.start();
    }

    onVisibleChanged: {
        if (visible) {
            if (GlobalStates.wallpaperManager) {
                console.log("WallpapersTab became visible, updating subfolders");
                GlobalStates.wallpaperManager.scanSubfolders();
            }
            centerTimer.restart();
        }
    }

    Timer {
        id: centerTimer
        interval: 50
        repeat: false
        onTriggered: {
            centerCurrentWallpaper();
            focusSearch();
        }
    }

    property var filteredWallpapers: {
        if (!GlobalStates.wallpaperManager)
            return [];

        let wallpapers = GlobalStates.wallpaperManager.wallpaperPaths;

        if (searchText.length > 0) {
            wallpapers = wallpapers.filter(function (path) {
                const fileName = path.split('/').pop().toLowerCase();
                return fileName.includes(searchText.toLowerCase());
            });
        }

        if (activeFilters.length > 0) {
            wallpapers = wallpapers.filter(function (path) {
                const fileType = GlobalStates.wallpaperManager.getFileType(path);
                const subfolder = GlobalStates.wallpaperManager.getSubfolderFromPath(path);

                for (var i = 0; i < activeFilters.length; i++) {
                    var filter = activeFilters[i];
                    if (filter === fileType) {
                        return true;
                    }
                    if (filter.startsWith("subfolder_") && subfolder === filter.replace("subfolder_", "")) {
                        return true;
                    }
                }
                return false;
            });
        }

        return wallpapers;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            spacing: 8
            z: 1000

            SearchInput {
                id: wallpaperSearchInput
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: searchText
                placeholderText: "Search wallpapers..."
                iconText: ""
                clearOnEscape: false
                handleTabNavigation: true
                disableCursorNavigation: true
                radius: Styling.radius(4)

                onSearchTextChanged: text => {
                    searchText = text;
                    if (text.length > 0 && filteredWallpapers.length > 0) {
                        setSelectedIndex(0);
                    } else {
                        setSelectedIndex(-1);
                    }
                }

                onEscapePressed: {
                    Visibilities.setActiveModule("");
                }

                onTabPressed: {
                    focusNextElement();
                }

                onShiftTabPressed: {
                    focusPreviousElement();
                }

                onDownPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            let newIndex = selectedIndex + wallpapersTabRoot.gridColumns;
                            if (newIndex >= filteredWallpapers.length) {
                                newIndex = filteredWallpapers.length - 1;
                            }
                            setSelectedIndex(newIndex);
                        } else if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        }
                    }
                }
                onUpPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        } else if (selectedIndex >= wallpapersTabRoot.gridColumns) {
                            setSelectedIndex(selectedIndex - wallpapersTabRoot.gridColumns);
                        }
                    }
                }
                onLeftPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        } else if (selectedIndex > 0) {
                            setSelectedIndex(selectedIndex - 1);
                        }
                    }
                }
                onRightPressed: {
                    if (filteredWallpapers.length > 0) {
                        if (selectedIndex < filteredWallpapers.length - 1) {
                            setSelectedIndex(selectedIndex + 1);
                        } else if (selectedIndex === -1) {
                            setSelectedIndex(0);
                        }
                    }
                }
                onAccepted: {
                    if (selectedIndex >= 0 && selectedIndex < filteredWallpapers.length) {
                        let selectedWallpaper = filteredWallpapers[selectedIndex];
                        if (selectedWallpaper && GlobalStates.wallpaperManager) {
                            if (isPerScreen && currentScreenName !== "") {
                                GlobalStates.wallpaperManager.setWallpaper(selectedWallpaper, currentScreenName);
                            } else {
                                GlobalStates.wallpaperManager.setWallpaper(selectedWallpaper);
                            }
                        }
                    }
                }
            }

            Item {
                id: perScreenCheckboxContainer
                Layout.preferredWidth: 120
                Layout.preferredHeight: 48

                property bool keyboardNavigationActive: false

                StyledRect {
                    variant: perScreenCheckboxContainer.keyboardNavigationActive && perScreenCheckbox.activeFocus ? "focus" : "pane"
                    anchors.fill: parent
                    radius: Styling.radius(4)
                    opacity: 1.0

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Colors.background
                            radius: Styling.radius(0)

                            Text {
                                anchors.fill: parent
                                text: currentScreenName
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                
                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        Item {
                            id: perScreenCheckbox
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            
                            property bool checked: isPerScreen

                            onActiveFocusChanged: {
                                if (!activeFocus) {
                                    perScreenCheckboxContainer.keyboardNavigationActive = false;
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    perScreenCheckboxContainer.keyboardNavigationActive = false;
                                    if (event.modifiers & Qt.ShiftModifier) {
                                        wallpapersTabRoot.focusPreviousElement();
                                    } else {
                                        wallpapersTabRoot.focusNextElement();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    togglePerScreenMode();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    perScreenCheckboxContainer.keyboardNavigationActive = false;
                                    focusSearch();
                                    event.accepted = true;
                                }
                            }

                            Item {
                                anchors.fill: parent

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    color: Colors.background
                                    visible: !perScreenCheckbox.checked
                                }

                                StyledRect {
                                    variant: "primary"
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    visible: perScreenCheckbox.checked
                                    opacity: perScreenCheckbox.checked ? 1.0 : 0.0

                                    Behavior on opacity {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.accept
                                        color: Styling.srItem("primary")
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        scale: perScreenCheckbox.checked ? 1.0 : 0.0

                                        Behavior on scale {
                                            enabled: Config.animDuration > 0
                                            NumberAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.5
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    togglePerScreenMode();
                                }
                            }
                        }
                    }
                }
            }
            
            Item {
                id: oledCheckboxContainer
                Layout.preferredWidth: 100
                Layout.preferredHeight: 48

                property bool keyboardNavigationActive: false

                StyledRect {
                    variant: oledCheckboxContainer.keyboardNavigationActive && oledCheckbox.activeFocus ? "focus" : "pane"
                    anchors.fill: parent
                    radius: Styling.radius(4)
                    opacity: oledCheckbox.enabled ? 1.0 : 0.5

                    Behavior on opacity {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Colors.background
                            radius: Styling.radius(0)

                            Text {
                                anchors.fill: parent
                                text: "OLED"
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutQuart
                                    }
                                }
                            }
                        }

                        Item {
                            id: oledCheckbox
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            property bool checked: Config.theme.oledMode
                            property bool enabled: !Config.theme.lightMode

                            onActiveFocusChanged: {
                                if (!activeFocus) {
                                    oledCheckboxContainer.keyboardNavigationActive = false;
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    oledCheckboxContainer.keyboardNavigationActive = false;
                                    if (event.modifiers & Qt.ShiftModifier) {
                                        wallpapersTabRoot.focusPreviousElement();
                                    } else {
                                        wallpapersTabRoot.focusNextElement();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    if (enabled) {
                                        Config.theme.oledMode = !Config.theme.oledMode;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    oledCheckboxContainer.keyboardNavigationActive = false;
                                    focusSearch();
                                    event.accepted = true;
                                }
                            }

                            Connections {
                                target: Config.theme
                                function onOledModeChanged() {
                                    oledCheckbox.checked = Config.theme.oledMode;
                                }
                            }

                            Item {
                                anchors.fill: parent

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    color: Colors.background
                                    visible: !oledCheckbox.checked
                                }

                                StyledRect {
                                    variant: "primary"
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    visible: oledCheckbox.checked
                                    opacity: oledCheckbox.checked ? 1.0 : 0.0

                                    Behavior on opacity {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.accept
                                        color: Styling.srItem("primary")
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        scale: oledCheckbox.checked ? 1.0 : 0.0

                                        Behavior on scale {
                                            enabled: Config.animDuration > 0
                                            NumberAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.5
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: oledCheckbox.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: {
                                    if (oledCheckbox.enabled) {
                                        Config.theme.oledMode = !Config.theme.oledMode;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: tintCheckboxContainer
                Layout.preferredWidth: 100
                Layout.preferredHeight: 48

                property bool keyboardNavigationActive: false

                StyledRect {
                    variant: tintCheckboxContainer.keyboardNavigationActive && tintCheckbox.activeFocus ? "focus" : "pane"
                    anchors.fill: parent
                    radius: Styling.radius(4)
                    opacity: 1.0

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Colors.background
                            radius: Styling.radius(0)

                            Text {
                                anchors.fill: parent
                                text: "Tint"
                                color: Colors.overSurface
                                font.family: Config.theme.font
                                font.pixelSize: Config.theme.fontSize
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8
                            }
                        }

                        Item {
                            id: tintCheckbox
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40

                            property bool checked: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false

                            onActiveFocusChanged: {
                                if (!activeFocus) {
                                    tintCheckboxContainer.keyboardNavigationActive = false;
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    tintCheckboxContainer.keyboardNavigationActive = false;
                                    if (event.modifiers & Qt.ShiftModifier) {
                                        wallpapersTabRoot.focusPreviousElement();
                                    } else {
                                        wallpapersTabRoot.focusNextElement();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                    if (GlobalStates.wallpaperManager) {
                                        GlobalStates.wallpaperManager.tintEnabled = !GlobalStates.wallpaperManager.tintEnabled;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    tintCheckboxContainer.keyboardNavigationActive = false;
                                    focusSearch();
                                    event.accepted = true;
                                }
                            }

                            Item {
                                anchors.fill: parent

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    color: Colors.background
                                    visible: !tintCheckbox.checked
                                }

                                StyledRect {
                                    variant: "primary"
                                    anchors.fill: parent
                                    radius: Styling.radius(0)
                                    visible: tintCheckbox.checked
                                    opacity: tintCheckbox.checked ? 1.0 : 0.0

                                    Behavior on opacity {
                                        enabled: Config.animDuration > 0
                                        NumberAnimation {
                                            duration: Config.animDuration / 2
                                            easing.type: Easing.OutQuart
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.accept
                                        color: Styling.srItem("primary")
                                        font.family: Icons.font
                                        font.pixelSize: 20
                                        scale: tintCheckbox.checked ? 1.0 : 0.0

                                        Behavior on scale {
                                            enabled: Config.animDuration > 0
                                            NumberAnimation {
                                                duration: Config.animDuration / 2
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.5
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (GlobalStates.wallpaperManager) {
                                        GlobalStates.wallpaperManager.tintEnabled = !GlobalStates.wallpaperManager.tintEnabled;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Spacer
            // Item { Layout.fillWidth: true }

            Item {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 48

                SchemeSelector {
                    id: schemeSelector
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    // No height set, allows expansion based on implicitHeight

                    onSchemeSelectorClosed: {
                        wallpapersTabRoot.focusSearch();
                    }

                    onEscapePressedOnScheme: {
                        wallpapersTabRoot.focusSearch();
                    }

                    onTabPressed: {
                        wallpapersTabRoot.focusNextElement();
                    }

                    onShiftTabPressed: {
                        wallpapersTabRoot.focusPreviousElement();
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: wallpapersFilterBar.height

            FilterBar {
                id: wallpapersFilterBar
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                activeFilters: wallpapersTabRoot.activeFilters

                onActiveFiltersChanged: {
                    wallpapersTabRoot.activeFilters = activeFilters;
                }

                onEscapePressedOnFilters: {
                    wallpapersTabRoot.focusSearch();
                }

                onTabPressed: {
                    wallpapersTabRoot.focusNextElement();
                }

                onShiftTabPressed: {
                    wallpapersTabRoot.focusPreviousElement();
                }
            }
        }

        ClippingRectangle {
            id: wallpaperGridContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            radius: Styling.radius(4)
            clip: true

            readonly property real gridWidth: width + (wallpapersTabRoot.wallpaperMargin * 2)
            readonly property real cellSize: gridWidth / wallpapersTabRoot.gridColumns

            GridView {
                id: wallpaperGrid
                anchors.fill: parent
                anchors.margins: -wallpapersTabRoot.wallpaperMargin
                cellWidth: wallpaperGridContainer.cellSize
                cellHeight: wallpaperGridContainer.cellSize
                flow: GridView.FlowLeftToRight
                boundsBehavior: Flickable.StopAtBounds
                model: filteredWallpapers
                currentIndex: selectedIndex

                property bool isScrolling: dragging || flicking

                highlightFollowsCurrentItem: !isScrolling

                cacheBuffer: cellHeight
                displayMarginBeginning: cellHeight
                displayMarginEnd: cellHeight
                reuseItems: true

                flickDeceleration: 5000
                maximumFlickVelocity: 8000

                onCurrentIndexChanged: {
                    if (currentIndex !== selectedIndex && currentIndex >= 0) {
                        setSelectedIndex(currentIndex);
                    }
                }

                highlight: Item {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight
                    z: 100

                    Behavior on x {
                        enabled: Config.animDuration > 0 && !wallpaperGrid.isScrolling
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    Behavior on y {
                        enabled: Config.animDuration > 0 && !wallpaperGrid.isScrolling
                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }
                    }

                    ClippingRectangle {
                        id: highlightRectangle
                        anchors.centerIn: parent
                        width: parent.width - wallpapersTabRoot.wallpaperMargin * 2
                        height: parent.height - wallpapersTabRoot.wallpaperMargin * 2
                        color: "transparent"
                        border.color: Styling.srItem("overprimary")
                        border.width: 2
                        visible: selectedIndex >= 0
                        radius: Styling.radius(4)
                        z: 10

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: -20
                            anchors.bottomMargin: 0
                            anchors.leftMargin: -20
                            anchors.rightMargin: -20
                            color: "transparent"
                            border.color: Colors.background
                            border.width: 28
                            radius: Styling.radius(24)
                            z: 5

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottomMargin: 0
                                height: 28
                                color: "transparent"
                                z: 6
                                clip: true

                                property var currentItem: wallpaperGrid.currentItem
                                property bool isCurrentWallpaper: {
                                    if (!GlobalStates.wallpaperManager || wallpaperGrid.currentIndex < 0)
                                        return false;
                                        
                                    let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
                                    let currentWall = "";
                                    if (currentScreenName !== "" && perScreen[currentScreenName] !== undefined) {
                                        currentWall = perScreen[currentScreenName];
                                    } else {
                                        currentWall = GlobalStates.wallpaperManager.currentWallpaper;
                                    }
                                        
                                    return currentWall === filteredWallpapers[wallpaperGrid.currentIndex];
                                }
                                property bool showHoveredItem: currentItem && currentItem.isHovered && !visible

                                visible: selectedIndex >= 0 || showHoveredItem

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: wallpaperGrid.cellWidth - 20
                                    height: parent.height
                                    color: "transparent"
                                    clip: true

                                    Text {
                                        id: labelText
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.horizontalCenter: needsScroll ? undefined : parent.horizontalCenter
                                        x: needsScroll ? 4 : undefined
                                        text: {
                                            if (parent.parent.isCurrentWallpaper) {
                                                return "CURRENT";
                                            } else if (wallpaperGrid.currentIndex >= 0 && wallpaperGrid.currentIndex < filteredWallpapers.length) {
                                                return filteredWallpapers[wallpaperGrid.currentIndex].split('/').pop();
                                            }
                                            return "";
                                        }
                                        color: parent.parent.isCurrentWallpaper ? Styling.srItem("overprimary") : Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Config.theme.fontSize
                                        font.weight: Font.Bold
                                        horizontalAlignment: Text.AlignHCenter

                                        readonly property bool needsScroll: contentWidth > parent.width - 8

                                        onTextChanged: {
                                            if (needsScroll) {
                                                x = 4;
                                            }
                                        }

                                        onNeedsScrollChanged: {
                                            if (needsScroll) {
                                                x = 4;
                                                scrollAnimation.restart();
                                            }
                                        }

                                        SequentialAnimation {
                                            id: scrollAnimation
                                            running: labelText.needsScroll && labelText.parent && labelText.parent.parent.visible && !labelText.parent.parent.isCurrentWallpaper
                                            loops: Animation.Infinite

                                            PauseAnimation {
                                                duration: 1000
                                            }
                                            NumberAnimation {
                                                target: labelText
                                                property: "x"
                                                to: labelText.parent.width - labelText.contentWidth - 4
                                                duration: 2000
                                                easing.type: Easing.InOutQuad
                                            }
                                            PauseAnimation {
                                                duration: 1000
                                            }
                                            NumberAnimation {
                                                target: labelText
                                                property: "x"
                                                to: 4
                                                duration: 2000
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillHeight: true
                                    }
                                }

                                onVisibleChanged: {
                                    if (visible) {
                                        labelText.x = 4;
                                        if (labelText.needsScroll && !isCurrentWallpaper) {
                                            scrollAnimation.restart();
                                        }
                                    } else {
                                        scrollAnimation.stop();
                                    }
                                }
                            }
                        }
                    }
                }

                delegate: Rectangle {
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight
                    color: "transparent"

                    property bool isCurrentWallpaper: {
                        if (!GlobalStates.wallpaperManager)
                            return false;
                            
                        let perScreen = GlobalStates.wallpaperManager.perScreenWallpapers || {};
                        let currentWall = "";
                        if (currentScreenName !== "" && perScreen[currentScreenName] !== undefined) {
                            currentWall = perScreen[currentScreenName];
                        } else {
                            currentWall = GlobalStates.wallpaperManager.currentWallpaper;
                        }
                        return currentWall === modelData;
                    }

                    property bool isHovered: false
                    property bool isSelected: selectedIndex === index

                    readonly property bool isInViewport: {
                        var gridTop = wallpaperGrid.contentY;
                        var gridBottom = gridTop + wallpaperGrid.height;
                        var itemTop = y;
                        var itemBottom = itemTop + height;

                        var buffer = wallpaperGrid.cellHeight;
                        return itemBottom + buffer >= gridTop && itemTop - buffer <= gridBottom;
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: wallpapersTabRoot.wallpaperMargin

                        ClippingRectangle {
                            anchors.fill: parent
                            color: Colors.surface
                            radius: Styling.radius(4)

                                Loader {
                                    anchors.fill: parent
                                    sourceComponent: staticImageComponent
                                    property string sourceFile: modelData
                                    active: isInViewport && wallpapersTabRoot.visible && GlobalStates.dashboardOpen
                                    asynchronous: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: Colors.surface
                                    visible: !parent.active || parent.status !== Loader.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.circleNotch
                                        font.family: Icons.font
                                        font.pixelSize: 24
                                        color: Colors.overSurfaceVariant
                                        rotation: 0

                                        NumberAnimation on rotation {
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                            running: parent.visible
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: !wallpaperGrid.isScrolling
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            if (wallpaperGrid.isScrolling)
                                return;
                            parent.isHovered = true;
                            setSelectedIndex(index);
                        }
                        onExited: {
                            parent.isHovered = false;
                        }
                        onPressed: {
                            if (!wallpaperGrid.isScrolling)
                                parent.scale = 0.95;
                        }
                        onReleased: parent.scale = 1.0

                        onClicked: {
                            if (wallpaperGrid.isScrolling)
                                return;
                            if (GlobalStates.wallpaperManager) {
                                if (isPerScreen && currentScreenName !== "") {
                                    GlobalStates.wallpaperManager.setWallpaper(modelData, currentScreenName);
                                } else {
                                    GlobalStates.wallpaperManager.setWallpaper(modelData);
                                }
                            }
                        }
                    }

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Config.animDuration / 3
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wallpaperComponent

        Loader {
            sourceComponent: staticImageComponent
            property string sourceFile: parent.sourceFile
        }
    }

    Component {
        id: staticImageComponent
        Image {
            mipmap: true
            source: {
                if (!parent.sourceFile || !GlobalStates.wallpaperManager)
                    return "";

                var thumbnailPath = GlobalStates.wallpaperManager.getThumbnailPath(parent.sourceFile);
                var version = GlobalStates.wallpaperManager.thumbnailsVersion;
                return "file://" + thumbnailPath + "?v=" + version;
            }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: false
            sourceSize.width: wallpaperGridContainer.cellSize
            sourceSize.height: wallpaperGridContainer.cellSize

            onStatusChanged: {
                if (status === Image.Error) {
                    // console.log("Thumbnail not ready yet for:", parent.sourceFile);
                }
            }
        }
    }
}
