import QtQuick
import "Singletons"

// The per-item action panel (Ctrl+K): a small list of the selected result's verbs
// over the bottom of the card, itself keyboard-navigable. The first action is the
// one Enter runs in the main list; this panel exposes the rest (and lets the user
// pick any). Opens with a short ease, the one place in the launcher motion budget
// spends time.
Item {
    id: root

    property real s: 1
    property var actions: []
    property bool open: false
    property int selectedIndex: 0

    signal chosen()

    visible: open || fade.running
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { id: fade; duration: Motion.panel; easing.type: Easing.OutCubic } }

    function move(delta) {
        if (root.actions.length === 0)
            return;
        root.selectedIndex = Math.max(0, Math.min(root.actions.length - 1, root.selectedIndex + delta));
    }

    function run() {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.actions.length) {
            var a = root.actions[root.selectedIndex];
            if (a && a.execute)
                a.execute();
        }
        root.chosen();
    }

    onOpenChanged: if (open) selectedIndex = 0;

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusRow * root.s
        color: Theme.cardBot
        border.width: 1
        border.color: Theme.frameBorder
        // the panel's height is capped at 5 rows by the launcher; without a
        // clip a 6th+ action would paint over the card below the panel.
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 6 * root.s
            spacing: 1 * root.s

            Text {
                text: "Actions"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Metrics.fontEyebrow * root.s
                leftPadding: 8 * root.s
                bottomPadding: 2 * root.s
            }

            Repeater {
                model: root.actions.length
                delegate: Rectangle {
                    required property int index
                    width: parent.width
                    height: 30 * root.s
                    radius: Metrics.radiusTag * root.s
                    readonly property bool sel: index === root.selectedIndex
                    color: sel ? Theme.frameBg : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10 * root.s
                        text: root.actions[index] ? root.actions[index].name : ""
                        color: parent.sel ? Theme.bright : Theme.cream
                        font.family: Theme.font
                        font.pixelSize: Metrics.fontSubtitle * root.s
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: { root.selectedIndex = index; root.run(); }
                    }
                }
            }
        }
    }
}
