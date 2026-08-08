import QtQuick
import Ryoku.Ui.Singletons

// An eki-stamp hanko for a machine: a vermillion ink seal, OS name set around
// the ring, the mark's initial at the center, station-stamp style. The one
// legitimately round object on the board, and (amendment 3) ryovm's one rationed
// splash of colour: at most one per screen, on the stage, only when it certifies
// (a sealed machine, the thud of a new one). It is print, not chrome. `thud()`
// plays the stamp landing.
Item {
    id: seal

    property string title: ""          // text around the ring (OS or VM name)
    property string glyph: ""          // center character; falls back to title's initial
    property string date: ""           // optional micro date line under the glyph
    property real size: 84
    property color ink: Tokens.sun
    property real inkOpacity: 0.92

    width: size
    height: size

    readonly property string _ringText: {
        var t = (seal.title || "").toUpperCase().trim();
        if (t.length === 0)
            return "";
        // pad short names so the ring never looks empty: "ALPINE · ALPINE ·"
        while (t.length < 10)
            t = t + " · " + (seal.title || "").toUpperCase().trim();
        return t + " · ";
    }
    readonly property string _center: seal.glyph.length > 0 ? seal.glyph
        : (seal.title.length > 0 ? seal.title.charAt(0).toUpperCase() : "?")

    function thud() { thudAnim.restart(); }

    rotation: -4
    opacity: seal.inkOpacity

    // outer ring, inner ring: stamped borders.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, seal.size * 0.032)
        border.color: seal.ink
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: seal.size * 0.16
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(seal.ink, 0.75)
    }

    // ring text: one character at a time, rotated around the center.
    Repeater {
        model: seal._ringText.length
        delegate: Item {
            required property int index
            anchors.fill: parent
            rotation: (360 / seal._ringText.length) * index
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: seal.size * 0.035
                text: seal._ringText.charAt(index)
                color: seal.ink
                font.family: Tokens.ui
                font.pixelSize: Math.max(7, seal.size * 0.10)
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }
        }
    }

    // center mark + micro date.
    Column {
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: seal._center
            color: seal.ink
            font.family: Tokens.display
            font.pixelSize: seal.size * 0.34
            font.weight: Font.Bold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: seal.date.length > 0
            text: seal.date
            color: seal.ink
            font.family: Tokens.mono
            font.pixelSize: Math.max(6, seal.size * 0.08)
            font.letterSpacing: 0.5
        }
    }

    // the stamp landing: scale-thud with a random tilt, fast and physical.
    SequentialAnimation {
        id: thudAnim
        ScriptAction { script: seal.rotation = -4 + (Math.random() * 6 - 3) }
        ParallelAnimation {
            NumberAnimation { target: seal; property: "scale"; from: 1.4; to: 1.0; duration: 80; easing.type: Easing.InQuad }
            NumberAnimation { target: seal; property: "opacity"; from: 0.2; to: seal.inkOpacity; duration: 80 }
        }
    }
}
