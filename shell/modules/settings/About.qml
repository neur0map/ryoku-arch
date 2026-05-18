import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

ContentPage {
    settingsPageIndex: 14
    settingsPageName: Translation.tr("About")

    // Compact circle icon button used by every card in this page so the
    // bento grid stays consistent across windowed and floating settings
    // modes (same fixed 36x36 footprint regardless of card width).
    component CircleIconButton: RippleButton {
        property string materialIcon: ""
        property string tooltip: ""
        property color backgroundColor: Appearance.colors.colLayer2
        property color iconColor: Appearance.colors.colOnSecondaryContainer

        implicitWidth: 36
        implicitHeight: 36
        buttonRadius: width / 2
        colBackground: backgroundColor

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: materialIcon
            iconSize: Appearance.font.pixelSize.large
            color: iconColor
            fill: 1
        }

        StyledToolTip { text: tooltip }
    }

    component UpdateCheckButton: RippleButton {
        implicitWidth: updateCheckRow.implicitWidth + 24
        implicitHeight: 36
        buttonRadius: height / 2
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active
        enabled: !ShellUpdates.isChecking && !ShellUpdates.isUpdating && !ShellUpdates.managedExternally
        opacity: enabled ? 1.0 : 0.5

        contentItem: RowLayout {
            id: updateCheckRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: ShellUpdates.isChecking ? "sync" : "refresh"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSecondaryContainer
                fill: 1
            }

            StyledText {
                text: ShellUpdates.isChecking ? Translation.tr("Checking") : Translation.tr("Check updates")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideRight
            }
        }

        StyledToolTip {
            text: Translation.tr("Fetch the latest Ryoku update status")
        }
    }

    function openShellUpdateDetails(): void {
        if (Config.options?.settingsUi?.overlayMode ?? false) {
            ShellUpdates.openOverlay()
        } else {
            Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "shellUpdate", "open"])
        }
    }

    function checkShellUpdates(): void {
        ShellUpdates.check()
        if (!(Config.options?.settingsUi?.overlayMode ?? false)) {
            Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "shellUpdate", "check"])
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ── Top row: Ryoku hero (2/3) + System info (1/3) ──────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            spacing: 16

            // ── Ryoku hero card ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 2

                color: Appearance.colors.colSurfaceContainerLow
                radius: 20
                border.width: 1
                border.color: Appearance.m3colors.m3primary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    // Icon + title + version row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        // Round icon container
                        Rectangle {
                            width: 68
                            height: 68
                            radius: 34
                            color: "transparent"
                            border.width: 2
                            border.color: Appearance.m3colors.m3primary

                            Image {
                                id: projectIcon

                                anchors.centerIn: parent
                                width: 60
                                height: 60
                                sourceSize.width: 60
                                sourceSize.height: 60
                                source: Quickshell.shellPath("assets/icons/ryoku-symbolic.svg")
                                fillMode: Image.PreserveAspectFit
                                layer.enabled: Appearance.effectsEnabled

                                layer.effect: MultiEffect {
                                    maskEnabled: true

                                    maskSource: ShaderEffectSource {
                                        sourceItem: Rectangle {
                                            width: 60
                                            height: 60
                                            radius: 30
                                        }
                                    }
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: projectIcon.status !== Image.Ready
                                text: "deployed_code"
                                iconSize: 48
                                color: Appearance.m3colors.m3primary
                            }

                            // Avatar interaction easter-egg
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: _avatarFx.restart()
                            }

                            Text {
                                id: _avatarFxLabel
                                text: "🫃🏻"
                                font.pixelSize: Appearance.font.pixelSize.hugeass
                                anchors.centerIn: parent
                                visible: false
                                z: 10

                                SequentialAnimation {
                                    id: _avatarFx
                                    PropertyAction { target: _avatarFxLabel; property: "visible"; value: true }
                                    PropertyAction { target: _avatarFxLabel; property: "scale"; value: 0 }
                                    PropertyAction { target: _avatarFxLabel; property: "opacity"; value: 1 }
                                    NumberAnimation { target: _avatarFxLabel; property: "scale"; to: 1.5; duration: 300; easing.type: Easing.OutBack }
                                    NumberAnimation { target: _avatarFxLabel; property: "scale"; to: 1.0; duration: 200 }
                                    PauseAnimation { duration: 800 }
                                    ParallelAnimation {
                                        NumberAnimation { target: _avatarFxLabel; property: "opacity"; to: 0; duration: 400 }
                                        NumberAnimation { target: _avatarFxLabel; property: "scale"; to: 2.0; duration: 400 }
                                    }
                                    PropertyAction { target: _avatarFxLabel; property: "visible"; value: false }
                                }
                            }
                        }

                        // Name + version + branch
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            StyledText {
                                text: "Ryoku"
                                font.pixelSize: Appearance.font.pixelSize.title
                                color: Appearance.m3colors.m3primary
                            }

                            RowLayout {
                                spacing: 6

                                StyledText {
                                    text: "0.1.0-pre-alpha"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }

                                Rectangle {
                                    visible: ShellUpdates.currentBranch.length > 0
                                    implicitWidth: branchLabel.implicitWidth + 12
                                    implicitHeight: branchLabel.implicitHeight + 4
                                    radius: Appearance.rounding.small
                                    color: ShellUpdates.isNonMainBranch
                                        ? ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.8)
                                        : ColorUtils.transparentize(Appearance.colors.colSubtext, 0.85)

                                    StyledText {
                                        id: branchLabel
                                        anchors.centerIn: parent
                                        text: ShellUpdates.currentBranch
                                        font {
                                            pixelSize: Appearance.font.pixelSize.smallest
                                            family: Appearance.font.family.monospace
                                        }
                                        color: ShellUpdates.isNonMainBranch
                                            ? Appearance.m3colors.m3tertiary
                                            : Appearance.colors.colSubtext
                                    }
                                }
                            }

                            StyledText {
                                text: "[https://github.com/neur0map/ryoku-arch](https://github.com/neur0map/ryoku-arch)"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.m3colors.m3primary
                                textFormat: Text.MarkdownText
                                onLinkActivated: (link) => Qt.openUrlExternally(link)

                                PointingHandLinkHover {}
                            }
                        }
                    }

                    // Tagline (fills the breathing room above the action buttons)
                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        text: Translation.tr("An opinionated Arch Linux environment for security work, built around Niri and a cohesive visual system.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }

                    // Spacer
                    Item { Layout.fillHeight: true }

                    // Action buttons
                    Row {
                        Layout.fillWidth: true
                        spacing: 8

                        CircleIconButton {
                            materialIcon: "auto_stories"
                            tooltip: Translation.tr("Documentation")
                            onClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch")
                        }

                        CircleIconButton {
                            materialIcon: "bug_report"
                            tooltip: Translation.tr("Issues")
                            onClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch/issues")
                        }

                        UpdateCheckButton {
                            onClicked: checkShellUpdates()
                        }

                        CircleIconButton {
                            visible: ShellUpdates.hasUpdate
                            materialIcon: "upgrade"
                            tooltip: Translation.tr("Update available")
                            backgroundColor: ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.86)
                            iconColor: Appearance.m3colors.m3primary
                            enabled: !ShellUpdates.isUpdating
                            opacity: enabled ? 1.0 : 0.5
                            onClicked: {
                                openShellUpdateDetails()
                            }
                        }
                    }
                }
            }

            // ── System info card ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1

                color: Appearance.colors.colSurfaceContainerLow
                radius: 20
                border.width: 1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    // Distro icon
                    Item {
                        width: 48
                        height: 48

                        Image {
                            id: distroIconImage

                            anchors.fill: parent
                            sourceSize.width: 48
                            sourceSize.height: 48
                            source: Quickshell.shellPath(`assets/icons/${SystemInfo.distroIcon}.svg`)
                            fillMode: Image.PreserveAspectFit
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: distroIconImage
                            source: distroIconImage
                            colorization: 1
                            colorizationColor: Appearance.m3colors.m3primary
                            visible: distroIconImage.status === Image.Ready
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: distroIconImage.status !== Image.Ready
                            text: "computer"
                            iconSize: 48
                            color: Appearance.m3colors.m3primary
                        }
                    }

                    StyledText {
                        text: SystemInfo.distroName || "Linux"
                        font.pixelSize: Appearance.font.pixelSize.title
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    StyledText {
                        visible: SystemInfo.homeUrl && SystemInfo.homeUrl.length > 0
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        text: SystemInfo.homeUrl
                            ? `[${SystemInfo.homeUrl}](${SystemInfo.homeUrl})`
                            : ""
                        textFormat: Text.MarkdownText
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        onLinkActivated: (link) => Qt.openUrlExternally(link)

                        PointingHandLinkHover {}
                    }

                    Item { Layout.fillHeight: true }

                    // Action shortcuts: distro Documentation / Help / Bug
                    Row {
                        Layout.fillWidth: true
                        spacing: 8

                        CircleIconButton {
                            visible: SystemInfo.documentationUrl && SystemInfo.documentationUrl.length > 0
                            materialIcon: "auto_stories"
                            tooltip: Translation.tr("Documentation")
                            onClicked: Qt.openUrlExternally(SystemInfo.documentationUrl)
                        }

                        CircleIconButton {
                            visible: SystemInfo.bugReportUrl && SystemInfo.bugReportUrl.length > 0
                            materialIcon: "bug_report"
                            tooltip: Translation.tr("Report a Bug")
                            onClicked: Qt.openUrlExternally(SystemInfo.bugReportUrl)
                        }
                    }
                }
            }
        }

        // ── Bottom grid: integration credit cards ──────────────────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 456
            columns: 2
            rowSpacing: 16
            columnSpacing: 16

            // ── iNiR credit card ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Appearance.colors.colSurfaceContainerLow
                radius: 20
                border.width: 1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8

                    StyledText {
                        text: "iNiR"
                        font.pixelSize: Appearance.font.pixelSize.title
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    StyledText {
                        text: Translation.tr("Upstream Quickshell desktop shell")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: "[github.com/snowarch/inir](https://github.com/snowarch/inir)"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        textFormat: Text.MarkdownText
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        onLinkActivated: (link) => Qt.openUrlExternally(link)

                        PointingHandLinkHover {}
                    }

                    Item { Layout.fillHeight: true }

                    CircleIconButton {
                        materialIcon: "open_in_new"
                        tooltip: "iNiR"
                        onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir")
                    }
                }
            }

            // ── illogical-impulse credit card ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Appearance.colors.colSurfaceContainerLow
                radius: 20
                border.width: 1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8

                    StyledText {
                        text: "illogical-impulse"
                        font.pixelSize: Appearance.font.pixelSize.title
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }

                    StyledText {
                        text: Translation.tr("Original Hyprland configuration")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: "[github.com/end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        textFormat: Text.MarkdownText
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        onLinkActivated: (link) => Qt.openUrlExternally(link)

                        PointingHandLinkHover {}
                    }

                    Item { Layout.fillHeight: true }

                    CircleIconButton {
                        materialIcon: "open_in_new"
                        tooltip: "illogical-impulse"
                        onClicked: Qt.openUrlExternally("https://github.com/end-4/dots-hyprland")
                    }
                }
            }

            // ── Omarchy credit card ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Appearance.colors.colSurfaceContainerLow
                radius: 20
                border.width: 1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8

                    StyledText {
                        text: "Omarchy"
                        font.pixelSize: Appearance.font.pixelSize.title
                    }

                    StyledText {
                        text: Translation.tr("Opinionated Arch baseline")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: "[github.com/basecamp/omarchy](https://github.com/basecamp/omarchy)"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        textFormat: Text.MarkdownText
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        onLinkActivated: (link) => Qt.openUrlExternally(link)

                        PointingHandLinkHover {}
                    }

                    Item { Layout.fillHeight: true }

                    CircleIconButton {
                        materialIcon: "open_in_new"
                        tooltip: "Omarchy"
                        onClicked: Qt.openUrlExternally("https://github.com/basecamp/omarchy")
                    }
                }
            }

            // ── qylock credit card ─────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Appearance.colors.colSurfaceContainerLow
                radius: 20
                border.width: 1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8

                    StyledText {
                        text: "qylock"
                        font.pixelSize: Appearance.font.pixelSize.title
                    }

                    StyledText {
                        text: Translation.tr("Optional SDDM greeter themes by Darkkal44")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: "[github.com/Darkkal44/qylock](https://github.com/Darkkal44/qylock)"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        textFormat: Text.MarkdownText
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        onLinkActivated: (link) => Qt.openUrlExternally(link)

                        PointingHandLinkHover {}
                    }

                    Item { Layout.fillHeight: true }

                    CircleIconButton {
                        materialIcon: "open_in_new"
                        tooltip: "qylock"
                        onClicked: Qt.openUrlExternally("https://github.com/Darkkal44/qylock")
                    }
                }
            }
        }
    }
}
