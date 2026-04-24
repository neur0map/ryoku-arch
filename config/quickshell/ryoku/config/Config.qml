pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property int frameThickness: 4
    readonly property int matboard: 12
    readonly property int topMatboard: 8
    readonly property int rounding: 0
    readonly property int topExclusion: topMatboard
    readonly property int sideExclusion: frameThickness + matboard

    property color frameColor: "#171717"

    FileView {
        id: themeColors
        path: Quickshell.env("HOME") + "/.config/ryoku/current/theme/quickshell-colors.qml"
        watchChanges: true

        onLoaded: {
            try {
                const loaded = Qt.createQmlObject(themeColors.text(), root, "quickshell-colors.qml")
                if (loaded !== null && loaded.frame !== undefined) {
                    root.frameColor = loaded.frame
                    loaded.destroy()
                }
            } catch (e) {
                console.warn("Config: failed to parse theme colors:", e.message)
            }
        }
    }
}
