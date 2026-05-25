import QtQuick
import Quickshell

PersistentProperties {
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool island
    property bool dashboard
    property bool utilities
    property bool sidebar

    function clearTransient(): void {
        osd = false;
        session = false;
        launcher = false;
        island = false;
        dashboard = false;
        utilities = false;
        sidebar = false;
    }

    Component.onCompleted: Qt.callLater(clearTransient)
}
