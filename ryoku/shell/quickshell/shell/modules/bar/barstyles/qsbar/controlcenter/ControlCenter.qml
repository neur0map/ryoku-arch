import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"
import "kit"
import "kit/Routes.js" as Routes

// The Control Center: a large route-based panel that replaces the old compact
// ControlPanel on BOTH variants. It reads/writes state straight off `root` (the
// qsbar Theme), so persistence and the Bar Studio bridge are untouched. Only
// tokens present in BOTH the V1 and V2 Theme are used here.
PanelWindow {
    id: cc
    required property var root

    // exposed to pages via their `cc` property
    property var tokens: tk
    property string mode: "quick"        // "quick" | "configure"
    property string route: ""            // "" | bars | appearance | logo | workspaces | pickers

    // navigation: a route id opens CONFIGURE on it; "configure"/"quick" switch mode
    function open(target) {
        if (target === undefined || target === "" || target === "quick") { cc.mode = "quick"; cc.route = "" }
        else if (target === "configure") { cc.mode = "configure"; cc.route = "" }
        else { cc.mode = "configure"; cc.route = target }
        cc.root.controlVisible = true
    }
    function close() { cc.root.controlVisible = false }

    function pageUrlFor(m, r) {
        if (m === "quick") return Qt.resolvedUrl("routes/QuickPage.qml")
        if (r === "") return Qt.resolvedUrl("routes/ConfigurePage.qml")
        var map = { "bars": "BarsRoute", "appearance": "AppearanceRoute", "logo": "LogoRoute",
                    "workspaces": "WorkspacesRoute", "pickers": "PickersRoute" }
        return map[r] ? Qt.resolvedUrl("routes/" + map[r] + ".qml") : Qt.resolvedUrl("routes/ConfigurePage.qml")
    }

    // Static settings index for the predictive search: one entry per route, the
    // notable controls inside each route, and the quick actions. `route` is where
    // accepting an entry navigates; tags/keywords/description feed the ranking.
    readonly property var searchEntries: cc.buildSearchIndex()
    function buildSearchIndex() {
        var out = []
        for (var i = 0; i < Routes.ROUTES.length; i++) {
            var r = Routes.ROUTES[i]
            out.push({ id: r.id, name: r.label, route: r.id, category: r.label,
                       searchTags: String(r.keywords || "").split(/\s+/), description: r.desc })
        }
        return out.concat([
            { id: "bars.position", name: "Bar position", route: "bars", category: "Bars",
              searchTags: ["top", "bottom", "edge", "position"], description: "Dock the bar to the top or bottom edge." },
            { id: "bars.form", name: "Bar form", route: "bars", category: "Bars",
              searchTags: ["full", "fit", "dock", "notch", "shape", "shell"], description: "Full, fit, dock or notch shell shape." },
            { id: "bars.border", name: "Bar border", route: "bars", category: "Bars",
              searchTags: ["outline", "frame", "stroke"], description: "Toggle the bar's outer border." },
            { id: "bars.tooltip", name: "Panel tooltip border", route: "bars", category: "Bars",
              searchTags: ["tooltip", "panel", "hint", "outline"], description: "Toggle borders on panel tooltips." },
            { id: "bars.accent", name: "Accent colour", route: "bars", category: "Bars",
              searchTags: ["colour", "color", "seal", "palette", "tint"], description: "Pick the bar accent from the palette." },
            { id: "bars.layout", name: "Edit layout", route: "bars", category: "Bars",
              searchTags: ["arrange", "reorder", "widgets", "move", "unlock"], description: "Rearrange the bar's widgets." },
            { id: "bars.restore", name: "Restore layout", route: "bars", category: "Bars",
              searchTags: ["reset", "default", "revert"], description: "Reset all bars to defaults." },
            { id: "appearance.visibility", name: "Widget visibility", route: "appearance", category: "Appearance",
              searchTags: ["show", "hide", "widgets", "toggle"], description: "Show or hide bar widgets." },
            { id: "appearance.colour", name: "Per-widget colour", route: "appearance", category: "Appearance",
              searchTags: ["colour", "color", "tint", "fill", "accent"], description: "Assign an accent to individual widgets." },
            { id: "appearance.compact", name: "Compact widgets", route: "appearance", category: "Appearance",
              searchTags: ["density", "compact", "tight", "small"], description: "Tighten widget spacing." },
            { id: "logo.wordmark", name: "Launcher wordmark", route: "logo", category: "Logo",
              searchTags: ["text", "word", "brand", "ryoku", "name"], description: "Show the launcher as a wordmark." },
            { id: "logo.kanji", name: "Launcher mark", route: "logo", category: "Logo",
              searchTags: ["icon", "kanji", "glyph", "mark", "symbol"], description: "Show the launcher as a kanji mark." },
            { id: "workspaces.count", name: "Workspace count", route: "workspaces", category: "Workspaces",
              searchTags: ["active", "five", "ten", "5", "10", "number"], description: "How many workspaces to show." },
            { id: "workspaces.marker", name: "Workspace marker", route: "workspaces", category: "Workspaces",
              searchTags: ["dots", "numbers", "glyph", "magic", "style", "default"], description: "Marker style: dots, numbers or glyph." },
            { id: "pickers.tanzaku", name: "Tanzaku picker", route: "pickers", category: "Pickers",
              searchTags: ["strip", "list", "tanzaku"], description: "Use the tanzaku picker style." },
            { id: "pickers.hearthstone", name: "Hearthstone picker", route: "pickers", category: "Pickers",
              searchTags: ["fan", "cards", "hearthstone"], description: "Use the hearthstone picker style." },
            { id: "pickers.carousel", name: "Carousel picker", route: "pickers", category: "Pickers",
              searchTags: ["wheel", "spin", "carousel"], description: "Use the carousel picker style." },
            { id: "quick.reload", name: "Reload shell", route: "quick", category: "Quick",
              searchTags: ["restart", "refresh", "reload"], description: "Restart the Quickshell session." },
            { id: "quick.lock", name: "Lock screen", route: "quick", category: "Quick",
              searchTags: ["lock", "hyprlock", "secure"], description: "Lock the session." },
            { id: "quick.reboot", name: "Reboot", route: "quick", category: "Quick",
              searchTags: ["restart", "reboot"], description: "Restart the machine." },
            { id: "quick.shutdown", name: "Shut down", route: "quick", category: "Quick",
              searchTags: ["poweroff", "shutdown", "power"], description: "Power off the machine." }
        ])
    }

    screen: cc.root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-control"
    WlrLayershell.keyboardFocus: cc.root.controlVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real reveal: cc.root.controlVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: cc.root.controlVisible ? tk.revealOpen : tk.revealClose
            easing.type: cc.root.controlVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    onRevealChanged: if (reveal < 0.01) { cc.mode = "quick"; cc.route = "" }

    CcTokens { id: tk; root: cc.root }

    readonly property int barH: (cc.root.variantHost && cc.root.variantHost.runningVariant === "v2") ? 33 : 35
    readonly property int cardW: Math.min(tk.cardW, cc.width - 2 * tk.screenMargin)
    readonly property int cardH: Math.min(tk.cardH, cc.height - cc.barH - 2 * tk.screenMargin - 8)

    // click-outside to dismiss
    MouseArea { anchors.fill: parent; onClicked: cc.close() }

    Rectangle {
        id: card
        width: cc.cardW
        height: (stage.item && stage.item.implicitHeight > 0)
            ? Math.min(cc.cardH, chromeCol.implicitHeight + tk.gap + tk.pad * 2 + stage.item.implicitHeight)
            : cc.cardH
        Behavior on height { NumberAnimation { duration: tk.pageIn; easing.type: Easing.OutCubic } }
        radius: cc.root.pillRadius
        color: cc.root.bg
        border.width: 1
        border.color: cc.root.sep
        PillShadow { theme: cc.root }

        x: Math.round(Math.max(tk.screenMargin, Math.min(cc.root.launcherBarX - 80, cc.width - width - tk.screenMargin)))
        y: (cc.root.barPosition === "bottom" ? (cc.height - cc.barH - 8 - height) : (cc.barH + 8))
           + (cc.root.barPosition === "bottom" ? 6 : -6) * (1 - cc.reveal)
        opacity: cc.reveal
        scale: 0.98 + 0.02 * cc.reveal
        transformOrigin: cc.root.barPosition === "bottom" ? Item.Bottom : Item.Top
        focus: cc.root.controlVisible
        Keys.onPressed: function(e) { if (e.key === Qt.Key_Escape) { cc.close(); e.accepted = true } }
        MouseArea { anchors.fill: parent; onClicked: {} }   // eat clicks so they don't dismiss

        // CTRL K focuses the search field from anywhere in the open panel.
        Shortcut {
            sequence: "Ctrl+K"
            context: Qt.WindowShortcut
            enabled: cc.root.controlVisible
            onActivated: search.focusInput()
        }

        Column {
            id: chromeCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: tk.pad }
            spacing: tk.gap

            CcHeader { width: parent.width; root: cc.root; mode: cc.mode; route: cc.route; onClosed: cc.close() }
            Rectangle { width: parent.width; height: 1; color: cc.root.sep }
            CcSearch {
                id: search
                width: parent.width
                root: cc.root
                entries: cc.searchEntries
                onAccepted: (entry) => cc.open(entry.route)
            }
            Item {
                width: parent.width
                height: 30
                CcTabs {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    root: cc.root; current: cc.mode
                    onChose: (m) => { cc.mode = m; cc.route = "" }
                }
                CcStatusStrip {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(360, parent.width * 0.46)
                    root: cc.root
                }
            }
        }

        PageMotionStage {
            id: stage
            anchors {
                top: chromeCol.bottom; topMargin: tk.gap
                left: parent.left; right: parent.right; bottom: parent.bottom
                leftMargin: tk.pad; rightMargin: tk.pad; bottomMargin: tk.pad
            }
            root: cc.root
            cc: cc
            outMs: tk.pageOut
            inMs: tk.pageIn
            pageUrl: cc.pageUrlFor(cc.mode, cc.route)
        }
    }
}
