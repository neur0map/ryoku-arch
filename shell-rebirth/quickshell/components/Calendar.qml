import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../colors" as ColorsModule

Item {
    id: root

    property date currentDate: new Date()

    implicitWidth: 340
    implicitHeight: 360

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate()
    }

    function firstDayOffset(y, m) {
        return (new Date(y, m, 1).getDay() + 6) % 7
    }

    function isToday(y, m, d) {
        const t = new Date()
        return t.getFullYear() === y &&
            t.getMonth() === m &&
            t.getDate() === d
    }

    function monthModel() {
        const y = currentDate.getFullYear()
        const m = currentDate.getMonth()

        const offset = firstDayOffset(y, m)
        const total = daysInMonth(y, m)

        let arr = []

        for (let i = 0; i < offset; i++)
            arr.push({ day: 0 })

        for (let d = 1; d <= total; d++)
            arr.push({ day: d })

        return arr
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: ColorsModule.Colors.surface_container
        border.color: ColorsModule.Colors.outline_variant
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true

                ToolButton {
                    text: "◀"
                    onClicked: {
                        root.currentDate =
                            new Date(root.currentDate.getFullYear(),
                                root.currentDate.getMonth()-1, 1)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.currentDate, "MMMM yyyy")
                    font.bold: true
                    font.pixelSize: 15
                    color: ColorsModule.Colors.on_surface
                }

                ToolButton {
                    text: "▶"
                    onClicked: {
                        root.currentDate =
                            new Date(root.currentDate.getFullYear(),
                                root.currentDate.getMonth()+1, 1)
                    }
                }
            }

            GridLayout {
                columns: 7
                Layout.fillWidth: true

                Repeater {
                    model: ["M","T","W","T","F","S","S"]

                    Text {
                        text: modelData
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 10
                        color: ColorsModule.Colors.on_surface_variant
                        opacity: 0.7
                        Layout.fillWidth: true
                    }
                }
            }

            GridLayout {
                columns: 7
                columnSpacing: 6
                rowSpacing: 6
                Layout.fillWidth: true

                Repeater {
                    model: root.monthModel()

                    delegate: Rectangle {
                        width: 40
                        height: 36
                        radius: 10

                        property bool valid: modelData.day > 0
                        property bool today:
                            valid &&
                            root.isToday(
                                root.currentDate.getFullYear(),
                                root.currentDate.getMonth(),
                                modelData.day
                            )

                        color:
                            today ? ColorsModule.Colors.primary :
                                "transparent"

                        border.color:
                            valid ? ColorsModule.Colors.outline_variant :
                                "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: valid ? modelData.day : ""
                            font.pixelSize: 12

                            color:
                                today ? ColorsModule.Colors.on_primary :
                                    ColorsModule.Colors.on_surface
                        }
                    }
                }
            }
        }
    }
}
