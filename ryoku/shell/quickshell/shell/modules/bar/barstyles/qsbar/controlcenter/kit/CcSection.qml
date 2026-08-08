import QtQuick
import "../../modules"

// A titled group inside a route editor: a mono uppercase eyebrow over a column
// of rows. `default` children flow into the body. Reads colours from `root`.
Column {
    id: sec
    property var root
    property string title: ""
    default property alias body: bodyCol.data

    spacing: 8

    UiText {
        visible: sec.title !== ""
        text: sec.title
        color: sec.root.sumiHi
        font.family: sec.root.mono
        font.pixelSize: 10
        font.letterSpacing: 1
    }

    Column {
        id: bodyCol
        width: sec.width
        spacing: 8
    }
}
