import QtQuick
import "Singletons"

/**
 * The unified Ryoku Store: browse and install shell plugins and extras bundles
 * from one place. A segmented switch flips between the two catalogues; a single
 * refresh sits to the left of the switch and re-pulls whichever catalogue is
 * showing. Managing what is already installed lives on the Add-ons page, so the
 * store only browses and installs.
 */
Item {
    id: store

    property string tab: "plugins"

    ShowcaseBackdrop { anchors.fill: parent }

    // Header: refresh (left) + the Plugins / Bundles switch.
    Row {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        spacing: 12
        z: 3

        Rectangle {
            id: refreshBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: 9
            readonly property bool spinning: store.tab === "plugins" ? pluginsPage.refreshing : extrasPage.loading
            color: rHover.hovered ? Theme.surface : "transparent"
            border.width: 1
            border.color: rHover.hovered ? Theme.ember : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            Icon {
                anchors.centerIn: parent
                name: "refresh"
                size: 15
                weight: 2
                tint: rHover.hovered ? Theme.bright : Theme.dim
                RotationAnimation on rotation { running: refreshBtn.spinning; loops: Animation.Infinite; from: 0; to: 360; duration: 800 }
            }
            HoverHandler { id: rHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (store.tab === "plugins") {
                        pluginsPage.refreshing = true;
                        pluginsPage.loadCatalog();
                        pluginsPage.refresh();
                    } else {
                        extrasPage.reload();
                    }
                }
            }
        }

        Segmented {
            id: seg
            anchors.verticalCenter: parent.verticalCenter
            model: [
                { "key": "plugins", "label": "Plugins" },
                { "key": "bundles", "label": "Bundles" }
            ]
            current: store.tab
            onSelected: (k) => store.tab = k
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 18
        anchors.bottom: parent.bottom

        PluginsPage {
            id: pluginsPage
            anchors.fill: parent
            visible: store.tab === "plugins"
            storeMode: true
        }

        ExtrasPage {
            id: extrasPage
            anchors.fill: parent
            visible: store.tab === "bundles"
            storeMode: true
        }
    }
}
