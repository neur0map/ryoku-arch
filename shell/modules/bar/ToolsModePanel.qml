pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.bar.threeIsland.dynamicIsland.tools

// Mod+S toolkit overlay, content-sized pill in Hug style.
//
// Visual: a centered pill at the top edge of the screen, sized to the
// toolkit row plus padding. Top corners flat (flush against screen
// edge); bottom corners rounded so the pill reads as a tab dropping
// down from the screen border. Color matches the Hug bar token.
//
// Motion: the pill slides down from above-screen via `topMargin`
// using the same `elementMoveEnter`/`elementMoveExit` curves the bar
// uses for its slide-out, so bar-up + pill-down swap in lockstep.
//
// Input: the panel surface is fullscreen so we can detect a click
// anywhere off the pill and close the toolkit. The pill itself
// absorbs its own clicks so dragging or clicking the pill background
// (between buttons) doesn't fall through to the close-on-click area.
//
// Notes that survived debugging earlier iterations:
//
//  * The Wayland surface stays mapped for the session. Hiding via
//    `visible: false` would cause a map/remap on every Mod+S press,
//    adding a frame of flicker and (on some compositors) a brief
//    focus restack.
//  * `keyboardFocus` left at default (None). OnDemand caused niri to
//    swap focus from the focused window to this surface, flickering
//    its focus ring. Exclusive would do the same and is reserved for
//    a future opt-in "type-anywhere-closes" mode.
//  * All visual state derives from a single `openProgress` driven by
//    explicit NumberAnimations, not Behaviors. A freshly-instantiated
//    component evaluates every binding to its target state in one
//    shot, so a Behavior watching that binding has no value change to
//    chase. Keeping the surface mounted sidesteps that, but the
//    imperative animation is also robust.
//  * The doc rule "padding >= corner_radius" applies: pill padding
//    must exceed `pillCornerRadius` so icons don't visually crowd the
//    curved bottom corners.
Scope {
    id: scope

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options?.bar?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            const matched = screens.filter(screen => {
                const name = screen?.name ?? "";
                return name.length > 0 && list.includes(name);
            });
            return matched.length > 0 ? matched : screens;
        }

        LazyLoader {
            id: panelLoader
            required property ShellScreen modelData
            active: !GlobalStates.screenLocked

            component: PanelWindow {
                id: panelRoot
                screen: panelLoader.modelData
                visible: !GameMode.shouldHidePanels
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell:toolsMode"
                WlrLayershell.layer: WlrLayer.Overlay

                readonly property bool atBottom: Config.options?.bar?.bottom ?? false
                readonly property bool showBackground: Config.options?.bar?.showBackground ?? true
                readonly property int pillHeight: Appearance.sizes.barHeight + 8
                readonly property int pillCornerRadius: Appearance.rounding.normal
                readonly property int pillHorizontalPadding: 24

                readonly property color hugColor: showBackground
                    ? (Appearance.ryokuEverywhere
                        ? Appearance.ryoku.colLayer0
                        : Appearance.auroraEverywhere
                            ? Appearance.aurora.colPopupSurface
                            : Appearance.colors.colLayer0)
                    : "transparent"

                // Single source of truth for entry/exit. 0 = fully
                // hidden (slid off-screen), 1 = fully shown.
                property real openProgress: 0
                readonly property bool visuallyOpen: openProgress > 0.001

                NumberAnimation {
                    id: openAnim
                    target: panelRoot
                    property: "openProgress"
                    to: 1.0
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }

                NumberAnimation {
                    id: closeAnim
                    target: panelRoot
                    property: "openProgress"
                    to: 0.0
                    duration: Appearance.animation.elementMoveExit.duration
                    easing.type: Appearance.animation.elementMoveExit.type
                    easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
                }

                Connections {
                    target: GlobalStates
                    function onToolsModeOpenChanged(): void {
                        if (GlobalStates.toolsModeOpen) {
                            closeAnim.stop();
                            openAnim.start();
                        } else {
                            openAnim.stop();
                            closeAnim.start();
                        }
                    }
                }

                // Fullscreen surface so click-outside can be detected
                // anywhere on the screen. exclusionMode is Ignore, so
                // the surface does not push windows around.
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                Item { id: emptyMask; width: 0; height: 0 }
                Item { id: fullMask; anchors.fill: parent }
                mask: Region {
                    item: panelRoot.visuallyOpen ? fullMask : emptyMask
                }

                // Click-outside: anywhere not on the pill closes the
                // toolkit. Lives below the pill in declaration order
                // so the pill's own MouseArea catches its own clicks
                // first. Disabled while closed to keep the surface
                // entirely passive.
                MouseArea {
                    id: outsideClickArea
                    anchors.fill: parent
                    enabled: panelRoot.visuallyOpen
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onPressed: GlobalStates.toolsModeOpen = false
                }

                Rectangle {
                    id: pill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: !panelRoot.atBottom ? parent.top : undefined
                    anchors.bottom: panelRoot.atBottom ? parent.bottom : undefined

                    // Slide from off-screen to flush with screen edge.
                    readonly property real slidePx: -panelRoot.pillHeight * (1 - panelRoot.openProgress)
                    anchors.topMargin: !panelRoot.atBottom ? slidePx : 0
                    anchors.bottomMargin: panelRoot.atBottom ? slidePx : 0

                    width: tools.implicitWidth + 2 * panelRoot.pillHorizontalPadding
                    height: panelRoot.pillHeight
                    color: panelRoot.hugColor

                    // Hug shape: flat against the screen edge, rounded
                    // on the side that faces the screen content.
                    topLeftRadius: panelRoot.atBottom ? panelRoot.pillCornerRadius : 0
                    topRightRadius: panelRoot.atBottom ? panelRoot.pillCornerRadius : 0
                    bottomLeftRadius: panelRoot.atBottom ? 0 : panelRoot.pillCornerRadius
                    bottomRightRadius: panelRoot.atBottom ? 0 : panelRoot.pillCornerRadius

                    // Smooth pill width when the user toggles which
                    // tool buttons are enabled.
                    Behavior on width {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveExit.duration
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Absorb any click that lands on the pill but not
                    // on a tool button, so it doesn't fall through to
                    // outsideClickArea and close the toolkit. Declared
                    // before the toolkit content so the buttons
                    // (declared after) sit on top in z-order and get
                    // first crack at left-click events.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                    }

                    RyokuToolsMode {
                        id: tools
                        anchors.centerIn: parent
                        // Drives per-icon scale stagger.
                        progress: panelRoot.openProgress
                    }
                }
            }
        }
    }
}
