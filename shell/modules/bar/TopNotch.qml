pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Ryoku.Config
import qs.components
import qs.services
import qs.utils
import "popouts" as BarPopouts
import "components"

// RYOKU: Brain_Shell-inspired "top-notch" template — a thin top strip with
// three notches hanging from it (left: logo + workspaces; center: a dynamic
// island showing now-playing or the clock; right: tray + status + power). The
// seamless notch outline is drawn by SeamlessBarShape; this file lays out the
// content over each notch. All Ryoku-native, bound to Ryoku services — no
// third-party runtime.
Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool hasMedia: (Players.active?.trackTitle ?? "") !== ""

    // The notch that owns the currently open popout (set by openPopout). checkPopout
    // holds the popout open while the cursor stays within this notch's bounds so the
    // gaps between status icons don't flicker it closed.
    property Item activeNotch

    // BarTemplate interface — hit-test notch content by X (the position along a
    // horizontal bar) and route to the shared popout/scroll machinery, mirroring
    // the sidebar-left Bar. The tray here is never compact, so closeTray is a no-op.
    function closeTray(): void {}

    function checkPopout(pos: real): void {
        // Right notch — tray menus + status-icon popouts.
        const r = mapToItem(rightContent, pos, 0);
        const rch = rightContent.childAt(r.x, rightContent.height / 2);
        if (rch?.popoutName) {
            root.openPopout(rch.popoutName, rightNotch);
            return;
        }
        // Left notch — hovering the active workspace dot peeks the active window.
        // Only when one exists: an empty preview (no active toplevel) collapses to a
        // negative width that renders as a stray line across the horizontal bar.
        const l = mapToItem(leftContent, pos, 0);
        const lch = leftContent.childAt(l.x, leftContent.height / 2);
        if (lch?.isWorkspaceDot && lch.active && Hypr.activeToplevel) {
            root.openPopout("activewindow", leftNotch);
            return;
        }
        // Crossing the spacing between icons within a notch hits a gap where childAt
        // returns null; closing there and reopening on the next icon flickers the
        // panel. While a popout is open, hold it as long as the cursor is still over
        // the notch that owns it; only close when the cursor leaves that notch.
        if (popouts.hasCurrent && activeNotch && pos >= activeNotch.x && pos <= activeNotch.x + activeNotch.width)
            return;
        popouts.hasCurrent = false;
    }

    // The popout morphs out of the notch it belongs to (left/centre/right) — width
    // from the notch's width to full, height from 0 — and retracts back into it on
    // close; activeNotch records which notch owns the open popout so checkPopout
    // can hold it while the cursor roams that notch (see above).
    function openPopout(name: string, notch: Item): void {
        activeNotch = notch;
        popouts.currentName = name;
        popouts.currentCenter = Qt.binding(() => notch.mapToItem(root, notch.width / 2, 0).x);
        popouts.currentNotchWidth = Qt.binding(() => notch.width);
        popouts.hasCurrent = true;
    }

    function isClockHover(pos: real): bool {
        return pos >= centerNotch.x && pos <= centerNotch.x + centerNotch.width;
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const dy = GlobalConfig.general.reverseScroll ? -angleDelta.y : angleDelta.y;
        if (pos <= leftNotch.x + leftNotch.width && Config.bar.scrollActions.workspaces) {
            const perMon = GlobalConfig.bar.workspaces.perMonitorWorkspaces;
            const mon = perMon ? Hypr.monitorFor(screen) : Hypr.focusedMonitor;
            const targetMon = perMon ? mon : null;
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatchOnMonitor(targetMon, `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (dy < 0 || (perMon ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatchOnMonitor(targetMon, `workspace r${dy > 0 ? "-" : "+"}1`);
        } else if (pos < root.width / 2 && Config.bar.scrollActions.volume) {
            if (dy > 0)
                Audio.incrementVolume();
            else if (dy < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (dy > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (dy < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    readonly property int pad: Tokens.padding.large
    readonly property color fg: Colours.palette.m3onSurface

    // Notch widths track their content (+ padding) with a floor so a near-empty
    // notch still reads as a deliberate tab.
    readonly property real leftW: Math.max(140, leftContent.implicitWidth + pad * 2)
    readonly property real centerW: Math.max(180, centerContent.implicitWidth + pad * 2)
    readonly property real rightW: Math.max(140, rightContent.implicitWidth + pad * 2)

    // ── Seamless top-bar shape (one continuous, frame-attached shape) ──
    SeamlessBarShape {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Extends below the bar by the rounding so the inner fillets that round
        // the content's top corners (where the bar narrows into the side
        // borders) have room to draw.
        height: root.height + GlobalConfig.border.rounding

        leftWidth: root.leftW
        centerWidth: root.centerW
        rightWidth: root.rightW
        notchHeight: root.height
        // Notch/island corner roundness tracks the frame "Corner rounding"
        // slider (GlobalConfig.border.rounding), clamped so the concave-top and
        // convex-bottom fillets on a notch edge never overlap (need 2r <= h - b).
        radius: Math.max(0, Math.min(GlobalConfig.border.rounding, (root.height - GlobalConfig.border.thickness) / 2))
        topBorderWidth: GlobalConfig.border.thickness
        outerRadius: GlobalConfig.border.rounding
        innerRadius: GlobalConfig.border.rounding
        color: Colours.palette.m3surface
    }

    // ── Left notch: logo + workspaces ──
    Item {
        id: leftNotch

        width: root.leftW
        height: root.height
        anchors.left: parent.left

        RowLayout {
            id: leftContent

            anchors.centerIn: parent
            spacing: Tokens.spacing.normal

            OsIcon {}

            Repeater {
                model: Config.bar.workspaces.shown

                StyledRect {
                    id: ws

                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool active: Hypr.activeWsId === wsId
                    readonly property bool occupied: Hypr.workspaces.values.some(w => w.id === wsId && w.lastIpcObject.windows > 0)
                    readonly property bool isWorkspaceDot: true

                    implicitWidth: active ? 22 : 10
                    implicitHeight: 10
                    radius: height / 2
                    color: active ? Colours.palette.m3primary : occupied ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3surfaceContainerHighest

                    Behavior on implicitWidth {
                        Anim {}
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hypr.dispatch(`workspace ${ws.wsId}`)
                    }
                }
            }
        }
    }

    // ── Center notch: dynamic island (media / clock) ──
    Item {
        id: centerNotch

        width: root.centerW
        height: root.height
        anchors.horizontalCenter: parent.horizontalCenter

        Loader {
            id: centerContent

            anchors.centerIn: parent
            sourceComponent: root.hasMedia ? mediaComp : clockComp
        }
    }

    Component {
        id: clockComp

        RowLayout {
            spacing: Tokens.spacing.small

            StyledText {
                text: Time.format(GlobalConfig.services.useTwelveHourClock ? "hh:mm A" : "hh:mm")
                font.family: Tokens.font.family.mono
                font.pointSize: Tokens.font.size.large
                color: Colours.palette.m3primary
            }

            StyledText {
                text: Time.format("ddd, d MMM")
                font.family: Tokens.font.family.sans
                font.pointSize: Tokens.font.size.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }

    Component {
        id: mediaComp

        RowLayout {
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: Players.active?.isPlaying ? "pause" : "play_arrow"
                color: Colours.palette.m3primary

                MouseArea {
                    anchors.fill: parent
                    onClicked: Players.active?.togglePlaying()
                }
            }

            StyledText {
                Layout.maximumWidth: 260
                elide: Text.ElideRight
                text: {
                    const a = Players.active?.trackArtist ?? "";
                    const t = Players.active?.trackTitle ?? "";
                    return a ? `${a} — ${t}` : t;
                }
                font.family: Tokens.font.family.sans
                font.pointSize: Tokens.font.size.normal
                color: root.fg
            }
        }
    }

    // ── Right notch: tray + status + power ──
    Item {
        id: rightNotch

        width: root.rightW
        height: root.height
        anchors.right: parent.right

        RowLayout {
            id: rightContent

            anchors.centerIn: parent
            spacing: Tokens.spacing.normal

            Repeater {
                model: ScriptModel {
                    values: SystemTray.items.values.filter(i => !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
                }

                TrayItem {
                    required property int index
                    readonly property string popoutName: "traymenu" + index
                }
            }

            MaterialIcon {
                readonly property string popoutName: "audio"
                text: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                color: root.fg
            }

            MaterialIcon {
                readonly property string popoutName: "network"
                text: Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi_off"
                color: root.fg
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Visibilities.pendingSettingsTab = "Connections";
                        root.visibilities.settings = true;
                    }
                }
            }

            MaterialIcon {
                readonly property string popoutName: "battery"
                visible: UPower.displayDevice?.isLaptopBattery ?? false
                fill: 1
                text: {
                    const p = UPower.displayDevice?.percentage ?? 1;
                    if (p > 0.9)
                        return "battery_full";
                    if (p > 0.6)
                        return "battery_5_bar";
                    if (p > 0.3)
                        return "battery_3_bar";
                    return "battery_1_bar";
                }
                color: (UPower.onBattery && (UPower.displayDevice?.percentage ?? 1) <= 0.2) ? Colours.palette.m3error : root.fg
            }

            Power {
                visibilities: root.visibilities
            }
        }
    }
}
