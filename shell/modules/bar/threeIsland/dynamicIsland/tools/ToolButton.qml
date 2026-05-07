import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

// Circular button used in the Mod+S tools pill. Reads metadata from
// ToolRegistry by tool id.
Item {
    id: root
    required property string toolId
    required property bool autoCloseAfterAction

    readonly property var entry: ToolRegistry.tools[root.toolId] ?? null
    readonly property bool isActive: entry?.activeWhen ? entry.activeWhen() : false

    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouseArea.containsMouse
            ? Appearance.colors.colLayer3Hover
            : (root.isActive ? Appearance.colors.colLayer3 : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.entry?.icon ?? "circle"
        iconSize: Appearance.font.pixelSize.large
        color: root.isActive
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colOnLayer2
        fill: root.isActive ? 1 : 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (!root.entry) return;
            root.entry.action();
            if (root.entry.kind === "action" && root.autoCloseAfterAction) {
                GlobalStates.toolsModeOpen = false;
            }
        }
        StyledToolTip { text: root.entry?.label ?? "" }
    }
}
