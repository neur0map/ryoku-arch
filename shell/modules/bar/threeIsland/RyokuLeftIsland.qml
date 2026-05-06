import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    readonly property bool taskbarEnabled: Config.options?.bar?.modules?.taskbar ?? false
    readonly property bool showDateLabel: Config.options?.bar?.modules?.dateLabel ?? true
    property var parentWindow: null

    implicitWidth: rowLayout.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        LeftSidebarButton {
            visible: Config.options?.bar?.modules?.leftSidebarButton ?? true
            Layout.alignment: Qt.AlignVCenter
            colBackground: buttonHovered
                ? (Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover)
                : "transparent"
        }

        ActiveWindow {
            visible: (Config.options?.bar?.modules?.activeWindow ?? true) && !root.taskbarEnabled
            Layout.fillWidth: !root.taskbarEnabled
            Layout.fillHeight: true
        }

        Loader {
            active: root.taskbarEnabled
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: BarTaskbar {
                parentWindow: root.parentWindow
            }
        }

        RyokuDateLabel {
            visible: root.showDateLabel
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
