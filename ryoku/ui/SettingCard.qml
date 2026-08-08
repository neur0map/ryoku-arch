import QtQuick
import "Singletons"

// A titled group of setting rows, drawn as one bordered sheet whose rows read
// top to bottom parted by hairlines -- the drawer the reference shells use to
// keep related controls together instead of scattering them across a bento
// grid. Collapsible: the header caret folds the group away so a long page
// discloses in sections. The card owns no control; SettingsSheet fills it with
// SettingRows.
Item {
    id: card

    property string title: ""
    property string kana: ""          // optional section seal, Latin + JP side by side
    property bool collapsible: true
    property bool expanded: true

    default property alias content: body.data

    readonly property int headerH: 46
    implicitHeight: headerH + bodyWrap.height
    height: implicitHeight

    // the sheet frame: flat, a hairline, no shadow -- the Hub is print.
    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.line
    }

    // header: the reference sheet's label vocabulary (a // lead, the tracked
    // title, its seal) plus the collapse caret on the right.
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: card.headerH

        Row {
            anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2
            Text {
                text: "//"
                color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: card.title + "_"
                color: Tokens.inkDim
                font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: card.kana !== ""
                text: card.kana
                color: Tokens.inkFaint
                font.family: Tokens.jp; font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            id: caret
            visible: card.collapsible
            anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            text: "\u25b8"
            color: hh.hovered ? Tokens.inkDim : Tokens.inkFaint
            font.family: Tokens.ui; font.pixelSize: 10
            rotation: card.expanded ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: Tokens.snap; easing.type: Tokens.easeSnap } }
            Behavior on color { ColorAnimation { duration: Tokens.snap } }
        }

        // the rule that closes the header, seen only while the group is open.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4
            height: 1
            color: Tokens.lineSoft
            opacity: card.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        }

        HoverHandler { id: hh; enabled: card.collapsible; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: card.collapsible; onTapped: card.expanded = !card.expanded }
    }

    // body: the rows, clipped so a collapsed group cannot be clicked and a
    // fold animates the height rather than snapping.
    Item {
        id: bodyWrap
        anchors { left: parent.left; right: parent.right; top: header.bottom }
        height: card.expanded ? body.implicitHeight : 0
        clip: true
        enabled: card.expanded
        opacity: card.expanded ? 1 : 0
        Behavior on height { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
        Behavior on opacity { NumberAnimation { duration: Tokens.flap; easing.type: Tokens.ease } }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 0
        }
    }
}
