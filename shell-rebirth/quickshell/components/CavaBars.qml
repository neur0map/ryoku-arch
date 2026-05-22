import QtQuick
import QtQuick.Layouts
import qs.services as Services
import "../colors" as ColorsModule

Item {
    id: root

    property int barCount: Services.Cava.barsCount
    property real spacing: 3
    property real corner: 2
    property bool enableShadow: true

    Component.onCompleted: Services.Cava.running = true

    implicitHeight: 42
    implicitWidth: 320

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: Services.Cava.values

            Rectangle {
                width: Math.max(2, root.width / barCount - root.spacing)
                height: Math.max(2, modelData * root.height)

                radius: root.corner

                // Simplified gradient (slightly faster)
                gradient: Gradient {
                    GradientStop { position: 0;   color: ColorsModule.Colors.primary_container }
                    GradientStop { position: 1;   color: ColorsModule.Colors.primary }
                }

                anchors.verticalCenter: parent.verticalCenter

                // Disable height animations - they cause repaints
                // The values update fast enough that animation isn't needed
            }
        }
    }
}
