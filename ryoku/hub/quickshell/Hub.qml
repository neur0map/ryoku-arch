import QtQuick
import Quickshell.Io
import "Singletons"

// The Hub application: the navigation rail (which owns the global search) beside a
// content area. With no query the content shows the selected section; with a
// query it shows global results across every section. Data and persisted state
// come from the ryoku-hub Go backend.
Rectangle {
    id: hub

    implicitWidth: 1360
    implicitHeight: 880

    property string section: "keybinds"
    property var keybindsModel: []
    readonly property bool searching: navRail.query.length > 0

    readonly property var sectionDefs: [
        { "key": "shell", "name": "Shell Settings", "icon": "gear" },
        { "key": "keybinds", "name": "Keybinds", "icon": "keyboard" },
        { "key": "extras", "name": "Extras", "icon": "sparkles" }
    ]

    readonly property var pageMeta: ({
        "keybinds": { "title": "Keybinds", "subtitle": "Every shortcut in the Ryoku desktop, read live from your Hyprland config." },
        "extras":   { "title": "Extras", "subtitle": "Desktop goodies and quick tweaks." },
        "shell":    { "title": "Shell Settings", "subtitle": "Tune the Ryoku shell: the pill, the frame, and its surfaces." }
    })

    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.bgTop }
        GradientStop { position: 1.0; color: Theme.bgBot }
    }

    focus: true
    Keys.onEscapePressed: Qt.quit()
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) {
            navRail.focusSearch();
            e.accepted = true;
        }
    }

    Process {
        id: kbProc
        command: ["ryoku-hub", "keybinds"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    hub.keybindsModel = JSON.parse(this.text).categories;
                } catch (e) {
                    console.log("hub: keybinds parse failed: " + e);
                }
            }
        }
    }

    Process {
        id: loadSection
        command: ["ryoku-hub", "config", "get", "section"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var s = this.text.trim();
                if (s === "keybinds" || s === "extras" || s === "shell")
                    hub.section = s;
            }
        }
    }

    Process { id: saveSection }

    function go(s) {
        navRail.query = "";
        if (hub.section === s)
            return;
        hub.section = s;
        saveSection.command = ["ryoku-hub", "config", "set", "section", s];
        saveSection.running = true;
    }

    Row {
        anchors.fill: parent

        NavRail {
            id: navRail
            width: 252
            height: parent.height
            current: hub.section
            onNavigate: (s) => hub.go(s)
            onEscaped: Qt.quit()
        }

        Item {
            width: parent.width - 252
            height: parent.height

            PageHeader {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 40
                anchors.rightMargin: 64
                anchors.topMargin: 16
                title: hub.searching ? "Search" : hub.pageMeta[hub.section].title
                subtitle: hub.searching ? "Results across every section" : hub.pageMeta[hub.section].subtitle
            }

            Loader {
                id: pageLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 40
                anchors.rightMargin: 30
                anchors.topMargin: 14
                anchors.bottomMargin: 12

                sourceComponent: hub.searching ? searchComp
                    : (hub.section === "keybinds" ? keybindsComp
                    : hub.section === "extras" ? extrasComp : shellComp)

                onLoaded: {
                    if (!item)
                        return;
                    item.opacity = 0;
                    item.y = 10;
                    fadeAnim.target = item;
                    slideAnim.target = item;
                    fadeAnim.restart();
                    slideAnim.restart();
                }
            }

            NumberAnimation {
                id: fadeAnim
                property: "opacity"
                to: 1
                duration: Theme.medium
                easing.type: Theme.ease
            }

            NumberAnimation {
                id: slideAnim
                property: "y"
                to: 0
                duration: Theme.medium
                easing.type: Theme.ease
            }
        }
    }

    Component {
        id: searchComp
        SearchResults {
            categories: hub.keybindsModel
            sections: hub.sectionDefs
            query: navRail.query
            onNavigate: (s) => hub.go(s)
        }
    }

    Component {
        id: keybindsComp
        KeybindsPage { categories: hub.keybindsModel }
    }

    Component {
        id: extrasComp
        UnderConstruction {
            title: "Extras"
            icon: "sparkles"
            blurb: "A home for desktop goodies and quick tweaks. This section is being built; its controls will likely use GTK4 and libadwaita through the Kirigami addons."
        }
    }

    Component {
        id: shellComp
        UnderConstruction {
            title: "Shell Settings"
            icon: "gear"
            blurb: "Live controls for the Ryoku shell: the pill, the frame, and the popout surfaces. This section is under construction."
        }
    }

    Item {
        id: closeBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 22
        width: 26
        height: 26

        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 16
            tint: closeHover.hovered ? Theme.ember : Theme.faint
            Behavior on tint { ColorAnimation { duration: Theme.quick } }
        }

        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Qt.quit() }
    }
}
