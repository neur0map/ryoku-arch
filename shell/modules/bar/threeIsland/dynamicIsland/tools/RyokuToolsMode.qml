import qs
import qs.modules.common
import QtQuick
import QtQuick.Layouts

// The toolkit content that lives INSIDE the center notch when tools mode
// is active. No background rectangle - the notch (drawn by RyokuTopFrame)
// is the visual container, so the buttons feel like they belong to the
// island itself, not a separate pill stacked on top.
Item {
    id: root
    implicitWidth: row.implicitWidth + 24
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

    Component.onCompleted: root.forceActiveFocus()

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.visibleOrder
            delegate: Loader {
                id: btnLoader
                required property string modelData
                required property int index
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
                        toolId: btnLoader.modelData
                        autoCloseAfterAction: root.autoCloseAfterAction
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: GlobalStates.toolsModeOpen = false
    }

    Keys.onEscapePressed: {
        if (root.closeOnEsc) GlobalStates.toolsModeOpen = false
    }

    // IpcHandler lives in services/ToolsModeService.qml so it registers
    // exactly once across all bar instances and stays alive even before the
    // tools pill is mounted (chicken-and-egg fix).
}
