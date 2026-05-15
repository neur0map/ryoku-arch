import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/*
 * Firewall sidebar tab. UFW status is read through RyokuFirewall without
 * auth prompts; changes go through the ryoku-firewall pkexec helper.
 */
Item {
    id: root
    anchors.fill: parent

    property string actionValue: "allow"
    property string directionValue: "in"
    property string protocolValue: "tcp"
    property bool advancedVisible: false

    readonly property color colAccent:
        Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colPrimary
        : Appearance.colors.colPrimary
    readonly property color colDanger: Appearance.m3colors.m3error ?? "#fb4934"
    readonly property int fontTitle: Appearance.font.pixelSize.small
    readonly property int fontBody: Appearance.font.pixelSize.smaller
    readonly property int fontCaption: Appearance.font.pixelSize.smallest

    function _validPort(s) {
        if (!s) return false
        return /^[0-9]{1,5}(:[0-9]{1,5})?$/.test(s)
    }

    function _validRemote(s) {
        if (!s || s === "any") return true
        return /^[0-9A-Fa-f:.]+(\/[0-9]{1,3})?$/.test(s)
    }

    function _endpointLabel(s) {
        if (!s || s === "0.0.0.0/0" || s === "::/0") return "any"
        return s
    }

    function _policyTitle(value) {
        if (value === "allow") return "Allow"
        if (value === "deny") return "Deny"
        if (value === "reject") return "Reject"
        return "Unknown"
    }

    function _ruleSummary(rule) {
        const rawAction = String(rule.action || "")
        const action = rawAction.length > 0 ? rawAction.charAt(0).toUpperCase() + rawAction.slice(1) : "Rule"
        const proto = (rule.protocol || "any").toUpperCase()
        const port = rule.port || "any"
        const dir = rule.direction === "out" ? "outbound" : "inbound"
        return action + " " + proto + " " + port + " " + dir
    }

    ScrollView {
        id: mainScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: Math.max(mainScroll.availableWidth - 2, 0)
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: overviewCol.implicitHeight + 24
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: overviewCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            text: "shield"
                            iconSize: Appearance.font.pixelSize.larger
                            fill: RyokuFirewall.enabled ? 1 : 0
                            color: RyokuFirewall.enabled ? root.colAccent : Appearance.colors.colSubtext
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: RyokuFirewall.enabled ? "Firewall active" : "Firewall inactive"
                                color: Appearance.colors.colOnLayer2
                                font.weight: Font.Bold
                                font.pixelSize: root.fontTitle
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: RyokuFirewall.rules.length + " rules"
                                      + (RyokuFirewall.lastRefresh.length > 0 ? " - refreshed " + RyokuFirewall.lastRefresh : "")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: root.fontBody
                                elide: Text.ElideRight
                            }
                        }
                        IconToolbarButton {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            text: "refresh"
                            enabled: !RyokuFirewall.busy
                            onClicked: RyokuFirewall.refresh()
                            StyledToolTip { text: "Refresh" }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        PolicyPill { label: "Incoming"; value: RyokuFirewall.policies.incoming }
                        PolicyPill { label: "Outgoing"; value: RyokuFirewall.policies.outgoing }
                        PolicyPill { label: "Routed"; value: RyokuFirewall.policies.routed }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        DialogButton {
                            buttonText: "Enable"
                            visible: !RyokuFirewall.enabled
                            enabled: !RyokuFirewall.busy && !RyokuFirewall.enabled
                            onClicked: RyokuFirewall.enableFirewall()
                        }
                        DialogButton {
                            buttonText: "Reload"
                            enabled: !RyokuFirewall.busy && RyokuFirewall.commandAvailable
                            onClicked: RyokuFirewall.reloadFirewall()
                        }
                        Item { Layout.fillWidth: true }
                        DialogButton {
                            buttonText: root.advancedVisible ? "Hide advanced" : "Advanced"
                            colEnabled: root.advancedVisible ? root.colDanger : root.colAccent
                            colBackground: root.advancedVisible
                                ? ColorUtils.transparentize(root.colDanger, 0.9)
                                : ColorUtils.transparentize(root.colAccent, 0.9)
                            onClicked: root.advancedVisible = !root.advancedVisible
                        }
                    }
                }
            }

            Rectangle {
                visible: RyokuFirewall.lastError.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: errRow.implicitHeight + 16
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(root.colDanger, 0.85)
                border.width: 1
                border.color: ColorUtils.transparentize(root.colDanger, 0.5)

                RowLayout {
                    id: errRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    MaterialSymbol {
                        text: "error_outline"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.colDanger
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Error: " + RyokuFirewall.lastError
                        color: root.colDanger
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.Wrap
                    }
                    DialogButton {
                        buttonText: "Dismiss"
                        colEnabled: root.colDanger
                        onClicked: RyokuFirewall.clearError()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: addCol.implicitHeight + 24
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: addCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "add_moderator"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.colAccent
                        }
                        StyledText {
                            text: "Add rule"
                            color: Appearance.colors.colOnLayer2
                            font.weight: Font.Bold
                            font.pixelSize: root.fontTitle
                        }
                        Item { Layout.fillWidth: true }
                    }

                    OptionRow {
                        label: "Action"
                        description: root.actionValue === "allow" ? "Permit matching traffic." : "Block matching traffic."
                        currentValue: root.actionValue
                        options: [
                            { title: "Allow", icon: "check", value: "allow" },
                            { title: "Deny", icon: "block", value: "deny" }
                        ]
                        onSelected: (newValue) => root.actionValue = newValue
                    }

                    OptionRow {
                        label: "Direction"
                        description: root.directionValue === "in" ? "Traffic coming into this device." : "Traffic leaving this device."
                        currentValue: root.directionValue
                        options: [
                            { title: "Inbound", icon: "south_west", value: "in" },
                            { title: "Outbound", icon: "north_east", value: "out" }
                        ]
                        onSelected: (newValue) => root.directionValue = newValue
                    }

                    OptionRow {
                        label: "Protocol"
                        description: root.protocolValue === "tcp" ? "TCP covers SSH, web apps, and most services."
                            : root.protocolValue === "udp" ? "UDP covers discovery, games, calls, and streaming."
                            : "Any applies the rule without protocol filtering."
                        currentValue: root.protocolValue
                        options: [
                            { title: "TCP", icon: "settings_ethernet", value: "tcp" },
                            { title: "UDP", icon: "hub", value: "udp" },
                            { title: "Any", icon: "all_inclusive", value: "any" }
                        ]
                        onSelected: (newValue) => root.protocolValue = newValue
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialTextField {
                            id: portField
                            Layout.fillWidth: true
                            placeholderText: "Port or range"
                            font.pixelSize: root.fontBody
                            enableSettingsSearch: false
                            onAccepted: addButton.clicked()
                        }
                        MaterialTextField {
                            id: remoteField
                            Layout.fillWidth: true
                            placeholderText: root.directionValue === "in" ? "Source CIDR or any" : "Destination CIDR or any"
                            font.pixelSize: root.fontBody
                            enableSettingsSearch: false
                            onAccepted: addButton.clicked()
                        }
                    }

                    MaterialTextField {
                        id: commentField
                        Layout.fillWidth: true
                        placeholderText: "Comment"
                        font.pixelSize: root.fontBody
                        enableSettingsSearch: false
                        onAccepted: addButton.clicked()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: root._validPort(portField.text)
                                  ? (root._validRemote(remoteField.text) ? "" : "Remote must be any, an IP, or CIDR")
                                  : "Use a port like 22 or range like 8000:8010"
                            color: Appearance.colors.colSubtext
                            font.pixelSize: root.fontBody
                            wrapMode: Text.Wrap
                        }
                        DialogButton {
                            id: addButton
                            buttonText: "Add"
                            enabled: !RyokuFirewall.busy
                                && root._validPort(portField.text)
                                && root._validRemote(remoteField.text)
                            onClicked: {
                                RyokuFirewall.addRule(root.actionValue, root.directionValue, root.protocolValue,
                                    portField.text, remoteField.text.length > 0 ? remoteField.text : "any", commentField.text)
                                portField.text = ""
                                remoteField.text = ""
                                commentField.text = ""
                                portField.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.advancedVisible
                Layout.fillWidth: true
                Layout.preferredHeight: advancedCol.implicitHeight + 24
                radius: Appearance.rounding.normal
                color: ColorUtils.transparentize(root.colDanger, 0.92)
                border.width: 1
                border.color: ColorUtils.transparentize(root.colDanger, 0.58)

                ColumnLayout {
                    id: advancedCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: "warning"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.colDanger
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Advanced firewall controls"
                            color: root.colDanger
                            font.weight: Font.Bold
                            font.pixelSize: root.fontTitle
                        }
                    }

                    PolicyControl {
                        label: "Incoming default"
                        target: "incoming"
                        currentValue: RyokuFirewall.policies.incoming
                    }
                    PolicyControl {
                        label: "Outgoing default"
                        target: "outgoing"
                        currentValue: RyokuFirewall.policies.outgoing
                    }
                    PolicyControl {
                        label: "Routed default"
                        target: "routed"
                        currentValue: RyokuFirewall.policies.routed
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        DialogButton {
                            buttonText: "Disable firewall"
                            enabled: !RyokuFirewall.busy && RyokuFirewall.enabled
                            colEnabled: root.colDanger
                            colBackground: ColorUtils.transparentize(root.colDanger, 0.9)
                            colBackgroundHover: ColorUtils.transparentize(root.colDanger, 0.82)
                            onClicked: RyokuFirewall.disableFirewall()
                        }
                        DialogButton {
                            buttonText: "Restore Ryoku defaults"
                            enabled: !RyokuFirewall.busy
                            colEnabled: root.colDanger
                            colBackground: ColorUtils.transparentize(root.colDanger, 0.9)
                            colBackgroundHover: ColorUtils.transparentize(root.colDanger, 0.82)
                            onClicked: RyokuFirewall.restoreDefaults()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MaterialSymbol {
                    text: "rule"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: "Rules"
                    color: Appearance.colors.colOnLayer1
                    font.weight: Font.Bold
                    font.pixelSize: root.fontTitle
                }
                StyledText {
                    text: RyokuFirewall.rules.length === 1 ? "1 rule" : RyokuFirewall.rules.length + " rules"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: root.fontBody
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: RyokuFirewall.rules.length === 0
                    ? 180
                    : Math.min(ruleList.implicitHeight + 16, 360)
                radius: Appearance.rounding.normal
                color: RyokuFirewall.rules.length === 0 ? "transparent" : Appearance.colors.colLayer2
                border.width: RyokuFirewall.rules.length === 0 ? 1 : 0
                border.color: ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.5)

                ColumnLayout {
                    visible: RyokuFirewall.rules.length === 0
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 32, 300)
                    spacing: 12

                    MaterialSymbol {
                        text: "shield_lock"
                        iconSize: 52
                        color: Appearance.colors.colSubtext
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "No user rules"
                        color: Appearance.colors.colOnLayer1
                        font.weight: Font.Bold
                        font.pixelSize: root.fontTitle
                        horizontalAlignment: Text.AlignHCenter
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Default policies still apply. Add explicit rules above when a service needs access."
                        color: Appearance.colors.colSubtext
                        font.pixelSize: root.fontBody
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                ScrollView {
                    visible: RyokuFirewall.rules.length > 0
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true

                    ColumnLayout {
                        id: ruleList
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: RyokuFirewall.rules
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: ruleRow.implicitHeight + 12
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer2

                                RowLayout {
                                    id: ruleRow
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 28
                                        radius: Appearance.rounding.small
                                        color: ColorUtils.transparentize(root.colAccent, 0.84)
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: modelData.number
                                            color: root.colAccent
                                            font.weight: Font.Bold
                                            font.pixelSize: root.fontBody
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root._ruleSummary(modelData)
                                            color: Appearance.colors.colOnLayer2
                                            font.weight: Font.DemiBold
                                            font.pixelSize: root.fontBody
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root._endpointLabel(modelData.source)
                                                  + " -> " + root._endpointLabel(modelData.destination)
                                                  + (modelData.comment ? " - " + modelData.comment : "")
                                            color: Appearance.colors.colSubtext
                                            font.pixelSize: root.fontCaption
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        id: removeBtn
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: Appearance.rounding.small
                                        color: removeMouse.containsPress ? ColorUtils.transparentize(root.colDanger, 0.74)
                                            : removeMouse.containsMouse ? ColorUtils.transparentize(root.colDanger, 0.86)
                                            : ColorUtils.transparentize(root.colDanger, 0.94)

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "delete"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: root.colDanger
                                        }
                                        MouseArea {
                                            id: removeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !RyokuFirewall.busy
                                            onClicked: RyokuFirewall.deleteRule(modelData.number)
                                        }
                                        StyledToolTip {
                                            extraVisibleCondition: removeMouse.containsMouse
                                            text: "Remove"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component PolicyPill: Rectangle {
        required property string label
        required property string value

        Layout.fillWidth: true
        implicitHeight: 34
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6
            StyledText {
                text: label
                color: Appearance.colors.colSubtext
                font.pixelSize: root.fontCaption
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: root._policyTitle(value)
                color: value === "allow" ? root.colAccent
                    : value === "reject" ? root.colDanger
                    : Appearance.colors.colOnLayer2
                font.weight: Font.Bold
                font.pixelSize: root.fontBody
            }
        }
    }

    component OptionRow: ColumnLayout {
        id: optionRow
        required property string label
        required property string currentValue
        property string description: ""
        property var options: []

        signal selected(string newValue)

        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                text: optionRow.label
                color: Appearance.colors.colOnLayer2
                font.pixelSize: root.fontBody
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                text: optionRow.description
                color: Appearance.colors.colSubtext
                font.pixelSize: root.fontCaption
                elide: Text.ElideRight
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: optionRow.options
                delegate: OptionChip {
                    required property var modelData
                    optionData: modelData
                    selected: optionRow.currentValue === modelData.value
                    onClicked: optionRow.selected(modelData.value)
                }
            }
        }
    }

    component OptionChip: Rectangle {
        id: chip
        required property var optionData
        required property bool selected

        signal clicked()

        implicitWidth: chipContent.implicitWidth + 20
        implicitHeight: 32
        radius: Appearance.rounding.full
        color: selected ? ColorUtils.transparentize(root.colAccent, 0.18)
            : chipMouse.containsMouse ? Appearance.colors.colLayer2Hover
            : Appearance.colors.colLayer1
        border.width: selected ? 0 : 1
        border.color: ColorUtils.transparentize(Appearance.colors.colLayer3Hover, 0.4)

        RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: chip.optionData.icon || "radio_button_unchecked"
                iconSize: root.fontTitle
                color: chip.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
            }
            StyledText {
                text: chip.optionData.title || ""
                color: chip.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                font.pixelSize: root.fontBody
                font.weight: chip.selected ? Font.DemiBold : Font.Medium
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component PolicyControl: ColumnLayout {
        id: policyCtl
        required property string label
        required property string target
        required property string currentValue

        Layout.fillWidth: true
        spacing: 6

        StyledText {
            text: label
            color: root.colDanger
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }
        ConfigSelectionArray {
            enableSettingsSearch: false
            currentValue: policyCtl.currentValue
            options: [
                { displayName: "Deny", icon: "block", value: "deny" },
                { displayName: "Allow", icon: "check", value: "allow" },
                { displayName: "Reject", icon: "report", value: "reject" }
            ]
            onSelected: (newValue) => RyokuFirewall.setDefaultPolicy(newValue, policyCtl.target)
        }
    }
}
