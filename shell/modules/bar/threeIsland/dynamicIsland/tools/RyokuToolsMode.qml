import qs
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Wide centered pill with tool buttons grouped by DIVIDER tokens. Mounted
// when GlobalStates.toolsModeOpen is true. Press Esc or right-click to close.
Item {
    id: root
    implicitWidth: pill.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    readonly property var toolsConfig: Config.options?.bar?.dynamicIsland?.tools
    readonly property var orderRaw: toolsConfig?.order ?? []
    readonly property bool autoCloseAfterAction: toolsConfig?.autoCloseAfterAction ?? true
    readonly property bool closeOnEsc: toolsConfig?.closeOnEsc ?? true

    readonly property var visibleOrder: {
        const buttons = toolsConfig?.buttons ?? {};
        const out = [];
        for (let i = 0; i < orderRaw.length; i++) {
            const id = orderRaw[i];
            if (id === "DIVIDER") {
                if (out.length > 0 && out[out.length - 1] !== "DIVIDER") out.push("DIVIDER");
            } else if (buttons[id] !== false) {
                out.push(id);
            }
        }
        while (out.length > 0 && out[out.length - 1] === "DIVIDER") out.pop();
        return out;
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 28
        implicitHeight: 40
        radius: height / 2
        color: Appearance.colors.colLayer2

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.visibleOrder
                delegate: Loader {
                    required property string modelData
                    sourceComponent: modelData === "DIVIDER" ? dividerComp : buttonComp

                    Component {
                        id: dividerComp
                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 22
                            color: Appearance.colors.colOutline
                            opacity: 0.4
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                        }
                    }
                    Component {
                        id: buttonComp
                        ToolButton {
                            toolId: modelData
                            autoCloseAfterAction: root.autoCloseAfterAction
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: pill
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: GlobalStates.toolsModeOpen = false
    }

    Keys.onEscapePressed: {
        if (root.closeOnEsc) GlobalStates.toolsModeOpen = false
    }

    Component.onCompleted: root.forceActiveFocus()

    IpcHandler {
        target: "toolsMode"
        function toggle(): void { GlobalStates.toolsModeOpen = !GlobalStates.toolsModeOpen }
        function open(): void   { GlobalStates.toolsModeOpen = true }
        function close(): void  { GlobalStates.toolsModeOpen = false }
    }
}
