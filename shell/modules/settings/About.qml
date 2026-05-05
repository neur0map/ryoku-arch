import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ContentPage {
    settingsPageIndex: 13
    settingsPageName: Translation.tr("About")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ── Top row: Ryoku hero (2/3) + System info (1/3) ──────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 280
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

                    // Spacer
                    Item { Layout.fillHeight: true }

                    // Action buttons
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        RippleButtonWithIcon {
                            materialIcon: "auto_stories"
                            mainText: Translation.tr("Documentation")
                            onClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch")
                        }

                        RippleButtonWithIcon {
                            materialIcon: "bug_report"
                            mainText: Translation.tr("Issues")
                            onClicked: Qt.openUrlExternally("https://github.com/neur0map/ryoku-arch/issues")
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
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        RippleButtonWithIcon {
                            visible: SystemInfo.documentationUrl && SystemInfo.documentationUrl.length > 0
                            materialIcon: "auto_stories"
                            mainText: Translation.tr("Documentation")
                            onClicked: Qt.openUrlExternally(SystemInfo.documentationUrl)
                        }

                        RippleButtonWithIcon {
                            visible: SystemInfo.supportUrl && SystemInfo.supportUrl.length > 0
                            materialIcon: "support"
                            mainText: Translation.tr("Help & Support")
                            onClicked: Qt.openUrlExternally(SystemInfo.supportUrl)
                        }

                        RippleButtonWithIcon {
                            visible: SystemInfo.bugReportUrl && SystemInfo.bugReportUrl.length > 0
                            materialIcon: "bug_report"
                            mainText: Translation.tr("Report a Bug")
                            onClicked: Qt.openUrlExternally(SystemInfo.bugReportUrl)
                        }
                    }
                }
            }
        }

        // ── Bottom row: iNiR + illogical-impulse credit cards ───────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            spacing: 16

            // ── iNiR credit card ────────────────────────────────────────────
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
                    }

                    StyledText {
                        text: Translation.tr("Upstream desktop shell")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        text: "[github.com/snowarch/iNiR](https://github.com/snowarch/iNiR)"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3primary
                        textFormat: Text.MarkdownText
                        onLinkActivated: (link) => Qt.openUrlExternally(link)

                        PointingHandLinkHover {}
                    }

                    Item { Layout.fillHeight: true }

                    RippleButtonWithIcon {
                        materialIcon: "open_in_new"
                        mainText: "iNiR"
                        onClicked: Qt.openUrlExternally("https://github.com/snowarch/iNiR")
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

                    RippleButtonWithIcon {
                        materialIcon: "open_in_new"
                        mainText: "illogical-impulse"
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

                    RippleButtonWithIcon {
                        materialIcon: "open_in_new"
                        mainText: "Omarchy"
                        onClicked: Qt.openUrlExternally("https://github.com/basecamp/omarchy")
                    }
                }
            }
        }
    }
}
