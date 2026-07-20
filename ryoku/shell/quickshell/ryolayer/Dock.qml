pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The board's control strip: the widget vocabulary as chips (click adds or
// removes the tool on this screen) and the backdrop blur slider, live.
Rectangle {
    id: dock

    property string screenName: ""

    implicitWidth: row.implicitWidth + Tokens.s5 * 2
    implicitHeight: Tokens.rowH
    color: Tokens.paper
    radius: Tokens.radius
    border { width: Tokens.border; color: Tokens.line }

    Grain { anchors.fill: parent; opacity: Tokens.grainOpacity }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.s3

        Repeater {
            model: Catalog.widgets
            delegate: Rectangle {
                id: chip
                required property var modelData
                // Config.rev keys the re-evaluation: entry() is a plain call.
                readonly property bool present: (Config.rev, Config.entry(modelData.id, dock.screenName) !== null)
                width: chipRow.implicitWidth + Tokens.s3 * 2
                height: Tokens.ctlH
                radius: Tokens.radius
                color: present ? Tokens.bone : (chipHover.hovered ? Tokens.tint10 : "transparent")
                border { width: Tokens.border; color: present ? Tokens.bone : Tokens.line }
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Tokens.s1
                    Text {
                        text: chip.modelData.kanji
                        color: chip.present ? Tokens.inkOnBone : Tokens.inkDim
                        font { family: Tokens.jp; pixelSize: Tokens.fMicro }
                    }
                    Text {
                        text: chip.modelData.title
                        color: chip.present ? Tokens.inkOnBone : Tokens.inkDim
                        font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
                    }
                }
                HoverHandler { id: chipHover }
                TapHandler {
                    onTapped: chip.present
                        ? Config.remove(chip.modelData.id, dock.screenName)
                        : Config.place(chip.modelData.id, dock.screenName)
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }

        Rectangle { width: Tokens.border; height: Tokens.ctlH; color: Tokens.lineSoft }

        Row {
            spacing: Tokens.s2
            Text {
                text: "BLUR"
                height: Tokens.ctlH
                verticalAlignment: Text.AlignVCenter
                color: Tokens.inkFaint
                font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
            }
            Slid {
                width: 120
                height: Tokens.ctlH
                from: 0; to: 64
                value: Config.bgBlur
                // live retune ramps through shell.qml's serialized blur writer;
                // persist once the drag settles, not once per frame.
                onModified: (v) => { Config.bgBlur = Math.round(v); blurSave.restart(); }
            }
            Text {
                text: Config.bgBlur > 0 ? Config.bgBlur + "px" : "OFF"
                height: Tokens.ctlH
                verticalAlignment: Text.AlignVCenter
                color: Tokens.inkMuted
                font { family: Tokens.mono; pixelSize: Tokens.fTiny }
            }
        }
    }

    Timer { id: blurSave; interval: Motion.settle; onTriggered: Config.save() }
}
