import QtQuick
import "Singletons"

// A two-tap guard for a destructive action: the first tap arms it (the label
// turns to a warning that auto-disarms after a few seconds), the second fires.
// Matches Ryoku Settings' ConfirmButton.
Item {
    id: cb
    property string label: ""
    property string confirmLabel: "Confirm?"
    property string icon: "trash"
    property bool primary: false
    property bool armed: false
    signal confirmed()
    implicitWidth: inner.implicitWidth
    implicitHeight: inner.implicitHeight
    HubButton {
        id: inner
        label: cb.armed ? cb.confirmLabel : cb.label
        icon: cb.icon
        primary: cb.primary || cb.armed
        accent: cb.armed ? Theme.bad : Theme.ember
        enabled: cb.enabled
        onClicked: {
            if (cb.armed) { cb.armed = false; cb.confirmed(); }
            else { cb.armed = true; disarm.restart(); }
        }
    }
    Timer { id: disarm; interval: 3500; onTriggered: cb.armed = false }
}
