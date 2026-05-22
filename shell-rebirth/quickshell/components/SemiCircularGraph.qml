import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real value: 0
    property color fillColor: "#3daee9"
    property color backgroundColor: "#2a2a2a"
    property int lineWidth: 8
    property string label: ""

    width: 100
    height: 60

    Shape {
        anchors.fill: parent

        // Background arc
        ShapePath {
            strokeColor: root.backgroundColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height
                radiusX: (root.width / 2) - (root.lineWidth / 2)
                radiusY: (root.width / 2) - (root.lineWidth / 2)
                startAngle: 180
                sweepAngle: 180
            }
        }

        // Foreground arc (progress)
        ShapePath {
            strokeColor: root.fillColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height
                radiusX: (root.width / 2) - (root.lineWidth / 2)
                radiusY: (root.width / 2) - (root.lineWidth / 2)
                startAngle: 180
                sweepAngle: (root.value / 100) * 180
            }
        }
    }

    // Center text
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10
        spacing: 2

        Text {
            text: Math.round(root.value) + "%"
            color: "white"
            font.pixelSize: 16
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: root.label
            color: "#888888"
            font.pixelSize: 10
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}