pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live config for the desktop widgets. one source of truth: the knobs Ryoku
// Settings' Desktop Widgets section edits, the desktop drag/right-click writes,
// and the shipped defaults. JSON at ~/.config/ryoku/widgets.json, watched, so a
// Settings save or a desktop drag retunes the running widgets next file event.
//
// placement = compass anchor (one of nine zones, kept across resolutions by a
// fixed edge margin) | "free" (absolute x/y in monitor pixels, set by dragging).
// dragging flips to "free"; right-click/Settings snap back to a zone. scale, bg,
// radius, opacity, design are independent. write helpers below let the desktop
// edit the same file Settings does.
Singleton {
    id: root

    // -- clock ---------------------------------------------------------------
    property alias clockEnabled: adapter.clockEnabled
    property alias clockDesign:  adapter.clockDesign   // digital | minimal | analog | flip | rings
    property alias clock24h:     adapter.clock24h
    property alias clockSeconds: adapter.clockSeconds
    property alias clockAccent:  adapter.clockAccent   // wallust | brand | mono
    property alias clockScale:   adapter.clockScale
    property alias clockAnchor:  adapter.clockAnchor   // top-left .. center .. bottom-right | free
    property alias clockX:       adapter.clockX        // free placement, monitor pixels
    property alias clockY:       adapter.clockY
    property alias clockLocked:  adapter.clockLocked   // prevent drag/resize
    property alias clockOpacity: adapter.clockOpacity
    property alias clockBg:      adapter.clockBg        // none | card | glass
    property alias clockRadius:  adapter.clockRadius
    property alias dateShow:     adapter.dateShow
    property alias dateDesign:   adapter.dateDesign     // inline | badge | stacked

    // -- weather -------------------------------------------------------------
    property alias weatherEnabled: adapter.weatherEnabled
    property alias weatherDesign:  adapter.weatherDesign  // card | minimal | strip
    property alias weatherUnit:    adapter.weatherUnit    // C | F
    property alias weatherScope:   adapter.weatherScope   // today | week
    property alias weatherAnimate: adapter.weatherAnimate
    property alias weatherScale:   adapter.weatherScale
    property alias weatherAnchor:  adapter.weatherAnchor
    property alias weatherX:       adapter.weatherX
    property alias weatherY:       adapter.weatherY
    property alias weatherLocked:  adapter.weatherLocked
    property alias weatherOpacity: adapter.weatherOpacity
    property alias weatherBg:      adapter.weatherBg       // none | card | glass
    property alias weatherRadius:  adapter.weatherRadius

    // -- calendar ------------------------------------------------------------
    property alias calEnabled:   adapter.calEnabled
    property alias calDesign:    adapter.calDesign     // month | minimal | agenda | week
    property alias calAccent:    adapter.calAccent     // wallust | brand | mono
    property alias calWeekStart: adapter.calWeekStart  // mon | sun
    property alias calScale:     adapter.calScale
    property alias calAnchor:    adapter.calAnchor
    property alias calX:         adapter.calX
    property alias calY:         adapter.calY
    property alias calLocked:    adapter.calLocked
    property alias calOpacity:   adapter.calOpacity
    property alias calBg:        adapter.calBg          // none | card | glass
    property alias calRadius:    adapter.calRadius

    // write helpers used by desktop drag + right-click menu. write the same file
    // Settings does; the watch reloads it (no-op for the value just written) so
    // running widgets and the next Settings open agree.
    function set(key, value) {
        adapter[key] = value;
        file.writeAdapter();
    }
    // memory-only, no file write. for a live drag like resize: aliases update
    // at once so the widget re-renders; setFree/set on release does the single
    // persisting write.
    function setLive(key, value) {
        adapter[key] = value;
    }
    function toggle(key) {
        adapter[key] = !adapter[key];
        file.writeAdapter();
    }
    function setAnchor(prefix, zone) {
        adapter[prefix + "Anchor"] = zone;
        file.writeAdapter();
    }
    function setFree(prefix, x, y) {
        adapter[prefix + "Anchor"] = "free";
        adapter[prefix + "X"] = x;
        adapter[prefix + "Y"] = y;
        file.writeAdapter();
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/widgets.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool clockEnabled: true
            property string clockDesign: "digital"
            property bool clock24h: true
            property bool clockSeconds: false
            property string clockAccent: "wallust"
            property real clockScale: 1.0
            property string clockAnchor: "top-left"
            property int clockX: 72
            property int clockY: 64
            property bool clockLocked: false
            property real clockOpacity: 1.0
            property string clockBg: "none"
            property int clockRadius: 26
            property bool dateShow: true
            property string dateDesign: "inline"

            property bool weatherEnabled: true
            property string weatherDesign: "card"
            property string weatherUnit: "C"
            property string weatherScope: "today"
            property bool weatherAnimate: true
            property real weatherScale: 1.0
            property string weatherAnchor: "top-right"
            property int weatherX: 72
            property int weatherY: 64
            property bool weatherLocked: false
            property real weatherOpacity: 1.0
            property string weatherBg: "glass"
            property int weatherRadius: 26

            property bool calEnabled: false
            property string calDesign: "month"
            property string calAccent: "wallust"
            property string calWeekStart: "mon"
            property real calScale: 1.0
            property string calAnchor: "bottom-right"
            property int calX: 72
            property int calY: 64
            property bool calLocked: false
            property real calOpacity: 1.0
            property string calBg: "glass"
            property int calRadius: 26
        }
    }

    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
