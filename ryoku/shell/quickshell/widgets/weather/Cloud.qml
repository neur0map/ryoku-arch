import QtQuick

// one soft cloud: base bar + 3 puffs, all rounded rects so it scales clean at
// any widget size. shared by every overcast sky (clouds, rain, snow, storm)
// so the shape lives in one place. tint = body, glow = the faint top highlight.
Item {
    id: cloud

    property color tint: "#e6ebff"
    property real solid: 0.92

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: parent.height * 0.46
        radius: height / 2
        color: Qt.rgba(cloud.tint.r, cloud.tint.g, cloud.tint.b, cloud.solid)
    }
    Rectangle {
        x: parent.width * 0.08
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.18
        width: parent.height * 0.62
        height: width
        radius: width / 2
        color: Qt.rgba(cloud.tint.r, cloud.tint.g, cloud.tint.b, cloud.solid)
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: parent.height * 0.86
        height: width
        radius: width / 2
        color: Qt.rgba(cloud.tint.r, cloud.tint.g, cloud.tint.b, cloud.solid)
    }
    Rectangle {
        x: parent.width * 0.92 - width
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.16
        width: parent.height * 0.66
        height: width
        radius: width / 2
        color: Qt.rgba(cloud.tint.r, cloud.tint.g, cloud.tint.b, cloud.solid)
    }
}
