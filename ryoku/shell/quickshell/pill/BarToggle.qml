pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// one placeable quick-toggle for the bar: a Material Symbol tinted to the accent
// and filled while on, dim while off. click flips it through the shared Toggles
// singleton. `kind` picks which: wifi | bluetooth | mic | dnd | caffeine |
// nightlight. this is the unit the modular layout drops into a zone, so one
// toggle is one module and a user places exactly the ones they want.
Item {
    id: tg

    property real s: 1
    property string kind: "caffeine"
    readonly property real glyphPx: 14 * s

    implicitWidth: glyphPx + 4 * s
    implicitHeight: glyphPx + 4 * s

    // keep the shared probes awake only while a toggle is on screen.
    Component.onCompleted: Toggles.watchers += 1
    Component.onDestruction: Toggles.watchers -= 1

    readonly property bool on: kind === "wifi" ? Toggles.wifiOn
        : kind === "bluetooth" ? Toggles.btOn
        : kind === "mic" ? !Toggles.micMuted
        : kind === "dnd" ? Toggles.dnd
        : kind === "caffeine" ? Toggles.keepAwake
        : kind === "nightlight" ? Toggles.nightOn
        : false

    readonly property string glyph: kind === "wifi" ? (Toggles.wifiOn ? "wifi" : "wifi_off")
        : kind === "bluetooth" ? (Toggles.btOn ? "bluetooth" : "bluetooth_disabled")
        : kind === "mic" ? (Toggles.micMuted ? "mic_off" : "mic")
        : kind === "dnd" ? (Toggles.dnd ? "do_not_disturb_on" : "notifications")
        : kind === "caffeine" ? "coffee"
        : kind === "nightlight" ? "bedtime"
        : "toggle_on"

    function act() {
        if (kind === "wifi") Toggles.toggleWifi();
        else if (kind === "bluetooth") Toggles.toggleBt();
        else if (kind === "mic") Toggles.toggleMic();
        else if (kind === "dnd") Toggles.toggleDnd();
        else if (kind === "caffeine") Toggles.toggleCaffeine();
        else if (kind === "nightlight") Toggles.toggleNight();
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: tg.glyph
        fill: tg.on ? 1 : 0
        color: tg.on ? Theme.brand : Theme.subtle
        font.pixelSize: tg.glyphPx
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tg.act()
    }
}
