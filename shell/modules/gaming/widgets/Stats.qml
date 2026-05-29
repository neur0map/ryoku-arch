pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import ".."
import qs.components
import qs.services

// RYOKU: draggable gaming-overlay widget showing live CPU / GPU / RAM usage
// (with temps) from the SystemUsage service. Holds a SystemUsage ref only while
// visible so the polling timer stays idle when the widget is hidden. GPU row is
// hidden when no GPU is detected (gpuType === "NONE").
OverlayWidget {
    id: root

    widgetId: "stats"

    // SystemUsage gates its polling Timer on refCount > 0. Acquire a ref only
    // while shown and release it when hidden or destroyed so we never poll for a
    // widget the user can't see.
    onVisibleChanged: visible ? SystemUsage.refCount++ : SystemUsage.refCount--
    Component.onCompleted: if (visible)
        SystemUsage.refCount++
    Component.onDestruction: if (visible)
        SystemUsage.refCount--

    StyledRect {
        anchors.fill: parent

        implicitWidth: col.implicitWidth + Tokens.padding.large * 2
        implicitHeight: col.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.small
        color: Qt.alpha(Colours.palette.m3surface, 0.7)

        Column {
            id: col

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            StyledText {
                text: `CPU  ${Math.round(SystemUsage.cpuPerc * 100)}%  ${Math.round(SystemUsage.cpuTemp)}°`
            }

            StyledText {
                visible: SystemUsage.gpuType !== "NONE"
                text: `GPU  ${Math.round(SystemUsage.gpuPerc * 100)}%  ${Math.round(SystemUsage.gpuTemp)}°`
            }

            StyledText {
                text: `RAM  ${Math.round(SystemUsage.memPerc * 100)}%`
            }
        }
    }
}
