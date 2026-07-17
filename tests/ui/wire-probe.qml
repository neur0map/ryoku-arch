import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "schema/ShellSettingsPage.js" as Schema

// wiring probe: the real FileView + JsonAdapter contract from ShellSettingsPage,
// driven by the schema, writing to a copy of the real shell.json.
ShellRoot {
    id: root
    property string cfgDir: Quickshell.env("RYOKU_TEST_CFG")
    property bool loaded: false
    property var draft: ({})

    readonly property var shellKeys: [
        "frameRadius","roundness","frameBorder","frameEnabled","frameSmoothing","frameOpacity",
        "shadowStrength","shadowSize","surfaceColor","osdRadius","osdOpacity",
        "barEnabled","barPosition","barStyle","barHeight","barShowTitle","barShowMedia",
        "barShowStatus","barOccupiedWorkspaces","islandEdge","islandAlong","islandHidden",
        "islandModules","islandRadius","fontFamily","fontScale","weatherLocation","weatherUnit",
        "sidebarLeftEnabled","sidebarRightEnabled","sidebarLeftPanes","sidebarRightPanes",
        "sidebarClickless","sidebarWidth","sidebarCornerSize"
    ]

    function adopt() {
        var d = {};
        for (var i = 0; i < shellKeys.length; i++) d[shellKeys[i]] = shellA[shellKeys[i]];
        draft = d; loaded = true;
        console.log("ADOPTED frameBorder=" + d.frameBorder + " barStyle=" + d.barStyle);
    }
    function edit(k, v) {
        var d = {}; for (var x in draft) d[x] = draft[x];
        d[k] = v; draft = d;
        console.log("EDIT " + k + "=" + JSON.stringify(v));
    }
    function flush() {
        for (var i = 0; i < shellKeys.length; i++) {
            var k = shellKeys[i];
            if (draft[k] !== undefined) shellA[k] = draft[k];
        }
        cfgShell.writeAdapter();
        console.log("FLUSHED");
    }

    FileView {
        id: cfgShell
        path: root.cfgDir + "/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: if (!root.loaded) root.adopt()
        JsonAdapter {
            id: shellA
            property real frameRadius: 9
            property real roundness: 10
            property real frameBorder: 59
            property bool frameEnabled: true
            property real frameSmoothing: 8
            property real frameOpacity: 1
            property real shadowStrength: 0.63
            property real shadowSize: 12
            property color surfaceColor: "#0f1115"
            property real osdRadius: 28
            property real osdOpacity: 1
            property bool barEnabled: true
            property string barPosition: "top"
            property string barStyle: "noctalia"
            property real barHeight: 30
            property bool barShowTitle: true
            property bool barShowMedia: true
            property bool barShowStatus: true
            property bool barOccupiedWorkspaces: true
            property string islandEdge: "top"
            property real islandAlong: -1
            property bool islandHidden: false
            property var islandModules: ["workspaces","clock","date","media"]
            property real islandRadius: 17
            property string fontFamily: "JetBrainsMono Nerd Font"
            property real fontScale: 1.3
            property string weatherLocation: ""
            property string weatherUnit: "auto"
            property bool sidebarLeftEnabled: true
            property bool sidebarRightEnabled: true
            property var sidebarLeftPanes: ["stash"]
            property var sidebarRightPanes: ["notifications","calendar","media","weather","recording"]
            property bool sidebarClickless: true
            property real sidebarWidth: 340
            property real sidebarCornerSize: 34
        }
    }

    // drive the probe headlessly: adopt, edit three kinds, flush, quit.
    Timer {
        interval: 900; running: true
        onTriggered: {
            if (!root.loaded) { console.log("PROBE-FAIL not loaded"); Qt.quit(); return }
            root.edit("frameBorder", 88);                                   // real
            root.edit("barStyle", "delos");                                 // enum
            root.edit("islandModules", ["workspaces","clock","tray"]);      // set
            root.flush();
            quit.start();
        }
    }
    Timer { id: quit; interval: 700; onTriggered: Qt.quit() }
}
