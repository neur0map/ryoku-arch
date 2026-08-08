pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Ui
import Ryoku.Ui.Singletons

Item {
    id: root

    property var settings: ({})
    signal editRequested(string key, var value)

    implicitWidth: 720
    implicitHeight: 250

    readonly property var applications: [
        { "name": "Firefox", "glyph": "language" },
        { "name": "Kitty", "glyph": "terminal" },
        { "name": "Files", "glyph": "folder" }
    ]

    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
    }

    Column {
        width: root.implicitWidth - Tokens.s7 * 3 - Tokens.s4
        anchors.centerIn: parent
        spacing: Tokens.s2

        Rectangle {
            width: parent.width
            height: Tokens.rowH + Tokens.s1
            radius: Tokens.radius
            color: Tokens.paperLift
            border.width: Tokens.border
            border.color: Tokens.lineStrong

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.s3
                anchors.rightMargin: Tokens.s2
                spacing: Tokens.s3

                Text {
                    text: "search"
                    color: Tokens.ink
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Tokens.fValue
                    Accessible.ignored: true
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.tr("Search")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fRow
                }

                Rectangle {
                    Layout.preferredWidth: Tokens.s6
                    Layout.preferredHeight: Tokens.s6
                    radius: Tokens.radius
                    color: Tokens.tint5
                    border.width: Tokens.border
                    border.color: Tokens.line

                    Text {
                        anchors.centerIn: parent
                        text: "visibility_off"
                        color: Tokens.inkDim
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.fRow
                        Accessible.ignored: true
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: appRows.height + Tokens.s4
            radius: Tokens.radius
            color: Tokens.paperLift
            border.width: Tokens.border
            border.color: Tokens.line

            Column {
                id: appRows
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.applications

                    delegate: Item {
                        id: appRow

                        required property var modelData
                        required property int index

                        width: appRows.width
                        height: Tokens.rowH
                        readonly property bool selected: index === 0

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.s2
                            anchors.rightMargin: Tokens.s2
                            visible: appRow.selected
                            radius: Tokens.radius
                            color: Tokens.tint10
                            border.width: Tokens.border
                            border.color: Tokens.lineStrong
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.s3 + (appRow.selected ? Tokens.s5 : 0)
                            anchors.rightMargin: Tokens.s4
                            spacing: Tokens.s3

                            Text {
                                text: appRow.modelData.glyph
                                color: Tokens.inkDim
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: Tokens.fValue
                                Accessible.ignored: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: appRow.modelData.name
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fBody
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: appRow.selected
                                text: I18n.tr("Run")
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fMicro
                            }
                        }
                    }
                }
            }
        }
    }

    Grain {
        anchors.fill: parent
        Accessible.ignored: true
    }
}
