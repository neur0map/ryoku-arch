pragma Singleton
import QtQuick

QtObject {
    // Existing property used by the decorative Frame (Config.qml reads this).
    readonly property color frame: "{{ background }}"

    // Properties added in Spec 1 for Brain_Shell components that prefer
    // QML import over JSON file watching. Currently unused; reserved for
    // future Ryoku-authored components that import Theme directly.
    readonly property color background:  "{{ background }}"
    readonly property color foreground:  "{{ foreground }}"
    readonly property color accent:      "{{ accent }}"
}
