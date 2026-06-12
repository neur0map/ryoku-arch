pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Ryoku.Blobs
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar

StyledWindow {
    id: root

    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property var monitorState: monitor?.lastIpcObject ?? ({})
    readonly property var activeWorkspaceState: monitor?.activeWorkspace?.lastIpcObject ?? ({})
    readonly property bool hasSpecialWorkspace: (monitorState.specialWorkspace?.name?.length ?? 0) > 0
    readonly property bool hasFullscreen: {
        if (hasSpecialWorkspace) {
            const specialName = monitorState.specialWorkspace?.name;
            if (!specialName)
                return false;
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }

    property real fsTransitionProg: hasFullscreen ? 1 : 0
    readonly property real sdfBorderOffset: 2 * fsTransitionProg // SDFs joins are not exact, so offset by 2px to ensure nothing shows
    readonly property real borderThickness: contentItem.Config.border.thickness * (1 - fsTransitionProg)
    readonly property real borderRounding: contentItem.Config.border.rounding * (1 - fsTransitionProg)
    readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : contentItem.Config.border.thickness
    // Per-edge inset: the bar's edge reserves the bar's thickness, the other
    // three reserve the border thickness. For edge === "left" these reduce to
    // the original (bar.implicitWidth on the left, borderThickness elsewhere).
    readonly property real barInsetLeft: bar.edge === "left" ? bar.thickness : root.borderThickness
    readonly property real barInsetTop: bar.edge === "top" ? bar.thickness : root.borderThickness
    readonly property real barInsetRight: bar.edge === "right" ? bar.thickness : root.borderThickness
    readonly property real barInsetBottom: bar.edge === "bottom" ? bar.thickness : root.borderThickness
    // Frame-border inset: like barInset, but only thickens the border when the
    // bar fills its edge (sidebar). A non-filling bar (top-notch) keeps a thin
    // border and draws its own notches, so wallpaper shows in the gaps.
    readonly property real barBorderInsetLeft: bar.edge === "left" && bar.fillsEdge ? bar.thickness : root.borderThickness
    readonly property real barBorderInsetTop: bar.edge === "top" && bar.fillsEdge ? bar.thickness : root.borderThickness
    readonly property real barBorderInsetRight: bar.edge === "right" && bar.fillsEdge ? bar.thickness : root.borderThickness
    readonly property real barBorderInsetBottom: bar.edge === "bottom" && bar.fillsEdge ? bar.thickness : root.borderThickness
    // True when the bar fills its edge (sidebar). A non-filling bar (top-notch)
    // shows wallpaper in the gaps between notches, so a fully-closed panel must
    // contribute nothing to the blob field — otherwise its tucked-under blob
    // bulges through the thin top border into those gaps.
    readonly property bool barFillsEdge: bar.fillsEdge

    readonly property int dragMaskPadding: {
        if (focusGrab.active || panels.popouts.isDetached)
            return 0;

        if (monitorState.specialWorkspace?.name || (activeWorkspaceState.windows ?? 0) > 0)
            return 0;

        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (contentItem.Config[panel].enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold);
        return Math.max(...thresholds);
    }

    onHasFullscreenChanged: {
        visibilities.launcher = false;
        visibilities.clipboard = false;
        visibilities.session = false;
        visibilities.dashboard = false;
        visibilities.island = false;
        visibilities.settings = false;
        panels.framePlugins.closeAll();
        visibilities.obsidian = false;
        panels.popouts.close();
    }

    name: "drawers"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: fsTransitionProg > 0 && contentItem.Config.general.showOverFullscreen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.clipboard || visibilities.session || panels.dashboard.needsKeyboard || panels.settings.needsKeyboard || panels.framePlugins.anyNeedsKeyboard || visibilities.obsidian ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: hasFullscreen ? emptyRegion : (visibilities.settings ? null : regions)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on fsTransitionProg {
        Anim {}
    }

    Region {
        id: emptyRegion

        x: panels.notifications.x + root.barInsetLeft
        y: panels.notifications.y + root.barInsetTop
        width: panels.notifications.width
        height: panels.notifications.height

        Region {
            x: root.width - width
            y: panels.osdWrapper.y + root.borderThickness
            width: panels.osdWrapper.width * (1 - panels.osd.offsetScale) + root.borderThickness
            height: panels.osd.height
        }
    }

    Regions {
        id: regions

        bar: bar
        panels: panels
        win: root
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: (visibilities.launcher && root.contentItem.Config.launcher.enabled) || visibilities.clipboard || (visibilities.session && root.contentItem.Config.session.enabled) || (visibilities.sidebar && root.contentItem.Config.sidebar.enabled) || visibilities.settings || panels.framePlugins.anyActive || visibilities.obsidian || (!root.contentItem.Config.dashboard.showOnHover && visibilities.dashboard && root.contentItem.Config.dashboard.enabled) || (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1)
        windows: [root]
        onCleared: {
            visibilities.launcher = false;
            visibilities.clipboard = false;
            visibilities.session = false;
            visibilities.sidebar = false;
            visibilities.dashboard = false;
            visibilities.island = false;
            visibilities.settings = false;
            panels.framePlugins.closeAll();
            visibilities.obsidian = false;
            panels.popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: (visibilities.session && Config.session.enabled) || panels.popouts.isDetached ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {}
        }
    }

    Item {
        anchors.fill: parent
        opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        BlobGroup {
            id: blobGroup

            color: Colours.palette.m3surface
            smoothing: root.contentItem.Config.border.smoothing

            Behavior on color {
                CAnim {}
            }
        }

        BlobInvertedRect {
            anchors.fill: parent
            anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
            group: blobGroup
            radius: root.borderRounding
            borderLeft: root.barBorderInsetLeft - anchors.margins - root.sdfBorderOffset
            borderRight: root.barBorderInsetRight - anchors.margins - root.sdfBorderOffset
            borderTop: root.barBorderInsetTop - anchors.margins - root.sdfBorderOffset
            borderBottom: root.barBorderInsetBottom - anchors.margins - root.sdfBorderOffset
        }

        PanelBg {
            id: dashBg

            panel: panels.dashboard
            deformAmount: 0.1
            attachTop: true
            pinReach: true
        }

        PanelBg {
            id: settingsBg

            panel: panels.settings
            deformAmount: 0.1
            attachTop: true
        }

        Repeater {
            model: panels.framePlugins.panels

            PanelBg {
                required property var modelData

                panel: modelData
                deformAmount: 0.1
                attachTop: (modelData?.edge ?? "top") === "top"

                Binding {
                    target: modelData
                    property: "deformMatrix"
                    value: deformMatrix
                }
            }
        }

        PanelBg {
            id: obsidianBg

            panel: panels.obsidian
            deformAmount: 0.1
        }

        PanelBg {
            id: launcherBg

            panel: panels.launcher
            deformAmount: 0.1
        }

        PanelBg {
            id: clipboardBg

            panel: panels.clipboard
            deformAmount: 0.1
        }

        PanelBg {
            id: islandBg

            panel: panels.island
            deformAmount: 0.1
            attachTop: true
            pinReach: true
        }

        PanelBg {
            id: sessionBg

            panel: panels.sessionWrapper
            deformAmount: 0.2
            x: panels.sessionWrapper.x + panels.session.x + root.barInsetLeft
            implicitWidth: panels.session.width
        }

        PanelBg {
            id: sidebarBg

            panel: panels.sidebar
            deformAmount: 0.03
            implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [utilsBg]
            bottomLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
        }

        PanelBg {
            id: osdBg

            panel: panels.osdWrapper
            deformAmount: 0.25
            x: panels.osdWrapper.x + panels.osd.x + root.barInsetLeft
            implicitWidth: panels.osd.width
        }

        PanelBg {
            id: notifsBg

            panel: panels.notifications
            attachTop: true
        }

        PanelBg {
            id: utilsBg

            panel: panels.utilities
            deformAmount: panels.sidebar.visible ? 0.1 : 0.15
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [sidebarBg]
            topLeftRadius: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius
        }

        PanelBg {
            id: popoutBg

            // Extra width to prevent vertical movement deformation partially detaching panel from bar
            property real extraWidth: panels.popouts.isDetached ? 0 : 0.2

            panel: panels.popoutsWrapper
            deformAmount: panels.popouts.isDetached ? 0.05 : panels.popouts.hasCurrent ? 0.15 : 0.1
            attachTop: true
            x: panels.popoutsWrapper.x + panels.popouts.x + root.barInsetLeft - panels.popouts.width * extraWidth
            implicitWidth: panels.popouts.width * (1 + extraWidth)

            Behavior on extraWidth {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }
    }

    DrawerVisibilities {
        id: visibilities

        Component.onCompleted: Visibilities.load(root.screen, this)
    }

    Interactions {
        id: interactions

        screen: root.screen
        popouts: panels.popouts
        visibilities: visibilities
        panels: panels
        bar: bar
        borderThickness: root.borderLayoutThickness
        fullscreen: root.hasFullscreen

        MouseArea {
            anchors.fill: parent
            visible: visibilities.settings
            enabled: visible
            acceptedButtons: Qt.AllButtons

            onPressed: event => {
                if (interactions.closeSettingsIfOutside(event.x, event.y))
                    event.accepted = true;
                else
                    event.accepted = false;
            }
        }

        Panels {
            id: panels

            screen: root.screen
            visibilities: visibilities
            bar: bar
            borderThickness: root.borderThickness

            utilities.horizontalStretch: (sidebarBg.rawDeformMatrix.m11 - 1) / 2 + 1
            utilities.deformMatrix: utilsBg.rawDeformMatrix
            island.deformMatrix: islandBg.rawDeformMatrix

            dashboard.transform: Matrix4x4 {
                matrix: dashBg.deformMatrix
            }
            settings.transform: Matrix4x4 {
                matrix: settingsBg.deformMatrix
            }
            obsidian.transform: Matrix4x4 {
                matrix: obsidianBg.deformMatrix
            }
            launcher.transform: Matrix4x4 {
                matrix: launcherBg.deformMatrix
            }
            // NOTE: clipboard intentionally has NO deform transform. The ClipboardTab
            // list selects on hover, and a Matrix4x4 item transform desyncs Qt's
            // pointer hit-testing from the (deformed) rendering, so hovering a row
            // highlights its neighbour. The blob background (clipboardBg) still deforms.
            island.transform: Matrix4x4 {
                matrix: islandBg.deformMatrix
            }
            session.transform: Matrix4x4 {
                matrix: sessionBg.deformMatrix
            }
            sidebar.transform: Matrix4x4 {
                matrix: sidebarBg.deformMatrix
            }
            osd.transform: Matrix4x4 {
                matrix: osdBg.deformMatrix
            }
            notifications.transform: Matrix4x4 {
                matrix: notifsBg.deformMatrix
            }
            utilities.transform: Matrix4x4 {
                matrix: utilsBg.deformMatrix
            }
            popouts.transform: Matrix4x4 {
                matrix: popoutBg.deformMatrix
            }
        }

        BarWrapper {
            id: bar

            screen: root.screen
            visibilities: visibilities
            popouts: panels.popouts

            fullscreen: root.hasFullscreen

            Component.onCompleted: Visibilities.bars.set(root.screen, this)
        }
    }

    component PanelBg: BlobRect {
        property Item panel: null
        property real deformAmount: 0.15
        // A panel that drops from a non-filling top bar (top-notch) must reach up
        // into the bar region so its blob fuses with the thin top border; without
        // this it floats below the notches with a wallpaper gap above it.
        property bool attachTop: false
        // Max upward reach: the gap between the panel's top (the bar's inner edge)
        // and the frame border — i.e. the notch interior. 0 unless this is a
        // top-edge panel on a non-filling (top-notch) bar.
        readonly property real maxReach: attachTop && root.bar.edge === "top" && !root.barFillsEdge ? root.barInsetTop - root.borderThickness : 0
        // pinReach keeps the neck fully extended to the notch the whole time the
        // panel is open (the centre dropdowns), so the panel's top edge stays
        // fused to the notch from frame one and the notch/clock pill reads as
        // expanding straight down — not a separate surface rising up to meet it.
        // At the open/close extremes the panel's own height is ~0, so the pinned
        // neck IS the notch; snapping it to full reach shows no popped slab. The
        // default (grow with open progress) suits panels with no notch origin.
        property bool pinReach: false
        readonly property real topReach: pinReach ? ((panel?.visible ?? false) ? maxReach : 0) : maxReach * (1 - (panel?.offsetScale ?? 0))

        group: blobGroup
        x: panel ? panel.x + root.barInsetLeft : 0
        y: panel ? panel.y + root.barInsetTop - topReach : 0
        implicitWidth: panel && (root.barFillsEdge || panel.visible) ? panel.width : 0
        implicitHeight: panel && (root.barFillsEdge || panel.visible) ? panel.height + topReach : 0
        radius: Tokens.rounding.large
        deformScale: (deformAmount * Config.appearance.deformScale) / 10000

        // Animate the metaball deform so it never jumps a frame when a panel's
        // open state flips (e.g. a popout becoming current).
        Behavior on deformAmount {
            Anim {}
        }
    }
}
