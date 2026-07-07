pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "Singletons"

// App Launcher: editor for the command palette (Super+Space). Edits land in
// ~/.config/ryoku/launcher.json, which the launcher watches, so they show the
// next time you open it. Save keeps them; Revert and leaving the section put the
// saved config back. Same draft-and-throttle shape as the Shell and Widgets
// pages.
Item {
    id: page

    readonly property var keys: [
        "radius", "weatherUnit", "heroImage", "heroStrength", "showWeather", "showGreeting"
    ]

    // mirror of the launcher's canonical defaults (launcher Singletons/
    // LauncherConfig.qml), for "Reset to defaults" only.
    readonly property var defaults: ({
        "radius": 16, "weatherUnit": "auto", "heroImage": "", "heroStrength": 0.6,
        "showWeather": true, "showGreeting": true
    })

    property bool loaded: false
    property var committedVals: ({})

    QtObject {
        id: draft
        property real radius: 16
        property string weatherUnit: "auto"
        property string heroImage: ""
        property real heroStrength: 0.6
        property bool showWeather: true
        property bool showGreeting: true
    }

    function sameVal(a, b) { return String(a) === String(b); }

    readonly property bool dirty: {
        if (!page.loaded)
            return false;
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            if (!page.sameVal(draft[k], page.committedVals[k]))
                return true;
        }
        return false;
    }

    // pull the file into draft + the committed baseline (fresh object each time
    // so bindings on the baseline re-evaluate).
    function adopt() {
        var c = {};
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            draft[k] = adapter[k];
            c[k] = adapter[k];
        }
        page.committedVals = c;
    }

    // a later external write reloaded into the adapter: pull it into any key the
    // user has not locally edited, leaving edited keys untouched.
    function adoptExternal() {
        var c = {};
        for (var k in page.committedVals)
            c[k] = page.committedVals[k];
        for (var i = 0; i < page.keys.length; i++) {
            var kk = page.keys[i];
            if (page.sameVal(draft[kk], page.committedVals[kk])) {
                draft[kk] = adapter[kk];
                c[kk] = adapter[kk];
            }
        }
        page.committedVals = c;
    }

    function flush() {
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            adapter[k] = draft[k];
        }
        cfg.writeAdapter();
    }

    // throttle live writes: apply at once, then at most once per interval while
    // the value keeps changing, with a trailing write. dragging stays smooth.
    property bool writePending: false
    Timer {
        id: throttle
        interval: 70
        onTriggered: {
            if (page.writePending) {
                page.writePending = false;
                page.flush();
                throttle.restart();
            }
        }
    }
    function edit(k, v) {
        draft[k] = v;
        if (throttle.running) {
            page.writePending = true;
        } else {
            page.flush();
            throttle.start();
        }
    }

    function snapshotDraft() {
        var s = {};
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            s[k] = draft[k];
        }
        return s;
    }
    function save() {
        throttle.stop();
        page.writePending = false;
        page.flush();
        page.committedVals = page.snapshotDraft();
    }
    function revert() {
        throttle.stop();
        page.writePending = false;
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            draft[k] = page.committedVals[k];
        }
        page.flush();
    }
    function resetDefaults() {
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            page.edit(k, page.defaults[k]);
        }
    }

    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: { if (!page.loaded) { page.adopt(); page.loaded = true; } else { page.adoptExternal(); } }
        onLoadFailed: { if (!page.loaded) { page.adopt(); page.loaded = true; } }

        JsonAdapter {
            id: adapter
            property real radius: 16
            property string weatherUnit: "auto"
            property string heroImage: ""
            property real heroStrength: 0.6
            property bool showWeather: true
            property bool showGreeting: true
        }
    }

    // leaving with unsaved edits puts the saved config back, so a preview is
    // never left applied by accident.
    Component.onDestruction: {
        if (page.loaded && page.dirty) {
            for (var i = 0; i < page.keys.length; i++) {
                var k = page.keys[i];
                adapter[k] = page.committedVals[k];
            }
            cfg.writeAdapter();
        }
    }

    Text {
        id: hint
        anchors.left: parent.left
        anchors.top: parent.top
        text: "Changes apply to the launcher \u00b7 open it with Super+Space to see them"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hint.bottom
        anchors.topMargin: 22
        anchors.bottom: bar.top
        anchors.bottomMargin: 18
        contentWidth: width
        contentHeight: Math.max(cols.height, height)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: Theme.radius
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Row {
            id: cols
            width: flick.width - 12
            spacing: 56
            readonly property real colW: (width - spacing) / 2

            Column {
                width: cols.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "SHAPE"
                    NumberField {
                        width: parent.width; label: "Corner radius"; unit: "px"
                        from: 0; to: 28; value: draft.radius
                        onModified: (v) => page.edit("radius", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "HOME CARD"
                    ChoiceRow {
                        width: parent.width; label: "Weather units"
                        options: [
                            { "key": "auto", "label": "Auto" },
                            { "key": "C", "label": "\u00b0C" },
                            { "key": "F", "label": "\u00b0F" }
                        ]
                        current: draft.weatherUnit
                        onChosen: (k) => page.edit("weatherUnit", k)
                    }
                    ToggleRow {
                        width: parent.width; label: "Show weather"
                        checked: draft.showWeather
                        onToggled: (v) => page.edit("showWeather", v)
                    }
                    ToggleRow {
                        width: parent.width; label: "Show greeting"
                        checked: draft.showGreeting
                        onToggled: (v) => page.edit("showGreeting", v)
                    }
                }
            }

            Column {
                width: cols.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "BACKDROP"

                    // picker: shows the current file (or the shipped default) and
                    // opens a native chooser.
                    Item {
                        width: parent.width
                        implicitHeight: 38

                        Text {
                            id: bdLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 116
                            text: "Image"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            anchors.left: bdLabel.right
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 32
                            radius: Theme.radius
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: pickHover.hovered ? Theme.subtle : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: bdIcon.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideLeft
                                text: draft.heroImage.length === 0
                                    ? "Shipped art"
                                    : ("" + draft.heroImage).replace(/^.*\//, "")
                                color: draft.heroImage.length === 0 ? Theme.faint : Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                            Icon {
                                id: bdIcon
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter
                                name: "image"
                                size: 14
                                tint: pickHover.hovered ? Theme.cream : Theme.dim
                            }
                            HoverHandler { id: pickHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: imgDlg.open() }
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                        text: "PNG or JPG, about 1600\u00d7640 (a ~5:1 banner). Keep the subject centred \u2014 the sides get cropped and the far left and right sit under the clock and date."
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Text {
                        visible: draft.heroImage.length > 0
                        text: "Use shipped art"
                        color: resetHover.hovered ? Theme.bright : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                        HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: page.edit("heroImage", "") }
                    }

                    SliderRow {
                        width: parent.width; label: "Strength"; percent: true
                        from: 0; to: 1; step: 0.01; value: draft.heroStrength
                        onModified: (v) => page.edit("heroStrength", v)
                    }
                }
            }
        }
    }

    FileDialog {
        id: imgDlg
        title: "Choose a launcher backdrop"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp)", "All files (*)"]
        onAccepted: page.edit("heroImage", "" + imgDlg.selectedFile)
    }

    // --- bottom: status + actions ------------------------------------------
    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 60
        radius: Theme.radius
        color: page.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.08) : Theme.surfaceLo
        border.width: 1
        border.color: page.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.4) : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.medium } }
        Behavior on border.color { ColorAnimation { duration: Theme.medium } }

        Rectangle {
            id: statusDot
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: 4.5
            color: page.dirty ? Theme.ember : Theme.ok
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        Text {
            anchors.left: statusDot.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: page.dirty ? "Unsaved changes" : "Saved \u00b7 applies to your launcher"
            color: page.dirty ? Theme.bright : Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Reset to defaults"
                icon: "refresh"
                onClicked: page.resetDefaults()
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Revert"
                icon: "close"
                enabled: page.dirty
                onClicked: page.revert()
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Save"
                icon: "check"
                primary: true
                enabled: page.dirty
                onClicked: page.save()
            }
        }
    }
}
