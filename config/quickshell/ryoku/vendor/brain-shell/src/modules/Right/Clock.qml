import QtQuick
import "../../"

Text {
    id: clock
    text: Qt.formatDateTime(new Date(), "hh:mm")
    color: Theme.text
    font.bold: true
    anchors.verticalCenter: parent.verticalCenter
    font.pixelSize: 16

    property int formatMode: 0

    state: "time"
    states: [
        State {
            name: "time"
            PropertyChanges { target: clock; formatMode: 0 }
        },
        State {
            name: "timeSeconds"
            PropertyChanges { target: clock; formatMode: 1 }
        },
        State {
            name: "date"
            PropertyChanges { target: clock; formatMode: 2 }
        }
    ]

    MouseArea {
        anchors.fill: parent
        acceptedButtons:     Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (clock.state === "time" || clock.state === "timeSeconds") {
                    clock.state = "date"
                } else if (clock.state === "date" || clock.state === "timeSeconds") {
                    clock.state = "time"
                }
            } else {
                if (clock.state === "time"|| clock.state === "date") {
                    clock.state = "timeSeconds"
                } else if (clock.state === "timeSeconds" || clock.state === "date") {
                    clock.state = "time"
                }
            }
            updateText()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateText()
    }

    function updateText() {
        let now = new Date()
        switch(formatMode) {
            case 0:
                text = Qt.formatDateTime(now, "hh:mm")
                break
            case 1:
                text = Qt.formatDateTime(now, "hh:mm:ss")
                break
            case 2:
                text = Qt.formatDateTime(now, "dd-MM-yyyy")
                break
        }
    }

    Component.onCompleted: updateText()
}
