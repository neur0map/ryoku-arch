pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property int frameThickness: 8
    readonly property int matboard: 8
    readonly property int rounding: 16
    readonly property int topExclusion: matboard
    readonly property int sideExclusion: frameThickness + matboard

    property color frameColor: "#171717"

    FileView {
        id: themeColors
        path: Qt.resolvedUrl(Qt.application.env.HOME + "/.config/ryoku/current/theme/quickshell-colors.qml")
        watchChanges: true

        onLoaded: {
            const loaded = Qt.createQmlObject(themeColors.text(), root, "quickshell-colors.qml")
            if (loaded && loaded.frame)
                root.frameColor = loaded.frame
        }
    }
}
