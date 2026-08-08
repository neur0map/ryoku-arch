pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Singletons"

// The desktop right-click menu, built on the shared DesktopMenu chrome in the
// quick-settings sidebar idiom. Two scopes:
//   right-click bare desktop = desktop menu (show/hide the clock, settings,
//     reload)
//   right-click a widget     = its menu (cycle design, toggle date, lock, snap
//     to a compass zone, hide) + the same globals
// Every action writes the same widgets Config the drag and Ryoku Settings do.
Item {
    id: menu

    anchors.fill: parent

    property string scope: "desktop"   // desktop | clock

    readonly property bool isWidget: menu.scope !== "desktop"
    readonly property bool isClock: menu.scope === "clock"
    readonly property bool isCalendar: menu.scope === "calendar"
    readonly property bool isMusic: menu.scope === "music"
    readonly property bool locked: menu.isWidget ? Config[menu.scope + "Locked"] : false
    readonly property string curAnchor: menu.isWidget ? Config[menu.scope + "Anchor"] : ""
    // clock faces persist as <scope>Design; the calendar and the music sheet
    // persist their look as <scope>Style.
    readonly property string designKey: menu.isCalendar || menu.isMusic
        ? menu.scope + "Style" : menu.scope + "Design"
    readonly property string curDesign: menu.isWidget ? Config[menu.designKey] : ""

    readonly property var zones: [
        { "zone": "top-left", "glyph": "\u2196" }, { "zone": "top", "glyph": "\u2191" }, { "zone": "top-right", "glyph": "\u2197" },
        { "zone": "left", "glyph": "\u2190" }, { "zone": "center", "glyph": "\u2299" }, { "zone": "right", "glyph": "\u2192" },
        { "zone": "bottom-left", "glyph": "\u2199" }, { "zone": "bottom", "glyph": "\u2193" }, { "zone": "bottom-right", "glyph": "\u2198" }
    ]

    function openFor(widget, x, y) { menu.scope = widget; shell.px = x; shell.py = y; shell.open = true; }
    function openDesktop(x, y) { menu.scope = "desktop"; shell.px = x; shell.py = y; shell.open = true; }
    function close() { shell.open = false; }
    function cap(s) { return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

    function cycleDesign() {
        const lists = {
            clock: ["digital", "minimal", "analog", "flip", "rings"],
            calendar: ["glass", "paper"],
            music: ["cover", "glass"]
        };
        const d = lists[menu.scope];
        if (!d)
            return;
        Config.set(menu.designKey, d[(d.indexOf(Config[menu.designKey]) + 1) % d.length]);
    }
    function openSettings() {
        Quickshell.execDetached(["sh", "-c", "ryoku-hub config set section widgets; flock -n -o /tmp/ryoku-hub.lock qs -c hub"]);
        menu.close();
    }
    function refreshShell() {
        Quickshell.execDetached(["ryoku-shell", "reload"]);
        menu.close();
    }
    function videoLabel(v) { return v === "canvas" ? "Spotify Canvas" : v === "custom" ? "Custom" : "Off"; }
    function videoName(p) {
        if (!p || p.length === 0)
            return "None";
        const s = ("" + p).replace(/\/+$/, "");
        return decodeURIComponent(s.slice(s.lastIndexOf("/") + 1));
    }
    function cycleVideo() {
        const d = ["off", "canvas", "custom"];
        Config.set("musicVideo", d[(d.indexOf(Config.musicVideo) + 1) % d.length]);
    }

    DesktopMenu {
        id: shell
        title: menu.scope

        // ── desktop scope ──────────────────────────────────────────────
        MenuRow {
            visible: !menu.isWidget
            label: "Clock"
            value: Config.clockEnabled ? "On" : "Off"
            on: Config.clockEnabled
            closeOnTrigger: false
            onTriggered: Config.set("clockEnabled", !Config.clockEnabled)
        }
        MenuRow {
            visible: !menu.isWidget
            label: "Calendar"
            value: Config.calendarEnabled ? "On" : "Off"
            on: Config.calendarEnabled
            closeOnTrigger: false
            onTriggered: Config.set("calendarEnabled", !Config.calendarEnabled)
        }
        MenuRow {
            visible: !menu.isWidget
            label: "Music"
            value: Config.musicEnabled ? "On" : "Off"
            on: Config.musicEnabled
            closeOnTrigger: false
            onTriggered: Config.set("musicEnabled", !Config.musicEnabled)
        }

        // ── widget scope ───────────────────────────────────────────────
        MenuRow {
            visible: menu.isWidget
            label: "Design"
            value: menu.cap(menu.curDesign)
            closeOnTrigger: false
            onTriggered: menu.cycleDesign()
        }
        MenuRow {
            visible: menu.isClock
            label: "Date"
            value: Config.dateShow ? "On" : "Off"
            on: Config.dateShow
            closeOnTrigger: false
            onTriggered: Config.toggle("dateShow")
        }
        MenuRow {
            visible: menu.isMusic
            label: "Lyrics"
            value: Config.musicLyrics ? "On" : "Off"
            on: Config.musicLyrics
            closeOnTrigger: false
            onTriggered: Config.toggle("musicLyrics")
        }
        MenuRow {
            visible: menu.isMusic
            label: "Canvas"
            value: Config.musicShape === "tall" ? "9:16" : "Wide"
            on: Config.musicShape === "tall"
            closeOnTrigger: false
            onTriggered: Config.set("musicShape", Config.musicShape === "tall" ? "wide" : "tall")
        }
        MenuRow {
            visible: menu.isMusic
            label: "Backdrop"
            value: menu.videoLabel(Config.musicVideo)
            on: Config.musicVideo !== "off"
            closeOnTrigger: false
            onTriggered: menu.cycleVideo()
        }
        MenuRow {
            visible: menu.isMusic
            label: "Video / GIF…"
            value: menu.videoName(Config.musicVideoFile)
            onTriggered: videoPicker.open = true
        }
        MenuRow {
            visible: menu.isWidget
            label: "Lock"
            value: menu.locked ? "On" : "Off"
            on: menu.locked
            closeOnTrigger: false
            onTriggered: Config.toggle(menu.scope + "Locked")
        }

        MenuSection { visible: menu.isWidget; label: "Snap" }

        // snap-to-zone pad (widget scope): a compass of chip targets.
        Item {
            visible: menu.isWidget
            width: parent.width
            implicitHeight: menu.isWidget ? zonePad.implicitHeight + 6 : 0
            Grid {
                id: zonePad
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 3
                columns: 3
                spacing: 5
                Repeater {
                    model: menu.zones
                    MenuChip {
                        id: cell
                        required property var modelData
                        width: 40
                        height: 28
                        selected: menu.curAnchor === cell.modelData.zone
                        onClicked: { Config.setAnchor(menu.scope, cell.modelData.zone); menu.close(); }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.glyph
                            color: cell.contentColor
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        MenuRow {
            visible: menu.isWidget
            label: "Hide"
            onTriggered: Config.set(menu.scope + "Enabled", false)
        }

        // ── globals ────────────────────────────────────────────────────
        MenuSection {}
        MenuRow { label: "Settings"; accent: true; closeOnTrigger: false; onTriggered: menu.openSettings() }
        MenuRow { label: "Reload shell"; closeOnTrigger: false; onTriggered: menu.refreshShell() }
    }

    MusicVideoPicker {
        id: videoPicker
        onChose: (url) => {
            Config.set("musicVideoFile", url);
            Config.set("musicVideo", "custom");
        }
    }
}
