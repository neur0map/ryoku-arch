import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The Themes category's provider strip: an All plate, one plate per colour-scheme
// provider, and a My themes plate (the installed library), plus an Install all
// action for the focused provider. It sits between the app bar and the grid when
// the Themes category is browsed, reusing the header's bone-invert Tabs idiom.
Item {
    id: tabs

    property var providers: []        // provider names, already sorted
    property string active: ""        // "" = All, "__mine__" = My themes, else a provider
    property int installableCount: 0  // uninstalled items in the focused provider
    property bool busy: false

    signal picked(string filter)
    signal installAll()

    implicitHeight: 44

    component Plate: Rectangle {
        id: plate
        property string label: ""
        property bool on: false
        signal chose()
        width: plateText.implicitWidth + Tokens.s4
        height: 30
        radius: Tokens.radius
        color: plate.on ? Tokens.bone : (ph.hovered ? Tokens.tint5 : "transparent")
        border.width: Tokens.border
        border.color: plate.on ? Tokens.bone : Tokens.line
        activeFocusOnTab: true
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        Accessible.role: Accessible.Button
        Accessible.name: plate.label
        Accessible.onPressAction: plate.chose()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                plate.chose();
                event.accepted = true;
            }
        }
        Text {
            id: plateText
            anchors.centerIn: parent
            text: plate.label
            color: plate.on ? Tokens.inkOnBone : (plate.activeFocus ? Tokens.ink : Tokens.inkDim)
            font.family: Tokens.ui
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: Tokens.trackLabel
            Behavior on color { ColorAnimation { duration: Tokens.snap } }
        }
        HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: plate.chose() }
    }

    Flickable {
        id: strip
        anchors {
            left: parent.left; leftMargin: Tokens.s6
            right: installAllBtn.left; rightMargin: Tokens.s4
            verticalCenter: parent.verticalCenter
        }
        height: 30
        contentWidth: plateRow.width
        contentHeight: height
        clip: true
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: plateRow
            height: parent.height
            spacing: Tokens.s2

            Plate {
                objectName: "ryostore-provider-all"
                label: "ALL"
                on: tabs.active === ""
                onChose: tabs.picked("")
            }
            Repeater {
                model: tabs.providers
                delegate: Plate {
                    required property var modelData
                    label: String(modelData).toUpperCase()
                    on: tabs.active === modelData
                    onChose: tabs.picked(String(modelData))
                }
            }
            Plate {
                objectName: "ryostore-provider-mine"
                label: "MY THEMES"
                on: tabs.active === "__mine__"
                onChose: tabs.picked("__mine__")
            }
        }
    }

    Btn {
        id: installAllBtn
        objectName: "ryostore-provider-install-all"
        anchors { right: parent.right; rightMargin: Tokens.s6; verticalCenter: parent.verticalCenter }
        visible: tabs.active !== "" && tabs.active !== "__mine__" && tabs.installableCount > 0
        text: tabs.busy ? "INSTALLING" : ("INSTALL ALL / " + tabs.installableCount)
        armed: !tabs.busy
        onAct: tabs.installAll()
        Accessible.role: Accessible.Button
        Accessible.name: installAllBtn.text
        Accessible.onPressAction: tabs.installAll()
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Tokens.border
        color: Tokens.line
    }
}
