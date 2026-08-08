import QtQuick

// Compatibility placeholder for existing surface declarations. V2 no longer
// renders individual pill/card shadows; the sole appearance option is the
// shared Transparent surface mode.
Item {
    required property var theme
    anchors.fill: parent
    visible: false
}
