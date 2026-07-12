pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Singletons"

// Rices: whole-desktop looks you can try on and take off. Two modes, one clear
// job each. My rices: save your current setup, apply one in a tap, restore your
// original in one click, and duplicate/delete your own. Browse: the community
// store, install a rice to add it to My rices. Built to read like trying on
// outfits, not editing config; editing lives behind the detail. Embedded as the
// Appearance Rices tab; grows by implicitHeight so the tab's Flickable scrolls.
Item {
    id: page

    property var rices: []
    property var catalog: []
    property bool loading: true
    property bool browseMode: false
    property bool catalogLoading: false
    property bool catalogError: false
    property string selectedSlug: ""
    property bool capturing: false

    readonly property var selected: {
        for (var i = 0; i < page.rices.length; i++)
            if (page.rices[i].slug === page.selectedSlug)
                return page.rices[i];
        return null;
    }
    readonly property bool hasActive: {
        for (var i = 0; i < page.rices.length; i++)
            if (page.rices[i].active)
                return true;
        return false;
    }

    implicitWidth: 600
    implicitHeight: (page.selectedSlug !== "" && detailLoader.item)
        ? detailLoader.item.implicitHeight
        : browse.implicitHeight

    Component.onCompleted: page.reload()
    function reload() {
        page.loading = true;
        listProc.running = true;
    }
    function loadCatalog() {
        page.catalogLoading = true;
        page.catalogError = false;
        catalogProc.running = true;
    }
    function showBrowse(on) {
        page.browseMode = on;
        if (on && page.catalog.length === 0 && !page.catalogLoading)
            page.loadCatalog();
    }
    function applyRice(slug, layers) {
        applyProc.command = ["ryoku-hub", "rice", "apply", slug].concat(layers || []);
        applyProc.running = true;
    }
    function restoreOriginal() {
        restoreProc.command = ["ryoku-hub", "rice", "restore", "baseline"];
        restoreProc.running = true;
    }
    function capture(name) {
        if (!name)
            return;
        captureProc.command = ["ryoku-hub", "rice", "capture", name];
        captureProc.running = true;
    }
    function del(slug) {
        deleteProc.command = ["ryoku-hub", "rice", "delete", slug];
        deleteProc.running = true;
    }
    function fork(slug) {
        forkProc.command = ["ryoku-hub", "rice", "fork", slug];
        forkProc.running = true;
    }
    function install(id) {
        installProc.command = ["ryoku-hub", "rice", "install", id];
        installProc.running = true;
    }

    Process {
        id: listProc
        command: ["ryoku-hub", "rice", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.rices = JSON.parse(this.text) || [];
                } catch (e) {
                    page.rices = [];
                }
                page.loading = false;
            }
        }
    }
    Process {
        id: catalogProc
        command: ["ryoku-hub", "rice", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.catalog = JSON.parse(this.text) || [];
                    page.catalogError = false;
                } catch (e) {
                    page.catalog = [];
                    page.catalogError = true;
                }
                page.catalogLoading = false;
            }
        }
    }
    Process { id: applyProc; onExited: (code, status) => { page.selectedSlug = ""; page.reload(); } }
    Process { id: restoreProc; onExited: (code, status) => page.reload() }
    Process { id: captureProc; onExited: (code, status) => { page.capturing = false; page.reload(); } }
    Process { id: deleteProc; onExited: (code, status) => { page.selectedSlug = ""; page.reload(); } }
    Process { id: forkProc; onExited: (code, status) => { page.selectedSlug = ""; page.reload(); } }
    Process { id: installProc; onExited: (code, status) => { page.reload(); page.loadCatalog(); } }

    Column {
        id: browse
        width: page.width
        visible: page.selectedSlug === ""
        spacing: 16

        Segmented {
            model: [
                { "key": "mine", "label": "My rices" },
                { "key": "store", "label": "Browse" }
            ]
            current: page.browseMode ? "store" : "mine"
            onSelected: k => page.showBrowse(k === "store")
        }

        // ---- My rices --------------------------------------------------------
        Column {
            width: parent.width
            visible: !page.browseMode
            spacing: 16

            Row {
                spacing: 10
                HubButton {
                    label: "Save current setup"
                    icon: "plus"
                    primary: true
                    enabled: !page.capturing
                    tooltip: "Snapshot your whole desktop look as a new rice you can re-apply later."
                    onClicked: page.capturing = true
                }
                HubButton {
                    label: "Restore original"
                    icon: "refresh"
                    enabled: page.hasActive
                    tooltip: "Revert every part of the desktop to how it was before you applied a rice."
                    onClicked: page.restoreOriginal()
                }
            }

            Rectangle {
                visible: page.capturing
                width: parent.width
                height: 46
                radius: Theme.radius
                color: Theme.surfaceLo
                border.width: 1
                border.color: nameInput.activeFocus ? Theme.ember : Theme.line
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 8
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - saveNow.width - cancelNow.width - 24
                        height: parent.height
                        TextInput {
                            id: nameInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 14
                            clip: true
                            selectByMouse: true
                            focus: page.capturing
                            onAccepted: page.capture(text)
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: nameInput.text === ""
                                text: "Name this rice (for example, My Setup)"
                                color: Theme.faint
                                font: nameInput.font
                            }
                        }
                    }
                    HubButton {
                        id: saveNow
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Save"
                        icon: "check"
                        primary: true
                        onClicked: page.capture(nameInput.text)
                    }
                    HubButton {
                        id: cancelNow
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Cancel"
                        onClicked: {
                            page.capturing = false;
                            nameInput.text = "";
                        }
                    }
                }
            }

            Text {
                visible: !page.capturing
                width: parent.width
                text: "Save your whole desktop look, windows, bar, colours, wallpaper, and cursor, as a rice. Switch between looks anytime, and restore your original in one click."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            Spinner {
                visible: page.loading
                anchors.horizontalCenter: parent.horizontalCenter
                size: 24
            }

            Column {
                visible: !page.loading && page.rices.length === 0 && !page.capturing
                width: parent.width
                spacing: 10
                topPadding: 20
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "palette"; size: 40; tint: Theme.faint }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No rices yet"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "Tune your desktop the way you like, then Save current setup to make your first rice, or Browse the store for one to install."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }

            Flow {
                id: grid
                width: parent.width
                visible: !page.loading && page.rices.length > 0
                spacing: 14
                Repeater {
                    model: page.rices
                    delegate: RiceTile {
                        required property var modelData
                        width: Math.max(280, (grid.width - 14 * 2) / 3)
                        rice: modelData
                        onOpened: page.selectedSlug = modelData.slug
                    }
                }
            }
        }

        // ---- Browse (the community store) -----------------------------------
        Column {
            width: parent.width
            visible: page.browseMode
            spacing: 16

            Text {
                width: parent.width
                text: "Install a rice from the community store, then apply it from My rices. A rice built for a different Ryoku version still applies; it is reconciled to yours."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            Spinner {
                visible: page.catalogLoading
                anchors.horizontalCenter: parent.horizontalCenter
                size: 24
            }

            Column {
                visible: !page.catalogLoading && page.catalog.length === 0
                width: parent.width
                spacing: 10
                topPadding: 20
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: page.catalogError ? "close" : "palette"; size: 40; tint: Theme.faint }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: page.catalogError ? "Couldn't reach the rice store." : "No rices in the store yet."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
                HubButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    label: "Try again"
                    icon: "refresh"
                    onClicked: page.loadCatalog()
                }
            }

            Flow {
                id: storeGrid
                width: parent.width
                visible: !page.catalogLoading && page.catalog.length > 0
                spacing: 14
                Repeater {
                    model: page.catalog
                    delegate: RiceTile {
                        required property var modelData
                        width: Math.max(280, (storeGrid.width - 14 * 2) / 3)
                        rice: modelData
                        store: true
                        onOpened: {
                            if (modelData.installed) {
                                page.browseMode = false;
                                page.selectedSlug = modelData.id;
                            } else {
                                page.install(modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: detailLoader
        width: page.width
        active: page.selectedSlug !== "" && page.selected !== null
        visible: active
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        sourceComponent: RiceDetail {
            width: detailLoader.width
            rice: page.selected
            onBack: page.selectedSlug = ""
            onApplied: layers => page.applyRice(page.selectedSlug, layers)
            onForked: page.fork(page.selectedSlug)
            onRemoved: page.del(page.selectedSlug)
        }
    }
}
