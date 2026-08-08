import QtQuick
import Quickshell
import Ryoku.Ui as Ui

ShellRoot {

    property int activated: 0
    property int choice: 0
    property int amount: 2
    property bool switchValue: false

    Ui.Btn {
        id: action
        objectName: "action"
        text: qsTr("Action")
        onAct: activated += 1
    }
    Ui.Chips {
        id: chips
        objectName: "chips"
        y: 40
        options: [qsTr("One"), qsTr("Two")]
        current: qsTr("One")
        onChose: value => choice = value === qsTr("Two") ? 2 : 1
    }
    Ui.Seg {
        id: seg
        objectName: "seg"
        y: 80
        options: [qsTr("One"), qsTr("Two")]
        current: qsTr("One")
        onChose: value => choice = value === qsTr("Two") ? 2 : 1
    }
    Ui.Step {
        id: step
        objectName: "step"
        y: 120
        value: amount
        from: 1
        to: 3
        onModified: value => amount = value
    }
    Ui.Sw {
        id: toggle
        objectName: "toggle"
        y: 160
        on: switchValue
        onToggled: value => switchValue = value
    }

    function require(condition, label) {
        if (!condition) throw new Error("KEYBOARD-PROBE-FAIL " + label)
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            require(action.activeFocusOnTab, "button accepts Tab focus")
            require(action.activeFocusOnTab, "button exposes visible Tab focus")
            action.activate()
            require(activated === 1, "button activates")
            chips.activate(1)
            require(choice === 2, "chips select")
            seg.activate(1)
            require(choice === 2, "segments select")
            step.activate(true)
            require(amount === 3, "step changes")
            toggle.activate()
            require(switchValue, "switch toggles")
            console.log("KEYBOARD-PROBE-PASS controls")
            Qt.quit()
        }
    }
}
