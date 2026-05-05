import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool showKanjiClock: (Config.options?.bar?.modules?.kanjiClock ?? true)
        && (Config.options?.bar?.cornerStyle === 4)
    readonly property bool showSecPulse: (Config.options?.bar?.modules?.secPulse ?? true)
        && (Config.options?.bar?.cornerStyle === 4)
    readonly property bool showSidebarButton: Config.options?.bar?.modules?.rightSidebarButton ?? true

    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer0

    implicitWidth: rowLayout.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        SecPulseIndicator {
            visible: root.showSecPulse
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            visible: root.showSecPulse && root.showKanjiClock
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 1
            Layout.preferredHeight: parent.height * 0.5
            color: root.colText
            opacity: 0.2
        }

        RyokuKanjiClock {
            visible: root.showKanjiClock
            Layout.alignment: Qt.AlignVCenter
        }

        // Compact sidebar trigger: tap to toggle the right sidebar.
        // The existing right-sidebar indicator cluster (mic/volume/notifs/etc.)
        // is intentionally NOT replicated here in v1; the cluster lives in
        // BarContent.qml only. Users who want it can leave Three-Island off.
        MaterialSymbol {
            visible: root.showSidebarButton
            Layout.alignment: Qt.AlignVCenter
            text: "menu"
            iconSize: Appearance.font.pixelSize.larger
            color: root.colText

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: event => {
                    if (event.button === Qt.RightButton)
                        GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
                    else
                        GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }
            }
        }
    }
}
