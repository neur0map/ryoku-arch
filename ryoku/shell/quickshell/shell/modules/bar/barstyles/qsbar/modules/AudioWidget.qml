import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    AudioData { id: audio; poll: true }
    readonly property int    volume:   audio.volume
    readonly property bool   muted:    audio.muted
    readonly property string compactVolumeIcon: "graphic_eq"

    readonly property string tooltipText: muted
        ? "Muted · " + volume + "%"
        : "Audio " + volume + "%"

    visible: implicitWidth > 0.5
    implicitWidth: root.modVolume ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modVolume ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.compactVolume ? 4 : 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactVolume
            text: "VOL"
            color: rootMod.muted
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }

        // ── workspace-capsule style slider ──
        Item {
            id: slider
            visible: !root.compactVolume
            width: 34
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            readonly property real ratio: rootMod.muted ? 0 : Math.min(rootMod.volume / 100, 1)

            // track capsule
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
            }

            // fill capsule — seal pill like the active workspace
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(slider.ratio > 0 ? 8 : 0, parent.width * slider.ratio)
                height: 8
                radius: 4
                color: root.seal
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactVolume
            text: String(rootMod.volume).padStart(2, '0') + "%"
            color: rootMod.muted
                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                : root.seal
            font.family: root.mono
            font.pixelSize: 12
        }

        IconText {
            id: compactVolumeGlyph
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactVolume
            text: rootMod.compactVolumeIcon
            color: rootMod.muted ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35) : root.seal
            font.pixelSize: 15
            font.weight: Font.Medium
            fill: 1
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactVolume
            text: String(rootMod.volume).padStart(2, '0') + "%"
            color: rootMod.muted
                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                : root.seal
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 160 } }
        }

    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    // Native PipeWire control through the tracked default sink (AudioData binds
    // it): setting volume/mute writes straight to the node, so the bar readout and
    // the hardware never disagree. No wpctl/pactl/pamixer shell-out.
    function stepVolume(up) {
        var s = audio.sink
        if (!s || !s.audio) return
        s.audio.volume = Math.max(0, Math.min(1, s.audio.volume + (up ? 0.05 : -0.05)))
    }
    function toggleMute() {
        var s = audio.sink
        if (s && s.audio) s.audio.muted = !s.audio.muted
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: { tip.hide() }
        onWheel: (e) => rootMod.stepVolume(e.angleDelta.y > 0)
        onClicked: (e) => {
            tip.hide()
            if (e.button === Qt.RightButton) rootMod.toggleMute()
            else                             root.volVisible = !root.volVisible
        }
    }
}
