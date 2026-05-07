import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.threeIsland.dynamicIsland.tools
import QtQuick
import QtQuick.Layouts
import Quickshell

// Legacy bar utility row. Renders the same buttons as the Dynamic Island
// tools pill (Mod+S), driven from the shared ToolRegistry. Visibility is
// gated by the existing `bar.utilButtons.show*` flags so user settings
// keep working.
Item {
    id: root
    property bool borderless: Config.options?.bar?.borderless ?? false

    readonly property var legacyOrder: [
        "screenshot", "record", "colorPicker", "notepad", "osk",
        "micToggle", "screenCast", "darkMode", "powerProfile"
    ]

    readonly property var legacyShown: {
        const ub = Config.options?.bar?.utilButtons ?? {};
        const map = {
            screenshot:   ub.showScreenSnip,
            record:       ub.showScreenRecord,
            colorPicker:  ub.showColorPicker,
            notepad:      ub.showNotepad,
            osk:          ub.showKeyboardToggle,
            micToggle:    ub.showMicToggle,
            screenCast:   ub.showScreenCast,
            darkMode:     ub.showDarkModeToggle,
            powerProfile: ub.showPerformanceProfileToggle
        };
        return root.legacyOrder.filter(id => map[id] === true);
    }

    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout
        spacing: 4
        anchors.centerIn: parent

        Repeater {
            model: root.legacyShown
            delegate: ToolButton {
                required property string modelData
                toolId: modelData
                autoCloseAfterAction: false
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
