pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Default Apps (DESIGN.md section 8, SYSTEM). Pick the apps the desktop launches:
// browser (Super+B), terminal (Super+Return), editor (Super+N), file manager
// (Super+E) and notes (Super+O). The keybinds run them through the ryoku-app
// resolver, which reads this store, so a swap takes effect on the next launch
// with no reload; genApps also exports $BROWSER and $TERMINAL for the CLI.
// Stored in hypr.json "apps".
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    readonly property bool hubReady: pg.hub && typeof pg.hub.hyprVal === "function"
    // role -> chosen command; an empty/absent role uses the shipped fallback.
    readonly property var chosen: pg.hubReady ? (pg.hub.hyprVal("apps") || ({})) : ({})
    readonly property int dirtyCount: pg.hubReady ? (pg.hub.dirty || 0) : 0

    // the swappable roles + candidates, from `ryoku-hub apps` (installed flagged).
    property var roles: []

    Process {
        id: appsGet
        command: ["ryoku-hub", "apps"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    pg.roles = JSON.parse(this.text) || [];
                } catch (e) { console.log("apps: role list parse failed: " + e); }
            }
        }
    }

    // the effective command for a role: the choice, else the shipped fallback.
    function effOf(role, fallback) {
        var v = pg.chosen[role];
        return (v && ("" + v).length) ? ("" + v) : fallback;
    }
    function setApp(role, cmd) {
        if (!pg.hubReady)
            return;
        var cur = pg.hub.hyprVal("apps") || {};
        var m = {};
        for (var k in cur)
            m[k] = cur[k];
        cmd = ("" + (cmd || "")).trim();
        if (!cmd)
            delete m[role];
        else
            m[role] = cmd;
        pg.hub.hyprEdit("apps", m);
    }
    function clearAll() { if (pg.hubReady) pg.hub.hyprEdit("apps", ({})); }
    function save() { if (pg.hubReady) pg.hub.save(); }
    function revert() { if (pg.hubReady) pg.hub.revert(); }

    // ── head: eyebrow, Fraunces title, blurb ──
    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s6
        spacing: Tokens.s2

        Row {
            spacing: Tokens.s2
            Rectangle {
                width: 16; height: 1; color: Tokens.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "力"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "SYSTEM"; color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: "Default Apps"; color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: "Pick the apps the desktop launches: browser (Super+B), terminal (Super+Return), editor (Super+N), file manager (Super+E) and notes (Super+O). Installed apps show as chips; type any command for the rest. A change takes effect on the next launch."
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
    }

    Marginalia {
        anchors { right: parent.right; top: head.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s1
        kana: "既定"
        index: "02"; label: "SYSTEM"
        glyph: "meander"; glyph2: "torii"
    }

    // ── the role list ──
    Flickable {
        id: flick
        anchors {
            left: parent.left; right: parent.right
            top: head.bottom; bottom: bar.top
            leftMargin: Tokens.s6; rightMargin: Tokens.s6
            topMargin: Tokens.s5; bottomMargin: Tokens.s3
        }
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width - Tokens.s3   // reserve a lane for the scroll rail
            spacing: Tokens.s5

            Repeater {
                model: pg.roles

                delegate: Column {
                    id: roleCard
                    required property var modelData
                    width: col.width
                    spacing: Tokens.s2
                    readonly property string role: roleCard.modelData.role
                    readonly property string fallback: roleCard.modelData.fallback || ""
                    readonly property string eff: pg.effOf(roleCard.role, roleCard.fallback)

                    // label left, current effective command right.
                    Item {
                        width: parent.width
                        height: 20
                        Text {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            text: roleCard.modelData.label
                            color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                            font.capitalization: Font.AllUppercase
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, parent.width * 0.55)
                            text: roleCard.eff !== "" ? roleCard.eff : "not set"
                            color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                            elide: Text.ElideLeft; horizontalAlignment: Text.AlignRight
                        }
                    }

                    // installed candidates as pills; tapping one sets the choice.
                    Flow {
                        width: parent.width
                        spacing: Tokens.s2

                        Repeater {
                            model: roleCard.modelData.candidates || []

                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                visible: chip.modelData.installed === true
                                readonly property bool sel: roleCard.eff === chip.modelData.cmd
                                implicitWidth: chipLabel.implicitWidth + Tokens.s4
                                implicitHeight: 28
                                radius: Tokens.radius
                                color: chip.sel ? Tokens.ink : (ch.hovered ? Tokens.tint10 : "transparent")
                                border.width: Tokens.border
                                border.color: chip.sel ? Tokens.ink : (ch.hovered ? Tokens.lineStrong : Tokens.line)
                                Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: chip.modelData.label
                                    color: chip.sel ? Tokens.paper : Tokens.inkDim
                                    font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                                }
                                HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: pg.setApp(roleCard.role, chip.modelData.cmd) }
                            }
                        }
                    }

                    // custom command: anything not offered as a chip.
                    Field {
                        width: parent.width
                        tabular: true
                        placeholder: roleCard.fallback !== "" ? ("custom command, e.g. " + roleCard.fallback) : "custom command"
                        text: ("" + (pg.chosen[roleCard.role] || ""))
                        onCommitted: (v) => pg.setApp(roleCard.role, v)
                    }
                }
            }
        }
    }

    // ── action bar: status + reset / revert / save ──
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.bottomMargin: Tokens.s5
        height: 60
        color: "transparent"
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1; color: Tokens.line
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3
            Rectangle {
                id: dot
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3; antialiasing: false
                color: pg.dirtyCount > 0 ? Tokens.ink : "transparent"
                border.width: pg.dirtyCount > 0 ? 0 : Tokens.border
                border.color: Tokens.inkFaint
                SequentialAnimation on opacity {
                    running: pg.dirtyCount > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    onStopped: dot.opacity = 1
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pg.dirtyCount > 0 ? "Unsaved changes" : "Saved"
                color: pg.dirtyCount > 0 ? Tokens.ink : Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.Medium
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: "RESET TO DEFAULTS"
                armed: Object.keys(pg.chosen).length > 0
                onAct: pg.clearAll()
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: "REVERT"
                armed: pg.dirtyCount > 0
                onAct: pg.revert()
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: "SAVE"
                primary: true
                armed: pg.dirtyCount > 0
                onAct: pg.save()
            }
        }
        Marginalia {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            kana: "既定"
            glyph: "meander"; glyph2: "torii"
        }
    }
}
