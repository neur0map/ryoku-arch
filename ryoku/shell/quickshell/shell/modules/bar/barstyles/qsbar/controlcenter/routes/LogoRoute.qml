import QtQuick
import "../kit"
import "../../modules"

// Logo route — choose the launcher mark shown on the bar. The one real qsbar
// knob: root.launcherLogoMode = "text" (RYOKU wordmark) | "icon" (力 kanji).
// Two selectable preview cards each render the ACTUAL launcher pill (see
// modules/LauncherWidget.qml), so the choice is live and honest.
Item {
    id: page
    property var root: null
    property var cc: null

    readonly property string mode: page.root ? String(page.root.launcherLogoMode || "text") : "text"

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
                title: "LAUNCHER MARK"

                UiText {
                    width: parent.width
                    text: "Pick the mark shown in the bar launcher pill."
                    color: page.root ? page.root.sumi : "#888888"
                    font.family: page.root ? page.root.mono : "monospace"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }

                Row {
                    width: parent.width
                    spacing: page.cc ? page.cc.tokens.colGap : 14

                    Repeater {
                        model: [
                            { mode: "text", label: "Wordmark", glyph: "RYOKU" },
                            { mode: "icon", label: "Kanji 力",  glyph: "力" }
                        ]

                        delegate: Rectangle {
                            id: markCard
                            required property var modelData
                            readonly property bool selected: page.mode === modelData.mode
                            readonly property bool iconMode: modelData.mode === "icon"

                            width: (parent.width - (page.cc ? page.cc.tokens.colGap : 14)) / 2
                            height: 132
                            radius: page.root ? page.root.tileRadius : 10
                            color: page.root
                                ? (selected || cardMa.containsMouse ? page.root.fillHover : page.root.fillIdle)
                                : "#1a1a1a"
                            border.width: selected ? 1.5 : 1
                            border.color: page.root
                                ? (selected ? page.root.seal : page.root.frameWeak)
                                : "#333333"

                            Behavior on border.color { ColorAnimation { duration: 160 } }
                            Behavior on color { ColorAnimation { duration: 160 } }

                            // The real launcher pill, faithful to LauncherWidget.qml.
                            Rectangle {
                                id: pill
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 30
                                width: mark.implicitWidth + 12
                                height: page.root ? page.root.pillH : 20
                                radius: page.root ? page.root.pillRadius : 8
                                color: page.root ? page.root.pill : "#222222"
                                border.color: page.root ? page.root.pillBorder : "#333333"
                                border.width: page.root ? page.root.pillBorderW : 1

                                Text {
                                    id: mark
                                    anchors.centerIn: parent
                                    text: markCard.modelData.glyph
                                    color: page.root ? page.root.seal : "#c0392b"
                                    renderType: Text.NativeRendering
                                    font.family: markCard.iconMode
                                        ? "Noto Sans CJK JP"
                                        : (page.root ? page.root.mono : "monospace")
                                    font.pixelSize: markCard.iconMode ? 15 : 12
                                    font.weight: Font.Bold
                                    font.letterSpacing: markCard.iconMode ? 0 : 2
                                }
                            }

                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                                text: markCard.modelData.label
                                color: page.root
                                    ? (markCard.selected ? page.root.seal : page.root.ink)
                                    : "#cccccc"
                                font.family: page.root ? page.root.mono : "monospace"
                                font.pixelSize: 11
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: cardMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (page.root) page.root.launcherLogoMode = markCard.modelData.mode
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
