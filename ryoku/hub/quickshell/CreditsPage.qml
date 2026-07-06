pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "Singletons"

// Credits = a showcase "thank you" screen, Profile's twin in build and mood.
// kansha (感謝, gratitude) meets the Three Graces of Greek myth: the marble trio
// dissolves off the right the way Lady Justice anchors the Profile. Left column
// carries the bilingual title, the projects Ryoku stands on as editorial type
// lines (never boxed cards), and a special band for the alpha/beta testers who
// keep finding the bugs. Rows with a known home open it (xdg-open); name-only
// credits stay quiet. Carbon vocabulary throughout: hairlines, mono labels, the
// one vermillion accent used as a dot, never a wash.
Item {
    id: page

    // people + projects Ryoku is built on. `url` empty => a quiet, unlinked
    // credit (no home was given, and we don't invent one).
    readonly property var projects: [
        { "name": "qylock",       "by": "Darkkal44",      "role": "lockscreen",          "url": "https://github.com/Darkkal44/qylock" },
        { "name": "caelestia",    "by": "caelestia-dots", "role": "Quickshell craft",     "url": "https://github.com/caelestia-dots/shell" },
        { "name": "rishot",       "by": "Gakuseei",       "role": "screenshot flow",      "url": "https://github.com/Gakuseei/rishot" },
        { "name": "cava-bg",      "by": "leriart",        "role": "audio-reactive walls", "url": "https://github.com/leriart/cava-bg" },
        { "name": "Brain_Shell",  "by": "Brainitech",     "role": "shell craft",          "url": "https://github.com/Brainitech/Brain_Shell" },
        { "name": "ActivSpot",    "by": "Devvvmn",        "role": "window spotlight",     "url": "https://github.com/Devvvmn/ActivSpot" },
        { "name": "hyprmod",      "by": "BlueManCZ",      "role": "Hyprland tooling",     "url": "https://github.com/BlueManCZ/hyprmod" },
        { "name": "dotfiles",     "by": "matteogini",     "role": "dotfile craft",        "url": "https://github.com/matteogini/dotfiles" },
        { "name": "inir",         "by": "snowarch",       "role": "launcher grid",        "url": "" },
        { "name": "noctalia",     "by": "noctalia-dev",   "role": "shell polish",         "url": "https://github.com/noctalia-dev/noctalia-shell" },
        { "name": "DankMaterial", "by": "AvengeMedia",    "role": "material shell",       "url": "https://github.com/AvengeMedia/DankMaterialShell" },
        { "name": "Omarchy",      "by": "DHH",            "role": "opinionated Arch",     "url": "" },
        { "name": "CachyOS",      "by": "CachyOS team",   "role": "performance Arch",     "url": "" }
    ]

    // the alpha/beta crew, constantly stress-testing and filing bugs.
    readonly property var testers: [
        { "name": "bhimio1",      "url": "https://github.com/bhimio1" },
        { "name": "povargg",      "url": "https://github.com/povargg" },
        { "name": "godspeed1709", "url": "https://github.com/godspeed1709" },
        { "name": "VortexVirus",  "url": "https://github.com/VortexVirus" },
        { "name": "Lowingx",      "url": "https://github.com/Lowingx" }
    ]

    function openUrl(u) {
        if (!u || u.length === 0)
            return;
        opener.command = ["xdg-open", u];
        opener.running = true;
    }

    Process { id: opener }

    ShowcaseBackdrop { anchors.fill: parent }

    readonly property real leftW: Math.min(page.width * 0.60, page.width - 430)

    // --- Three Graces, dissolving off the right (the Profile justice motif). the
    // left dissolve is baked into the asset's alpha (a horizontal ramp), so the
    // marble melts into the canvas with no fade rectangle and no hard seam.
    Image {
        id: graces
        source: "art/three-graces.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        opacity: 0.5
        height: parent.height
        width: height
        anchors.right: parent.right
        anchors.rightMargin: -parent.width * 0.02
        anchors.verticalCenter: parent.verticalCenter
        layer.enabled: true
        layer.effect: MultiEffect {
            brightness: -0.14
            saturation: -0.32
        }
    }

    // --- left column: title + credits ------------------------------------
    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.topMargin: 6
        anchors.bottomMargin: 12
        width: page.leftW
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: col
            width: flick.width
            spacing: 26

            // hero: kicker, bilingual 感謝 / Gratitude, a line of thanks.
            Column {
                width: parent.width
                spacing: 12

                Eyebrow { text: "Kansha \u00b7 Gratitude" }

                Row {
                    spacing: 16
                    Text {
                        text: "\u611f\u8b1d"                 // 感謝
                        color: Theme.bright
                        font.family: Theme.fontJp
                        font.pixelSize: 56
                        font.weight: Font.Black
                        anchors.bottom: parent.bottom
                    }
                    Text {
                        text: "Gratitude"
                        color: Theme.sun
                        font.family: Theme.display
                        font.pixelSize: 40
                        font.weight: Font.Medium
                        font.italic: true
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                    }
                }

                Text {
                    width: Math.min(parent.width, 500)
                    text: "Ryoku stands on the work of others. These projects, communities, and "
                        + "people lent code, ideas, and a sharp eye. Like the Three Graces who give, "
                        + "receive, and return, we pass the thanks on."
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 13
                    lineHeight: 1.4
                    wrapMode: Text.WordWrap
                }
            }

            // --- projects: editorial type lines in two columns ----------
            Column {
                width: parent.width
                spacing: 14
                SectionHead { text: "Standing on the shoulders" }

                Grid {
                    id: projGrid
                    width: parent.width
                    columns: 2
                    columnSpacing: 34
                    rowSpacing: 0
                    readonly property real cellW: (width - columnSpacing) / 2

                    Repeater {
                        model: page.projects
                        delegate: CreditLine {
                            required property var modelData
                            width: projGrid.cellW
                            name: modelData.name
                            by: modelData.by
                            role: modelData.role
                            url: modelData.url
                        }
                    }
                }
            }

            // --- testers: their own quiet band --------------------------
            Column {
                width: parent.width
                spacing: 14
                SectionHead { text: "Alpha \u00b7 Beta \u2014 the bug hunters" }

                Flow {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: page.testers
                        delegate: TesterChip {
                            required property var modelData
                            handle: modelData.name
                            url: modelData.url
                        }
                    }
                }
            }

            // footer seal
            Row {
                spacing: 8
                Text {
                    text: "\u529b"
                    color: Theme.sun
                    font.family: Theme.fontJp
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    opacity: 0.9
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Built in the open, with kansha."
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item { width: 1; height: 2 }
        }
    }

    // ===== inline components ============================================

    // section kicker: brand dot + mono label, then a hairline. the hub idiom.
    component SectionHead: Column {
        id: sh
        property string text: ""
        width: parent ? parent.width : 0
        spacing: 10
        Row {
            spacing: 8
            Rectangle {
                width: 5
                height: 5
                radius: Theme.radius
                color: Theme.brand
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: sh.text
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 2.4
                font.capitalization: Font.AllUppercase
            }
        }
        Rectangle { width: parent.width; height: 1; color: Theme.line }
    }

    // one credit = an editorial type line: name, then role · author in mono,
    // a hairline under it. no box, no colored bar. an arrow marks a live link;
    // hover only brightens (linked rows show a pointer).
    component CreditLine: Item {
        id: cl
        property string name: ""
        property string by: ""
        property string role: ""
        property string url: ""
        readonly property bool linked: cl.url.length > 0

        height: 52

        HoverHandler { id: hov; enabled: cl.linked; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: cl.linked; onTapped: page.openUrl(cl.url) }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Item {
                width: parent.width
                height: nameT.implicitHeight
                Text {
                    id: nameT
                    anchors.left: parent.left
                    text: cl.name
                    color: hov.hovered ? Theme.bright : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: nameT.verticalCenter
                    visible: cl.linked
                    text: "\u2197"
                    color: hov.hovered ? Theme.ember : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
            }
            Text {
                width: parent.width
                text: cl.role.toUpperCase() + "  \u00b7  " + cl.by
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1.2
                elide: Text.ElideRight
            }
        }

        // baseline hairline, brightening under a hovered link.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: hov.hovered ? Theme.line : Theme.lineSoft
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
    }

    // one tester: a monogram in a hairline ring + handle + role. special by its
    // own section and the ringed initial, not by any colour wash.
    component TesterChip: Item {
        id: tc
        property string handle: ""
        property string url: ""
        width: chipRow.width + 26
        height: 50

        HoverHandler { id: thov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: page.openUrl(tc.url) }

        Rectangle {
            anchors.fill: parent
            color: thov.hovered ? Theme.surfaceLo : "transparent"
            border.width: 1
            border.color: thov.hovered ? Theme.lineStrong : Theme.line
            Behavior on color { ColorAnimation { duration: Theme.quick } }
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        }

        Row {
            id: chipRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            spacing: 11

            Rectangle {
                width: 30
                height: 30
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.width: 1.5
                border.color: thov.hovered ? Theme.ember : Theme.brand
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                Text {
                    anchors.centerIn: parent
                    text: tc.handle.length > 0 ? tc.handle.charAt(0).toUpperCase() : "?"
                    color: thov.hovered ? Theme.bright : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Black
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: tc.handle
                    color: thov.hovered ? Theme.bright : Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "BUG HUNTER"
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1.4
                }
            }
        }
    }
}
