import QtQuick
import "../kit"
import "../../modules"

// PICKERS route — port of Shibumi's PickerSettingsPage + PickerPreviewCard.
// Choose the media/image browser layout used by the next wallpaper/screenshot
// picker. The style is written straight to root.pickerStyle. Three selectable
// cards, each with a small schematic of its layout drawn from root tokens:
//   tanzaku     = two columns
//   hearthstone = single wide column
//   carousel    = a centered row of thumbs
Item {
    id: page
    property var root: null
    property var cc: null

    readonly property var pickers: [
        { key: "tanzaku", label: "Tanzaku", sub: "Two columns" },
        { key: "hearthstone", label: "Hearthstone", sub: "Single column" },
        { key: "carousel", label: "Carousel", sub: "Thumb row" }
    ]

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: page.cc ? page.cc.tokens.sectionGap : 16

            CcSection {
                width: parent.width
                root: page.root
                title: "PICKER STYLE"

                UiText {
                    width: parent.width
                    text: "The layout the wallpaper and screenshot pickers use."
                    color: page.root ? page.root.sumi : "#888888"
                    font.family: page.root ? page.root.mono : "monospace"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Row {
                    width: parent.width
                    spacing: page.cc ? page.cc.tokens.gap : 10

                    Repeater {
                        model: page.pickers
                        delegate: PickerCard {
                            required property var modelData
                            width: (parent.width - parent.spacing * 2) / 3
                            item: modelData
                        }
                    }
                }
            }
        }
    }

    // ── a selectable style card with a schematic layout preview ──
    component PickerCard: Rectangle {
        id: cardRoot
        property var item: ({})
        readonly property var root: page.root
        readonly property string key: item.key || ""
        readonly property bool sel: cardRoot.root ? cardRoot.root.pickerStyle === cardRoot.key : false

        readonly property color accent: cardRoot.root ? cardRoot.root.seal : "#c4746e"
        readonly property color panelFill: cardRoot.sel ? Qt.rgba(accent.r, accent.g, accent.b, 0.20)
                     : (cardRoot.root ? Qt.rgba(cardRoot.root.ink.r, cardRoot.root.ink.g, cardRoot.root.ink.b, 0.10) : "#22ffffff")
        readonly property color panelLine: cardRoot.sel ? accent
                     : (cardRoot.root ? Qt.rgba(cardRoot.root.ink.r, cardRoot.root.ink.g, cardRoot.root.ink.b, 0.34) : "#55888888")
        readonly property color slat: cardRoot.sel ? Qt.rgba(accent.r, accent.g, accent.b, 0.80)
                     : (cardRoot.root ? Qt.rgba(cardRoot.root.ink.r, cardRoot.root.ink.g, cardRoot.root.ink.b, 0.42) : "#66888888")

        height: 138
        radius: cardRoot.root ? cardRoot.root.tileRadius : 6
        color: cardRoot.sel ? Qt.rgba(accent.r, accent.g, accent.b, cardRoot.root ? cardRoot.root.fillActiveAlpha : 0.14)
                            : (ma.containsMouse ? (cardRoot.root ? Qt.rgba(accent.r, accent.g, accent.b, cardRoot.root.fillHoverAlpha) : "#22ffffff")
                                                : (cardRoot.root ? cardRoot.root.fillIdle : "#1affffff"))
        border.width: cardRoot.sel ? 2 : 1
        border.color: (cardRoot.sel || ma.containsMouse) ? accent : (cardRoot.root ? cardRoot.root.sep : "#444444")
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        // ── schematic preview ──
        Item {
            id: schematic
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            height: 66

            // tanzaku: two columns of stacked slats
            Row {
                visible: cardRoot.key === "tanzaku"
                anchors.fill: parent
                spacing: 8
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        width: (schematic.width - 8) / 2
                        height: schematic.height
                        radius: 4
                        color: cardRoot.panelFill
                        border.width: 1
                        border.color: cardRoot.panelLine
                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 5
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    width: parent.width; height: 4; radius: 2
                                    color: cardRoot.slat
                                }
                            }
                        }
                    }
                }
            }

            // hearthstone: one wide centered column, header + rows
            Rectangle {
                visible: cardRoot.key === "hearthstone"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: schematic.width * 0.62
                height: schematic.height
                radius: 4
                color: cardRoot.panelFill
                border.width: 1
                border.color: cardRoot.panelLine
                Column {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 6
                    Rectangle {                       // header
                        width: parent.width; height: 12; radius: 2
                        color: cardRoot.slat
                    }
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: parent.width; height: 6; radius: 2
                            color: cardRoot.panelLine
                        }
                    }
                }
            }

            // carousel: a centered row of thumbs, middle one emphasized
            Row {
                visible: cardRoot.key === "carousel"
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        readonly property bool mid: index === 2
                        width: mid ? 30 : 18
                        height: mid ? 46 : 34
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: mid ? cardRoot.panelFill
                                   : (cardRoot.root ? Qt.rgba(cardRoot.root.ink.r, cardRoot.root.ink.g, cardRoot.root.ink.b, 0.06) : "#14ffffff")
                        border.width: 1
                        border.color: mid ? cardRoot.panelLine
                                          : (cardRoot.root ? Qt.rgba(cardRoot.root.ink.r, cardRoot.root.ink.g, cardRoot.root.ink.b, 0.22) : "#44888888")
                    }
                }
            }
        }

        // ── label + sub ──
        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8 }
            spacing: 1
            UiText {
                text: cardRoot.item.label || ""
                color: cardRoot.sel ? cardRoot.accent : (cardRoot.root ? cardRoot.root.ink : "#dddddd")
                font.family: cardRoot.root ? cardRoot.root.mono : "monospace"
                font.pixelSize: 12
            }
            UiText {
                text: cardRoot.item.sub || ""
                color: cardRoot.root ? cardRoot.root.sumi : "#888888"
                font.family: cardRoot.root ? cardRoot.root.mono : "monospace"
                font.pixelSize: 9
            }
        }

        // ── selected tick ──
        IconText {
            visible: cardRoot.sel
            anchors { right: parent.right; top: parent.top; margins: 6 }
            text: "check"
            color: cardRoot.accent
            font.pixelSize: 14
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (cardRoot.root) cardRoot.root.pickerStyle = cardRoot.key
        }
    }
}
