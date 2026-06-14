import QtQuick
import Quickshell

PersistentProperties {
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool island
    property bool dashboard
    property bool settings
    property bool obsidian
    property bool utilities
    property bool sidebar
    property bool clipboard

    function clearTransient(): void {
        osd = false;
        session = false;
        launcher = false;
        island = false;
        dashboard = false;
        obsidian = false;
        utilities = false;
        sidebar = false;
        clipboard = false;
    }

    Component.onCompleted: Qt.callLater(clearTransient)
}
