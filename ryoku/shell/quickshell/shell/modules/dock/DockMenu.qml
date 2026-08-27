pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import Ryoku.Ui.Singletons

// Right-click context menu for a dock item: open / new window, pin or unpin
// (reflecting the current pin state), and close when the app is running. The
// Dock singleton owns the target and the actions; this only renders the rows.
Rectangle {
    id: menu

    readonly property bool pinned: Dock.menuPinned
    readonly property int count: Dock.menuCount

    readonly property var rows: {
        const r = [];
        r.push({ key: "open", label: menu.count > 0 ? I18n.tr("New window") : I18n.tr("Open") });
        r.push({ key: "pin", label: menu.pinned ? I18n.tr("Unpin") : I18n.tr("Pin") });
        if (menu.count > 0)
            r.push({ key: "close", label: I18n.tr("Close") });
        return r;
    }

    implicitWidth: 172
    implicitHeight: col.implicitHeight + 8
    radius: Theme.radiusWidget
    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.97)
    border.width: 1
    border.color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.14)

    // consume stray clicks on the menu background so they never fall through to
    // the overlay's dismiss layer
    MouseArea { anchors.fill: parent }

    Column {
        id: col
        width: parent.width
        y: 4

        Repeater {
            model: menu.rows
            delegate: Rectangle {
                id: row
                required property var modelData
                width: col.width
                height: 30
                color: rowMouse.containsMouse
                    ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                    : "transparent"

                Text {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: row.modelData.label
                    color: row.modelData.key === "close" ? Theme.error : Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.key === "open") Dock.menuActOpen();
                        else if (row.modelData.key === "pin") Dock.menuActPin();
                        else Dock.menuActClose();
                    }
                }
            }
        }
    }
}
