import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colSuccess: "#7fcc7f"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        color: Qt.rgba(0.5, 0.8, 0.5, 0.16)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "✓"
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
            color: root.colSuccess
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: ScreenshotEvents.toastText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: event => {
            const path = ScreenshotEvents.lastFilePath
            if (!path) return;
            if (event.button === Qt.LeftButton) {
                Qt.openUrlExternally("file://" + path)
            } else if (event.button === Qt.RightButton) {
                const dir = path.substring(0, path.lastIndexOf("/"))
                Qt.openUrlExternally("file://" + dir)
            }
        }
    }
}
