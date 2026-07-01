//@ pragma DefaultEnv QSG_RENDER_LOOP = threaded
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io

/**
 * Window switcher: a full-screen Alt-Tab overlay launched as its own `qs -c
 * switcher` instance (like ryoshot), so it never burdens the always-on pill. It
 * lists the open windows in most-recently-used order (Hyprland focusHistoryID),
 * each an app icon + title card, and opens with the previous window selected so a
 * hold-Alt, tap-Tab, release-Alt gesture switches back to it. Tab / arrows cycle,
 * Enter or a click activates, Escape cancels; activating dispatches
 * `focuswindow` and quits. The frame and pill identity are untouched (separate
 * layer). Colours mirror the shell chrome locally since this is its own config.
 */
ShellRoot {
    id: root

    readonly property color dimBg:   Qt.rgba(0, 0, 0, 0.45)
    readonly property bool matchWallpaper: switchCfg.followWallpaper
    readonly property color wallBase: switchPalette.background
    readonly property color cardTop: matchWallpaper ? wallBase : "#1a1b26"
    readonly property color cardBot: matchWallpaper ? tone(wallBase, -0.03) : "#16161e"
    readonly property color border:  matchWallpaper ? tone(wallBase, 0.14) : "#2f3549"

    // Shift a colour's HSV value by dv (hue and saturation kept), for the ramp.
    function tone(c, dv) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        return Qt.hsva(hue, c.hsvSaturation, Math.max(0, Math.min(1, c.hsvValue + dv)), 1);
    }

    // The shell-wide Match wallpaper toggle (theme.json.FollowWallpaper) and
    // the live palette (colors.json), mirrored locally since the switcher is
    // its own qs config.
    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/wallust/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter { id: switchPalette; property color background: "#1a1b26" }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter { id: switchCfg; property bool followWallpaper: true }
    }
    readonly property color accent:  "#7aa2f7"
    readonly property color cream:   "#c0caf5"
    readonly property color dim:     "#7aa2f7"
    readonly property color faint:   "#565f89"
    readonly property string uiFont: "Inter"

    // Reactive over the toplevel model, so the list fills in once the async
    // refreshToplevels() lands (a fresh instance starts with an empty model).
    // Sorted by focusHistoryID: 0 = current, 1 = previous, ...
    readonly property var wins: {
        var tl = Hyprland.toplevels.values;
        var out = [];
        for (var i = 0; i < tl.length; i++) {
            var o = tl[i] && tl[i].lastIpcObject;
            if (!o || o.mapped === false || o.hidden === true)
                continue;
            if (!o.title && !o.class)
                continue;
            out.push({
                addr: o.address,
                title: o.title || o.class || "window",
                cls: (o.class || "").toLowerCase(),
                fh: typeof o.focusHistoryID === "number" ? o.focusHistoryID : 999
            });
        }
        out.sort(function (a, b) { return a.fh - b.fh; });
        return out;
    }

    property bool seeded: false
    property int sel: 0

    onWinsChanged: {
        if (!seeded && wins.length > 0) {
            sel = wins.length > 1 ? 1 : 0;
            seeded = true;
        } else if (sel >= wins.length) {
            sel = Math.max(0, wins.length - 1);
        }
    }

    function move(d) {
        var n = root.wins.length;
        if (n === 0)
            return;
        root.sel = ((root.sel + d) % n + n) % n;
    }

    function activate() {
        var w = root.wins[root.sel];
        if (w && w.addr)
            Hyprland.dispatch("focuswindow address:" + w.addr);
        Qt.quit();
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    // Belt-and-suspenders: a fresh instance occasionally needs a second poke
    // before the toplevel model is fully populated with lastIpcObject data.
    Timer {
        interval: 200
        running: !root.seeded
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    PanelWindow {
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "ryoku-switcher"

        Rectangle {
            anchors.fill: parent
            color: root.dimBg
            MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
        }

        Text {
            anchors.centerIn: parent
            visible: root.wins.length === 0
            text: "No open windows"
            color: root.faint
            font.family: root.uiFont
            font.pixelSize: 16
        }

        Rectangle {
            id: card
            visible: root.wins.length > 0
            anchors.centerIn: parent
            readonly property int cols: Math.max(1, Math.min(root.wins.length, 5))
            readonly property int cellW: 196
            readonly property int cellH: 148
            readonly property int pad: 20
            readonly property int gap: 12
            readonly property int rows: Math.ceil(root.wins.length / cols)
            width: cols * cellW + (cols - 1) * gap + pad * 2
            height: rows * cellH + (rows - 1) * gap + pad * 2
            radius: 22
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.cardTop }
                GradientStop { position: 1.0; color: root.cardBot }
            }
            border.width: 1
            border.color: root.border

            Grid {
                anchors.centerIn: parent
                columns: card.cols
                rowSpacing: card.gap
                columnSpacing: card.gap

                Repeater {
                    model: root.wins
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        width: card.cellW
                        height: card.cellH
                        radius: 14
                        readonly property bool current: index === root.sel
                        color: current ? Qt.rgba(0.48, 0.63, 0.96, 0.16) : Qt.rgba(1, 1, 1, 0.03)
                        border.width: current ? 2 : 1
                        border.color: current ? root.accent : root.border
                        Behavior on border.color { ColorAnimation { duration: 110 } }
                        Behavior on color { ColorAnimation { duration: 110 } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 9

                            IconImage {
                                anchors.horizontalCenter: parent.horizontalCenter
                                implicitSize: 60
                                source: {
                                    var c = cell.modelData.cls;
                                    var e = DesktopEntries.heuristicLookup(c);
                                    var p = (e && e.icon) ? Quickshell.iconPath(e.icon, true) : "";
                                    if (!p && c)
                                        p = Quickshell.iconPath(c, true);
                                    return p;
                                }
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                text: cell.modelData.title
                                color: cell.current ? root.cream : root.dim
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.weight: cell.current ? Font.DemiBold : Font.Normal
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.sel = cell.index
                            onClicked: root.activate()
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Component.onCompleted: forceActiveFocus()
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_Down) {
                    root.move((e.modifiers & Qt.ShiftModifier) ? -1 : 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
                    root.move(-1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                    root.activate();
                    e.accepted = true;
                } else if (e.key === Qt.Key_Escape) {
                    Qt.quit();
                    e.accepted = true;
                }
            }
            Keys.onReleased: (e) => {
                if (e.key === Qt.Key_Alt || e.key === Qt.Key_Meta) {
                    root.activate();
                    e.accepted = true;
                }
            }
        }
    }
}
