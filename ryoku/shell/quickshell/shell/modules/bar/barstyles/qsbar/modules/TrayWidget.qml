import Quickshell
import shell.services
import QtQuick

Item {
    id: rootMod
    required property var root

    implicitWidth: trayRow.implicitWidth
    implicitHeight: 28
    visible: trayRow.implicitWidth > 0

    function toggleHide(item) {
        root.trayToggleHide(item)
    }

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Tray.items

            delegate: Item {
                id: trayDelegate
                required property var modelData

                // Tray glyphs are visually smaller than the adjacent package/bell
                // icons. Keep their cell compact so pinning does not open a large
                // apparent gap inside the shared status pill.
                implicitWidth: 18
                implicitHeight: 28
                visible: root.trayPinned.indexOf(modelData.service) >= 0

                Image {
                    anchors.centerIn: parent
                    source: modelData.iconPath ? "file://" + modelData.iconPath : (modelData.iconName ? Quickshell.iconPath(modelData.iconName, true) : "")
                    sourceSize.width: 14
                    sourceSize.height: 14
                    width: 14
                    height: 14
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (e) => {
                        if (e.button === Qt.LeftButton)
                            Tray.activate(modelData.service)
                        else if (e.button === Qt.RightButton)
                            rootMod.toggleHide(modelData)
                    }
                }
            }
        }

        // ── toggle: more_horiz icon + seal count badge ──
        Item {
            id: toggleBtn
            implicitWidth: 22
            implicitHeight: 28
            visible: hiddenCount > 0

            // count CURRENTLY-EXISTING tray items that are not pinned (= hidden behind this
            // button), iterating Tray.items so stale pinned IDs can't inflate the count
            readonly property int hiddenCount: {
                var n = 0, its = Tray.items
                for (var i = 0; i < its.length; i++) if (root.trayPinned.indexOf(its[i].service) < 0) n++
                return n
            }
            readonly property int totalCount:  Tray.items.length
            readonly property string tooltipText: totalCount + (totalCount === 1 ? " app" : " apps")
                                                  + (hiddenCount > 0 ? " · " + hiddenCount + " hidden" : "")

            TooltipMixin { id: tip; root: rootMod.root; owner: toggleBtn; text: toggleBtn.tooltipText }

            IconText {
                id: moreIcon
                anchors.centerIn: parent
                text: "\uE5D3"   // more_horiz
                font.pixelSize: 16
                color: toggleMa.containsMouse
                    ? root.ink
                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            // count badge — top-right
            Rectangle {
                id: toggleBadge
                visible: toggleBtn.hiddenCount > 0
                width: Math.max(12, toggleBadgeTxt.implicitWidth + 6)
                height: 12
                radius: 6
                color: root.seal
                anchors.verticalCenter: moreIcon.verticalCenter
                anchors.verticalCenterOffset: -6
                anchors.horizontalCenter: moreIcon.horizontalCenter
                anchors.horizontalCenterOffset: 7
                Text {
                    id: toggleBadgeTxt
                    anchors.centerIn: parent
                    text: toggleBtn.hiddenCount
                    color: root.paper
                    font.family: root.mono
                    font.pixelSize: 7
                    font.weight: Font.Bold
                }
            }

            MouseArea {
                id: toggleMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: tip.show()
                onExited: { tip.hide() }
                onClicked: { tip.hide(); root.trayVisible = !root.trayVisible }
            }
        }
    }
}
