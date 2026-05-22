import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services as Services
import "../../../colors" as ColorsModule

Rectangle {
    id: wsContainer

    required property string fontFamily
    required property int fontSize

    readonly property var hypr: Services.Hyprland
    readonly property int activeWs: hypr.focusedWorkspaceId
    readonly property int workspaceCount: Math.max(10, hypr.workspaceIds.length)
    readonly property bool isSpecialOpen: false

    readonly property int visibleCount: 5
    property int pageCount: Math.max(
        20,
        Math.ceil(workspaceCount / visibleCount),
        Math.ceil(activeWs / visibleCount)
    )

    readonly property var colors: ColorsModule.Colors

    function changeWorkspace(id) {
        Services.Hyprland.changeWorkspace(id)
    }

    function changeWorkspaceRelative(delta) {
        changeWorkspace(activeWs + delta)
    }

    Layout.preferredHeight: 26
    Layout.preferredWidth: visibleCount * 26 + (visibleCount - 1) * 4 + 4
    color: colors.surface_container
    radius: height / 2
    clip: true

    ListView {
        id: pager
        anchors.fill: parent

        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        interactive: false

        highlightMoveDuration: 400

        model: pageCount
        currentIndex: Math.floor((activeWs - 1) / visibleCount)

        delegate: Item {
            property int startWs: index * visibleCount + 1
            property var pageOccupiedRanges: []

            function updatePageOccupied() {
                const ranges = []
                let start = -1

                for (let i = 0; i < visibleCount; i++) {
                    let wsId = startWs + i
                    let occupied = hypr.isWorkspaceOccupied(wsId)

                    if (occupied) {
                        if (start === -1) start = i
                    } else if (start !== -1) {
                        ranges.push({ start, end: i - 1 })
                        start = -1
                    }
                }

                if (start !== -1)
                    ranges.push({ start, end: visibleCount - 1 })

                pageOccupiedRanges = ranges
            }

            width: wsContainer.width
            height: wsContainer.height

            Component.onCompleted: updatePageOccupied()

            Connections {
                target: hypr
                function onStateChanged() { updatePageOccupied() }
            }

            Repeater {
                model: pageOccupiedRanges

                Rectangle {
                    height: 26
                    radius: 14
                    opacity: 0.8
                    color: colors.background

                    x: modelData.start * (26 + 4)
                    width: (modelData.end - modelData.start + 1) * 26 +
                        (modelData.end - modelData.start) * 4
                }
            }

            Rectangle {
                property int localIndex: activeWs - startWs

                visible: localIndex >= 0 && localIndex < visibleCount

                x: localIndex * (26 + 4) + 2
                width: 26
                height: 26
                radius: 13

                color: colors.primary

                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutSine } }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 4

                Repeater {
                    model: visibleCount

                    Item {
                        property int wsId: startWs + index
                        property bool isActive: wsId === activeWs
                        property bool hasWindows: hypr.isWorkspaceOccupied(wsId)

                        width: 26
                        height: 26

                        Rectangle {
                            visible: !isActive
                            anchors.centerIn: parent
                            width: hasWindows ? 6 : 4
                            height: width
                            radius: width / 2
                            color: hasWindows ? colors.primary : colors.secondary
                        }

                        Text {
                            visible: isActive
                            anchors.centerIn: parent
                            text: wsId
                            font.family: fontFamily
                            font.bold: true
                            color: colors.background
                            font.pixelSize: 17
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: changeWorkspace(wsId)
                        }
                    }
                }
            }
        }
    }
}
