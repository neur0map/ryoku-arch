pragma Singleton
import QtQuick

QtObject {
    // Used by the decorative Frame (Config.qml reads this). Mapped to
    // theme accent for visibility against arbitrary wallpapers; switches
    // automatically when the user runs ryoku-theme-set.
    readonly property color frame: "{{ accent }}"

    // Properties added in Spec 1 for Brain_Shell components that prefer
    // QML import over JSON file watching. Currently unused; reserved for
    // future Ryoku-authored components that import Theme directly.
    readonly property color background:  "{{ background }}"
    readonly property color foreground:  "{{ foreground }}"
    readonly property color accent:      "{{ accent }}"
}
