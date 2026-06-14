import QtQuick

Item {
    id: root

    readonly property real designWidth: 512
    readonly property real designHeight: 512

    implicitWidth: designWidth
    implicitHeight: designHeight

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/logo.png")
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
    }
}
