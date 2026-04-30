import QtQuick
import "../../"

// Ryoku Patch 8: Arch logo replaced with Ryoku monogram (kanji 力).
// Rendered as a QML Text element with Noto Sans CJK JP rather than
// loaded from logo-mark.svg, because that SVG's text baseline is too
// high in its viewBox and the top horizontal stroke of 力 gets clipped.
// QML Text positions the kanji properly inside the button bounds.
// Ryoku's left topbar control opens the compact system menu. The full
// upstream ArchMenu remains vendored but dormant.
Rectangle {
    id: root
    width:  24
    height: 24
    radius: 4
    color:  hover.hovered ? Theme.active : "transparent"

    Text {
        anchors.centerIn: parent
        text:        "力"   // U+529B kanji 力 (chikara/ryoku, "power")
        color:       "#F25623"  // Ryoku Greek-Noir accent orange
        font.family: "Noto Sans CJK JP"
        font.weight: Font.Black
        font.pixelSize: 14
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            var next = !Popups.systemMenuOpen
            Popups.closeAll()
            Popups.systemMenuOpen = next
        }
    }
}
