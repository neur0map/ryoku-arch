import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../colors" as ColorsModule
import qs.services

Item {
    id: readerView

    readonly property var c: ColorsModule.Colors
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    signal backRequested()

    property real fontSize:      17
    property real lineHeight:    1.75
    property bool headerVisible: true

    function reset() {
        headerVisible = true
        textScroll.contentY = 0
    }

    readonly property bool _hasPrev: Novel.currentChapter !== null && Novel.currentChapter.prevId !== ""
    readonly property bool _hasNext: Novel.currentChapter !== null && Novel.currentChapter.nextId !== ""

    Rectangle { anchors.fill: parent; color: "#1a1714" }

    Rectangle {
        id: readerHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 54; color: Qt.rgba(0.08, 0.07, 0.06, 0.97); z: 10
        opacity: readerView.headerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1; color: Qt.rgba(1, 1, 1, 0.07)
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 14 }
            spacing: 2

            Item {
                width: 44; height: 44
                Rectangle {
                    anchors.centerIn: parent; width: 34; height: 34; radius: 17
                    color: backHover.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: 130 } }
                }
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 18; color: Qt.rgba(1,1,1,0.7) }
                MouseArea {
                    id: backHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: { Novel.clearChapter(); readerView.backRequested() }
                }
            }

            Column {
                Layout.fillWidth: true; spacing: 1
                Text {
                    width: parent.width
                    text: Novel.currentNovel ? Novel.currentNovel.title : ""
                    font.family: readerView.fontDisplay; font.pixelSize: 11
                    color: Qt.rgba(1,1,1,0.45); elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Novel.currentChapter ? Novel.currentChapter.title : ""
                    font.family: readerView.fontDisplay; font.pixelSize: 13
                    color: Qt.rgba(1,1,1,0.85); elide: Text.ElideRight
                }
            }

            Item {
                width: 34; height: 34
                Rectangle {
                    anchors.centerIn: parent; width: 30; height: 30; radius: 15
                    color: fsMinusHover.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text { anchors.centerIn: parent; text: "A−"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.55) }
                MouseArea {
                    id: fsMinusHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: readerView.fontSize = Math.max(13, readerView.fontSize - 1)
                }
            }

            Item {
                width: 34; height: 34
                Rectangle {
                    anchors.centerIn: parent; width: 30; height: 30; radius: 15
                    color: fsPlusHover.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Text { anchors.centerIn: parent; text: "A+"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.55) }
                MouseArea {
                    id: fsPlusHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: readerView.fontSize = Math.min(26, readerView.fontSize + 1)
                }
            }

            Rectangle {
                visible: Novel.currentChapter !== null && Novel.currentChapter.wordCount > 0
                height: 24; width: wcTxt.implicitWidth + 18; radius: 12
                color: Qt.rgba(1,1,1,0.07); border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                Text {
                    id: wcTxt; anchors.centerIn: parent
                    text: Novel.currentChapter !== null
                        ? (Math.round(Novel.currentChapter.wordCount / 100) / 10) + "k words" : ""
                    font.family: readerView.fontBody; font.pixelSize: 10
                    font.letterSpacing: 0.4; color: Qt.rgba(1,1,1,0.45)
                }
            }
        }
    }

    Item {
        anchors { top: readerHeader.bottom; left: parent.left; right: parent.right }
        height: 2; z: 9
        Rectangle { anchors.fill: parent; color: Qt.rgba(1,1,1,0.04) }
        Rectangle {
            width: textScroll.contentHeight > textScroll.height
                ? parent.width * Math.min(1,
                (textScroll.contentY + textScroll.height) / textScroll.contentHeight)
                : parent.width
            height: parent.height; color: c.primary
            Behavior on width { NumberAnimation { duration: 120 } }
        }
    }

    Rectangle {
        anchors.fill: parent; color: "#1a1714"; visible: Novel.isFetchingChapter; z: 8
        Column {
            anchors.centerIn: parent; spacing: 16
            Rectangle {
                width: 40; height: 40; radius: 20
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"; border.color: c.primary; border.width: 2.5
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 800
                    loops: Animation.Infinite; running: parent.visible; easing.type: Easing.Linear
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "loading chapter"; color: Qt.rgba(1,1,1,0.35)
                font.family: readerView.fontBody; font.pixelSize: 11; font.letterSpacing: 2.5
            }
        }
    }

    Rectangle {
        anchors.fill: parent; color: "#1a1714"; z: 7
        visible: Novel.chapterError.length > 0 && !Novel.isFetchingChapter
        Column {
            anchors.centerIn: parent; spacing: 10
            Text {
                text: "⚠"; font.pixelSize: 32; color: c.error; opacity: 0.85
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: Novel.chapterError; color: Qt.rgba(1,1,1,0.4)
                font.pixelSize: 11; font.family: readerView.fontBody
                wrapMode: Text.Wrap; width: 260; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
            }
        }
    }

    Flickable {
        id: textScroll
        anchors {
            fill: parent
            topMargin: readerView.headerVisible ? 56 : 2
            bottomMargin: 56
        }
        contentWidth: width
        contentHeight: textColumn.implicitHeight + 80
        clip: true; boundsBehavior: Flickable.StopAtBounds
        Behavior on anchors.topMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent; propagateComposedEvents: true
            onClicked: { readerView.headerVisible = !readerView.headerVisible; mouse.accepted = false }
        }

        Column {
            id: textColumn
            width: Math.min(parent.width - 48, 720)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 36; bottomPadding: 48; spacing: 0

            Text {
                width: parent.width
                text: Novel.currentChapter ? Novel.currentChapter.title : ""
                font.family: readerView.fontDisplay
                font.pixelSize: readerView.fontSize + 7
                font.bold: true
                color: Qt.rgba(0.96, 0.93, 0.87, 0.90)
                wrapMode: Text.Wrap; lineHeight: 1.25; bottomPadding: 8
            }

            Item {
                width: parent.width; height: 24
                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    Rectangle { width: 8;  height: 2; radius: 1; color: c.primary; opacity: 0.3 }
                    Rectangle { width: 32; height: 2; radius: 1; color: c.primary; opacity: 0.7 }
                    Rectangle { width: 8;  height: 2; radius: 1; color: c.primary; opacity: 0.3 }
                }
            }

            Item { width: 1; height: 20 }

            Repeater {
                model: Novel.currentChapter ? Novel.currentChapter.paragraphs : []
                Text {
                    width: textColumn.width
                    text: modelData
                    font.family: readerView.fontDisplay
                    font.pixelSize: readerView.fontSize
                    color: Qt.rgba(0.91, 0.87, 0.80, 0.87)
                    wrapMode: Text.Wrap; lineHeight: readerView.lineHeight
                    bottomPadding: Math.round(readerView.fontSize * readerView.lineHeight * 0.75)
                    textFormat: Text.PlainText
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 2; color: c.primary; opacity: 0.25; radius: 1 }
        }
    }

    Rectangle {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 56; color: Qt.rgba(0.08, 0.07, 0.06, 0.97); z: 10

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1; color: Qt.rgba(1,1,1,0.07)
        }

        Row {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

            Item {
                width: parent.width / 3; height: parent.height
                opacity: readerView._hasPrev ? 1.0 : 0.25
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Rectangle {
                    id: prevBtn
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left }
                    width: prevBtnRow.implicitWidth + 28; height: 36; radius: 18
                    color: prevNavArea.containsMouse && readerView._hasPrev
                        ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.06)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: prevBtnRow; anchors.centerIn: parent; spacing: 5
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "‹"; font.pixelSize: 18; color: Qt.rgba(1,1,1,0.7) }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Prev"; font.family: readerView.fontBody; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.7) }
                    }
                }

                MouseArea {
                    id: prevNavArea; anchors.fill: parent; hoverEnabled: true
                    enabled: readerView._hasPrev
                    onClicked: { Novel.fetchPrevChapter(); textScroll.contentY = 0 }
                }
            }

            Item {
                width: parent.width / 3; height: parent.height
                Text {
                    anchors.centerIn: parent
                    text: Novel.currentChapter ? Novel.currentChapter.title : ""
                    font.family: readerView.fontBody; font.pixelSize: 10
                    color: Qt.rgba(1,1,1,0.28); font.letterSpacing: 0.4
                    elide: Text.ElideMiddle; width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item {
                width: parent.width / 3; height: parent.height
                opacity: readerView._hasNext ? 1.0 : 0.25
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Rectangle {
                    id: nextBtn
                    anchors { verticalCenter: parent.verticalCenter; right: parent.right }
                    width: nextBtnRow.implicitWidth + 28; height: 36; radius: 18
                    color: nextNavArea.containsMouse && readerView._hasNext
                        ? Qt.rgba(c.primary.r, c.primary.g, c.primary.b, 0.45)
                        : Qt.rgba(c.primary.r, c.primary.g, c.primary.b, 0.22)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: nextBtnRow; anchors.centerIn: parent; spacing: 5
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Next"; font.family: readerView.fontBody; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.92) }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "›"; font.pixelSize: 18; color: Qt.rgba(1,1,1,0.92) }
                    }
                }

                MouseArea {
                    id: nextNavArea; anchors.fill: parent; hoverEnabled: true
                    enabled: readerView._hasNext
                    onClicked: {
                        if (Novel.currentNovel && Novel.isInLibrary(Novel.currentNovel.id) && Novel.currentChapter)
                            Novel.updateLastRead(Novel.currentNovel.id, Novel.currentChapter.nextId, "")
                        Novel.fetchNextChapter()
                        textScroll.contentY = 0
                    }
                }
            }
        }
    }
}
