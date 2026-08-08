import QtQuick
import "../modules"

// A quiet summary of the running bar: form · variant on the left, position ·
// accent on the right. Ryoku has no plugin/health counts to show here (those
// live in ryostore and `ryoku doctor`), so this strip stays informational.
Item {
    id: strip
    property var root
    implicitHeight: 34

    readonly property string variant: root.variantHost ? String(root.variantHost.runningVariant).toUpperCase() : ""
    readonly property string form: root.barShellStyle ? String(root.barShellStyle).toUpperCase() : "ISLANDS"

    Rectangle {
        anchors.fill: parent
        radius: strip.root.tileRadius
        color: strip.root.fillIdle
        border.width: 1
        border.color: strip.root.sep
    }
    Row {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "BAR"; color: strip.root.sumiHi; font.family: strip.root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: strip.variant + " · " + strip.form; color: strip.root.ink; font.family: strip.root.mono; font.pixelSize: 11 }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        UiText { anchors.verticalCenter: parent.verticalCenter; text: String(strip.root.barPosition).toUpperCase(); color: strip.root.sumi; font.family: strip.root.mono; font.pixelSize: 11 }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: strip.root.tileRadius; color: strip.root.seal; border.width: 1; border.color: strip.root.sep }
    }
}
