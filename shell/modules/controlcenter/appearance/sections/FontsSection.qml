pragma ComponentBehavior: Bound

import ".."
import "../../components"
import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

CollapsibleSection {
    id: root

    required property var rootPane
    readonly property var availableFontFamilies: Qt.fontFamilies().filter(f => f && f.trim()).sort((a, b) => a.localeCompare(b))

    function fontModel(current: string, preferred: var): var {
        const seen = new Set();
        const result = [];
        const add = font => {
            if (!font || seen.has(font))
                return;

            seen.add(font);
            result.push(font);
        };

        for (const font of preferred) {
            if (availableFontFamilies.includes(font))
                add(font);
        }

        add(current);
        for (const font of availableFontFamilies)
            add(font);

        return result;
    }

    function materialFontModel(current: string): var {
        const seen = new Set();
        const result = [];
        const add = font => {
            if (!font || seen.has(font))
                return;

            seen.add(font);
            result.push(font);
        };

        for (const font of ["Material Symbols Rounded", "Material Symbols Outlined"]) {
            if (availableFontFamilies.includes(font))
                add(font);
        }

        add(current);
        for (const font of availableFontFamilies.filter(f => f.startsWith("Material Symbols")))
            add(font);

        return result;
    }

    title: qsTr("Fonts")
    showBackground: true

    CollapsibleSection {
        id: sansFontSection

        title: qsTr("Sans-serif font family")
        expanded: true
        showBackground: true
        nested: true

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: item ? Math.min(item.contentHeight, 300) : 0
            asynchronous: true
            active: sansFontSection.expanded

            sourceComponent: StyledListView {
                id: sansFontList

                clip: true
                spacing: Tokens.spacing.small / 2
                model: root.fontModel(rootPane.fontFamilySans, ["Rubik", "Adwaita Sans", "Noto Sans", "DejaVu Sans"])

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: sansFontList
                }

                delegate: StyledRect {
                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: modelData === rootPane.fontFamilySans

                    width: ListView.view.width
                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Tokens.rounding.normal
                    border.width: isCurrent ? 1 : 0
                    border.color: Colours.palette.m3primary
                    implicitHeight: fontFamilySansRow.implicitHeight + Tokens.padding.normal * 2

                    StateLayer {
                        onClicked: {
                            rootPane.fontFamilySans = modelData;
                            rootPane.saveConfig();
                        }
                    }

                    RowLayout {
                        id: fontFamilySansRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.normal

                        spacing: Tokens.spacing.normal

                        StyledText {
                            text: modelData
                            font.pointSize: Tokens.font.size.normal
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Loader {
                            asynchronous: true
                            active: isCurrent

                            sourceComponent: MaterialIcon {
                                text: "check"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.large
                            }
                        }
                    }
                }
            }
        }
    }

    CollapsibleSection {
        id: monoFontSection

        title: qsTr("Monospace font family")
        expanded: false
        showBackground: true
        nested: true

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: item ? Math.min(item.contentHeight, 300) : 0
            asynchronous: true
            active: monoFontSection.expanded

            sourceComponent: StyledListView {
                id: monoFontList

                clip: true
                spacing: Tokens.spacing.small / 2
                model: root.fontModel(rootPane.fontFamilyMono, ["CaskaydiaCove Nerd Font", "CaskaydiaCove NF", "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font"])

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: monoFontList
                }

                delegate: StyledRect {
                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: modelData === rootPane.fontFamilyMono

                    width: ListView.view.width
                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Tokens.rounding.normal
                    border.width: isCurrent ? 1 : 0
                    border.color: Colours.palette.m3primary
                    implicitHeight: fontFamilyMonoRow.implicitHeight + Tokens.padding.normal * 2

                    StateLayer {
                        onClicked: {
                            rootPane.fontFamilyMono = modelData;
                            rootPane.saveConfig();
                        }
                    }

                    RowLayout {
                        id: fontFamilyMonoRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.normal

                        spacing: Tokens.spacing.normal

                        StyledText {
                            text: modelData
                            font.pointSize: Tokens.font.size.normal
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Loader {
                            asynchronous: true
                            active: isCurrent

                            sourceComponent: MaterialIcon {
                                text: "check"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.large
                            }
                        }
                    }
                }
            }
        }
    }

    CollapsibleSection {
        id: materialFontSection

        title: qsTr("Material font family")
        expanded: false
        showBackground: true
        nested: true

        Loader {
            id: materialFontLoader

            Layout.fillWidth: true
            Layout.preferredHeight: item ? Math.min(item.contentHeight, 300) : 0
            asynchronous: true
            active: materialFontSection.expanded

            sourceComponent: StyledListView {
                id: materialFontList

                clip: true
                spacing: Tokens.spacing.small / 2
                model: root.materialFontModel(rootPane.fontFamilyMaterial)

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: materialFontList
                }

                delegate: StyledRect {
                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: modelData === rootPane.fontFamilyMaterial

                    width: ListView.view.width
                    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, isCurrent ? Colours.tPalette.m3surfaceContainer.a : 0)
                    radius: Tokens.rounding.normal
                    border.width: isCurrent ? 1 : 0
                    border.color: Colours.palette.m3primary
                    implicitHeight: fontFamilyMaterialRow.implicitHeight + Tokens.padding.normal * 2

                    StateLayer {
                        onClicked: {
                            rootPane.fontFamilyMaterial = modelData;
                            rootPane.saveConfig();
                        }
                    }

                    RowLayout {
                        id: fontFamilyMaterialRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.normal

                        spacing: Tokens.spacing.normal

                        StyledText {
                            text: modelData
                            font.pointSize: Tokens.font.size.normal
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Loader {
                            asynchronous: true
                            active: isCurrent

                            sourceComponent: MaterialIcon {
                                text: "check"
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.large
                            }
                        }
                    }
                }
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Font size scale")
            value: rootPane.fontSizeScale
            from: 0.7
            to: 1.5
            decimals: 2
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.7
                top: 1.5
            }

            onValueModified: newValue => {
                rootPane.fontSizeScale = newValue;
                rootPane.saveConfig();
            }
        }
    }
}
