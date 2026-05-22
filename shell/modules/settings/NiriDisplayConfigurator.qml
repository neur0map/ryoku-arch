import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ColumnLayout {
    id: root

    required property var pageRoot

    spacing: 14

    function outputPhysicalSize(output) {
        const resolution = output?.current_resolution ?? ""
        const match = String(resolution).match(/^(\d+)x(\d+)$/)
        if (match)
            return { w: Number(match[1]), h: Number(match[2]) }
        const resolutions = output?.resolutions ?? []
        if (resolutions.length > 0)
            return { w: Number(resolutions[0].width ?? 1920), h: Number(resolutions[0].height ?? 1080) }
        return { w: 1920, h: 1080 }
    }

    function outputIsRotated(output) {
        const transform = String(output?.transform ?? "normal").toLowerCase()
        return transform === "90" || transform === "270" || transform === "flipped-90" || transform === "flipped-270"
    }

    function outputLogicalSize(output) {
        const physical = outputPhysicalSize(output)
        const scale = Math.max(0.25, Number(output?.scale ?? 1))
        const size = outputIsRotated(output)
            ? { w: physical.h, h: physical.w }
            : physical
        return {
            w: Math.max(1, Math.round(size.w / scale)),
            h: Math.max(1, Math.round(size.h / scale))
        }
    }

    function outputBounds(outputs) {
        if (!outputs || outputs.length === 0)
            return { minX: 0, minY: 0, width: 1920, height: 1080 }

        let minX = Infinity
        let minY = Infinity
        let maxX = -Infinity
        let maxY = -Infinity

        for (const output of outputs) {
            const pos = output?.position ?? ({ x: 0, y: 0 })
            const size = outputLogicalSize(output)
            minX = Math.min(minX, Number(pos.x ?? 0))
            minY = Math.min(minY, Number(pos.y ?? 0))
            maxX = Math.max(maxX, Number(pos.x ?? 0) + size.w)
            maxY = Math.max(maxY, Number(pos.y ?? 0) + size.h)
        }

        if (minX === Infinity)
            return { minX: 0, minY: 0, width: 1920, height: 1080 }

        return {
            minX: minX,
            minY: minY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        }
    }

    function selectOutput(outputName) {
        const idx = pageRoot.outputList.findIndex(output => output.name === outputName)
        if (idx >= 0)
            pageRoot.selectedOutputIndex = idx
    }

    function displayActionTextColor(preferredTextColor, buttonColor) {
        return ColorUtils.ensureReadable(preferredTextColor, buttonColor, 4.5)
    }

    StyledText {
        Layout.fillWidth: true
        text: Translation.tr("Arrange monitors visually, then apply all pending display changes as one live preview. If the layout breaks, Ryoku reverts automatically after 10 seconds.")
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
        wrapMode: Text.WordWrap
    }

    Rectangle {
        id: monitorPanel

        Layout.fillWidth: true
        implicitHeight: 288
        radius: Appearance.rounding.large
        color: SettingsMaterialPreset.cardColor
        border.width: 1
        border.color: SettingsMaterialPreset.cardBorderColor
        clip: true

        readonly property var outputs: root.pageRoot.effectiveOutputList
        readonly property var bounds: root.outputBounds(outputs)
        readonly property real scaleFactor: {
            const usableW = Math.max(1, width - 48)
            const usableH = Math.max(1, height - 48)
            return Math.min(usableW / bounds.width, usableH / bounds.height)
        }
        readonly property real offsetX: (width - bounds.width * scaleFactor) / 2 - bounds.minX * scaleFactor
        readonly property real offsetY: (height - bounds.height * scaleFactor) / 2 - bounds.minY * scaleFactor

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colLayer1
            opacity: 0.35
        }

        Repeater {
            model: monitorPanel.outputs

            delegate: MonitorRect {
                required property var modelData

                pageRoot: root.pageRoot
                outputData: modelData
                canvasScaleFactor: monitorPanel.scaleFactor
                canvasOffset: Qt.point(monitorPanel.offsetX, monitorPanel.offsetY)
                logicalSize: root.outputLogicalSize(modelData)
                selected: root.pageRoot.currentOutputName === modelData.name
                onSelectedOutput: root.selectOutput(outputName)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: root.pageRoot.outputList.length > 0

        StyledText {
            Layout.fillWidth: true
            text: root.pageRoot.displayPendingChangeCount > 0
                ? Translation.tr("%1 pending display changes").arg(root.pageRoot.displayPendingChangeCount)
                : Translation.tr("No pending display changes")
            color: root.pageRoot.displayPendingChangeCount > 0
                ? Appearance.colors.colPrimary
                : Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }

        Button {
            visible: root.pageRoot.displayPendingChangeCount > 0
            enabled: root.pageRoot.displayPendingChangeCount > 0 && !root.pageRoot.displayControlsLocked
            text: Translation.tr("Discard")
            onClicked: root.pageRoot.clearDisplayDraft()

            background: Rectangle {
                id: discardButtonBg
                implicitWidth: 86
                implicitHeight: 36
                radius: Appearance.rounding.small
                color: parent.enabled ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
            }

            contentItem: StyledText {
                text: parent.text
                color: root.displayActionTextColor(
                    parent.enabled ? SettingsMaterialPreset.titleExpandedColor : SettingsMaterialPreset.titleCollapsedColor,
                    discardButtonBg.color
                )
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
        }

        Button {
            visible: root.pageRoot.displayPendingChangeCount > 0
            enabled: root.pageRoot.displayPendingChangeCount > 0 && !root.pageRoot.displayControlsLocked
            text: Translation.tr("Apply changes")
            onClicked: root.pageRoot.applyDisplayDraft()

            background: Rectangle {
                id: applyButtonBg
                implicitWidth: 128
                implicitHeight: 36
                radius: Appearance.rounding.small
                color: parent.enabled ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
            }

            contentItem: StyledText {
                text: parent.text
                color: root.displayActionTextColor(
                    parent.enabled ? Appearance.colors.colOnPrimary : SettingsMaterialPreset.titleCollapsedColor,
                    applyButtonBg.color
                )
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
        }
    }

    Repeater {
        model: root.pageRoot.effectiveOutputList

        delegate: OutputCard {
            required property var modelData

            Layout.fillWidth: true
            pageRoot: root.pageRoot
            outputData: modelData
            selected: root.pageRoot.currentOutputName === modelData.name
            onSelectedOutput: root.selectOutput(outputName)
        }
    }

    MaterialPlaceholderMessage {
        Layout.fillWidth: true
        shown: root.pageRoot.outputReady && root.pageRoot.outputList.length === 0
        icon: "monitor"
        text: Translation.tr("No connected displays")
        explanation: Translation.tr("Ryoku did not receive output data from Niri.")
    }

    component MonitorRect: Rectangle {
        id: monitorRect

        required property var pageRoot
        required property var outputData
        required property real canvasScaleFactor
        required property point canvasOffset
        required property var logicalSize
        property bool selected: false
        property bool dragging: false
        property point originalLogical: Qt.point(0, 0)

        signal selectedOutput(string outputName)

        x: dragging ? x : Number(outputData?.position?.x ?? 0) * canvasScaleFactor + canvasOffset.x
        y: dragging ? y : Number(outputData?.position?.y ?? 0) * canvasScaleFactor + canvasOffset.y
        width: Math.max(88, logicalSize.w * canvasScaleFactor)
        height: Math.max(58, logicalSize.h * canvasScaleFactor)
        radius: Appearance.rounding.small
        color: monitorRect.dragging ? SettingsMaterialPreset.headerHoverColor : SettingsMaterialPreset.groupColor
        border.width: selected || dragging ? 2 : 1
        border.color: selected || dragging ? SettingsMaterialPreset.accentColor : SettingsMaterialPreset.groupBorderColor
        z: dragging ? 10 : (selected ? 2 : 1)

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "monitor"
                iconSize: Math.min(Appearance.font.pixelSize.hugeass, Math.max(18, parent.width * 0.2))
                color: SettingsMaterialPreset.iconExpandedColor
            }

            StyledText {
                Layout.fillWidth: true
                text: monitorRect.outputData?.name ?? ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                color: SettingsMaterialPreset.titleExpandedColor
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }

            StyledText {
                Layout.fillWidth: true
                text: monitorRect.outputData?.current_resolution ?? ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: SettingsMaterialPreset.titleCollapsedColor
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent
            enabled: !monitorRect.pageRoot.displayControlsLocked
            hoverEnabled: true
            cursorShape: monitorRect.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: monitorRect
            drag.axis: Drag.XAndYAxis
            drag.threshold: 0

            onPressed: {
                monitorRect.selectedOutput(monitorRect.outputData.name)
                monitorRect.dragging = true
                monitorRect.originalLogical = Qt.point(
                    Number(monitorRect.outputData?.position?.x ?? 0),
                    Number(monitorRect.outputData?.position?.y ?? 0)
                )
            }

            onReleased: {
                if (!monitorRect.dragging)
                    return

                monitorRect.dragging = false
                const xValue = Math.round((monitorRect.x - monitorRect.canvasOffset.x) / monitorRect.canvasScaleFactor)
                const yValue = Math.round((monitorRect.y - monitorRect.canvasOffset.y) / monitorRect.canvasScaleFactor)
                if (xValue === monitorRect.originalLogical.x && yValue === monitorRect.originalLogical.y)
                    return
                monitorRect.pageRoot.stageDisplayChange(monitorRect.outputData.name, "position", `${xValue},${yValue}`)
            }
        }
    }

    component OutputCard: Rectangle {
        id: outputCard

        required property var pageRoot
        required property var outputData
        property bool selected: false
        property bool ready: false

        signal selectedOutput(string outputName)

        implicitHeight: cardColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: SettingsMaterialPreset.groupColor
        border.width: 1
        border.color: selected ? SettingsMaterialPreset.accentColor : SettingsMaterialPreset.groupBorderColor

        Component.onCompleted: ready = true

        ColumnLayout {
            id: cardColumn

            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: "monitor"
                    iconSize: Appearance.font.pixelSize.hugeass
                    color: SettingsMaterialPreset.iconExpandedColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: outputCard.outputData?.name ?? ""
                        color: SettingsMaterialPreset.titleExpandedColor
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const output = outputCard.outputData
                            const makeModel = `${output?.make ?? ""} ${output?.model ?? ""}`.trim()
                            const phys = output?.physical_size ?? [0, 0]
                            if (phys[0] > 0 && phys[1] > 0) {
                                const diag = Math.sqrt(phys[0] * phys[0] + phys[1] * phys[1]) / 25.4
                                return `${makeModel} - ${diag.toFixed(1)}"`
                            }
                            return makeModel
                        }
                        color: SettingsMaterialPreset.titleCollapsedColor
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    visible: outputCard.pageRoot.displayPendingChanges[outputCard.outputData.name] !== undefined
                    text: Translation.tr("Pending")
                    color: SettingsMaterialPreset.accentColor
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: outputCard.width < 720 ? 1 : 2
                rowSpacing: 10
                columnSpacing: 10

                DisplayField {
                    Layout.fillWidth: true
                    title: Translation.tr("Resolution")

                    StyledComboBox {
                        Layout.fillWidth: true
                        enabled: !outputCard.pageRoot.displayControlsLocked
                        model: outputCard.pageRoot.resolutionOptionsForOutput(outputCard.outputData)
                        textRole: "displayName"
                        currentIndex: outputCard.pageRoot.optionIndex(model, outputCard.outputData?.current_resolution ?? "")
                        onActivated: {
                            const selected = model[currentIndex]
                            const match = outputCard.outputData?.resolutions?.find(r => `${r.width}x${r.height}` === selected.value)
                            if (match?.rates?.length > 0) {
                                const best = match.rates.reduce((a, b) => a.rate > b.rate ? a : b)
                                outputCard.pageRoot.stageDisplayChange(outputCard.outputData.name, "mode", `${selected.value}@${best.rate_string ?? Number(best.rate).toFixed(3)}`)
                            }
                        }
                    }
                }

                DisplayField {
                    Layout.fillWidth: true
                    title: Translation.tr("Refresh rate")
                    visible: outputCard.pageRoot.refreshOptionsForOutput(outputCard.outputData, outputCard.outputData?.current_resolution ?? "").length > 1

                    StyledComboBox {
                        Layout.fillWidth: true
                        enabled: !outputCard.pageRoot.displayControlsLocked
                        model: outputCard.pageRoot.refreshOptionsForOutput(outputCard.outputData, outputCard.outputData?.current_resolution ?? "")
                        textRole: "displayName"
                        currentIndex: outputCard.pageRoot.optionIndex(model, outputCard.outputData?.current_rate ?? 0)
                        onActivated: outputCard.pageRoot.stageDisplayChange(outputCard.outputData.name, "mode", `${outputCard.outputData.current_resolution}@${model[currentIndex].rateString}`)
                    }
                }

                DisplayField {
                    Layout.fillWidth: true
                    title: Translation.tr("Scale")

                    StyledComboBox {
                        Layout.fillWidth: true
                        enabled: !outputCard.pageRoot.displayControlsLocked
                        model: outputCard.pageRoot.scaleOptions
                        textRole: "displayName"
                        currentIndex: outputCard.pageRoot.optionIndex(model, outputCard.outputData?.scale ?? 1)
                        onActivated: outputCard.pageRoot.stageDisplayChange(outputCard.outputData.name, "scale", String(model[currentIndex].value))
                    }
                }

                DisplayField {
                    Layout.fillWidth: true
                    title: Translation.tr("Rotation")

                    StyledComboBox {
                        Layout.fillWidth: true
                        enabled: !outputCard.pageRoot.displayControlsLocked
                        model: outputCard.pageRoot.transformOptions
                        textRole: "displayName"
                        currentIndex: outputCard.pageRoot.optionIndex(model, String(outputCard.outputData?.transform ?? "normal").toLowerCase())
                        onActivated: outputCard.pageRoot.stageDisplayChange(outputCard.outputData.name, "transform", model[currentIndex].value)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ConfigSpinBox {
                    id: positionXSpin
                    Layout.fillWidth: true
                    enabled: !outputCard.pageRoot.displayControlsLocked
                    text: "X"
                    value: outputCard.outputData?.position?.x ?? 0
                    from: -10000
                    to: 10000
                    stepSize: 10
                    onValueChanged: {
                        if (!outputCard.ready || !outputCard.pageRoot.outputReady)
                            return
                        outputCard.pageRoot.stageDisplayChange(outputCard.outputData.name, "position", `${value},${positionYSpin.value}`)
                    }
                }

                ConfigSpinBox {
                    id: positionYSpin
                    Layout.fillWidth: true
                    enabled: !outputCard.pageRoot.displayControlsLocked
                    text: "Y"
                    value: outputCard.outputData?.position?.y ?? 0
                    from: -10000
                    to: 10000
                    stepSize: 10
                    onValueChanged: {
                        if (!outputCard.ready || !outputCard.pageRoot.outputReady)
                            return
                        outputCard.pageRoot.stageDisplayChange(outputCard.outputData.name, "position", `${positionXSpin.value},${value}`)
                    }
                }

                SettingsSwitch {
                    Layout.fillWidth: true
                    visible: outputCard.outputData?.vrr_supported ?? false
                    enabled: !outputCard.pageRoot.displayControlsLocked
                    buttonIcon: "display_settings"
                    text: Translation.tr("VRR")
                    checked: outputCard.outputData?.vrr_enabled ?? false
                    onCheckedChanged: {
                        if (!outputCard.ready || !outputCard.pageRoot.outputReady)
                            return
                        outputCard.pageRoot.stageDisplayChange(outputCard.outputData.name, "vrr", checked ? "on" : "off")
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: outputCard.selectedOutput(outputCard.outputData.name)
        }
    }

    component DisplayField: ColumnLayout {
        id: displayField

        property string title: ""

        spacing: 4

        StyledText {
            Layout.fillWidth: true
            text: displayField.title
            color: SettingsMaterialPreset.titleCollapsedColor
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
        }
    }
}
