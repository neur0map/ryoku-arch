import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "Singletons"

RowLayout {
    id: root
    property real s: 1
    property bool opened: false

    spacing: 10 * s

    component Pill: Rectangle {
        property bool active: false
        property string icon: ""
        property string title: ""
        property string state: ""
        signal clicked()

        Layout.fillWidth: true
        radius: 13 * root.s
        implicitHeight: 44 * root.s
        border.width: 1
        border.color: active ? Theme.vermLit : Theme.border
        gradient: active ? onGrad : offGrad

        Gradient {
            id: offGrad
            GradientStop { position: 0.0; color: Theme.panelTop }
            GradientStop { position: 1.0; color: Theme.panelBot }
        }
        Gradient {
            id: onGrad
            GradientStop { position: 0.0; color: Theme.vermLit }
            GradientStop { position: 1.0; color: Theme.verm }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 9 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 18 * root.s; height: 18 * root.s
                Image {
                    id: pIcon
                    anchors.fill: parent
                    source: Qt.resolvedUrl("assets/icons/" + icon + ".svg")
                    sourceSize.width: 64; sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true; visible: false
                }
                MultiEffect {
                    anchors.fill: pIcon
                    source: pIcon
                    colorization: 1.0
                    colorizationColor: active ? Theme.onAccent : Theme.iconDim
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s
                Text {
                    text: title
                    color: active ? Theme.onAccent : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    text: state
                    color: active ? Qt.rgba(251/255, 238/255, 231/255, 0.78) : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.4 * root.s
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Pill {
        active: Flags.dnd
        icon: "bell"
        title: "Do Not Disturb"
        state: Flags.dnd ? "On" : "Off"
        onClicked: Flags.dnd = !Flags.dnd
    }
    Pill {
        active: Flags.keepAwake
        icon: "eye"
        title: "Keep Awake"
        state: Flags.keepAwake ? "On" : "Off"
        onClicked: Flags.keepAwake = !Flags.keepAwake
    }
}
