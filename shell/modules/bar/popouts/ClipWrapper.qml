pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    // A horizontal bar (top/bottom) drops popouts DOWN from its inner edge, centred on
    // the hovered item's X; a vertical bar (left/right) slides them OUT, centred on its Y.
    // The parent (Panels) is already inset past the bar, so the bar-facing edge is parent's.
    readonly property string edge: BarDesign.edge
    readonly property bool horizontal: edge === "top" || edge === "bottom"

    readonly property alias content: content
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: root.horizontal ? content.implicitWidth : content.implicitWidth * (1 - offsetScale)
    implicitHeight: root.horizontal ? content.implicitHeight * (1 - offsetScale) : content.implicitHeight

    x: {
        if (!root.horizontal)
            return content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : 0;
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimWidth / 2;
        const diff = parent.width - Math.floor(off + content.nonAnimWidth);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }
    y: {
        if (root.horizontal)
            return content.isDetached ? (parent.height - content.nonAnimHeight) / 2 : 0;
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on x {
        enabled: root.horizontal ? root.offsetScale < 1 : true

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.horizontal ? true : root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.verticalCenter: root.horizontal ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.horizontal ? parent.horizontalCenter : undefined
        anchors.left: root.horizontal ? undefined : parent.left
        anchors.top: root.horizontal ? parent.top : undefined
        anchors.leftMargin: root.horizontal ? 0 : (-implicitWidth - 5) * root.offsetScale
        anchors.topMargin: root.horizontal ? (-implicitHeight - 5) * root.offsetScale : 0
    }
}
