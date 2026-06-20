import QtQuick
import "Singletons"

// The navigation rail: brand header, a global search field (it searches content
// across every section, not just the open one), the section list with a single
// sliding selection indicator, and a footer mark.
Rectangle {
    id: rail

    property string current: "keybinds"
    property alias query: search.text
    signal navigate(string section)
    signal escaped()

    function focusSearch() { search.focusInput(); }

    readonly property int navTop: 96 + 54 + 26
    readonly property int navItemH: 44
    function indexOf(s) { return s === "shell" ? 0 : (s === "keybinds" ? 1 : (s === "updates" ? 2 : 3)); }

    color: Theme.rail

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.line
    }

    // Sliding selection indicator (dimmed while a search is active, since the
    // content then shows results rather than the highlighted section).
    Rectangle {
        id: selector
        x: 12
        width: rail.width - 24
        height: 42
        radius: 11
        y: rail.navTop + rail.indexOf(rail.current) * rail.navItemH + (rail.navItemH - height) / 2
        color: Theme.keyTop
        border.width: 1
        border.color: Theme.line
        opacity: rail.query.length > 0 ? 0.4 : 1
        Behavior on y { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }

        // Lifted keycap feel: a faint top sheen and a darker bottom lip, so the
        // active section reads as a pressed key rather than a templated accent bar.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: parent.height * 0.5
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 3
            radius: 3
            color: Theme.keyBot
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        Item {
            width: parent.width
            height: 96

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.ember }
                        GradientStop { position: 1.0; color: Theme.emberDeep }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\u529b"
                        color: Theme.onAccent
                        font.family: Theme.fontJp
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Ryoku Hub"
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.2
                    }

                    Text {
                        text: "Control center"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 54

            SearchField {
                id: search
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                placeholder: "Search everything\u2026"
                onEscaped: rail.escaped()
            }
        }

        Item {
            width: parent.width
            height: 26

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                text: "SECTIONS"
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }
        }

        NavButton {
            width: parent.width
            icon: "gear"
            label: "Shell Settings"
            soon: true
            selected: rail.current === "shell"
            onClicked: rail.navigate("shell")
        }

        NavButton {
            width: parent.width
            icon: "keyboard"
            label: "Keybinds"
            selected: rail.current === "keybinds"
            onClicked: rail.navigate("keybinds")
        }

        NavButton {
            width: parent.width
            icon: "download"
            label: "Updates"
            badge: Updates.available ? Updates.behind : 0
            selected: rail.current === "updates"
            onClicked: rail.navigate("updates")
        }

        NavButton {
            width: parent.width
            icon: "sparkles"
            label: "Extras"
            soon: true
            selected: rail.current === "extras"
            onClicked: rail.navigate("extras")
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 26
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        text: "\u529b  ryoku desktop"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
