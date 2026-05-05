import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: workspacesWidget.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    Workspaces {
        id: workspacesWidget
        anchors.centerIn: parent
        visible: Config.options?.bar?.modules?.workspaces ?? true
        height: parent.height

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onPressed: event => {
                if (event.button === Qt.RightButton) {
                    GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                }
            }
        }
    }
}
