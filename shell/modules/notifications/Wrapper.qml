import QtQuick
import qs.components
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel

    // The whole notification panel (its blob tracks this position) slides out into
    // the right frame border on close and emerges from it on open, keyed on whether
    // any popup is showing. Combined with the height collapse this reads as the panel
    // merging with the right frame, instead of only shrinking vertically. Driven via
    // anchors.rightMargin (not a transform) so the panel's real x moves and the blob
    // (ContentWindow notifsBg, x = panel.x) follows it.
    readonly property bool hasPopups: Notifs.popups.some(n => !n.closed)

    visible: hasPopups || anchors.rightMargin > -implicitWidth + 0.5
    anchors.topMargin: -5
    anchors.rightMargin: hasPopups ? 0 : -implicitWidth
    implicitWidth: Math.max(sidebarPanel.width, content.implicitWidth)
    implicitHeight: content.implicitHeight

    Behavior on anchors.rightMargin {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Content {
        id: content

        visibilities: root.visibilities
    }
}
