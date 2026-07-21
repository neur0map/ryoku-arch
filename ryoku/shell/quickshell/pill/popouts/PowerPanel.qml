pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../Singletons"

// The power/session panel: the frame-blob popout's content. A live-wallpaper
// hero over a session strip, rendered straight onto the blob surface -- the blob
// IS the surface, so this paints no fill of its own (that would double it). The
// hero is the one splash of colour (data, the desktop's skin); identity and
// uptime read on the left, session actions on the right, a scannable barcode in
// the corner. Deprecates the old glyph-column Power popout.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal closeRequested()

    readonly property real cardW: 720 * root.s
    readonly property real heroH: 300 * root.s
    readonly property real stripH: 158 * root.s
    implicitWidth: cardW
    implicitHeight: heroH + stripH

    readonly property var actions: [
        { glyph: "lock",               label: "Lock",     confirm: false, dispatch: "",              argv: ["ryoku-shell", "lock"] },
        { glyph: "bedtime",            label: "Sleep",    confirm: false, dispatch: "",              argv: ["systemctl", "suspend"] },
        { glyph: "logout",             label: "Logout",   confirm: true,  dispatch: "hl.dsp.exit()", argv: [] },
        { glyph: "restart_alt",        label: "Restart",  confirm: true,  dispatch: "",              argv: ["systemctl", "reboot"] },
        { glyph: "power_settings_new", label: "Shutdown", confirm: true,  dispatch: "",              argv: ["systemctl", "poweroff"] }
    ]

    // absorb clicks on the panel body so they never fall through the blob.
    MouseArea { anchors.fill: parent }

    // ── hero: the live wallpaper ──────────────────────────────────────────
    WallpaperHero {
        id: hero
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.heroH
        active: root.open
        path: Session.wallpaper
        isVideo: Session.wallIsVideo
        poster: Session.livePoster

        // fade the hero's foot into the blob so hero and strip read as one body.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 110 * root.s
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Tokens.paper }
            }
        }
    }

    // hairline seam between hero and strip.
    Rectangle {
        anchors { left: parent.left; right: parent.right }
        y: root.heroH
        height: Tokens.border
        color: Tokens.line
    }

    // ── strip: identity (left) + actions (right) ──────────────────────────
    Item {
        id: strip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.stripH

        Row {
            anchors { left: parent.left; top: parent.top; leftMargin: Tokens.s5 * root.s; topMargin: Tokens.s4 * root.s }
            spacing: Tokens.s3 * root.s

            Rectangle {
                width: 56 * root.s; height: 56 * root.s; radius: width / 2
                color: "transparent"
                border.width: Tokens.border
                border.color: Tokens.lineStrong
                Text {
                    anchors.centerIn: parent
                    text: "力"; color: Tokens.ink; font.family: Tokens.jp
                    font.pixelSize: 26 * root.s
                }
            }

            Column {
                spacing: 4 * root.s
                Text {
                    text: Session.user
                    color: Tokens.ink; font.family: Tokens.display
                    font.pixelSize: 26 * root.s; font.capitalization: Font.Capitalize
                }
                Row {
                    spacing: Tokens.s2 * root.s
                    Text {
                        text: Session.user + "@" + Session.host
                        color: Tokens.inkMuted; font.family: Tokens.mono
                        font.pixelSize: Tokens.fSmall * root.s
                    }
                    Text {
                        text: "·"; color: Tokens.inkFaint; font.family: Tokens.mono
                        font.pixelSize: Tokens.fSmall * root.s
                    }
                    Text {
                        text: "UP " + Session.uptimeText
                        color: Tokens.inkFaint; font.family: Tokens.mono
                        font.pixelSize: Tokens.fSmall * root.s
                        font.capitalization: Font.AllUppercase; font.letterSpacing: Tokens.trackLabel * root.s
                    }
                }
            }
        }

        // session actions, right-aligned and vertically centred.
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Tokens.s4 * root.s }
            spacing: Tokens.s2 * root.s
            Repeater {
                model: root.actions
                delegate: PowerAction {
                    required property var modelData
                    s: root.s
                    glyph: modelData.glyph
                    label: modelData.label
                    confirm: modelData.confirm
                    argv: modelData.argv
                    dispatch: modelData.dispatch
                    onRan: root.closeRequested()
                }
            }
        }

        // a scannable Code 39 barcode: the printed-instrument tell.
        Barcode {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: Tokens.s5 * root.s; bottomMargin: Tokens.s3 * root.s }
            text: "RYOKU"
            barHeight: 9 * root.s
            unit: 1.0 * root.s
            opacity: 0.4
        }
    }

    // grain tooth over the whole panel so it reads matte, hero included.
    Grain { anchors.fill: parent }
}
