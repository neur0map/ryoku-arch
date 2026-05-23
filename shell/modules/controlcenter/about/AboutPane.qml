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
    property string pendingChannel: "main"
    readonly property real doctorOutputInset: Tokens.padding.small

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

    function currentChannel(): string {
        return RyokuAbout.info.configuredChannel || "main";
    }

    function packageChannelLabel(channel: string): string {
        if (channel === "main")
            return qsTr("Main package mirror");
        return channel || qsTr("Unknown");
    }

    function checkoutStateTitle(): string {
        if (RyokuAbout.info.checkoutMode === "official")
            return qsTr("Checkout matches channel");
        if (RyokuAbout.info.checkoutMode === "mismatch")
            return qsTr("Checkout and channel differ");
        if (RyokuAbout.info.checkoutMode === "custom")
            return qsTr("Custom checkout branch");
        return qsTr("Checkout state unknown");
    }

    function checkoutStateDetail(): string {
        if (RyokuAbout.info.checkoutMode === "official")
            return qsTr("Updates are checked against the current checkout branch.");
        if (RyokuAbout.info.checkoutMode === "mismatch")
            return qsTr("Update checks stay on %1 until you explicitly switch channels.").arg(RyokuAbout.info.currentBranch || qsTr("this branch"));
        if (RyokuAbout.info.checkoutMode === "custom")
            return qsTr("This branch can be checked for updates, but only main and unstable-dev are offered as install channels.");
        return qsTr("Refresh status before running updates.");
    }

    function updateStateIcon(report: var): string {
        if (report.updateState === "blocked")
            return "block";
        if (report.updateState === "ready")
            return "download";
        if (report.updateState === "ahead")
            return "publish";
        return "check_circle";
    }

    function updateStateTitle(report: var): string {
        if (report.updateAvailable === true)
            return qsTr("Update available");
        if (report.updateStateLabel)
            return report.updateStateLabel;
        return qsTr("No updates available");
    }

    function updateStateDetail(report: var): string {
        if (report.updateStateDetail)
            return report.updateStateDetail;
        if (report.updateAvailable === true)
            return qsTr("%1 incoming commits on %2. Current %3 -> remote %4.").arg(report.behindCount || 0).arg(report.updateBranch || report.currentBranch || qsTr("this branch")).arg(report.head || "?").arg(report.remoteHead || "?");
        return qsTr("%1 is current at %2.").arg(report.updateBranch || report.currentBranch || qsTr("This branch")).arg(report.head || "?");
    }

    function updateStateValue(report: var): string {
        if (report.updateStateLabel)
            return report.updateStateLabel;
        return report.canFastForward ? qsTr("Fast-forward ready") : qsTr("No update");
    }

    function syncPendingChannel(): void {
        if (modalMode === "channel" && modalOpen)
            return;

        pendingChannel = currentChannel();
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
        modalSubtitle = report.ok ? qsTr("Global doctor completed") : qsTr("Doctor found something to review");
        modalOpen = true;
    }

    function showMessage(title: string, subtitle: string, report: var): void {
        modalMode = "message";
        modalTitle = title;
        modalSubtitle = subtitle;
        modalReport = report;
        modalOpen = true;
    }

    function showChannelSwitch(channel: string): void {
        pendingChannel = channel || currentChannel();
        modalMode = "channel";
        modalReport = {
            ok: true,
            channel: pendingChannel,
            currentBranch: RyokuAbout.info.currentBranch || "",
            configuredChannel: currentChannel(),
            updateBranch: pendingChannel,
            packageChannel: RyokuAbout.info.packageChannel || "main",
            dirty: RyokuAbout.info.dirty === true,
            checkoutMode: RyokuAbout.info.checkoutMode || "unknown"
        };
        modalTitle = qsTr("Switch update channel");
        modalSubtitle = qsTr("%1 -> %2").arg(channelLabel(currentChannel())).arg(channelLabel(pendingChannel));
        modalOpen = true;
    }

    anchors.fill: parent

    Component.onCompleted: {
        root.syncPendingChannel();
        RyokuAbout.refreshStatus();
    }

    Connections {
        function onUpdateCheckFinished(report: var): void {
            root.showUpdates(report);
        }

        function onDoctorFinished(report: var): void {
            root.showDoctor(report);
        }

        function onUpdateStartFinished(report: var): void {
            root.showMessage(qsTr("Ryoku update"), report.ok ? report.message : report.error, report);
        }

        function onChannelSwitchFinished(report: var): void {
            root.showMessage(qsTr("Branch switch"), report.ok ? report.message : report.error, report);
        }

        function onInfoChanged(): void {
            root.syncPendingChannel();
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

                    StatusLine {
                        icon: RyokuAbout.info.checkoutMode === "official" ? "check_circle" : RyokuAbout.info.checkoutMode === "mismatch" ? "sync_problem" : "account_tree"
                        title: root.checkoutStateTitle()
                        detail: root.checkoutStateDetail()
                        error: RyokuAbout.info.checkoutMode === "mismatch"
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: aboutFlickable.width > 1100 ? 3 : 2
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
                            label: qsTr("Update branch")
                            value: RyokuAbout.info.updateBranch || RyokuAbout.info.currentBranch || qsTr("Detecting")
                        }

                        InfoTile {
                            Layout.fillWidth: true
                            label: qsTr("Package mirror")
                            value: packageChannelLabel(RyokuAbout.info.packageChannel || "main")
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

                        ActionButton {
                            Layout.fillWidth: aboutFlickable.width < 760
                            icon: RyokuAbout.checkingUpdates ? "progress_activity" : "system_update"
                            text: RyokuAbout.checkingUpdates ? qsTr("Checking") : qsTr("Check updates")
                            filled: true
                            onClicked: RyokuAbout.checkUpdates()
                        }

                        ActionButton {
                            Layout.fillWidth: aboutFlickable.width < 760
                            icon: RyokuAbout.runningDoctor ? "progress_activity" : "health_and_safety"
                            text: RyokuAbout.runningDoctor ? qsTr("Running") : qsTr("Run doctor")
                            onClicked: RyokuAbout.runDoctor()
                        }

                        ActionButton {
                            Layout.fillWidth: aboutFlickable.width < 760
                            icon: "refresh"
                            text: qsTr("Refresh")
                            onClicked: RyokuAbout.refreshStatus()
                        }
                    }
                }

                SectionContainer {
                    Layout.fillWidth: true
                    alignTop: true
                    contentSpacing: Tokens.spacing.normal

                    StyledText {
                        text: qsTr("Update channels")
                        font.pointSize: Tokens.font.size.normal
                        font.weight: 650
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Choose the channel first, then start the switch from an explicit confirmation step. Authentication, package output, and snapshots stay visible in a terminal.")
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
                            description: qsTr("Release channel for normal daily systems")
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

                    StatusLine {
                        icon: root.pendingChannel === root.currentChannel() ? "check_circle" : "rule_settings"
                        title: root.pendingChannel === root.currentChannel() ? qsTr("Selected channel is active") : qsTr("Ready to switch channel")
                        detail: root.pendingChannel === root.currentChannel()
                            ? qsTr("%1 is already selected.").arg(channelLabel(root.pendingChannel))
                            : qsTr("The switch will open a terminal and move the checkout to %1. Package mirrors remain on %2.").arg(root.pendingChannel).arg(packageChannelLabel(RyokuAbout.info.packageChannel || "main"))
                        error: false
                    }

                    RowLayout {
                        visible: root.pendingChannel !== root.currentChannel()
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        ActionButton {
                            icon: "alt_route"
                            text: qsTr("Switch channel")
                            filled: true
                            onClicked: root.showChannelSwitch(root.pendingChannel)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: RyokuAbout.info.dirty ? qsTr("Local changes are present; the terminal updater will show exactly what is preserved or blocked.") : qsTr("No branch change starts until the terminal action is confirmed.")
                            color: Colours.palette.m3onSurfaceVariant
                            wrapMode: Text.WordWrap
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
            width: Math.max(360, Math.min(820, modalLayer.width - Tokens.padding.large * 4))
            height: Math.max(260, Math.min(root.modalMode === "message" ? modalContent.implicitHeight + Tokens.padding.large * 2 : 660, modalLayer.height - Tokens.padding.large * 4))
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surface

            ColumnLayout {
                id: modalContent

                anchors.fill: parent
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
                            text: root.modalMode === "doctor" ? "health_and_safety" : root.modalMode === "updates" ? "system_update" : root.modalMode === "channel" ? "alt_route" : "info"
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
                    Layout.fillHeight: root.modalMode !== "message"
                    Layout.preferredHeight: root.modalMode === "message" ? implicitHeight : 1
                    sourceComponent: root.modalMode === "updates" ? updatesComponent : root.modalMode === "doctor" ? doctorComponent : root.modalMode === "channel" ? channelComponent : messageComponent
                }
            }
        }
    }

    Component {
        id: updatesComponent

        StyledFlickable {
            id: updatesFlickable

            width: modalBodyLoader.width
            height: modalBodyLoader.height
            clip: true
            contentHeight: updatesLayout.implicitHeight
            flickableDirection: Flickable.VerticalFlick

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: updatesFlickable
            }

            ColumnLayout {
                id: updatesLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
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
                    icon: root.updateStateIcon(root.modalReport)
                    title: root.updateStateTitle(root.modalReport)
                    detail: root.updateStateDetail(root.modalReport)
                    error: root.modalReport.updateState === "blocked"
                }

                StatusLine {
                    visible: root.modalReport.ok === true && root.modalReport.updateState === "blocked"
                    icon: "warning"
                    title: qsTr("Update blocked")
                    detail: root.modalReport.blockReason || qsTr("This checkout cannot fast-forward to the selected branch.")
                    error: true
                }

                GridLayout {
                    visible: root.modalReport.ok === true
                    Layout.fillWidth: true
                    columns: modalBodyLoader.width > 620 ? 2 : 1
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
                        label: qsTr("Update branch")
                        value: root.modalReport.updateBranch || root.modalReport.currentBranch || qsTr("Unknown")
                    }

                    InfoTile {
                        Layout.fillWidth: true
                        label: qsTr("Package mirror")
                        value: packageChannelLabel(root.modalReport.packageChannel || "main")
                    }

                    InfoTile {
                        Layout.fillWidth: true
                        label: qsTr("Remote")
                        value: root.modalReport.remoteBranch || qsTr("Unknown")
                    }

                    InfoTile {
                        Layout.fillWidth: true
                        label: qsTr("Update state")
                        value: root.updateStateValue(root.modalReport)
                    }
                }

                RowLayout {
                    visible: root.modalReport.ok === true && root.modalReport.updateAvailable === true
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    ActionButton {
                        icon: RyokuAbout.startingUpdate ? "progress_activity" : "download"
                        text: RyokuAbout.startingUpdate ? qsTr("Starting") : root.modalReport.canStartUpdate ? qsTr("Update now") : qsTr("Update blocked")
                        filled: true
                        disabled: !root.modalReport.canStartUpdate
                        onClicked: {
                            if (root.modalReport.canStartUpdate)
                                RyokuAbout.startUpdate(root.modalReport.updateBranch || root.modalReport.currentBranch || "");
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.modalReport.canStartUpdate ? qsTr("Opens the updater in a terminal for this checkout branch.") : root.modalReport.blockReason || qsTr("This checkout cannot fast-forward to the remote branch. Run doctor or review the branch before updating.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                }

                StyledText {
                    visible: root.modalReport.ok === true && (root.modalReport.incoming || []).length > 0
                    text: qsTr("Commit descriptions")
                    font.weight: 600
                }

                StyledText {
                    visible: root.modalReport.ok === true && (root.modalReport.incoming || []).length > 0
                    Layout.fillWidth: true
                    text: qsTr("These are the commits the updater will pull into this checkout.")
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                }

                ColumnLayout {
                    visible: root.modalReport.ok === true && (root.modalReport.incoming || []).length > 0
                    Layout.fillWidth: true
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

    Component {
        id: channelComponent

        ColumnLayout {
            width: modalBodyLoader.width
            height: modalBodyLoader.height
            spacing: Tokens.spacing.normal

            StatusLine {
                icon: "alt_route"
                title: qsTr("Terminal switch required")
                detail: qsTr("Ryoku will switch the checkout to %1, keep package mirrors on %2, and run the update workflow with visible output.").arg(channelLabel(root.pendingChannel)).arg(packageChannelLabel(root.modalReport.packageChannel || "main"))
                error: false
            }

            GridLayout {
                Layout.fillWidth: true
                columns: modalBodyLoader.width > 620 ? 2 : 1
                columnSpacing: Tokens.spacing.normal
                rowSpacing: Tokens.spacing.normal

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Current checkout")
                    value: root.modalReport.currentBranch || qsTr("Unknown")
                }

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Current channel")
                    value: channelLabel(root.modalReport.configuredChannel || "main")
                }

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Target channel")
                    value: channelLabel(root.pendingChannel)
                }

                InfoTile {
                    Layout.fillWidth: true
                    label: qsTr("Package mirror")
                    value: packageChannelLabel(root.modalReport.packageChannel || "main")
                }
            }

            StatusLine {
                visible: root.modalReport.dirty === true
                icon: "warning"
                title: qsTr("Local changes detected")
                detail: qsTr("The terminal updater will preserve or stop on local changes before committing the new channel state.")
                error: true
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("No branch switch starts from selecting a card. This button only opens the terminal workflow.")
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                }

                ActionButton {
                    icon: RyokuAbout.switchingChannel ? "progress_activity" : "terminal"
                    text: RyokuAbout.switchingChannel ? qsTr("Starting") : qsTr("Open terminal")
                    filled: true
                    onClicked: {
                        RyokuAbout.switchChannel(root.pendingChannel);
                        root.modalOpen = false;
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
                detail: qsTr("Global ryoku-doctor exit code %1").arg(root.modalReport.exitCode ?? 1)
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

                            x: root.doctorOutputInset
                            width: doctorOutputFlickable.width - root.doctorOutputInset * 2
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

    component ActionButton: IconTextButton {
        property bool filled: false
        property bool disabled: false

        opacity: disabled ? 0.55 : 1
        type: filled ? IconTextButton.Filled : IconTextButton.Tonal
        inactiveColour: filled ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
        inactiveOnColour: filled ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
        activeColour: inactiveColour
        activeOnColour: inactiveOnColour
        horizontalPadding: Tokens.padding.normal
        verticalPadding: Tokens.padding.small
        stateLayer.disabled: disabled
        label.wrapMode: Text.NoWrap
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

        readonly property bool current: root.currentChannel() === channel
        readonly property bool selected: root.pendingChannel === channel

        implicitHeight: channelContent.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: selected ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh
        border.width: selected ? 0 : 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.35)

        StateLayer {
            onClicked: root.pendingChannel = channelButton.channel
            color: channelButton.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
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
                color: channelButton.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                fill: channelButton.selected ? 1 : 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: channelButton.title
                    color: channelButton.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.weight: 600
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: channelButton.current
                    text: qsTr("Current channel")
                    color: channelButton.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.small
                    font.weight: 600
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: channelButton.description
                    color: channelButton.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    wrapMode: Text.WordWrap
                }
            }

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: channelButton.selected
                text: channelButton.current ? "check_circle" : "radio_button_checked"
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
