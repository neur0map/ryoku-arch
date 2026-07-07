pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
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
        "radius", "weatherUnit", "heroImage", "heroStrength", "heroPosX", "heroPosY", "showWeather", "showGreeting"
    ]

    // mirror of the launcher's canonical defaults (launcher Singletons/
    // LauncherConfig.qml), for "Reset to defaults" only.
    readonly property var defaults: ({
        "radius": 16, "weatherUnit": "auto", "heroImage": "", "heroStrength": 0.6,
        "heroPosX": 0.5, "heroPosY": 0.5, "showWeather": true, "showGreeting": true
    })

    property bool loaded: false
    property var committedVals: ({})

    QtObject {
        id: draft
        property real radius: 16
        property string weatherUnit: "auto"
        property string heroImage: ""
        property real heroStrength: 0.6
        property real heroPosX: 0.5
        property real heroPosY: 0.5
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
            property real heroPosX: 0.5
            property real heroPosY: 0.5
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

                    // preview of the backdrop, cover-cropped like the launcher
                    // card. Drag it to choose the part that shows.
                    Rectangle {
                        id: prevFrame
                        width: parent.width
                        height: Math.round(parent.width * 106 / 560)  // launcher card aspect (560x106)
                        radius: Theme.radius
                        color: Theme.surfaceLo
                        border.width: 1
                        border.color: dragHov.hovered ? Theme.subtle : Theme.line
                        clip: true
                        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                        Image {
                            id: prevImg
                            visible: draft.heroImage.length > 0
                            readonly property real ir: prevImg.implicitHeight > 0 ? prevImg.implicitWidth / prevImg.implicitHeight : 1
                            readonly property real fr: prevFrame.height > 0 ? prevFrame.width / prevFrame.height : 1
                            width: prevImg.ir > prevImg.fr ? prevFrame.height * prevImg.ir : prevFrame.width
                            height: prevImg.ir > prevImg.fr ? prevFrame.height : prevFrame.width / prevImg.ir
                            x: (prevFrame.width - width) * draft.heroPosX
                            y: (prevFrame.height - height) * draft.heroPosY
                            source: draft.heroImage
                            opacity: draft.heroStrength
                            asynchronous: true
                            cache: true
                        }

                        Column {
                            visible: draft.heroImage.length === 0
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "image"; size: 24; tint: Theme.faint }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Shipped art"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        // drag the image to reposition the crop; only a real
                        // drag on a custom image moves it.
                        DragHandler {
                            id: dragH
                            target: null
                            enabled: draft.heroImage.length > 0
                            cursorShape: Qt.SizeAllCursor
                            property real ox: 0.5
                            property real oy: 0.5
                            onActiveChanged: if (dragH.active) { dragH.ox = draft.heroPosX; dragH.oy = draft.heroPosY; }
                            onActiveTranslationChanged: {
                                if (!dragH.active)
                                    return;
                                var rx = prevImg.width - prevFrame.width;
                                var ry = prevImg.height - prevFrame.height;
                                if (rx > 1)
                                    page.edit("heroPosX", Math.max(0, Math.min(1, dragH.ox - dragH.activeTranslation.x / rx)));
                                if (ry > 1)
                                    page.edit("heroPosY", Math.max(0, Math.min(1, dragH.oy - dragH.activeTranslation.y / ry)));
                            }
                        }

                        HoverHandler { id: dragHov; enabled: draft.heroImage.length > 0; cursorShape: Qt.SizeAllCursor }

                        Rectangle {
                            visible: draft.heroImage.length > 0 && dragHov.hovered
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            width: dragHint.implicitWidth + 18
                            height: 24
                            radius: Theme.radius
                            color: Qt.rgba(0, 0, 0, 0.6)
                            Text {
                                id: dragHint
                                anchors.centerIn: parent
                                text: "Drag to reposition"
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                        }
                    }

                    // current file, with a change / reset.
                    Item {
                        width: parent.width
                        implicitHeight: 22
                        Text {
                            anchors.left: parent.left
                            anchors.right: actions.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                            text: draft.heroImage.length === 0 ? "Shipped art" : ("" + draft.heroImage).replace(/^.*\//, "")
                            color: draft.heroImage.length === 0 ? Theme.faint : Theme.cream
                            font.family: Theme.mono
                            font.pixelSize: 11
                        }
                        Row {
                            id: actions
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16
                            Text {
                                text: "Change\u2026"
                                color: changeHov.hovered ? Theme.bright : Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Behavior on color { ColorAnimation { duration: Theme.quick } }
                                HoverHandler { id: changeHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: imgPicker.open() }
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
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                        text: "A landscape PNG or JPG, ideally 1600px wide or more. It is cropped to a wide banner and dimmed; drag the preview to pick the part that shows."
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
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

    ImagePicker {
        id: imgPicker
        onPicked: (p) => { page.edit("heroImage", p); imgPicker.active = false; }
        onCanceled: imgPicker.active = false
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
