pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "Singletons"

// desktop right-click menu, carbon-dossier idiom (力 masthead, corner
// registration ticks, hairline rules, mono uppercase spec rows + vermilion
// hover tick), so it reads as the same shell as the pill rather than a
// generic popup. two scopes:
//   right-click bare desktop = desktop menu (show/hide each widget,
//     settings, reload)
//   right-click a widget     = its menu (cycle design, toggle date/motion/
//     units, lock, snap to a zone, hide) + the same globals
// every action writes the same widgets Config the drag and Ryoku Settings
// do. fills the host window so its click-away catcher can dismiss.
Item {
    id: menu

    anchors.fill: parent
    visible: menu.open

    property bool open: false
    property string scope: "desktop"   // desktop | clock | weather | cal
    property real px: 0
    property real py: 0

    readonly property bool isWidget: menu.scope !== "desktop"
    readonly property bool isClock: menu.scope === "clock"
    readonly property bool isWeather: menu.scope === "weather"
    readonly property bool isCal: menu.scope === "cal"
    readonly property bool locked: menu.isWidget ? Config[menu.scope + "Locked"] : false
    readonly property string curAnchor: menu.isWidget ? Config[menu.scope + "Anchor"] : ""
    readonly property string curDesign: menu.isWidget ? Config[menu.scope + "Design"] : ""

    readonly property var zones: [
        { "zone": "top-left", "glyph": "\u2196" }, { "zone": "top", "glyph": "\u2191" }, { "zone": "top-right", "glyph": "\u2197" },
        { "zone": "left", "glyph": "\u2190" }, { "zone": "center", "glyph": "\u2299" }, { "zone": "right", "glyph": "\u2192" },
        { "zone": "bottom-left", "glyph": "\u2199" }, { "zone": "bottom", "glyph": "\u2193" }, { "zone": "bottom-right", "glyph": "\u2198" }
    ]

    function openFor(widget, x, y) { menu.scope = widget; menu.px = x; menu.py = y; menu.open = true; }
    function openDesktop(x, y) { menu.scope = "desktop"; menu.px = x; menu.py = y; menu.open = true; }
    function close() { menu.open = false; }
    function cap(s) { return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

    function cycleDesign() {
        const lists = {
            clock: ["digital", "minimal", "analog", "flip", "rings"],
            weather: ["card", "minimal", "strip"],
            cal: ["month", "minimal", "agenda", "week", "heat"]
        };
        const d = lists[menu.scope];
        if (!d)
            return;
        const key = menu.scope + "Design";
        Config.set(key, d[(d.indexOf(Config[key]) + 1) % d.length]);
    }
    function cycleCalAccent() {
        const a = ["wallust", "brand", "mono"];
        Config.set("calAccent", a[(a.indexOf(Config.calAccent) + 1) % a.length]);
    }
    function openSettings() {
        Quickshell.execDetached(["sh", "-c", "ryoku-hub config set section widgets; flock -n -o /tmp/ryoku-hub.lock qs -c hub"]);
        menu.close();
    }
    function refreshShell() {
        Quickshell.execDetached(["ryoku-shell", "reload"]);
        menu.close();
    }

    // click-away.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: menu.close()
    }

    MultiEffect {
        source: panel
        anchors.fill: panel
        visible: !Performance.shadowsDisabled
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.6)
        shadowBlur: 1.0
        shadowVerticalOffset: 10
        blurMax: 48
        autoPaddingEnabled: true
    }

    Rectangle {
        id: panel
        x: Math.max(8, Math.min(menu.px, menu.width - width - 8))
        y: Math.max(8, Math.min(menu.py, menu.height - height - 8))
        width: 234
        height: col.implicitHeight + 28
        radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.hair

        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.95
        opacity: menu.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 130 } }

        CornerTicks { anchors.fill: parent; anchors.margins: 7 }

        Column {
            id: col
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 0

            // masthead = 力 + scope.
            Item {
                width: parent.width
                height: 26
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    BrandMark {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: menu.scope.toUpperCase()
                        color: Theme.inkSoft
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2.4
                    }
                }
            }

            Rule {}

            // desktop scope.
            MenuRow { visible: !menu.isWidget; k: "Clock"; v: Config.clockEnabled ? "On" : "Off"; on: Config.clockEnabled; closeOnTrigger: false; onTriggered: Config.set("clockEnabled", !Config.clockEnabled) }
            MenuRow { visible: !menu.isWidget; k: "Weather"; v: Config.weatherEnabled ? "On" : "Off"; on: Config.weatherEnabled; closeOnTrigger: false; onTriggered: Config.set("weatherEnabled", !Config.weatherEnabled) }
            MenuRow { visible: !menu.isWidget; k: "Calendar"; v: Config.calEnabled ? "On" : "Off"; on: Config.calEnabled; closeOnTrigger: false; onTriggered: Config.set("calEnabled", !Config.calEnabled) }

            // widget scope.
            MenuRow { visible: menu.isWidget; k: "Design"; v: menu.cap(menu.curDesign); closeOnTrigger: false; onTriggered: menu.cycleDesign() }
            MenuRow { visible: menu.isClock; k: "Date"; v: Config.dateShow ? "On" : "Off"; on: Config.dateShow; closeOnTrigger: false; onTriggered: Config.toggle("dateShow") }
            MenuRow { visible: menu.isWeather; k: "Motion"; v: Config.weatherAnimate ? "On" : "Off"; on: Config.weatherAnimate; closeOnTrigger: false; onTriggered: Config.toggle("weatherAnimate") }
            MenuRow { visible: menu.isWeather; k: "Units"; v: Config.weatherUnit === "C" ? "\u00b0C" : "\u00b0F"; closeOnTrigger: false; onTriggered: Config.set("weatherUnit", Config.weatherUnit === "C" ? "F" : "C") }
            MenuRow { visible: menu.isCal; k: "Week start"; v: Config.calWeekStart === "sun" ? "Sun" : "Mon"; closeOnTrigger: false; onTriggered: Config.set("calWeekStart", Config.calWeekStart === "sun" ? "mon" : "sun") }
            MenuRow { visible: menu.isCal; k: "Accent"; v: menu.cap(Config.calAccent); closeOnTrigger: false; onTriggered: menu.cycleCalAccent() }
            MenuRow { visible: menu.isWidget; k: "Lock"; v: menu.locked ? "On" : "Off"; on: menu.locked; closeOnTrigger: false; onTriggered: Config.toggle(menu.scope + "Locked") }

            Rule { visible: menu.isWidget }

            // snap-to-zone pad (widget scope).
            Item {
                visible: menu.isWidget
                width: parent.width
                height: menu.isWidget ? pad.height + 12 : 0
                Grid {
                    id: pad
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 3
                    spacing: 4
                    Repeater {
                        model: menu.zones
                        Rectangle {
                            id: cell
                            required property var modelData
                            readonly property bool on: menu.curAnchor === cell.modelData.zone
                            width: 32
                            height: 24
                            radius: Theme.radius
                            color: cell.on ? Theme.brand : (cellMa.containsMouse ? Qt.rgba(Theme.brand.r, Theme.brand.g, Theme.brand.b, 0.12) : "transparent")
                            border.width: 1
                            border.color: cell.on ? Theme.brand : Theme.hair
                            Behavior on color { ColorAnimation { duration: 90 } }
                            Text {
                                anchors.centerIn: parent
                                text: cell.modelData.glyph
                                color: cell.on ? Theme.cardBot : (cellMa.containsMouse ? Theme.ink : Theme.faint)
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { Config.setAnchor(menu.scope, cell.modelData.zone); menu.close(); }
                            }
                        }
                    }
                }
            }

            Rule { visible: menu.isWidget }
            MenuRow { visible: menu.isWidget; k: "Hide"; onTriggered: { Config.set(menu.scope + "Enabled", false); menu.close(); } }

            Rule {}
            MenuRow { k: "Settings"; accent: true; onTriggered: menu.openSettings() }
            MenuRow { k: "Reload shell"; onTriggered: menu.refreshShell() }
        }
    }

    component Rule: Item {
        width: parent ? parent.width : 0
        height: 11
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Theme.hair }
    }

    component MenuRow: Item {
        id: mi
        property string k: ""
        property string v: ""
        property bool on: false
        property bool accent: false
        property bool closeOnTrigger: true
        signal triggered()

        width: parent ? parent.width : 0
        height: 30

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            radius: Theme.radius
            color: miMa.containsMouse ? Qt.rgba(Theme.brand.r, Theme.brand.g, Theme.brand.b, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        // vermilion registration tick on hover.
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: -6
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 14
            radius: Theme.radius
            color: Theme.brand
            opacity: miMa.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: mi.k
            color: mi.accent ? Theme.brand : (miMa.containsMouse ? Theme.ink : Theme.inkDim)
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        Text {
            visible: mi.v.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: mi.v
            color: mi.on ? Theme.brand : Theme.inkSoft
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MouseArea {
            id: miMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                mi.triggered();
                if (mi.closeOnTrigger)
                    menu.close();
            }
        }
    }
}
