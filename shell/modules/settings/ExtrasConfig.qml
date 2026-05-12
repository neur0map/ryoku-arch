import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 15
    settingsPageName: Translation.tr("Extras")

    property var profiles: []
    property string toastText: ""
    property string busyProfileId: ""
    property string busyMessage: ""
    property bool reopenSettingsOverlayAfterPolkit: false
    readonly property bool workflowRunning: listProc.running || installProc.running

    function helperPath(name) {
        var ryokuPath = Quickshell.env("RYOKU_PATH")
        if (!ryokuPath || ryokuPath.length === 0) {
            ryokuPath = Quickshell.env("HOME") + "/.local/share/ryoku"
        }
        return ryokuPath + "/bin/" + name
    }

    function statusLabel(profile) {
        if (profile.installed === true) return Translation.tr("Installed")
        if (profile.state === "failed") return Translation.tr("Failed")
        return Translation.tr("Not installed")
    }

    function statusColor(profile) {
        if (profile.installed === true) return Appearance.colors.colPrimary
        if (profile.state === "failed") return Appearance.colors.colError
        return Appearance.colors.colSubtext
    }

    function colorWithAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function arrayCount(values) {
        return values ? values.length : 0
    }

    function refreshProfiles() {
        if (listProc.running) return
        listProc.output = ""
        listProc.command = [helperPath("ryoku-cmd-profile-list"), "--json"]
        listProc.running = true
    }

    function installProfile(profile) {
        if (workflowRunning || !profile || !profile.id) return
        installProc.profileId = profile.id
        installProc.profileName = profile.name || profile.id
        installProc.command = ["pkexec", helperPath("ryoku-install-profile"), profile.id]
        busyProfileId = profile.id
        busyMessage = Translation.tr("Installing %1...").arg(installProc.profileName)
        yieldSettingsOverlayForPolkit()
        installProc.running = true
    }

    function clearBusyState() {
        busyProfileId = ""
        busyMessage = ""
    }

    function toast(text) {
        toastText = text
        toastTimer.restart()
    }

    function yieldSettingsOverlayForPolkit() {
        reopenSettingsOverlayAfterPolkit = GlobalStates.settingsOverlayOpen
        if (reopenSettingsOverlayAfterPolkit) {
            GlobalStates.settingsOverlayOpen = false
        }
    }

    function restoreSettingsOverlayAfterPolkit() {
        if (reopenSettingsOverlayAfterPolkit) {
            reopenSettingsOverlayAfterPolkit = false
            GlobalStates.settingsOverlayOpen = true
        }
    }

    Timer {
        id: toastTimer
        interval: 4500
        onTriggered: root.toastText = ""
    }

    Process {
        id: listProc
        property string output: ""

        stdout: SplitParser {
            onRead: data => listProc.output += data
        }

        onExited: code => {
            if (code !== 0) {
                root.toast(Translation.tr("Profile list failed (exit %1).").arg(code))
                return
            }

            try {
                root.profiles = JSON.parse(listProc.output.trim() || "[]")
            } catch (error) {
                root.profiles = []
                root.toast(Translation.tr("Profile list returned invalid data."))
            }
        }
    }

    Process {
        id: installProc
        property string profileId: ""
        property string profileName: ""

        onExited: code => {
            if (code === 0) {
                root.toast(Translation.tr("%1 installed.").arg(profileName))
            } else if (code === 126 || code === 127) {
                root.toast(Translation.tr("Install did not start (exit %1).").arg(code))
            } else {
                root.toast(Translation.tr("Install failed (exit %1). Connect internet and retry.").arg(code))
            }

            root.clearBusyState()
            root.restoreSettingsOverlayAfterPolkit()
            root.refreshProfiles()
        }
    }

    Component.onCompleted: refreshProfiles()

    onVisibleChanged: if (visible) refreshProfiles()

    Rectangle {
        visible: root.busyMessage.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            StyledText {
                text: Translation.tr("Working")
                color: Appearance.colors.colPrimary
                font.pixelSize: 12
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: root.busyMessage
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                StyledIndeterminateProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.profiles.length === 0 && !listProc.running
        expanded: true
        icon: "extension"
        title: Translation.tr("Profiles")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("No install profiles were found.")
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }

    Repeater {
        model: root.profiles
        delegate: ProfileCard {
            profile: modelData
            busy: root.busyProfileId === modelData.id
            onInstallProfile: root.installProfile(modelData)
        }
    }

    Rectangle {
        visible: root.toastText.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer1

        StyledText {
            anchors.centerIn: parent
            text: root.toastText
            font.pixelSize: 12
        }
    }

    component ProfileCard: SettingsCardSection {
        id: cardRoot
        property var profile
        property bool busy: false

        signal installProfile()

        Layout.fillWidth: true
        expanded: true
        icon: profile.icon || "extension"
        title: profile.name || profile.id

        SettingsGroup {
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledText {
                    Layout.fillWidth: true
                    text: profile.description || ""
                    wrapMode: Text.WordWrap
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 13
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: profile.tags || []

                        Rectangle {
                            radius: 999
                            color: root.colorWithAlpha(Appearance.colors.colPrimary, 0.14)
                            implicitWidth: tagText.implicitWidth + 16
                            implicitHeight: tagText.implicitHeight + 6

                            StyledText {
                                id: tagText
                                anchors.centerIn: parent
                                text: modelData
                                color: Appearance.colors.colPrimary
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    PackageList {
                        title: Translation.tr("Official packages")
                        icon: "inventory_2"
                        packages: profile.packages || []
                    }

                    PackageList {
                        title: Translation.tr("AUR packages")
                        icon: "deployed_code"
                        packages: profile.aurPackages || []
                    }

                    PackageList {
                        title: Translation.tr("BlackArch packages")
                        icon: "security"
                        packages: profile.blackarchPackages || []
                    }

                    PackageList {
                        title: Translation.tr("Hardware add-ons")
                        icon: "memory"
                        packages: profile.hardwarePackages || []
                    }
                }

                RowLayout {
                    visible: cardRoot.busy
                    Layout.fillWidth: true
                    spacing: 10

                    StyledIndeterminateProgressBar {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 4
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.busyMessage
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        radius: 999
                        color: root.colorWithAlpha(root.statusColor(profile), 0.16)
                        border.width: profile.installed === true ? 0 : 1
                        border.color: root.statusColor(profile)
                        implicitWidth: statusText.implicitWidth + 16
                        implicitHeight: statusText.implicitHeight + 6

                        StyledText {
                            id: statusText
                            anchors.centerIn: parent
                            text: root.statusLabel(profile)
                            color: root.statusColor(profile)
                            font.pixelSize: 11
                            font.bold: profile.installed === true
                        }
                    }

                    StyledText {
                        visible: profile.packageCount > 0
                        text: Translation.tr("%1 packages").arg(profile.packageCount)
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 12
                    }

                    StyledText {
                        visible: profile.missingCount > 0 && profile.missingCount !== profile.packageCount
                        text: Translation.tr("%1 missing").arg(profile.missingCount)
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 12
                    }

                    StyledText {
                        visible: profile.installed === true && profile.rebootRecommended === true
                        text: Translation.tr("Reboot recommended")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    RippleButtonWithIcon {
                        enabled: !root.workflowRunning
                        materialIcon: profile.installed === true ? "settings_backup_restore" : "download"
                        mainText: profile.installed === true ? Translation.tr("Re-run") : Translation.tr("Install")
                        onClicked: cardRoot.installProfile()
                    }
                }
            }
        }
    }

    component PackageList: ColumnLayout {
        id: listRoot
        property string title: ""
        property string icon: "inventory_2"
        property var packages: []
        property int previewLimit: 18
        property bool expanded: false
        readonly property int packageCount: root.arrayCount(packages)
        readonly property int hiddenCount: Math.max(0, packageCount - previewLimit)

        function visiblePackages() {
            if (!packages) return []
            if (expanded || hiddenCount === 0) return packages
            return packages.slice(0, previewLimit)
        }

        visible: packageCount > 0
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: listRoot.icon
                iconSize: 17
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: listRoot.title
                color: Appearance.colors.colOnLayer1
                font.pixelSize: 12
                font.bold: true
            }

            Rectangle {
                radius: 999
                color: root.colorWithAlpha(Appearance.colors.colSubtext, 0.12)
                implicitWidth: countText.implicitWidth + 12
                implicitHeight: countText.implicitHeight + 4

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: listRoot.packageCount
                    color: Appearance.colors.colSubtext
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            StyledText {
                visible: !listRoot.expanded && listRoot.hiddenCount > 0
                text: Translation.tr("%1 shown").arg(listRoot.previewLimit)
                color: Appearance.colors.colSubtext
                font.pixelSize: 11
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                visible: listRoot.hiddenCount > 0
                implicitWidth: expandRow.implicitWidth + 18
                implicitHeight: 28
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: listRoot.expanded = !listRoot.expanded

                contentItem: RowLayout {
                    id: expandRow
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: listRoot.expanded
                            ? Translation.tr("Show less")
                            : Translation.tr("Show all")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MaterialSymbol {
                        text: listRoot.expanded ? "expand_less" : "expand_more"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: listRoot.visiblePackages()

                Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    width: Math.min(packageText.implicitWidth + 12, Math.max(120, listRoot.width - 24))
                    height: packageText.implicitHeight + 6

                    StyledText {
                        id: packageText
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 11
                    }
                }
            }
        }

        StyledText {
            visible: !listRoot.expanded && listRoot.hiddenCount > 0
            Layout.fillWidth: true
            text: Translation.tr("%1 more hidden in this group.").arg(listRoot.hiddenCount)
            color: Appearance.colors.colSubtext
            font.pixelSize: 11
        }
    }
}
