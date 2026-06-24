pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The rail-job sheet for install and compress. It opens on a confirm step that
 * spells out what the job will do, runs the helper once confirmed, then shows the
 * helper's final line as the result until dismissed. The work lives in the helper
 * scripts behind the Stash singleton; this is its confirm-run-report face.
 */
Rectangle {
    id: root

    property real s: 1

    readonly property bool confirming: Stash.taskState === "confirm"
    readonly property bool running: Stash.taskState === "running"
    readonly property bool ok: Stash.taskState === "done"
    readonly property bool failed: Stash.taskState === "error"

    readonly property string verb: Stash.task === "install" ? "Install" : "Compress"
    readonly property string gerund: Stash.task === "install" ? "Installing" : "Compressing"
    readonly property string glyph: Stash.task === "install" ? "install" : "compress"

    readonly property string prompt: Stash.task === "install"
        ? ("Install " + Stash.count + (Stash.count === 1 ? " file" : " files") + "? AppImages and tarballs become launchable apps.")
        : ("Compress " + Stash.count + (Stash.count === 1 ? " file" : " files") + "? Smaller copies are written beside the originals.")

    radius: Motion.rTile * s
    color: Qt.alpha(Theme.cardTop, 0.98)
    visible: Stash.task !== "" && Stash.taskState !== "idle"

    MouseArea { anchors.fill: parent; hoverEnabled: true }

    SheetBack {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12 * root.s
        anchors.leftMargin: 14 * root.s
        s: root.s
        onBack: Stash.dismissTask()
    }

    // ── Confirm step ────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        width: parent.width - 40 * root.s
        spacing: 14 * root.s
        visible: root.confirming

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44 * root.s
            height: 44 * root.s
            radius: width / 2
            color: Qt.alpha(Theme.flameGlow, 0.14)
            border.width: 1
            border.color: Qt.alpha(Theme.flameGlow, 0.5)
            GlyphIcon {
                anchors.centerIn: parent
                width: 21 * root.s; height: 21 * root.s
                name: root.glyph
                color: Theme.flameGlow
                stroke: 1.7
            }
        }

        Text {
            width: parent.width
            text: root.prompt
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.25
            textFormat: Text.PlainText
        }


        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * root.s

            Rectangle {
                width: 84 * root.s
                height: 30 * root.s
                radius: Motion.rSmall * root.s
                color: cancelArea.containsMouse ? Theme.frameBg : "transparent"
                border.width: 1
                border.color: Theme.border
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: cancelArea.containsMouse ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.dismissTask()
                }
            }

            Rectangle {
                width: 110 * root.s
                height: 30 * root.s
                radius: Motion.rSmall * root.s
                color: runArea.containsMouse ? Theme.flameGlow : Qt.alpha(Theme.flameGlow, 0.18)
                border.width: 1
                border.color: Qt.alpha(Theme.flameGlow, 0.7)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6 * root.s
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12 * root.s; height: 12 * root.s
                        name: root.glyph
                        color: runArea.containsMouse ? Theme.cardBot : Theme.flameGlow
                        stroke: 1.7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.verb
                        color: runArea.containsMouse ? Theme.cardBot : Theme.flameCore
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: runArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Stash.confirmTask()
                }
            }
        }
    }

    // ── Running / result step ───────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        width: parent.width - 44 * root.s
        spacing: 12 * root.s
        visible: !root.confirming

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34 * root.s
            height: 34 * root.s

            // Orbiting dot while running.
            Item {
                anchors.fill: parent
                visible: root.running
                Rectangle {
                    width: 6 * root.s; height: 6 * root.s
                    radius: width / 2
                    color: Theme.flameGlow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                }
                RotationAnimation on rotation {
                    running: root.running
                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                }
            }

            // Result ring once finished.
            Rectangle {
                anchors.centerIn: parent
                visible: !root.running
                width: 30 * root.s; height: 30 * root.s
                radius: width / 2
                color: "transparent"
                border.width: 2 * root.s
                border.color: root.ok ? Theme.flameGlow : Theme.vermLit
                GlyphIcon {
                    anchors.centerIn: parent
                    width: 15 * root.s; height: 15 * root.s
                    name: root.ok ? "check" : "close"
                    color: root.ok ? Theme.flameGlow : Theme.vermLit
                    stroke: 2
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.running ? (root.gerund + "…")
                : root.ok ? (root.verb + " done")
                : (root.verb + " failed")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: !root.running && Stash.taskMsg.length > 0
            text: Stash.taskMsg
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.running
            width: 88 * root.s
            height: 28 * root.s
            radius: Motion.rSmall * root.s
            color: doneArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: doneArea.containsMouse ? Theme.frameBorder : Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "Done"
                color: doneArea.containsMouse ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: doneArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.dismissTask()
            }
        }
    }
}
