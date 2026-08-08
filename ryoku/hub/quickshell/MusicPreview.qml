pragma ComponentBehavior: Bound
import QtQuick

/**
 * A plain-QML preview of the desktop music sheet for the Desktop Widgets
 * section, so the chosen style and the lyric toggle read at a glance without
 * playing a track. It mirrors the live sheet in
 * ryoku/shell/quickshell/shell/modules/desktop/music: the album's colour leads
 * (a fixed vibrant stand-in here, since there is no real track to sample), the
 * sung line lights in that accent, and the one filled tile is play. Static mock
 * copy, not an import of the live widget.
 */
Item {
    id: preview

    property string style: "cover"     // cover | glass
    property bool lyrics: true

    readonly property color accent: "#e2645a"
    readonly property color ink:    "#f3efe9"
    readonly property color dim:    "#a79f97"
    readonly property color plate:  preview.style === "glass" ? "#232029" : "#1d1712"
    readonly property real pad:      14
    readonly property real coverSize: 104

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: preview.plate
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        Rectangle {
            anchors.fill: parent
            radius: 16
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }
    }

    // sleeve
    Rectangle {
        id: cover
        x: preview.pad
        y: preview.pad
        width: preview.coverSize
        height: preview.coverSize
        radius: 9
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(preview.accent, 1.2) }
            GradientStop { position: 1.0; color: Qt.darker(preview.accent, 1.7) }
        }
        Text {
            anchors.centerIn: parent
            text: "\u266a"
            color: Qt.rgba(1, 1, 1, 0.85)
            font.family: "Space Grotesk"
            font.pixelSize: 30
        }
        Rectangle {
            anchors.fill: parent
            radius: 9
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.3)
        }
    }

    // lyric column
    Column {
        id: lyricCol
        x: cover.x + cover.width + 14
        y: preview.pad
        width: preview.width - x - preview.pad
        height: preview.coverSize
        spacing: 5
        visible: preview.lyrics
        clip: true

        property var rows: [
            { t: "I've been on my own", a: false },
            { t: "for long enough, maybe", a: false },
            { t: "You can turn me on", a: true },
            { t: "with just a touch, baby", a: false },
            { t: "I look around and", a: false }
        ]

        Repeater {
            model: lyricCol.rows
            delegate: Text {
                required property var modelData
                width: lyricCol.width
                elide: Text.ElideRight
                text: modelData.t
                color: modelData.a ? preview.accent : preview.ink
                opacity: modelData.a ? 1 : 0.45
                font.family: "Space Grotesk"
                font.pixelSize: modelData.a ? 15 : 13
                font.weight: modelData.a ? Font.DemiBold : Font.Medium
            }
        }
    }

    // album stand-in when lyrics are off
    Text {
        visible: !preview.lyrics
        x: cover.x + cover.width + 14
        width: preview.width - x - preview.pad
        y: preview.pad + preview.coverSize / 2 - implicitHeight / 2
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "After Hours"
        color: preview.dim
        font.family: "Space Grotesk"
        font.pixelSize: 14
    }

    // title + artist
    Column {
        id: meta
        x: preview.pad
        y: cover.y + cover.height + 10
        spacing: 1
        Text {
            text: "Blinding Lights"
            color: preview.ink
            font.family: "Fraunces"
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
        Text {
            text: "The Weeknd"
            color: preview.dim
            font.family: "Space Grotesk"
            font.pixelSize: 12
        }
    }

    // seek rail
    Rectangle {
        id: rail
        x: preview.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: preview.pad
        width: preview.width - moves.width - preview.pad * 2 - 14
        height: 2.4
        radius: height / 2
        color: Qt.rgba(preview.ink.r, preview.ink.g, preview.ink.b, 0.16)
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.42
            height: parent.height
            radius: height / 2
            color: preview.accent
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * 0.42 - width / 2
            width: 3
            height: 10
            radius: width / 2
            color: preview.accent
        }
    }

    // transport
    Row {
        id: moves
        anchors.right: parent.right
        anchors.rightMargin: preview.pad
        anchors.verticalCenter: rail.verticalCenter
        spacing: 6

        Repeater {
            model: 3
            delegate: Rectangle {
                required property int index
                readonly property bool mid: index === 1
                anchors.verticalCenter: parent.verticalCenter
                width: mid ? 26 : 20
                height: width
                radius: width / 2
                color: mid ? preview.accent : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.index === 0 ? "\u23ee" : parent.index === 1 ? "\u25b6" : "\u23ed"
                    color: parent.mid ? preview.plate : preview.ink
                    font.family: "Space Grotesk"
                    font.pixelSize: parent.mid ? 12 : 11
                }
            }
        }
    }
}
