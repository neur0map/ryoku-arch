import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

// Circular button used in the Mod+S tools pill. Reads metadata from
// ToolRegistry by tool id. When the registry's activeWhen() returns true
// the button shows a pulsing primary-tinted background AND a soft glow
// ring so users can tell at a glance that the tool is currently doing
// something (mic in use, music recognition listening, etc.).
Item {
    id: root
    required property string toolId
    required property bool autoCloseAfterAction
    // Set by RyokuToolsMode for the row item under arrow-key focus.
    property bool keyboardFocused: false

    readonly property var entry: ToolRegistry.tools[root.toolId] ?? null
    readonly property bool isActive: entry?.activeWhen ? entry.activeWhen() : false

    function activate() {
        if (!root.entry) return;
        root.entry.action();
        // Auto-close after action unless the entry opts out via keepOpen
        // (e.g. musicRecognize, where the user wants to watch the listening
        // halo pulse without the tools row vanishing).
        const keepOpen = root.entry.keepOpen ?? false;
        if (root.entry.kind === "action" && root.autoCloseAfterAction && !keepOpen) {
            GlobalStates.toolsModeOpen = false;
        }
    }

    implicitWidth: 32
    implicitHeight: 32

    // Outer pulsing glow ring, only visible when the tool is active.
    // Drawn beneath the button background so it reads as a halo around
    // the icon without obscuring it.
    Rectangle {
        id: glow
        anchors.centerIn: parent
        width: parent.width + 8
        height: parent.height + 8
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colPrimary
        visible: root.isActive
        opacity: 0

        SequentialAnimation on opacity {
            running: root.isActive && Appearance.animationsEnabled
            loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0.10; duration: 700; easing.type: Easing.InOutQuad }
        }
        SequentialAnimation on scale {
            running: root.isActive && Appearance.animationsEnabled
            loops: Animation.Infinite
            NumberAnimation { to: 1.06; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.00; duration: 700; easing.type: Easing.InOutQuad }
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: root.keyboardFocused
            ? Appearance.colors.colLayer3Active
            : (mouseArea.containsMouse
                ? Appearance.colors.colLayer3Hover
                : (root.isActive
                    ? Qt.rgba(Appearance.colors.colPrimary.r,
                              Appearance.colors.colPrimary.g,
                              Appearance.colors.colPrimary.b, 0.22)
                    : "transparent"))
        border.width: root.keyboardFocused ? 1 : (root.isActive ? 1 : 0)
        border.color: root.keyboardFocused
            ? Appearance.colors.colOnLayer2
            : Qt.rgba(Appearance.colors.colPrimary.r,
                      Appearance.colors.colPrimary.g,
                      Appearance.colors.colPrimary.b, 0.45)

        Behavior on color { ColorAnimation { duration: 120 } }

        // Subtle background opacity pulse so the active state breathes
        // even before the user hovers over the button.
        SequentialAnimation on opacity {
            running: root.isActive && !mouseArea.containsMouse && Appearance.animationsEnabled
            loops: Animation.Infinite
            NumberAnimation { to: 0.7; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.entry?.icon ?? "circle"
        iconSize: Appearance.font.pixelSize.large
        color: root.isActive
            ? Appearance.colors.colPrimary
            : Appearance.colors.colOnLayer2
        fill: root.isActive ? 1 : 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activate()
    }

    // PopupToolTip's parentHoverState defaults to true when the parent has
    // no hovered/buttonHovered property. Bind extraVisibleCondition to the
    // actual mouse-over state so tooltips are not permanently visible.
    StyledToolTip {
        text: root.entry?.label ?? ""
        extraVisibleCondition: mouseArea.containsMouse
    }
}
