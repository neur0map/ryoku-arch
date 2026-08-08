pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services

// Power profiles entry (contract 06 sec 2.9): a RevealerRow whose inert action
// button carries the active-profile icon and whose label reads
// "Power Profile: <name>"; the reveal opens the service-ordered profile list,
// each row activating a profile and marking the active one with a check. State
// comes from the PowerProfiles singleton (no client sort).
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitHeight: row.implicitHeight

    onOpenChanged: PowerProfiles.setActive(root, root.open)
    Component.onCompleted: PowerProfiles.setActive(root, root.open)
    Component.onDestruction: PowerProfiles.setActive(root, false)

    function labelFor(name) {
        switch (name) {
        case "power-saver": return qsTr("Power Saver");
        case "balanced": return qsTr("Balanced");
        case "performance": return qsTr("Performance");
        }
        return name;
    }
    function iconFor(name) {
        switch (name) {
        case "power-saver": return "eco";
        case "performance": return "bolt";
        }
        return "balance";
    }

    RevealerRow {
        id: row
        width: root.width
        actionIconName: root.iconFor(PowerProfiles.profile)
        actionSensitive: false

        middle: RevealerRowLabel {
            anchors.fill: parent
            label: PowerProfiles.profile.length > 0
                ? qsTr("Power Profile: %1").arg(root.labelFor(PowerProfiles.profile))
                : qsTr("Power Profile")
        }

        Column {
            width: parent.width
            spacing: 0

            Text {
                width: parent.width
                visible: !PowerProfiles.available
                text: qsTr("Power profiles unavailable")
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }

            Repeater {
                model: PowerProfiles.available ? PowerProfiles.profiles : []
                delegate: MenuButton {
                    id: prow
                    required property var modelData
                    readonly property bool sel: PowerProfiles.profile === prow.modelData
                    width: parent.width
                    minH: prowLabel.implicitHeight + prow.pad * 2
                    onClicked: PowerProfiles.setProfile(prow.modelData)
                    RevealerIconLabel {
                        id: prowLabel
                        anchors.fill: parent
                        iconName: prow.sel ? "check_circle" : ""
                        label: root.labelFor(prow.modelData)
                    }
                }
            }
        }
    }
}
