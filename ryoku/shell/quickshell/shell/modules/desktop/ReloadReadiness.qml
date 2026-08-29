import QtQuick

QtObject {
    required property real width
    required property real height
    required property bool configReady
    required property bool registryReady

    readonly property bool ready: width > 0 && height > 0 && configReady && registryReady
}
