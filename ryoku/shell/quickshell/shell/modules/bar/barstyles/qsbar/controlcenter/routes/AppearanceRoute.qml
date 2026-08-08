import QtQuick
import "../kit"
import "../../modules"

// APPEARANCE route: a scrollable per-widget list. One row per bar widget group
// with a visibility toggle (the mod* booleans), an assigned-accent control (the
// V2 per-widget colour system, reached through a small palette popover) and a
// density toggle where the widget supports it. Ported from Shibumi's
// WidgetAppearanceWorkbench, wearing qsbar's dark skin and driving `root` (the
// Theme) directly the same way the old V2 ControlPanel's WidgetStateTile did.
//
// The colour + density backends differ per variant: V2 exposes widget*() /
// iconOnly() / mprisBarStyle; V1 exposes plain compact* booleans and no colour
// system. Every helper call is capability-gated so the page loads clean under
// the V1 Theme (the offscreen probe) and drives live state under either variant.
Item {
    id: page
    property var root: null
    property var cc: null

    // Colour popover state (a single floating menu, addressed by widget group).
    property string colorGid: ""
    property string colorLabel: ""

    // Per-widget colour is a V2-only capability: the V1 Theme has no widget*()
    // helpers. Gate the whole accent affordance on it so V1 stays error-free.
    readonly property bool colorSupported: !!(page.root && page.root.widgetHasFill)

    // ── visibility (mod* booleans; present on both V1 and V2) ──
    function boolOf(prop) {
        return (page.root && prop !== "") ? page.root[prop] === true : false
    }
    function toggleMod(prop) {
        if (page.root && prop !== "" && page.root[prop] !== undefined)
            page.root[prop] = !page.root[prop]
    }

    // ── density (compact) — drive whichever mechanism the live Theme consumes ──
    // V2 renders one presentation toggled per-group via iconOnly()/mprisBarStyle;
    // V1 reads plain compact* booleans. `flag` is the V1 property name.
    function compactOf(gid, flag) {
        if (!page.root || flag === "") return false
        if (gid === "G9" && page.root.mprisBarStyle !== undefined)
            return page.root.mprisBarStyle === "full"
        if (page.root.iconOnly !== undefined)
            return page.root.iconOnly(gid) === true
        return page.root[flag] === true
    }
    function toggleCompact(gid, flag) {
        if (!page.root || flag === "") return
        if (gid === "G9" && page.root.mprisBarStyle !== undefined) {
            page.root.mprisBarStyle = (page.root.mprisBarStyle === "full") ? "default" : "full"
            return
        }
        if (page.root.toggleIconOnly !== undefined) { page.root.toggleIconOnly(gid); return }
        if (page.root[flag] !== undefined) page.root[flag] = !page.root[flag]
    }

    // ── one widget row: label, then a right cluster of palette / eye / density.
    // Lifted from the old ControlPanel WidgetStateTile, stretched full-width and
    // made capability-aware. Kept in THIS file per the route contract.
    component WidgetRow: Rectangle {
        id: wr
        property string modProp: ""
        property string gid: ""
        property string flag: ""
        property string title: ""
        property string offLabel: "Full"
        property string onLabel: "Icon"

        readonly property bool shown: page.boolOf(modProp)
        readonly property bool colorable: page.colorSupported && gid !== ""
        readonly property bool compactable: flag !== ""
        readonly property bool compactOn: page.compactOf(gid, flag)
        readonly property bool menuOpen: gid !== "" && page.colorGid === gid
        readonly property bool hovered: bodyMa.containsMouse || colorMa.containsMouse
            || eyeMa.containsMouse || modeMa.containsMouse

        width: parent ? parent.width : 0
        height: 34
        radius: page.root ? page.root.tileRadius : 4
        color: page.root ? page.root.fillIdle : "transparent"
        border.color: page.root ? (hovered || menuOpen ? page.root.seal : page.root.sep) : "transparent"
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }

        UiText {
            id: nameLabel
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: stateArea.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: wr.title
            color: page.root ? (wr.shown ? page.root.ink : page.root.sumi) : "#888888"
            font.family: page.root ? page.root.mono : "monospace"
            font.pixelSize: 12
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // Right control cluster. A Row skips invisible children, so unsupported
        // controls collapse and the visible ones stay flush-right.
        Row {
            id: stateArea
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // palette chip → opens the accent popover for this group (V2 only)
            Item {
                width: 26; height: 26
                visible: wr.colorable
                IconText {
                    id: colorChip
                    anchors.centerIn: parent
                    text: "palette"
                    color: (wr.colorable && page.root.widgetHasFill(wr.gid))
                        ? page.root.widgetAssignedColor(wr.gid)
                        : (page.root
                            ? (colorMa.containsMouse || wr.menuOpen ? page.root.seal : page.root.sumiHi)
                            : "#888888")
                    font.pixelSize: 15
                    scale: colorMa.containsMouse ? 1.06 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: colorMa
                    anchors.fill: parent
                    enabled: wr.colorable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (page.colorGid === wr.gid) { page.colorGid = ""; page.colorLabel = "" }
                        else { page.colorGid = wr.gid; page.colorLabel = wr.title }
                    }
                }
            }

            // visibility toggle (always present; the mod* boolean)
            Item {
                width: 26; height: 26
                IconText {
                    anchors.centerIn: parent
                    text: wr.shown ? "visibility" : "visibility_off"
                    color: page.root
                        ? (eyeMa.containsMouse ? page.root.seal
                            : wr.shown ? page.root.sumiHi : page.root.sumi)
                        : "#888888"
                    font.pixelSize: 15
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: eyeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.toggleMod(wr.modProp)
                }
            }

            // density toggle (only where a compact mode exists for the group)
            Item {
                width: 38; height: 26
                visible: wr.compactable
                opacity: wr.shown ? 1 : 0.4
                UiText {
                    anchors.centerIn: parent
                    text: wr.compactOn ? wr.onLabel : wr.offLabel
                    color: page.root
                        ? (modeMa.containsMouse || (wr.shown && wr.compactOn) ? page.root.seal : page.root.sumiHi)
                        : "#888888"
                    font.family: page.root ? page.root.mono : "monospace"
                    font.pixelSize: 10
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: modeMa
                    anchors.fill: parent
                    enabled: wr.shown && wr.compactable
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: page.toggleCompact(wr.gid, wr.flag)
                }
            }
        }

        // clicking the label body toggles visibility too (matches the old tile)
        MouseArea {
            id: bodyMa
            anchors.left: parent.left
            anchors.right: stateArea.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.toggleMod(wr.modProp)
        }
    }

    // ── the scrollable list ──
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentCol
            width: flick.width
            spacing: 12

            CcSection {
                width: contentCol.width
                root: page.root
                title: "WIDGETS"

                UiText {
                    width: parent.width
                    text: "palette assigns an accent · eye toggles visibility · label toggles density"
                    color: page.root ? page.root.sumi : "#888888"
                    font.family: page.root ? page.root.mono : "monospace"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                WidgetRow { modProp: "modStatus";     gid: "G3";  title: "Status" }
                WidgetRow { modProp: "modMemory";     gid: "G4";  flag: "compactMemory";     title: "Memory" }
                WidgetRow { modProp: "modCpu";        gid: "G5";  flag: "compactCpu";        title: "CPU" }
                WidgetRow { modProp: "modVolume";     gid: "G6";  flag: "compactVolume";     title: "Volume" }
                WidgetRow { modProp: "modClaude";     gid: "G7";  title: "AI Usage" }
                WidgetRow { modProp: "modWeather";    gid: "G8";  title: "Clock / Weather" }
                WidgetRow { modProp: "modMpris";      gid: "G9";  flag: "compactMpris";      title: "Now Playing"; offLabel: "Def"; onLabel: "Full" }
                WidgetRow { modProp: "modQuick";      gid: "G10"; title: "Quick Tools" }
                WidgetRow { modProp: "modMedia";                  title: "Media" }
                WidgetRow { modProp: "modNetwork";    gid: "G11"; flag: "compactNetwork";    title: "Network" }
                WidgetRow { modProp: "modBrightness"; gid: "G13"; flag: "compactBrightness"; title: "Brightness" }
                WidgetRow { modProp: "modPower";      gid: "G14"; flag: "compactPower";      title: "Power Profile" }
                WidgetRow { modProp: "modBluetooth";  gid: "G15"; flag: "compactBluetooth";  title: "Bluetooth" }
                WidgetRow { visible: page.root && page.root.modGpu !== undefined;            modProp: "modGpu";            gid: "G17"; flag: "compactGpu";            title: "GPU" }
                WidgetRow { visible: page.root && page.root.modCpuTemperature !== undefined; modProp: "modCpuTemperature"; gid: "G16"; flag: "compactCpuTemperature"; title: "CPU Temp" }
                WidgetRow { visible: page.root && page.root.modStorage !== undefined;        modProp: "modStorage";        gid: "G18"; flag: "compactStorage";        title: "Storage" }
            }

            // AI-usage tool: which coding-agent meter the pill shows. A per-widget
            // behaviour, not a mod*/palette/density knob, so it sits in its own
            // section under the list and only shows while the widget is enabled.
            CcSection {
                width: contentCol.width
                root: page.root
                title: "AI USAGE"
                visible: page.boolOf("modClaude")

                CcSeg {
                    root: page.root
                    options: [{ key: "claude", label: "Claude" }, { key: "codex", label: "Codex" }, { key: "opencode", label: "OpenCode" }]
                    current: page.root ? page.root.aiTool : ""
                    onChose: (key) => { if (page.root) page.root.aiTool = key }
                }
            }

            // Temperature source for the V2 CPU-temperature widget: the same
            // sensor picker the Thermals panel carries, surfaced while the widget
            // is enabled (V1 has no CPU-temp widget, so this never shows there).
            CcSection {
                width: contentCol.width
                root: page.root
                title: "TEMPERATURE"
                visible: page.boolOf("modCpuTemperature")

                CcSeg {
                    root: page.root
                    options: [{ key: "cpu", label: "CPU" }, { key: "core", label: "Core" }, { key: "gpu", label: "GPU" }, { key: "nvme", label: "NVMe" }, { key: "memory", label: "Memory" }]
                    current: page.root ? page.root.barTemperatureSource : ""
                    onChose: (key) => { if (page.root) page.root.barTemperatureSource = key }
                }
            }
        }
    }

    // ── accent popover ── floats above the list, addressed by page.colorGid.
    // Only instantiated when the Theme supports per-widget colour (V2), so its
    // widget*() bindings never evaluate under the V1 probe Theme.
    Loader {
        anchors.fill: parent
        z: 50
        active: page.colorSupported && page.colorGid !== ""
        sourceComponent: popoverComp
    }

    Component {
        id: popoverComp
        Item {
            anchors.fill: parent

            // scrim: click anywhere outside to dismiss
            MouseArea { anchors.fill: parent; onClicked: { page.colorGid = ""; page.colorLabel = "" } }

            Rectangle {
                id: menu
                anchors.centerIn: parent
                width: Math.min(360, page.width - 40)
                height: menuCol.implicitHeight + 20
                radius: page.root.pillRadius
                color: page.root.bg
                border.color: page.root.sep
                border.width: 1

                MouseArea { anchors.fill: parent; onClicked: {} }   // eat clicks inside

                Column {
                    id: menuCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // header: "<WIDGET> COLOR" + reset / inherit hint
                    Item {
                        width: parent.width
                        height: 16
                        UiText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.colorLabel.toUpperCase() + " ACCENT"
                            color: page.root.sumiHi
                            font.family: page.root.mono
                            font.pixelSize: 9
                            font.letterSpacing: 0.7
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.root.widgetPaletteId(page.colorGid) === "inherit" ? "INHERIT" : "RESET"
                            color: resetMa.containsMouse ? page.root.seal : page.root.sumiHi
                            font.family: page.root.mono
                            font.pixelSize: 9
                        }
                        MouseArea {
                            id: resetMa
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 48
                            height: parent.height
                            enabled: page.root.widgetPaletteId(page.colorGid) !== "inherit"
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: page.root.resetWidgetColor(page.colorGid)
                        }
                    }

                    // palette swatches (colors.toml palette, 8 across)
                    Grid {
                        width: parent.width
                        columns: 8
                        columnSpacing: 4
                        rowSpacing: 4
                        Repeater {
                            model: page.root.barColorOptions
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool selected:
                                    page.root.widgetPaletteId(page.colorGid) === modelData
                                width: page.root.evenW((menuCol.width - 28) / 8)
                                height: 22
                                radius: page.root.tileRadius
                                color: page.root.paletteColor(modelData)
                                border.color: page.root.sep
                                border.width: 1
                                scale: swatchMa.containsMouse ? 1.06 : 1.0
                                z: swatchMa.containsMouse ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData === "foreground" ? "F" : modelData.slice(-1)
                                    color: page.root.paletteContrastColor(modelData)
                                    font.family: page.root.mono
                                    font.pixelSize: 8
                                    font.weight: Font.Medium
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    width: 12; height: 2; radius: 1
                                    visible: parent.selected
                                    color: page.root.paletteContrastColor(modelData)
                                }
                                MouseArea {
                                    id: swatchMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (parent.selected) page.root.resetWidgetColor(page.colorGid)
                                        else page.root.setWidgetPaletteColor(page.colorGid, modelData)
                                    }
                                }
                            }
                        }
                    }

                    // outline (border) toggle
                    Rectangle {
                        width: parent.width
                        height: 24
                        radius: page.root.tileRadius
                        readonly property bool outlineOn: page.root.widgetHasBorder(page.colorGid)
                        color: outlineOn ? page.root.fillActive : borderMa.containsMouse ? page.root.fillHover : page.root.fillIdle
                        border.color: outlineOn || borderMa.containsMouse ? page.root.seal : page.root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: "Outline"
                            color: parent.outlineOn || borderMa.containsMouse ? page.root.seal : page.root.ink
                            font.family: page.root.mono
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: borderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.root.setWidgetBorderEnabled(
                                page.colorGid, !page.root.widgetHasBorder(page.colorGid))
                        }
                    }

                    // content tone — only meaningful when the group carries a fill
                    Row {
                        width: parent.width
                        spacing: 4
                        visible: page.root.widgetHasFill(page.colorGid)
                        Repeater {
                            model: [
                                { id: "auto",       label: "Auto" },
                                { id: "background", label: "BG" },
                                { id: "foreground", label: "FG" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected:
                                    page.root.widgetTone(page.colorGid) === modelData.id
                                width: page.root.evenW((menuCol.width - 8) / 3)
                                height: 24
                                radius: page.root.tileRadius
                                color: selected ? page.root.fillActive
                                    : toneMa.containsMouse ? page.root.fillHover : "transparent"
                                border.color: selected || toneMa.containsMouse ? page.root.seal : page.root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: parent.selected ? page.root.seal : page.root.ink
                                    font.family: page.root.mono
                                    font.pixelSize: 9
                                }
                                MouseArea {
                                    id: toneMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.root.setWidgetTone(page.colorGid, modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
