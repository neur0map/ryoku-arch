import Quickshell
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import "../colors" as ColorsModule

Rectangle {
    id: root
    width: parent.width
    color: "transparent"
    clip: true
    property bool opened: false
    height: opened ? parent.height / 2 : 0

    Behavior on height {
        NumberAnimation {
            duration: 1000
            easing.type: Easing.OutCubic
        }
    }

    Repeater {
        model: {
            const min = 20
            const max = 50
            return Math.floor(Math.random() * (max - min + 1)) + min
        }

        Rectangle {
            id: shingle

            // Base X position stored once at creation
            property real baseX: {
                const min = 20
                const max = root.width - 10
                return Math.floor(Math.random() * (max - min)) + min
            }

            // Base height ratio stored at creation time
            property real baseHeightRatio: {
                const min = 70
                const max = root.parent.height / 2 - 40
                const range = max - min
                return (Math.floor(Math.random() * (range - 1)) + 1) / (root.parent.height / 2)
            }

            // Per-shingle random wave characteristics
            property real vAmplitude: Math.random() * 0.07 + 0.03   // vertical (ratio)
            property real hAmplitude: Math.random() * 6 + 2          // horizontal (px)
            property real vOffset: 0.0
            property real hOffset: 0.0

            height: (baseHeightRatio + vOffset) * root.height
            width: 3
            x: baseX + hOffset
            color: ColorsModule.Colors.surface_container
            bottomLeftRadius: width / 2
            bottomRightRadius: width / 2

            // ── Continuous vertical wave ──────────────────────────────────
            SequentialAnimation on vOffset {
                id: vWave
                loops: Animation.Infinite
                running: false
                PauseAnimation { duration: Math.random() * 900 }
                NumberAnimation {
                    from: 0; to: shingle.vAmplitude
                    duration: 550 + Math.random() * 550
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: shingle.vAmplitude; to: -shingle.vAmplitude * 0.45
                    duration: 480 + Math.random() * 480
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: -shingle.vAmplitude * 0.45; to: 0
                    duration: 380 + Math.random() * 380
                    easing.type: Easing.InOutSine
                }
            }

            // ── Continuous horizontal sway ────────────────────────────────
            SequentialAnimation on hOffset {
                id: hWave
                loops: Animation.Infinite
                running: false
                PauseAnimation { duration: Math.random() * 700 }
                NumberAnimation {
                    from: 0; to: shingle.hAmplitude
                    duration: 700 + Math.random() * 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: shingle.hAmplitude; to: -shingle.hAmplitude
                    duration: 900 + Math.random() * 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: -shingle.hAmplitude; to: 0
                    duration: 600 + Math.random() * 400
                    easing.type: Easing.InOutSine
                }
            }

            // ── One-shot drop ripple on open (vertical bounce + horizontal burst) ──
            SequentialAnimation {
                id: dropRipple
                PauseAnimation { duration: Math.random() * 450 }
                ParallelAnimation {
                    NumberAnimation {
                        target: shingle; property: "vOffset"
                        from: shingle.vAmplitude * 1.8; to: 0
                        duration: 750 + Math.random() * 400
                        easing.type: Easing.OutBounce
                    }
                    NumberAnimation {
                        target: shingle; property: "hOffset"
                        from: shingle.hAmplitude * (Math.random() > 0.5 ? 1.5 : -1.5)
                        to: 0
                        duration: 800 + Math.random() * 400
                        easing.type: Easing.OutElastic
                    }
                }
                ScriptAction {
                    script: {
                        vWave.start()
                        hWave.start()
                    }
                }
            }

            Connections {
                target: root
                function onOpenedChanged() {
                    if (root.opened) {
                        dropRipple.start()
                    } else {
                        vWave.stop()
                        hWave.stop()
                        dropRipple.stop()
                        shingle.vOffset = 0
                        shingle.hOffset = 0
                    }
                }
            }

            Text {
                text: {
                    const options = ["󰽧", ""]
                    return options[Math.floor(Math.random() * options.length)]
                }
                font.family: "Symbols Nerd Font"
                color: ColorsModule.Colors.primary
                font.pointSize: text === "󰽧" ? 28 : 25
                rotation: text === "󰽧" ? 45 : 0
                anchors.horizontalCenterOffset: text === "󰽧" ? -5.6 : 0
                anchors.top: parent.bottom
                anchors.topMargin: text === "󰽧" ? -5 : -3
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
