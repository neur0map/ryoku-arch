pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"
import "lib/store.js" as StoreLogic

Rectangle {
    id: app

    implicitWidth: 1180
    implicitHeight: 760
    color: Tokens.paper
    focus: true

    property string view: "discover"
    property string categoryID: ""
    property string query: ""
    property bool searchOpen: false
    property string providerFilter: ""
    property string selectedKey: ""
    property var previewItem: null
    property var detailItem: null
    property bool detailOpen: false
    property real gridOffset: 0
    property var searchContext: null
    property var detailContext: null
    property rect detailOriginRect: Qt.rect(0, 0, 0, 0)
    property bool reducedMotion: performance.lowPowerMode || performance.reduceMotion
    readonly property bool catalogLoading: Store.loading && Store.items.length === 0
    readonly property bool catalogError: !Store.loading && Store.items.length === 0 && Store.error !== ""
    // A nav-open (from `ryostore open` / `settings`) can arrive before the
    // catalogue's categories load, with nothing to validate the route against;
    // stash it and apply once the categories arrive so the store lands right.
    property string pendingRoute: ""
    onNavigationCategoriesChanged: if (app.pendingRoute !== "" && app.validRoute(app.pendingRoute)) app.openRoute(app.pendingRoute)

    readonly property var searchableItems: Store.items.map(item => {
        const copy = {};
        Object.keys(item).forEach(key => copy[key] = item[key]);
        const category = Store.category(item.category);
        copy.categoryName = category ? category.name : item.category;
        return copy;
    })
    readonly property var navigationCategories: StoreLogic.sortCategories(Store.categories)
            .filter(category => Number(category.count || 0) > 0)
    readonly property var collection: StoreLogic.collection(searchableItems, {
        view: view,
        categoryID: categoryID,
        query: query,
        provider: app.themesBrowse && app.providerFilter !== "" && app.providerFilter !== "__mine__" ? app.providerFilter : "",
        installedOnly: app.themesBrowse && app.providerFilter === "__mine__"
    })
    readonly property var selectedItem: itemForKey(selectedKey, collection)
    readonly property var resolvedDetail: detailItem
            ? itemForKey(StoreLogic.itemKey(detailItem), searchableItems) || detailItem
            : null
    readonly property int selectedIndex: indexForKey(selectedKey, collection)
    readonly property int libraryCount: StoreLogic.installed(searchableItems).length
    readonly property int updateCount: searchableItems.filter(item => item.updateAvailable === true).length
    readonly property string positionText: collection.length > 0 && selectedIndex >= 0
            ? String(selectedIndex + 1) + " / " + String(collection.length)
            : ""
    readonly property bool showHero: view === "discover" && categoryID === "" && !searchOpen && collection.length > 0
    // The Themes category browses per provider through a subtab strip; the filter
    // narrows the collection to one provider or to the installed library.
    readonly property bool themesBrowse: app.categoryID === "colorschemes" && app.view === "discover" && !app.searchOpen
    readonly property var themeProviders: {
        var seen = ({});
        var out = [];
        var its = Store.items;
        for (var i = 0; i < its.length; i++) {
            if (its[i].category !== "colorschemes")
                continue;
            var pv = (its[i].metadata && its[i].metadata.provider) ? its[i].metadata.provider : "Community";
            if (!seen[pv]) { seen[pv] = true; out.push(pv); }
        }
        out.sort();
        return out;
    }
    readonly property int themeInstallable: {
        if (!app.themesBrowse || app.providerFilter === "" || app.providerFilter === "__mine__")
            return 0;
        var n = 0;
        var its = Store.items;
        for (var i = 0; i < its.length; i++) {
            var it = its[i];
            if (it.category !== "colorschemes")
                continue;
            var pv = (it.metadata && it.metadata.provider) ? it.metadata.provider : "Community";
            if (pv === app.providerFilter && it.installed !== true)
                n++;
        }
        return n;
    }

    function itemForKey(key, items) {
        const source = Array.isArray(items) ? items : [];
        for (let i = 0; i < source.length; i++)
            if (StoreLogic.itemKey(source[i]) === key)
                return source[i];
        return null;
    }

    function indexForKey(key, items) {
        const source = Array.isArray(items) ? items : [];
        for (let i = 0; i < source.length; i++)
            if (StoreLogic.itemKey(source[i]) === key)
                return i;
        return -1;
    }
    function providerItems(provider) {
        var out = [];
        var its = Store.items;
        for (var i = 0; i < its.length; i++) {
            var it = its[i];
            if (it.category !== "colorschemes")
                continue;
            var pv = (it.metadata && it.metadata.provider) ? it.metadata.provider : "Community";
            if (pv === provider)
                out.push(it);
        }
        return out;
    }

    function reconcileSelection(fallbackIndex) {
        selectedKey = StoreLogic.selectionKey(collection, selectedKey,
                                                fallbackIndex === undefined ? 0 : fallbackIndex);
    }

    function validRoute(route) {
        if (route === "discover" || route === "library")
            return true;
        return Store.categories.some(category => category.id === route);
    }

    function currentFocusObject() {
        return app.Window.window ? app.Window.window.activeFocusItem : null;
    }

    function snapshotContext() {
        return {
            view: view,
            categoryID: categoryID,
            query: query,
            selectedKey: selectedKey,
            gridOffset: productGrid.contentY,
            focusObject: currentFocusObject()
        };
    }

    function restoreContext(context) {
        if (!context)
            return;
        view = context.view;
        categoryID = context.categoryID;
        query = context.query;
        selectedKey = context.selectedKey;
        gridOffset = context.gridOffset;
        Qt.callLater(function() {
            app.reconcileSelection(0);
            Qt.callLater(function() {
                productGrid.restoreOffset(context.gridOffset);
                app.gridOffset = productGrid.contentY;
                if (context.focusObject && context.focusObject.forceActiveFocus)
                    context.focusObject.forceActiveFocus();
                else
                    productGrid.forceActiveFocus();
            });
        });
    }

    function openRoute(route) {
        if (!validRoute(route)) {
            app.pendingRoute = route;
            return;
        }
        app.pendingRoute = "";
        app.providerFilter = "";
        detailClear.stop();
        detailOpen = false;
        detailItem = null;
        detailContext = null;
        searchOpen = false;
        searchContext = null;
        query = "";
        previewItem = null;
        if (route === "discover" || route === "library") {
            view = route;
            categoryID = "";
        } else {
            view = "discover";
            categoryID = route;
        }
        reconcileSelection(0);
        Qt.callLater(function() { productGrid.forceActiveFocus(); });
    }

    function selectKey(key) {
        selectedKey = StoreLogic.selectionKey(collection, key, 0);
        previewItem = null;
    }

    function selectedCoverRect() {
        const rect = productGrid.cellRectFor(selectedKey);
        if (rect.width === 0)
            return Qt.rect(0, 0, 0, 0);
        const point = productGrid.mapToItem(productDetail, rect.x, rect.y);
        return Qt.rect(point.x, point.y, rect.width, rect.height);
    }

    function openSelectedDetail() {
        if (!selectedItem)
            return;
        detailClear.stop();
        detailContext = snapshotContext();
        detailOriginRect = selectedCoverRect();
        detailItem = selectedItem;
        detailOpen = true;
        previewItem = null;
        Qt.callLater(function() { productDetail.focusInitialAction(); });
    }

    function closeDetail() {
        if (!detailOpen)
            return;
        const context = detailContext;
        detailOpen = false;
        detailContext = null;
        restoreContext(context);
        if (reducedMotion)
            detailItem = null;
        else
            detailClear.restart();
    }

    function enterSearch() {
        if (searchOpen)
            return;
        searchContext = snapshotContext();
        searchOpen = true;
        previewItem = null;
        reconcileSelection(0);
    }

    function searchFor(value) {
        enterSearch();
        query = value;
        previewItem = null;
        reconcileSelection(0);
    }

    function exitSearch() {
        if (!searchOpen)
            return;
        const context = searchContext;
        searchOpen = false;
        searchContext = null;
        query = "";
        restoreContext(context);
    }

    function escapeLayer() {
        if (detailOpen && productDetail.lightboxOpen)
            productDetail.closeLightbox();
        else if (detailOpen)
            closeDetail();
        else if (searchOpen)
            exitSearch();
        else if (view !== "discover" || categoryID !== "")
            openRoute("discover");
    }

    function requestQuit() {
        if (Store.busyKey !== "" && !quitArm.running) {
            quitArm.restart();
            return;
        }
        Qt.quit();
    }

    onCollectionChanged: reconcileSelection(0)
    onSearchableItemsChanged: {
        reconcileSelection(0);
        if (detailItem)
            detailItem = itemForKey(StoreLogic.itemKey(detailItem), searchableItems) || detailItem;
    }
    Component.onCompleted: Qt.callLater(function() { productGrid.forceActiveFocus(); })

    Keys.onEscapePressed: event => {
        escapeLayer();
        event.accepted = true;
    }
    Keys.onPressed: event => {
        if (event.text === "/" && event.modifiers === Qt.NoModifier) {
            header.focusSearch();
        } else if (!detailOpen && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            openSelectedDetail();
        } else {
            return;
        }
        event.accepted = true;
    }

    Shortcut { sequence: "Ctrl+K"; onActivated: header.focusSearch() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: app.requestQuit() }

    Timer { id: quitArm; interval: 3000 }
    Timer {
        id: detailClear
        interval: Tokens.swap
        onTriggered: app.detailItem = null
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
              + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: performance
            property bool lowPowerMode: false
            property bool reduceMotion: false
        }
    }

    StoreHeader {
        id: header
        objectName: "ryostore-header"
        anchors { left: parent.left; top: parent.top; right: parent.right }
        height: implicitHeight
        view: app.view
        categoryID: app.categoryID
        categories: app.navigationCategories
        query: app.query
        libraryCount: app.libraryCount
        updateCount: app.updateCount
        offline: Store.offline
        refreshing: Store.refreshing
        searchActive: app.searchOpen
        resultCount: app.collection.length
        onRouteRequested: (routeView, routeCategory) => app.openRoute(routeCategory || routeView)
        onRefreshRequested: Store.refresh(true)
        onQueryEdited: value => app.searchFor(value)
        onSearchActivated: app.enterSearch()
        onSearchEscaped: app.exitSearch()
    }
    ProviderTabs {
        id: providerTabs
        objectName: "ryostore-provider-tabs"
        anchors { left: parent.left; top: header.bottom; right: parent.right }
        height: app.themesBrowse ? implicitHeight : 0
        visible: app.themesBrowse
        providers: app.themeProviders
        active: app.providerFilter
        installableCount: app.themeInstallable
        busy: Store.busyKey !== ""
        onPicked: filter => {
            app.providerFilter = filter;
            app.reconcileSelection(0);
            Qt.callLater(function() { productGrid.forceActiveFocus(); });
        }
        onInstallAll: Store.installAll(app.providerItems(app.providerFilter))
    }

    ShowroomStage {
        id: stage
        objectName: "ryostore-stage"
        anchors { left: parent.left; top: providerTabs.bottom; right: parent.right }
        height: app.showHero ? Math.round((app.height - header.height) * 0.42) : 0
        visible: app.showHero
        enabled: !app.detailOpen
        item: app.selectedItem
        previewItem: app.previewItem
        busyKey: Store.busyKey
        installStage: Store.installStage
        installErrorKey: Store.installErrorKey
        installError: Store.installError
        positionText: app.positionText
        offline: Store.offline
        reducedMotion: app.reducedMotion
        onInstallRequested: item => Store.install(item)
        onDetailsRequested: item => app.openSelectedDetail()
        onSettingsRequested: item => Store.openSettings(item)
    }

    ProductGrid {
        id: productGrid
        objectName: "ryostore-grid"
        anchors { left: parent.left; top: stage.bottom; right: parent.right; bottom: parent.bottom }
        items: app.collection
        selectedKey: app.selectedKey
        reducedMotion: app.reducedMotion
        enabled: !app.detailOpen
        onPreviewRequested: item => app.previewItem = item
        onSelectionRequested: item => app.selectKey(StoreLogic.itemKey(item))
        onActivated: item => {
            app.selectKey(StoreLogic.itemKey(item));
            app.openSelectedDetail();
        }
    }

    // initial catalogue fetch: show progress, never the empty plate, so a slow
    // network never reads as "there is nothing here".
    Column {
        id: loadingState
        anchors.centerIn: productGrid
        spacing: Tokens.s4
        visible: app.catalogLoading
        z: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "LOADING CATALOGUE"
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
            font.letterSpacing: Tokens.trackLabel
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 220
            height: 2
            color: Tokens.lineSoft
            clip: true

            Rectangle {
                width: 74
                height: parent.height
                radius: 1
                color: Tokens.sun
                x: app.reducedMotion ? (parent.width - width) / 2 : -width
                XAnimator on x {
                    from: -74
                    to: 220
                    duration: 1100
                    loops: Animation.Infinite
                    running: loadingState.visible && !app.reducedMotion
                }
            }
        }
    }

    // catalogue source failed with nothing cached to fall back on.
    Column {
        anchors.centerIn: productGrid
        spacing: Tokens.s3
        visible: app.catalogError
        z: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CATALOGUE UNAVAILABLE"
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
            font.letterSpacing: Tokens.trackLabel
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(productGrid.width - Tokens.s7 * 2, 420)
            text: Store.error
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RETRY"
            armed: true
            onAct: Store.refresh(true)
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: Store.refresh(true)
        }
    }

    Column {
        anchors.centerIn: productGrid
        spacing: Tokens.s3
        visible: app.collection.length === 0 && !app.catalogLoading && !app.catalogError
        z: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: app.view === "library" ? "YOUR LIBRARY IS EMPTY"
                  : (app.query !== "" ? "NO SEARCH RESULTS" : "NO PRODUCTS AVAILABLE")
            color: Tokens.inkDim
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
            font.letterSpacing: Tokens.trackLabel
        }

        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RETURN TO DISCOVER"
            visible: app.view === "library"
            armed: visible
            onAct: app.openRoute("discover")
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: app.openRoute("discover")
        }
    }

    ProductDetail {
        id: productDetail
        objectName: "ryostore-detail"
        anchors { left: parent.left; top: header.bottom; right: parent.right; bottom: parent.bottom }
        z: 20
        item: app.resolvedDetail
        open: app.detailOpen
        originRect: app.detailOriginRect
        busyKey: Store.busyKey
        installStage: Store.installStage
        installErrorKey: Store.installErrorKey
        installError: Store.installError
        reducedMotion: app.reducedMotion
        onCloseRequested: app.closeDetail()
        onInstallRequested: (item, dither, components) => Store.install(item, dither, components)
        onRetryRequested: (item, dither, components) => Store.retryInstall(item, dither, components)
        onSettingsRequested: item => Store.openSettings(item)
    }
}
