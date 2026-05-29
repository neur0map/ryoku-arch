pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.components
import qs.services

// RYOKU: base type for gaming-overlay widgets. Visibility is enabled AND
// (overlay open OR pinned). Position restores from the layout record or a
// default cascade; `centered` mode ignores stored coords, stays screen-centered
// and is drag-exempt. The drag handle + pin toggle chrome shows only while the
// overlay is open. Moves persist on drag-release; pin toggles persist
// immediately via Gaming.setRecord.
Item {
    id: widget

    required property string widgetId
    property bool centered: false
    default property alias content: body.data

    readonly property var rec: Gaming.record(widget.widgetId)
    readonly property bool open: Gaming.open
    readonly property bool pinned: rec.pinned === true

    // True while the drag handle is actively dragging the widget. Position is
    // applied imperatively (see applyPosition) so the live drag isn't fought,
    // and external record/layout changes are ignored until the drag releases.
    readonly property bool dragging: dragArea.drag.active

    visible: rec.enabled === true && (open || pinned)

    // Centered widgets stay screen-centered reactively via anchors and are
    // drag-exempt; non-centered widgets get x/y applied imperatively so a drag
    // (which writes x/y directly) doesn't permanently kill a declarative binding.
    anchors.centerIn: centered ? parent : undefined

    function applyPosition(): void {
        if (widget.centered || widget.dragging)
            return;
        widget.x = rec.x >= 0 ? rec.x : 40 + Gaming.widgetIds.indexOf(widget.widgetId) * 30;
        widget.y = rec.y >= 0 ? rec.y : 40 + Gaming.widgetIds.indexOf(widget.widgetId) * 30;
    }

    onRecChanged: applyPosition()
    onCenteredChanged: applyPosition()
    Component.onCompleted: applyPosition()

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    Item {
        id: body

        anchors.fill: parent
    }

    // Edit chrome: drag handle + pin toggle. Only while the overlay is open and
    // not in centered (drag-exempt) mode.
    Row {
        visible: widget.open && !widget.centered
        anchors.bottom: parent.top
        anchors.left: parent.left
        spacing: 4

        // Drag handle. Persists the new position on release.
        StyledRect {
            implicitWidth: 22
            implicitHeight: 22
            radius: Tokens.rounding.small
            color: dragArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3surfaceVariant

            MaterialIcon {
                anchors.centerIn: parent
                text: "drag_indicator"
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: widget
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: widget.parent.width - widget.width
                drag.maximumY: widget.parent.height - widget.height

                onReleased: Gaming.setRecord(widget.widgetId, {
                    "x": Math.round(widget.x),
                    "y": Math.round(widget.y)
                })
            }
        }

        // Pin toggle. Persists immediately.
        StyledRect {
            implicitWidth: 22
            implicitHeight: 22
            radius: Tokens.rounding.small
            color: widget.pinned ? Colours.palette.m3primary : Colours.palette.m3surfaceVariant

            MaterialIcon {
                anchors.centerIn: parent
                text: "push_pin"
                fill: widget.pinned ? 1 : 0
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Gaming.setRecord(widget.widgetId, {
                    "pinned": !widget.pinned
                })
            }
        }
    }
}
