pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.services
import qs.modules.controlcenter

Item {
    id: root

    required property ShellScreen screen
    required property Session session
    required property bool initialOpeningComplete

    readonly property var activeEntry: PaneRegistry.getByLabel(session.active)

    function selectGroup(group: string): void {
        if (!root.initialOpeningComplete)
            return;

        const panes = PaneRegistry.getByGroup(group);
        if (panes.length > 0)
            root.session.active = panes[0].label;
    }

    implicitWidth: 216
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.normal
            spacing: Tokens.spacing.normal

            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 40
                implicitHeight: 40
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "tune"
                    color: Colours.palette.m3onPrimaryContainer
                    font.pointSize: Tokens.font.size.large
                    fill: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Settings")
                    font.pointSize: Tokens.font.size.larger
                    font.weight: 600
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Ryoku")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    elide: Text.ElideRight
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            asynchronous: true
            active: !root.session.floating
            visible: active

            sourceComponent: StyledRect {
                Layout.fillWidth: true
                implicitHeight: 42
                color: Colours.palette.m3primaryContainer
                radius: Tokens.rounding.small

                StateLayer {
                    id: normalWinState

                    onClicked: {
                        root.session.root.close();
                        WindowFactory.close();
                        WindowFactory.open(null, {
                            active: root.session.active,
                            navExpanded: root.session.navExpanded
                        });
                    }

                    color: Colours.palette.m3onPrimaryContainer
                }

                MaterialIcon {
                    id: normalWinIcon

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.normal

                    text: "select_window"
                    color: Colours.palette.m3onPrimaryContainer
                    font.pointSize: Tokens.font.size.large
                    fill: 1
                }

                StyledText {
                    id: normalWinLabel

                    anchors.left: normalWinIcon.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.spacing.normal

                    text: qsTr("Float window")
                    color: Colours.palette.m3onPrimaryContainer
                    font.weight: 500
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.normal
            color: Colours.transparency.enabled ? Colours.layer(Colours.palette.m3surfaceContainer, 1) : Colours.tPalette.m3surfaceContainerLow

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.normal
                spacing: Tokens.spacing.normal

                CategoryItem {
                    Layout.fillWidth: true
                    group: "system"
                    icon: PaneRegistry.groupIcon("system")
                    label: PaneRegistry.groupLabel("system")
                }

                CategoryItem {
                    Layout.fillWidth: true
                    group: "interface"
                    icon: PaneRegistry.groupIcon("interface")
                    label: PaneRegistry.groupLabel("interface")
                }

                CategoryItem {
                    Layout.fillWidth: true
                    group: "workflow"
                    icon: PaneRegistry.groupIcon("workflow")
                    label: PaneRegistry.groupLabel("workflow")
                }

                CategoryItem {
                    Layout.fillWidth: true
                    group: "about"
                    icon: PaneRegistry.groupIcon("about")
                    label: PaneRegistry.groupLabel("about")
                }
            }
        }
    }

    component CategoryItem: Item {
        id: item

        required property string group
        required property string icon
        required property string label

        readonly property bool active: root.activeEntry !== null && root.activeEntry.group === group

        implicitHeight: 56

        StyledRect {
            id: background

            anchors.fill: parent
            radius: Tokens.rounding.small
            color: item.active ? Colours.palette.m3secondaryContainer : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)

            StateLayer {
                onClicked: {
                    root.selectGroup(item.group);
                }

                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                radius: background.radius
            }

            RowLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.normal
                spacing: Tokens.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: item.icon
                    color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.size.large
                    fill: item.active ? 1 : 0

                    Behavior on fill {
                        Anim {}
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: item.label
                    color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                    font.weight: item.active ? 650 : 500
                    elide: Text.ElideRight
                }
            }
        }
    }
}
