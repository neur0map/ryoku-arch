import QtQuick
import QtQuick.Layouts
import qs.dashboard.config
import qs.dashboard.modules.theme

Rectangle {
    property bool vert: false

    color: Colors.overBackground
    opacity: 0.1
    radius: Styling.radius(0)

    implicitWidth: vert ? 2 : 20
    implicitHeight: vert ? 20 : 2

    Layout.fillWidth: !vert
    Layout.fillHeight: vert
}
