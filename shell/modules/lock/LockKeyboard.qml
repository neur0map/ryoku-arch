pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

// On-screen keyboard for lock screen password entry.
// Designed for touch and tablet users. Connects via signals -- the lock surface
// wires keyClicked/backspaceClicked/enterClicked to its TextInput.
// Exposes theme properties so both ii (Appearance) and waffle (Looks) can use it.
Rectangle {
    id: kbd
    height: 290
    radius: kbd.themeRounding
    color: kbd.themeBgColor
    border.color: ColorUtils.transparentize(kbd.themeTextColor, 0.88)
    border.width: 1

    signal keyClicked(string key)
    signal backspaceClicked()
    signal enterClicked()
    signal closeRequested()

    property bool showSymbols: false
    property bool isShifted: false

    // Theme properties — defaults are ii (Appearance). Override for waffle (Looks).
    property color themeBgColor: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.06)
    property color themeKeySurfaceColor: Appearance.colors.colLayer1
    property color themeTextColor: Appearance.colors.colOnSurface
    property color themeSubtextColor: Appearance.colors.colOnSurfaceVariant
    property color themeAccentColor: Appearance.colors.colPrimary
    property color themeAccentActiveColor: Appearance.colors.colPrimaryActive
    property color themeAccentTextColor: Appearance.colors.colOnPrimary
    property real themeRounding: Appearance.rounding.large
    property real themeKeyRounding: Appearance.rounding.small
    property int themeAnimDuration: Appearance.animation.elementMoveFast.duration
    property real themeFontSize: Appearance.font.pixelSize.normal
    property real themeFontSizeLarge: Appearance.font.pixelSize.large
    property real themeFontSizeSmall: Appearance.font.pixelSize.smaller
    property string themeFontFamily: Appearance.font.family.main

    component KeyButton: Rectangle {
        id: keyBtn
        property string label: ""
        property string shiftLabel: label.toUpperCase()
        property string symLabel: ""
        property real keyWidth: 1

        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.preferredWidth: keyWidth

        color: keyArea.pressed
            ? ColorUtils.transparentize(kbd.themeTextColor, 0.7)
            : ColorUtils.transparentize(kbd.themeKeySurfaceColor, 0.2)
        radius: kbd.themeKeyRounding

        Behavior on color {
            ColorAnimation { duration: kbd.themeAnimDuration }
        }

        Text {
            anchors.centerIn: parent
            text: kbd.showSymbols && keyBtn.symLabel ? keyBtn.symLabel
                : kbd.isShifted ? keyBtn.shiftLabel : keyBtn.label
            color: kbd.themeTextColor
            font.pixelSize: kbd.themeFontSize
            font.weight: Font.Medium
            font.family: kbd.themeFontFamily
        }

        MouseArea {
            id: keyArea
            anchors.fill: parent
            onClicked: {
                kbd.keyClicked(kbd.showSymbols && keyBtn.symLabel ? keyBtn.symLabel
                    : kbd.isShifted ? keyBtn.shiftLabel : keyBtn.label)
                if (kbd.isShifted) kbd.isShifted = false
            }
        }
    }

    component FuncButton: Rectangle {
        id: funcBtn
        property string icon: ""
        property string textLabel: ""
        property var action: null
        property bool active: false
        property bool isEnter: false
        property real keyWidth: isEnter ? 2.2 : 1.6

        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.preferredWidth: keyWidth

        color: (funcBtn.active || funcBtn.isEnter)
            ? (funcArea.pressed ? kbd.themeAccentActiveColor : kbd.themeAccentColor)
            : (funcArea.pressed
                ? ColorUtils.transparentize(kbd.themeTextColor, 0.7)
                : ColorUtils.transparentize(kbd.themeKeySurfaceColor, 0.3))
        radius: kbd.themeKeyRounding

        Behavior on color {
            ColorAnimation { duration: kbd.themeAnimDuration }
        }

        Text {
            anchors.centerIn: parent
            text: funcBtn.icon !== "" ? funcBtn.icon : funcBtn.textLabel
            color: (funcBtn.active || funcBtn.isEnter) ? kbd.themeAccentTextColor : kbd.themeTextColor
            font.pixelSize: funcBtn.isEnter ? kbd.themeFontSize : kbd.themeFontSizeLarge
            font.weight: Font.Medium
            font.family: kbd.themeFontFamily
        }

        MouseArea {
            id: funcArea
            anchors.fill: parent
            onClicked: if (funcBtn.action) funcBtn.action()
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 5

        // Header: label + close
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 0

            Text {
                text: Translation.tr("Virtual Keyboard")
                font.pixelSize: kbd.themeFontSizeSmall
                font.family: kbd.themeFontFamily
                color: kbd.themeSubtextColor
                Layout.fillWidth: true
                Layout.leftMargin: 4
            }

            Rectangle {
                width: 28; height: 28
                radius: kbd.themeKeyRounding
                color: closeHover.containsMouse
                    ? ColorUtils.transparentize(kbd.themeTextColor, 0.85)
                    : "transparent"

                Behavior on color {
                    ColorAnimation { duration: kbd.themeAnimDuration }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: closeHover.containsMouse
                        ? kbd.themeTextColor
                        : kbd.themeSubtextColor
                }

                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: kbd.closeRequested()
                }
            }
        }

        // Row 1: qwertyuiop
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            KeyButton { label: "q"; symLabel: "1" } KeyButton { label: "w"; symLabel: "2" }
            KeyButton { label: "e"; symLabel: "3" } KeyButton { label: "r"; symLabel: "4" }
            KeyButton { label: "t"; symLabel: "5" } KeyButton { label: "y"; symLabel: "6" }
            KeyButton { label: "u"; symLabel: "7" } KeyButton { label: "i"; symLabel: "8" }
            KeyButton { label: "o"; symLabel: "9" } KeyButton { label: "p"; symLabel: "0" }
        }

        // Row 2: asdfghjkl (inset)
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            Item { Layout.preferredWidth: 0.5; Layout.fillWidth: true }
            KeyButton { label: "a"; symLabel: "@" } KeyButton { label: "s"; symLabel: "#" }
            KeyButton { label: "d"; symLabel: "$" } KeyButton { label: "f"; symLabel: "%" }
            KeyButton { label: "g"; symLabel: "&" } KeyButton { label: "h"; symLabel: "-" }
            KeyButton { label: "j"; symLabel: "+" } KeyButton { label: "k"; symLabel: "(" }
            KeyButton { label: "l"; symLabel: ")" }
            Item { Layout.preferredWidth: 0.5; Layout.fillWidth: true }
        }

        // Row 3: shift + zxcvbnm + backspace
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            FuncButton { icon: "\u21E7"; active: kbd.isShifted; action: function() { kbd.isShifted = !kbd.isShifted } }
            KeyButton { label: "z"; symLabel: "*" }  KeyButton { label: "x"; symLabel: "\"" }
            KeyButton { label: "c"; symLabel: "'" }  KeyButton { label: "v"; symLabel: ":" }
            KeyButton { label: "b"; symLabel: ";" }  KeyButton { label: "n"; symLabel: "!" }
            KeyButton { label: "m"; symLabel: "?" }
            FuncButton { icon: "\u232B"; action: function() { kbd.backspaceClicked() } }
        }

        // Row 4: ?123 / space / enter
        RowLayout { spacing: 4; Layout.fillWidth: true; Layout.fillHeight: true
            FuncButton { textLabel: "?123"; active: kbd.showSymbols; action: function() { kbd.showSymbols = !kbd.showSymbols } }
            KeyButton { label: ","; symLabel: ","; keyWidth: 1 }
            KeyButton { label: " "; symLabel: " "; keyWidth: 4.5 }
            KeyButton { label: "."; symLabel: "."; keyWidth: 1 }
            FuncButton { icon: "\u23CE"; isEnter: true; action: function() { kbd.enterClicked() } }
        }
    }
}
