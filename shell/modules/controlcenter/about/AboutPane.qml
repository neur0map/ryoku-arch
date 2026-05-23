pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    required property Session session

    readonly property var credits: [
        {
            name: "Omarchy",
            url: "https://github.com/basecamp/omarchy",
            icon: "foundation",
            summary: qsTr("Install architecture, command shape, and theme pipeline ancestry.")
        },
        {
            name: "Caelestia Shell",
            url: "https://github.com/caelestia-dots/shell",
            icon: "auto_awesome",
            summary: qsTr("Quickshell shell foundation adapted into Ryoku-owned surfaces.")
        },
        {
            name: "HyprMod",
            url: "https://github.com/BlueManCZ/hyprmod",
            icon: "tune",
            summary: qsTr("Hyprland GUI configuration work that informed Ryoku's compositor control path.")
        },
        {
            name: "qylock",
            url: "https://github.com/Darkkal44/qylock",
            icon: "lock",
            summary: qsTr("Default lockscreen and SDDM theme integration.")
        }
    ]

    property bool modalOpen: false
    property string modalMode: "updates"
    property string modalTitle: ""
    property string modalSubtitle: ""
    property var modalReport: ({})

    function channelLabel(channel: string): string {
        if (channel === "main")
            return qsTr("Stable (main)");
        if (channel === "unstable-dev")
            return qsTr("Unstable (unstable-dev)");
        return channel || qsTr("Unknown");
    }

    function branchSummary(): string {
        const branch = RyokuAbout.info.currentBranch || qsTr("Unknown");
        const channel = RyokuAbout.info.configuredChannel || "main";
        return qsTr("%1 checkout, %2 channel").arg(branch).arg(channelLabel(channel));
    }

    function showUpdates(report: var): void {
        modalMode = "updates";
        modalReport = report;
        modalTitle = qsTr("Ryoku updates");
        modalSubtitle = report.ok ? branchSummary() : qsTr("Update check failed");
        modalOpen = true;
    }

    function showDoctor(report: var): void {
        modalMode = "doctor";
        modalReport = report;
        modalTitle = qsTr("Ryoku doctor");
        modalSubtitle = report.ok ? qsTr("No shell issues detected") : qsTr("Doctor found something to review");
        modalOpen = true;
    }

    function showMessage(title: string, subtitle: string, report: var): void {
        modalMode = "message";
        modalTitle = title;
        modalSubtitle = subtitle;
        modalReport = report;
        modalOpen = true;
    }

    anchors.fill: parent

    Component.onCompleted: RyokuAbout.refreshStatus()

    Connections {
        function onUpdateCheckFinished(report: var): void {
            root.showUpdates(report);
        }

        function onDoctorFinished(report: var): void {
            root.showDoctor(report);
        }

        function onChannelSwitchFinished(report: var): void {
            root.showMessage(qsTr("Branch switch"), report.ok ? report.message : report.error, report);
        }

        target: RyokuAbout
    }

    ClippingRectangle {
        id: aboutClippingRect

        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Tokens.padding.normal

        radius: aboutBorder.innerRadius
        color: "transparent"

        Loader {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large + Tokens.padding.normal
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large
            asynchronous: true
            sourceComponent: aboutContentComponent
        }
    }

    InnerBorder {
        id: aboutBorder

        leftThickness: 0
        rightThickness: Tokens.padding.normal
    }

    Component {
        id: aboutContentComponent

        StyledFlickable {
            id: aboutFlickable

            flickableDirection: Flickable.VerticalFlick
            contentHeight: aboutLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: aboutFlickable
            }

            ColumnLayout {
                id: aboutLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Tokens.spacing.large

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true
                    contentSpacing: Tokens.spacing.large

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 64
                            implicitHeight: 64
                            radius: Tokens.rounding.normal
                            color: Colours.palette.m3primaryContainer

                            Logo {
                                anchors.centerIn: parent
                                width: 38
                                height: 38
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Tokens.spacing.smaller

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Ryoku")
                                font.pointSize: Tokens.font.size.larger
                                font.weight: 700
                                wrapMode: Text.WordWrap
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Hyprland workstation shell")
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.small
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: aboutFlickable.width > 980 ? 4 : 2
                        columnSpacing: Tokens.spacing.normal
                        rowSpacing: Tokens.spacing.normal

                        InfoTile {
                            Layout.fillWidth: true
                            label: qsTr("Version")
                            value: RyokuAbout.info.version || qsTr("Detecting")
                        }

                        InfoTile {
                            Layout.fillWidth: true
                            label: qsTr("Checkout branch")
                            value: RyokuAbout.info.currentBranch || qsTr("Detecting")
                        }

                        InfoTile {
                            Layout.fillWidth: true
                            label: qsTr("Update channel")
                            value: channelLabel(RyokuAbout.info.configuredChannel || "main")
                        }

                        InfoTile {
                            Layout.fillWidth: true
                            label: qsTr("Repository")
                            value: RyokuAbout.info.dirty ? qsTr("Local changes present") : qsTr("Clean checkout")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        IconTextButton {
                            icon: RyokuAbout.checkingUpdates ? "progress_activity" : "system_update"
                            text: RyokuAbout.checkingUpdates ? qsTr("Checking") : qsTr("Check updates")
                            type: IconTextButton.Filled
                            onClicked: RyokuAbout.checkUpdates()
                        }

                        IconTextButton {
                            icon: RyokuAbout.runningDoctor ? "progress_activity" : "health_and_safety"
                            text: RyokuAbout.runningDoctor ? qsTr("Running") : qsTr("Run doctor")
                            type: IconTextButton.Tonal
                            onClicked: RyokuAbout.runDoctor()
                        }

                        IconTextButton {
                            icon: "refresh"
                            text: qsTr("Refresh")
                            type: IconTextButton.Tonal
                            onClicked: RyokuAbout.refreshStatus()
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true
                    contentSpacing: Tokens.spacing.normal

                    StyledText {
                        text: qsTr("Branch channel")
                        font.pointSize: Tokens.font.size.normal
                        font.weight: 650
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Ryoku exposes two update channels. Switching opens the updater in a terminal so authentication and package output stay visible.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: aboutFlickable.width > 760 ? 2 : 1
                        columnSpacing: Tokens.spacing.normal
                        rowSpacing: Tokens.spacing.normal

                        ChannelButton {
                            Layout.fillWidth: true
                            channel: "main"
                            title: qsTr("Main stable")
                            description: qsTr("Stable release channel for normal systems")
                            icon: "verified"
                        }

                        ChannelButton {
                            Layout.fillWidth: true
                            channel: "unstable-dev"
                            title: qsTr("Unstable dev")
                            description: qsTr("Development channel for testing upcoming Ryoku changes")
                            icon: "science"
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true
                    contentSpacing: Tokens.spacing.normal

                    StyledText {
                        text: qsTr("Credits")
                        font.pointSize: Tokens.font.size.normal
                        font.weight: 650
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: aboutFlickable.width > 760 ? 2 : 1
                        columnSpacing: Tokens.spacing.normal
                        rowSpacing: Tokens.spacing.normal

                        Repeater {
                            model: root.credits.length

                            CreditRow {
                                required property int index

                                Layout.fillWidth: true
                                credit: root.credits[index] || ({})
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: modalLayer

        anchors.fill: parent
        visible: root.modalOpen
        z: 20

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)

            MouseArea {
                anchors.fill: parent
                onClicked: root.modalOpen = false
            }
        }

        StyledRect {
            id: modal

            anchors.centerIn: parent
            implicitWidth: Math.min(760, modalLayer.width - Tokens.padding.large * 4)
            implicitHeight: Math.min(modalContent.implicitHeight + Tokens.padding.large * 2, modalLayer.height - Tokens.padding.large * 4)
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surface

            ColumnLayout {
                id: modalContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    StyledRect {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 46
                        implicitHeight: 46
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: root.modalMode === "doctor" ? "health_and_safety" : root.modalMode === "updates" ? "system_update" : "info"
                            color: Colours.palette.m3onSecondaryContainer
                            fill: 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.modalTitle
                            font.pointSize: Tokens.font.size.large
                            font.weight: 650
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.modalSubtitle
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.WordWrap
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "close"
                        onClicked: root.modalOpen = false
                    }
                }

                Loader {
                    id: modalBodyLoader

                    Layout.fillWidth: true
                    Layout.preferredHeight: root.modalMode === "doctor" ? Math.min(420, modalLayer.height - 260) : implicitHeight
                    sourceComponent: root.modalMode === "updates" ? updatesComponent : root.modalMode === "doctor" ? doctorComponent : messageComponent
                }
            }
        }
    }

    Component {
        id: updatesComponent

        ColumnLayout {
            width: modalBodyLoader.width
            spacing: Tokens.spacing.normal

            StatusLine {
                visible: root.modalReport.ok === false
                icon: "error"
                title: qsTr("Unable to check updates")
                detail: root.modalReport.error || qsTr("Unknown error")
                error: true
            }

            StatusLine {
                visible: root.modalReport.ok === true
                icon: root.modalReport.updateAvailable === true ? "download" : "check_circle"
                title: root.modalReport.updateAvailable === true ? qsTr("%1 incoming commits").arg(root.modalReport.behindCount || 0) : qsTr("Ryoku is current")
                detail: root.modalReport.ok === true ? qsTr("%1 -> %2").arg(root.modalReport.head || "?").arg(root.modalReport.remoteHead || "?") : ""
            }

            GridLayout {
                visible: root.modalReport.ok === true
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Tokens.spacing.normal
                rowSpacing: Tokens.spacing.normal

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Checkout")
                    value: root.modalReport.currentBranch || qsTr("Unknown")
                }

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Channel")
                    value: channelLabel(root.modalReport.configuredChannel || "main")
                }

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Remote")
                    value: root.modalReport.remoteBranch || qsTr("Unknown")
                }

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Fast-forward")
                    value: root.modalReport.canFastForward ? qsTr("Available") : qsTr("Not needed")
                }
            }

            StyledText {
                visible: root.modalReport.ok === true && (root.modalReport.incoming || []).length > 0
                text: qsTr("Incoming commits")
                font.weight: 600
            }

            StyledRect {
                visible: root.modalReport.ok === true && (root.modalReport.incoming || []).length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(260, incomingColumn.implicitHeight + Tokens.padding.normal * 2)
                radius: Tokens.rounding.normal
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.normal
                    radius: parent.radius
                    color: "transparent"

                    StyledFlickable {
                        id: incomingFlickable

                        anchors.fill: parent
                        clip: true
                        contentHeight: incomingColumn.implicitHeight
                        flickableDirection: Flickable.VerticalFlick

                        StyledScrollBar.vertical: StyledScrollBar {
                            flickable: incomingFlickable
                        }

                        ColumnLayout {
                            id: incomingColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: (root.modalReport.incoming || []).length

                                CommitRow {
                                    required property int index

                                    Layout.fillWidth: true
                                    commit: root.modalReport.incoming[index] || ({})
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: doctorComponent

        ColumnLayout {
            width: modalBodyLoader.width
            height: modalBodyLoader.height
            spacing: Tokens.spacing.normal

            StatusLine {
                icon: root.modalReport.ok === true ? "check_circle" : "warning"
                title: root.modalReport.ok === true ? qsTr("Doctor passed") : qsTr("Doctor needs review")
                detail: qsTr("Exit code %1").arg(root.modalReport.exitCode ?? 1)
                error: root.modalReport.ok !== true
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 180
                Layout.preferredHeight: 320
                radius: Tokens.rounding.normal
                color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.normal
                    radius: parent.radius
                    color: "transparent"

                    StyledFlickable {
                        id: doctorOutputFlickable

                        anchors.fill: parent
                        clip: true
                        contentHeight: doctorOutput.implicitHeight
                        flickableDirection: Flickable.VerticalFlick

                        StyledScrollBar.vertical: StyledScrollBar {
                            flickable: doctorOutputFlickable
                        }

                        StyledText {
                            id: doctorOutput

                            width: doctorOutputFlickable.width
                            text: root.modalReport.output || root.modalReport.error || qsTr("No doctor output")
                            color: Colours.palette.m3onSurfaceVariant
                            font.family: "monospace"
                            font.pointSize: Tokens.font.size.small
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }

    Component {
        id: messageComponent

        StatusLine {
            icon: root.modalReport.ok === true ? "terminal" : "error"
            title: root.modalReport.ok === true ? qsTr("Started") : qsTr("Unable to start")
            detail: root.modalSubtitle || root.modalReport.error || ""
            error: root.modalReport.ok !== true
        }
    }

    component InfoTile: StyledRect {
        id: infoTile

        property string label: ""
        property string value: ""

        implicitWidth: 180
        implicitHeight: infoColumn.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        ColumnLayout {
            id: infoColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.normal
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: infoTile.label
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: infoTile.value
                font.weight: 600
                wrapMode: Text.WordWrap
            }
        }
    }

    component ChannelButton: StyledRect {
        id: channelButton

        property string channel: ""
        property string title: ""
        property string description: ""
        property string icon: ""

        readonly property bool active: RyokuAbout.info.configuredChannel === channel || (!RyokuAbout.info.configuredChannel && channel === "main")

        implicitHeight: channelContent.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: active ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 2)

        StateLayer {
            onClicked: RyokuAbout.switchChannel(channelButton.channel)
            color: channelButton.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
            radius: channelButton.radius
        }

        RowLayout {
            id: channelContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: channelButton.icon
                color: channelButton.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fill: channelButton.active ? 1 : 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: channelButton.title
                    color: channelButton.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.weight: 600
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: channelButton.description
                    color: channelButton.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    wrapMode: Text.WordWrap
                }
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: channelButton.active
                text: "check_circle"
                color: Colours.palette.m3onSecondaryContainer
                fill: 1
            }
        }
    }

    component CreditRow: StyledRect {
        id: creditRow

        property var credit: ({})
        readonly property string creditIcon: credit && credit.icon ? credit.icon : "open_in_new"
        readonly property string creditName: credit && credit.name ? credit.name : ""
        readonly property string creditSummary: credit && credit.summary ? credit.summary : ""
        readonly property string creditUrl: credit && credit.url ? credit.url : ""

        implicitHeight: creditContent.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        RowLayout {
            id: creditContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                text: creditRow.creditIcon
                color: Colours.palette.m3primary
                fill: 1
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: creditRow.creditName
                    font.weight: 600
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: creditRow.creditSummary
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    wrapMode: Text.WordWrap
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "open_in_new"
                onClicked: RyokuAbout.openUrl(creditRow.creditUrl)
            }
        }
    }

    component CommitRow: StyledRect {
        id: commitRow

        property var commit: ({})
        readonly property string commitHash: commit && commit.hash ? commit.hash : ""
        readonly property string commitSubject: commit && commit.subject ? commit.subject : ""
        readonly property string commitAuthor: commit && commit.author ? commit.author : ""
        readonly property string commitTime: commit && commit.relativeTime ? commit.relativeTime : ""

        implicitHeight: commitContent.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

        RowLayout {
            id: commitContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.normal
            spacing: Tokens.spacing.normal

            StyledText {
                Layout.alignment: Qt.AlignTop
                text: commitRow.commitHash
                color: Colours.palette.m3primary
                font.family: "monospace"
                font.weight: 700
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: commitRow.commitSubject
                    font.weight: 600
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("%1 · %2").arg(commitRow.commitAuthor).arg(commitRow.commitTime)
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    elide: Text.ElideRight
                }
            }
        }
    }

    component StatusLine: StyledRect {
        id: statusLine

        property string icon: ""
        property string title: ""
        property string detail: ""
        property bool error: false

        Layout.fillWidth: true

        implicitHeight: Math.max(statusIcon.implicitHeight, statusContent.implicitHeight) + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: error ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer

        MaterialIcon {
            id: statusIcon

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Tokens.padding.normal
            anchors.topMargin: Tokens.padding.normal
            width: 34
            text: statusLine.icon
            color: statusLine.error ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
            fill: 1
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            id: statusContent

            anchors.left: statusIcon.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.normal
            anchors.leftMargin: Tokens.spacing.normal
            spacing: Tokens.spacing.normal

            StyledText {
                Layout.fillWidth: true
                text: statusLine.title
                color: statusLine.error ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                font.weight: 650
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: statusLine.detail !== ""
                text: statusLine.detail
                color: statusLine.error ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                wrapMode: Text.WordWrap
            }
        }
    }
}
