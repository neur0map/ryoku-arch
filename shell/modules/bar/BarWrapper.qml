pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components
import qs.utils
import qs.services
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    // Which screen edge the active design's bar occupies. Drives anchoring and
    // the reserved-space ("thickness") axis. edge === "left" reproduces the
    // original vertical sidebar exactly.
    readonly property string edge: BarDesign.edge
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property bool fillsEdge: BarDesign.fillsEdge

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int padding: Math.max(Tokens.padding.smaller, Config.border.thickness)
    // The bar's depth on its short axis (width for a vertical bar, height for a
    // horizontal one). Consumers reserve `thickness` on the bar's edge.
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int thickness: horizontal ? implicitHeight : implicitWidth
    readonly property int clampedThickness: Math.max(Config.border.minThickness, thickness)
    // Back-compat alias for vertical-only consumers (still correct for left/right).
    readonly property int clampedWidth: Math.max(Config.border.minThickness, implicitWidth)

    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || visibilities.bar) ? contentWidth : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
    property bool isHovered

    // The active template is one of the known bar types; cast to each (a wrong-type
    // cast yields null) so interface calls resolve for whichever is live.
    readonly property Bar tplSidebar: content.item as Bar
    readonly property TopNotch tplTopNotch: content.item as TopNotch

    // Collapsed dynamic-island pill width (top-notch centre notch); 0 for designs
    // without an island (e.g. the vertical sidebar). Morph origin for the centre
    // dropdowns (island/dashboard).
    readonly property real islandWidth: tplTopNotch ? tplTopNotch.centerW : 0

    function closeTray(): void {
        if (tplSidebar)
            tplSidebar.closeTray();
        else if (tplTopNotch)
            tplTopNotch.closeTray();
    }

    function checkPopout(pos: real): void {
        if (tplSidebar)
            tplSidebar.checkPopout(pos);
        else if (tplTopNotch)
            tplTopNotch.checkPopout(pos);
    }

    function isClockHover(pos: real): bool {
        if (tplSidebar)
            return tplSidebar.isClockHover(pos);
        if (tplTopNotch)
            return tplTopNotch.isClockHover(pos);
        return false;
    }

    function handleWheel(pos: real, angleDelta: point): void {
        if (tplSidebar)
            tplSidebar.handleWheel(pos, angleDelta);
        else if (tplTopNotch)
            tplTopNotch.handleWheel(pos, angleDelta);
    }

    // A non-filling horizontal bar (top-notch) draws inner-step fillets just
    // below the bar to merge into the frame, so it must not clip; every other
    // design clips its content to the bar bounds as before.
    clip: fillsEdge || !horizontal
    visible: (horizontal ? height : width) > Config.border.thickness

    // Anchor to the bar's edge; the opposite edge is left free so `thickness`
    // controls the reserved depth. Collapsed depth is the border thickness so
    // the frame still draws its rounded border while the bar is hidden.
    anchors.left: edge !== "right" ? parent.left : undefined
    anchors.right: edge !== "left" ? parent.right : undefined
    anchors.top: edge !== "bottom" ? parent.top : undefined
    anchors.bottom: edge !== "top" ? parent.bottom : undefined

    implicitWidth: horizontal ? 0 : (fullscreen ? 0 : Config.border.thickness)
    implicitHeight: horizontal ? (fullscreen ? 0 : Config.border.thickness) : 0

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitWidth: root.horizontal ? 0 : root.contentWidth
            root.implicitHeight: root.horizontal ? root.contentWidth : 0
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: root.horizontal ? "implicitHeight" : "implicitWidth"
                type: Anim.DefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: root.horizontal ? "implicitHeight" : "implicitWidth"
                type: Anim.EmphasizedAccel
            }
        }
    ]

    Loader {
        id: content

        anchors.fill: parent
        active: root.shouldBeVisible

        // RYOKU: the visible bar is drawn by the active design's template.
        // sidebar-left is the original vertical Bar; unknown design ids fall
        // back to it. New templates add a case here.
        sourceComponent: {
            // BarDesign.templateId is frozen at startup, so switching the design does
            // not hot-swap the live bar; the change applies on the shell restart the
            // picker triggers.
            switch (BarDesign.templateId) {
            case "top-notch":
                return topNotchTemplate;
            default:
                return sidebarLeftTemplate;
            }
        }
    }

    Component {
        id: sidebarLeftTemplate

        Bar {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right

            width: root.contentWidth
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts
            fullscreen: root.fullscreen
        }
    }

    Component {
        id: topNotchTemplate

        TopNotch {
            anchors.fill: parent

            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts
            fullscreen: root.fullscreen
        }
    }
}
