pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property string configEntryName
    required property var manifestKeys
    property var readConfigKey: null

    implicitWidth: _col.implicitWidth
    implicitHeight: _col.implicitHeight

    Column {
        id: _col
        spacing: 4

        Repeater {
            model: root.manifestKeys

            Item {
                id: keyDelegate
                required property var modelData
                readonly property string cfgKey: modelData.key
                readonly property var spec: modelData.spec
                readonly property string cfgType: spec?.type ?? "bool"
                readonly property string label: spec?.label ?? cfgKey
                readonly property var currentVal: root.readConfigKey ? root.readConfigKey(cfgKey) : spec?.["default"]
                readonly property bool isBool: cfgType === "bool"
                readonly property bool isNumeric: cfgType === "int" || cfgType === "real" || cfgType === "number"
                readonly property bool isString: cfgType === "string"
                readonly property bool hasOptions: Array.isArray(spec?.options) && spec.options.length > 0
                readonly property bool isUnsupported: !isBool && !isNumeric && !(isString && hasOptions)

                width: _content.implicitWidth
                height: _content.implicitHeight

                function optionValue(option) {
                    if (option && typeof option === "object")
                        return option.value ?? option.id ?? option.name ?? option.label ?? "";
                    return option ?? "";
                }

                function optionLabel(option) {
                    if (option && typeof option === "object")
                        return option.label ?? option.displayName ?? option.name ?? option.value ?? "";
                    return String(option ?? "");
                }

                function numericValue() {
                    const fallback = Number(spec?.["default"] ?? 0);
                    const value = Number(currentVal ?? fallback);
                    if (isNaN(value))
                        return isNaN(fallback) ? 0 : fallback;
                    return value;
                }

                function writeConfigValue(value) {
                    Config.setNestedValue("background.widgets." + root.configEntryName + "." + cfgKey, value);
                }

                Row {
                    id: _content
                    spacing: 4

                    // Bool: toggle button
                    RippleButton {
                        visible: keyDelegate.isBool
                        width: visible ? Math.max(100, _boolLabel.implicitWidth + 16) : 0; height: 28
                        buttonRadius: Appearance.rounding.small
                        toggled: Boolean(keyDelegate.currentVal)
                        colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => keyDelegate.writeConfigValue(!Boolean(keyDelegate.currentVal))
                        contentItem: StyledText {
                            id: _boolLabel
                            anchors.centerIn: parent
                            text: keyDelegate.label
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    // Numeric: label + -/value/+
                    StyledText {
                        visible: keyDelegate.isNumeric
                        anchors.verticalCenter: parent.verticalCenter
                        text: keyDelegate.label
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    RippleButton {
                        visible: keyDelegate.isNumeric
                        width: visible ? 24 : 0; height: 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.06)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        downAction: () => {
                            const step = keyDelegate.spec?.step ?? 1;
                            const min = keyDelegate.spec?.min ?? -Infinity;
                            keyDelegate.writeConfigValue(Math.max(min, keyDelegate.numericValue() - step));
                        }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "remove"; iconSize: 14; color: Appearance.colors.colOnLayer2 }
                    }
                    StyledText {
                        visible: keyDelegate.isNumeric
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(keyDelegate.numericValue())
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.numbers
                    }
                    RippleButton {
                        visible: keyDelegate.isNumeric
                        width: visible ? 24 : 0; height: 24
                        buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.06)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                        downAction: () => {
                            const step = keyDelegate.spec?.step ?? 1;
                            const max = keyDelegate.spec?.max ?? Infinity;
                            keyDelegate.writeConfigValue(Math.min(max, keyDelegate.numericValue() + step));
                        }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "add"; iconSize: 14; color: Appearance.colors.colOnLayer2 }
                    }

                    // String with options: safe selector.
                    StyledText {
                        visible: keyDelegate.isString && keyDelegate.hasOptions
                        anchors.verticalCenter: parent.verticalCenter
                        text: keyDelegate.label
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    Repeater {
                        model: keyDelegate.isString && keyDelegate.hasOptions ? keyDelegate.spec.options : []

                        RippleButton {
                            id: optionButton
                            required property var modelData
                            readonly property var optionValue: keyDelegate.optionValue(modelData)
                            readonly property string optionLabel: keyDelegate.optionLabel(modelData)

                            width: Math.max(52, _optionLabel.implicitWidth + 16)
                            height: 24
                            buttonRadius: Appearance.rounding.full
                            toggled: String(keyDelegate.currentVal ?? keyDelegate.spec?.["default"] ?? "") === String(optionValue)
                            colBackground: toggled ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16) : ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.06)
                            colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.12)
                            colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                            downAction: () => keyDelegate.writeConfigValue(optionButton.optionValue)
                            contentItem: StyledText {
                                id: _optionLabel
                                anchors.centerIn: parent
                                text: optionButton.optionLabel
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }

                    // Unsupported or freeform string values are read-only here.
                    StyledText {
                        visible: keyDelegate.isUnsupported || (keyDelegate.isString && !keyDelegate.hasOptions)
                        anchors.verticalCenter: parent.verticalCenter
                        text: keyDelegate.label + ": " + String(keyDelegate.currentVal ?? keyDelegate.spec?.["default"] ?? "")
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, 0.62)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }
}
