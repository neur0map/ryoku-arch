pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// PALETTE lane: the wallpaper's colours are derived globally by matugen (Hub ->
// Appearance -> Wallpaper), so ryowalls no longer tunes the scheme per image.
// What stays local is the sampled frame of a live wallpaper -- the second matugen
// reads its colours from -- plus a caption pointing at where the scheme is tuned.
Item {
    id: sheet

    readonly property bool videoMode: !!Wallhaven.selected && Wallhaven.selectedVideo

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollRail {}

        Column {
            id: col
            width: flick.width
            spacing: Tokens.s5

            Text {
                width: parent.width
                visible: !Wallhaven.selected
                wrapMode: Text.WordWrap
                text: "Pick a wallpaper to preview its palette."
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: 12
            }

            // ── SAMPLING: which second of a clip matugen reads (video picks) ───
            SheetSection {
                id: sampleSec
                width: parent.width
                title: "SAMPLING"
                visible: sheet.videoMode
                Cell {
                    width: sampleSec.span(12)
                    label: "Frame"
                    source: "ryowalls.json"
                    value: Wallhaven.settings.frame.toFixed(1) + "s"
                    def: "1.0s"
                    desc: "The second of the clip matugen samples for colour."
                    controlWidth: Spans.inlineWidth("slid", 0, width)
                    // the module Slid seats integers, so scrub in half-second steps.
                    Slid {
                        anchors.fill: parent
                        from: 0; to: 20
                        value: Math.round(Wallhaven.settings.frame * 2)
                        onModified: (v) => Wallhaven.retuneFrame(v / 2)
                    }
                }
            }

            // colours are global now: the scheme (tone, character, contrast) lives
            // in the Hub, not per image, so the sheet just says where to tune it.
            Text {
                width: parent.width
                visible: !!Wallhaven.selected
                wrapMode: Text.WordWrap
                text: "Colours follow Appearance → Wallpaper tuning."
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: 12
            }

            Item { width: 1; height: Tokens.s2 }
        }
    }
}
