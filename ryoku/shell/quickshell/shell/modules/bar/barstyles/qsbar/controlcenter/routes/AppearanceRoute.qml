import QtQuick
import "../kit"
import "../../modules"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// WIDGETS route (id "widgets"): the bar's widget inventory as a two-column card
// grid, one card per group, then the AI-usage and CPU-temperature settings that
// are per-widget behaviours rather than plain visibility. Ported from the old
// Appearance panel, control for control. Every helper call is capability-gated
// so the page also loads clean under the offscreen probe Theme (root === null).
Item {
    id: page
    property var root: null
    property var cc: null
    readonly property var tk: cc ? cc.tokens : null

    // A card grid is NOT a form column, so this route alone lets the grid span
    // the whole plate: colW is page.width, not the contentW cap. The AI and
    // temperature settings below ARE form rows, so they keep the cap (formW).
    readonly property real colW: page.width
    readonly property real formW: tk ? Math.min(page.width, tk.contentW) : page.width

    implicitHeight: contentCol.implicitHeight

    // Colour popover state (a single floating menu, addressed by widget group).
    property string colorGid: ""
    property string colorLabel: ""

    // Per-widget colour is gated on widgetHasFill so the page stays error-free
    // if the live Theme (or the offscreen probe) does not expose the helpers.
    readonly property bool colorSupported: !!(page.root && page.root.widgetHasFill)

    // ── visibility (mod* booleans) ──
    function boolOf(prop) {
        return (page.root && prop !== "") ? page.root[prop] === true : false
    }
    function toggleMod(prop) {
        if (!page.root || prop === "" || page.root[prop] === undefined)
            return

        page.root[prop] = !page.root[prop]

        if (page.root.saveWidgets)
            page.root.saveWidgets()
    }

    // ── density (compact) - drive whichever mechanism the live Theme consumes ──
    // The bar renders one presentation toggled per-group via iconOnly() /
    // mprisBarStyle; `flag` is an optional legacy per-group compact property.
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

    // Separator: ends the widget's island run, so it stands alone in islands form.
    function sepOf(gid) {
        return (page.root && gid !== "" && page.root.sepAfter !== undefined)
            ? page.root.sepAfter(gid) === true : false
    }
    function toggleSep(gid) {
        if (page.root && gid !== "" && page.root.toggleSep !== undefined)
            page.root.toggleSep(gid)
    }

    // Each card wears the exact mark its widget draws in the bar; absent = no single honest glyph.
    readonly property var widgetGlyph: ({
        "modVolume":         "graphic_eq",
        "modCpu":            "planner_review",
        "modMedia":          "collections",
        "modMpris":          "music_note",
        "modNetwork":        "signal_wifi_4_bar",
        "modBluetooth":      "bluetooth",
        "modStorage":        "󰋊",
        "modCpuTemperature": "\uf2c9",
        "modPower":          "\uf24e"
    })

    // One widget group as a card: name and accent swatch on top, the state
    // controls below. The card is a hairline plate; emphasis lives in the
    // controls (a bone On/Off segment, a bone density pick), never in a card
    // tint. On/Off is always live; density and Split apply only while the widget
    // is shown, so they dim and go inert when it is off (the old live gating).
    component WidgetCard: Rectangle {
        id: wc
        property string modProp: ""
        property string gid: ""
        property string flag: ""
        property string title: ""
        property string offLabel: "Full"
        property string onLabel: "Icon"

        readonly property bool shown: page.boolOf(modProp)
        readonly property bool colorable: page.colorSupported && gid !== ""
        readonly property bool assigned: colorable && page.root && page.root.widgetHasFill(gid)
        readonly property bool compactable: flag !== ""
        readonly property bool compactOn: page.compactOf(gid, flag)
        readonly property bool menuOpen: gid !== "" && page.colorGid === gid
        readonly property bool sepOn: page.sepOf(gid)
        readonly property string glyph: page.widgetGlyph[modProp] || ""
        readonly property bool glyphNerd: glyph !== "" && glyph.charCodeAt(0) >= 0x80

        height: page.tk ? Tokens.ctlH * 2 + page.tk.gap * 3 : 88
        radius: page.tk ? Tokens.radius : 6
        color: "transparent"
        border.width: 1
        border.color: page.tk ? Tokens.line : "#333333"

        IconText {
            id: cardGlyph
            visible: wc.glyph !== ""
            anchors.left: parent.left
            anchors.leftMargin: page.tk ? page.tk.gap : 12
            anchors.verticalCenter: cardName.verticalCenter
            text: wc.glyph
            // a Nerd-Font mark needs the mono Nerd family; a Material name keeps IconText's own
            font.family: wc.glyphNerd ? Tokens.mono : "Material Symbols Rounded"
            font.pixelSize: Tokens.fRow
            color: Tokens.inkDim
            opacity: wc.shown ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: page.tk ? Tokens.snap : 90 } }
        }

        UiText {
            id: cardName
            anchors.left: cardGlyph.visible ? cardGlyph.right : parent.left
            anchors.leftMargin: cardGlyph.visible ? (page.tk ? page.tk.gap / 2 : 6)
                                                  : (page.tk ? page.tk.gap : 12)
            anchors.right: swatch.visible ? swatch.left : parent.right
            anchors.rightMargin: page.tk ? page.tk.gap : 12
            anchors.top: parent.top
            anchors.topMargin: page.tk ? page.tk.gap : 12
            text: I18n.tr(wc.title)
            color: page.tk ? Tokens.ink : "#cdc4ba"
            font.family: page.tk ? Tokens.ui : "sans-serif"
            font.pixelSize: page.tk ? Tokens.fBody : 14
            elide: Text.ElideRight
        }

        // Accent swatch → opens the colour popover for this group. It shows the
        // widget's assigned accent, or an empty well when the widget inherits, so
        // the affordance says what it does instead of an unlabelled palette glyph.
        Rectangle {
            id: swatch
            visible: wc.colorable
            anchors.right: parent.right
            anchors.rightMargin: page.tk ? page.tk.gap : 12
            anchors.top: parent.top
            anchors.topMargin: page.tk ? page.tk.gap : 12
            width: page.tk ? Tokens.ctlH : 26
            height: width
            radius: page.tk ? Tokens.radius : 6
            color: wc.assigned ? page.root.widgetAssignedColor(wc.gid)
                : (swatchMa.containsMouse ? (page.tk ? Tokens.tint5 : "#111111") : "transparent")
            border.width: (wc.menuOpen || wc.assigned) ? 2 : 1
            border.color: (wc.menuOpen || wc.assigned) ? (page.tk ? Tokens.bone : "#cdc4ba")
                : (swatchMa.containsMouse ? (page.tk ? Tokens.ink : "#cccccc")
                    : (page.tk ? Tokens.line : "#333333"))
            Behavior on color { ColorAnimation { duration: page.tk ? Tokens.snap : 90 } }
            Behavior on border.color { ColorAnimation { duration: page.tk ? Tokens.snap : 90 } }

            // An empty well is not self-explanatory, so while the widget inherits
            // the accent it carries the palette mark; once a colour is assigned the
            // colour itself is the label.
            IconText {
                anchors.centerIn: parent
                visible: !wc.assigned
                text: "palette"
                color: swatchMa.containsMouse ? Tokens.inkMuted : Tokens.inkFaint
                font.pixelSize: Tokens.fSmall
            }

            MouseArea {
                id: swatchMa
                anchors.fill: parent
                enabled: wc.colorable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (page.colorGid === wc.gid) { page.colorGid = ""; page.colorLabel = "" }
                    else { page.colorGid = wc.gid; page.colorLabel = wc.title }
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: page.tk ? page.tk.gap : 12
            anchors.right: parent.right
            anchors.rightMargin: page.tk ? page.tk.gap : 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: page.tk ? page.tk.gap : 12
            spacing: page.tk ? page.tk.gap / 2 : 6

            Sw {
                on: wc.shown
                onToggled: (v) => page.toggleMod(wc.modProp)
            }

            Row {
                spacing: page.tk ? page.tk.gap / 2 : 6
                enabled: wc.shown
                opacity: wc.shown ? 1 : 0.45
                Behavior on opacity { NumberAnimation { duration: page.tk ? Tokens.snap : 90 } }

                Seg {
                    visible: wc.compactable
                    width: implicitWidth
                    options: [wc.offLabel, wc.onLabel]
                    current: wc.compactOn ? wc.onLabel : wc.offLabel
                    onChose: (key) => { if ((key === wc.onLabel) !== wc.compactOn) page.toggleCompact(wc.gid, wc.flag) }
                }

                Multi {
                    visible: wc.gid !== ""
                    width: 64
                    options: ["Split"]
                    chosen: wc.sepOn ? ["Split"] : []
                    onToggled: (key) => page.toggleSep(wc.gid)
                }
            }
        }
    }

    // ── the scrollable body ──
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentCol
            width: page.colW
            spacing: page.tk ? page.tk.sectionGap : 24

            Entrance {
                width: page.colW
                index: 0
                SettingCard {
                    width: page.colW
                    title: "WIDGETS"
                    kana: "\u90e8\u54c1"

                    Grid {
                        id: widgetGrid
                    width: parent.width
                        columns: 2
                        columnSpacing: page.tk ? page.tk.colGap : 16
                        rowSpacing: page.tk ? page.tk.colGap : 16
                        // Two equal columns that divide the width exactly, so the
                        // grid never trails the ragged remainder the old floor()-fit
                        // layout left against the plate edge.
                        readonly property real cellW: (width - columnSpacing) / 2

                        WidgetCard { width: widgetGrid.cellW; modProp: "modStatus";     gid: "G3";  title: "Status" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modMemory";     gid: "G4";  flag: "compactMemory";     title: "Memory" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modCpu";        gid: "G5";  flag: "compactCpu";        title: "CPU" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modVolume";     gid: "G6";  flag: "compactVolume";     title: "Volume" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modClaude";     gid: "G7";  title: "AI Usage" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modWeather";    gid: "G8";  title: "Clock / Weather" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modMpris";      gid: "G9";  flag: "compactMpris";      title: "Now Playing"; offLabel: "Def"; onLabel: "Full" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modQuick";      gid: "G10"; title: "Quick Tools" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modMedia";                  title: "Media" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modNetwork";    gid: "G11"; flag: "compactNetwork";    title: "Network" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modBattery";    gid: "G12"; flag: "compactBattery";    title: "Battery" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modBrightness"; gid: "G13"; flag: "compactBrightness"; title: "Brightness" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modPower";      gid: "G14"; flag: "compactPower";      title: "Power Profile" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modBluetooth";  gid: "G15"; flag: "compactBluetooth";  title: "Bluetooth" }
                        WidgetCard { width: widgetGrid.cellW; visible: page.root && page.root.modGpu !== undefined;            modProp: "modGpu";            gid: "G17"; flag: "compactGpu";            title: "GPU" }
                        WidgetCard { width: widgetGrid.cellW; visible: page.root && page.root.modCpuTemperature !== undefined; modProp: "modCpuTemperature"; gid: "G16"; flag: "compactCpuTemperature"; title: "CPU Temp" }
                        WidgetCard { width: widgetGrid.cellW; visible: page.root && page.root.modStorage !== undefined;        modProp: "modStorage";        gid: "G18"; flag: "compactStorage";        title: "Storage" }
                        WidgetCard { width: widgetGrid.cellW; modProp: "modLayout"; gid: "G19"; flag: "compactLayout"; title: "Keyboard Layout" }
                    }
                }
            }

            // AI-usage tool: which coding-agent meters the pill shows. A per-widget
            // behaviour, not a mod*/palette/density knob, so it is a normal form
            // row under the grid and only shows while the AI widget is enabled.
            Entrance {
                width: page.formW
                index: 1
                    visible: page.boolOf("modClaude")
                SettingCard {
                    width: page.formW
                    title: "AI USAGE"
                    kana: "\u9053\u5177"
                    visible: page.boolOf("modClaude")

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        block: true
                        label: I18n.tr("Agents")
                        source: "shell.json"
                        Multi {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["claude", "codex", "opencode"]
                            chosen: page.root ? page.root.aiTools : []
                            onToggled: (key) => { if (page.root) page.root.toggleAiTool(key) }
                        }
                    }
                }
            }

            // Temperature source for the CPU-temperature widget: the same sensor
            // pick the Thermals panel carries, surfaced as a form row while the
            // widget is enabled.
            Entrance {
                width: page.formW
                index: 2
                    visible: page.boolOf("modCpuTemperature")
                SettingCard {
                    width: page.formW
                    title: "TEMPERATURE"
                    kana: "\u6e29\u5ea6"
                    visible: page.boolOf("modCpuTemperature")

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        block: true
                        label: I18n.tr("Source")
                        source: "shell.json"
                        Seg {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["cpu", "core", "gpu", "nvme", "memory"]
                            current: page.root ? page.root.barTemperatureSource : ""
                            onChose: (key) => { if (page.root) page.root.barTemperatureSource = key }
                        }
                    }
                }
            }
        }
    }

    // ── accent popover ── floats above the body, addressed by page.colorGid.
    // Only instantiated when the Theme supports per-widget colour, so its
    // widget*() bindings never evaluate under the offscreen probe Theme. Chrome
    // is studio ink and inversion; the swatches stay coloured, because there the
    // colour is the data. Every backing key from the old menu is preserved.
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
            readonly property var tk: page.tk

            // preset row for a per-widget geometry knob (opacity/radius/pad)
            component GeomRow: Column {
                id: grow
                property string glabel: ""
                property string gkey: ""
                property var opts: []
                readonly property real cellGap: page.tk ? page.tk.gap / 3 : 4
                width: parent ? parent.width : 0
                spacing: grow.cellGap
                UiText {
                    text: grow.glabel
                    color: page.tk ? Tokens.inkMuted : "#958f87"
                    font.family: page.tk ? Tokens.mono : "monospace"
                    font.pixelSize: page.tk ? Tokens.fTiny : 9
                    font.letterSpacing: page.tk ? Tokens.trackLabel : 0.7
                }
                Row {
                    width: parent.width
                    spacing: grow.cellGap
                    Repeater {
                        model: grow.opts
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: page.root.widgetGeomOf(page.colorGid)[grow.gkey] === modelData.v
                            width: page.root.evenW((grow.width - (grow.opts.length - 1) * grow.cellGap) / grow.opts.length)
                            height: page.tk ? Tokens.ctlH : 26
                            radius: page.tk ? Tokens.radius : 6
                            color: sel ? (page.tk ? Tokens.bone : "#cdc4ba")
                                : gma.containsMouse ? (page.tk ? Tokens.tint5 : "#111111") : "transparent"
                            border.color: sel ? "transparent" : (page.tk ? Tokens.line : "#333333")
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: page.tk ? Tokens.snap : 90 } }
                            UiText {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.sel ? (page.tk ? Tokens.inkOnBone : "#000000") : (page.tk ? Tokens.ink : "#cdc4ba")
                                font.family: page.tk ? Tokens.mono : "monospace"
                                font.pixelSize: page.tk ? Tokens.fSmall : 13
                            }
                            MouseArea {
                                id: gma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.root.setWidgetGeom(page.colorGid, grow.gkey, modelData.v)
                            }
                        }
                    }
                }
            }

            // frame width preset row - GeomRow's language, wired to the border
            // width instead of the widgetGeom map.
            component FrameWidthRow: Column {
                id: fwrow
                property string glabel: ""
                property var opts: []
                readonly property real cellGap: page.tk ? page.tk.gap / 3 : 4
                width: parent ? parent.width : 0
                spacing: fwrow.cellGap
                UiText {
                    text: fwrow.glabel
                    color: page.tk ? Tokens.inkMuted : "#958f87"
                    font.family: page.tk ? Tokens.mono : "monospace"
                    font.pixelSize: page.tk ? Tokens.fTiny : 9
                    font.letterSpacing: page.tk ? Tokens.trackLabel : 0.7
                }
                Row {
                    width: parent.width
                    spacing: fwrow.cellGap
                    Repeater {
                        model: fwrow.opts
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: page.root.widgetBorderWidth(page.colorGid) === modelData.v
                            width: page.root.evenW((fwrow.width - (fwrow.opts.length - 1) * fwrow.cellGap) / fwrow.opts.length)
                            height: page.tk ? Tokens.ctlH : 26
                            radius: page.tk ? Tokens.radius : 6
                            color: sel ? (page.tk ? Tokens.bone : "#cdc4ba")
                                : fwma.containsMouse ? (page.tk ? Tokens.tint5 : "#111111") : "transparent"
                            border.color: sel ? "transparent" : (page.tk ? Tokens.line : "#333333")
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: page.tk ? Tokens.snap : 90 } }
                            UiText {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.sel ? (page.tk ? Tokens.inkOnBone : "#000000") : (page.tk ? Tokens.ink : "#cdc4ba")
                                font.family: page.tk ? Tokens.mono : "monospace"
                                font.pixelSize: page.tk ? Tokens.fSmall : 13
                            }
                            MouseArea {
                                id: fwma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.root.setWidgetBorderWidth(page.colorGid, modelData.v)
                            }
                        }
                    }
                }
            }

            // frame colour row - swatches for the border key. inherit/surface are
            // labelled chips (not fixed palette colours) and invert when chosen;
            // the rest render as the palette swatches do, with a bone ring.
            component FrameColorRow: Column {
                id: fcrow
                property string glabel: ""
                readonly property real cellGap: page.tk ? page.tk.gap / 2 : 4
                width: parent ? parent.width : 0
                spacing: page.tk ? page.tk.gap / 3 : 4
                UiText {
                    text: fcrow.glabel
                    color: page.tk ? Tokens.inkMuted : "#958f87"
                    font.family: page.tk ? Tokens.mono : "monospace"
                    font.pixelSize: page.tk ? Tokens.fTiny : 9
                    font.letterSpacing: page.tk ? Tokens.trackLabel : 0.7
                }
                Grid {
                    width: parent.width
                    columns: 8
                    columnSpacing: fcrow.cellGap
                    rowSpacing: fcrow.cellGap
                    Repeater {
                        model: ["inherit", "surface"].concat(page.root.barColorOptions)
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool labelled: modelData === "inherit" || modelData === "surface"
                            readonly property bool selected: page.root.widgetBorderColorKey(page.colorGid) === modelData
                            width: page.root.evenW((fcrow.width - 7 * fcrow.cellGap) / 8)
                            height: page.tk ? Tokens.ctlH : 26
                            radius: page.tk ? Tokens.radius : 6
                            color: labelled
                                ? (selected ? (page.tk ? Tokens.bone : "#cdc4ba")
                                    : fcma.containsMouse ? (page.tk ? Tokens.tint5 : "#111111") : "transparent")
                                : page.root.paletteColor(modelData)
                            border.color: labelled
                                ? (selected ? "transparent"
                                    : (fcma.containsMouse ? (page.tk ? Tokens.ink : "#cccccc") : (page.tk ? Tokens.line : "#333333")))
                                : (selected ? (page.tk ? Tokens.bone : "#cdc4ba") : (page.tk ? Tokens.line : "#333333"))
                            border.width: (!labelled && selected) ? 2 : 1
                            scale: fcma.containsMouse ? 1.06 : 1.0
                            z: fcma.containsMouse ? 1 : 0
                            Behavior on scale { NumberAnimation { duration: page.tk ? Tokens.snap : 90; easing.type: Easing.OutCubic } }
                            UiText {
                                anchors.centerIn: parent
                                text: parent.labelled
                                    ? (modelData === "inherit" ? I18n.tr("Auto") : I18n.tr("Fill"))
                                    : (modelData === "foreground" ? I18n.tr("F") : modelData.slice(-1))
                                color: parent.labelled
                                    ? (parent.selected ? (page.tk ? Tokens.inkOnBone : "#000000") : (page.tk ? Tokens.ink : "#cdc4ba"))
                                    : page.root.paletteContrastColor(modelData)
                                font.family: page.tk ? Tokens.mono : "monospace"
                                font.pixelSize: page.tk ? Tokens.fTiny : 9
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: fcma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.root.setWidgetBorderColorKey(page.colorGid, modelData)
                            }
                        }
                    }
                }
            }

            // dim backdrop: click outside to dismiss. The scrim is tk ink at low
            // alpha, not a hardcoded black, so it darkens paper honestly.
            Rectangle {
                anchors.fill: parent
                color: tk ? Qt.rgba(Tokens.ink.r, Tokens.ink.g, Tokens.ink.b, 0.32) : Qt.rgba(0, 0, 0, 0.38)
                MouseArea { anchors.fill: parent; onClicked: { page.colorGid = ""; page.colorLabel = "" } }
            }

            Rectangle {
                id: menu
                anchors.centerIn: parent
                readonly property int cell: tk ? Tokens.ctlH : 26
                readonly property int pad: tk ? tk.gap : 12
                width: Math.min(parent.width - 2 * (tk ? tk.pad : 20),
                    8 * cell + 7 * (tk ? tk.gap / 2 : 4) + 2 * pad)
                height: menuCol.implicitHeight + 2 * pad
                radius: tk ? Tokens.radius : 6
                color: tk ? Tokens.paperLift : "#161310"
                border.color: tk ? Tokens.line : "#333333"
                border.width: 1

                MouseArea { anchors.fill: parent; onClicked: {} }   // eat clicks inside

                Column {
                    id: menuCol
                    anchors.fill: parent
                    anchors.margins: menu.pad
                    spacing: tk ? tk.gap : 10

                    // header: "<WIDGET> APPEARANCE" + reset / inherit affordance
                    Item {
                        width: parent.width
                        height: tk ? tk.eyebrowH : 16
                        UiText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.colorLabel.toUpperCase() + I18n.tr(" APPEARANCE")
                            color: tk ? Tokens.inkMuted : "#958f87"
                            font.family: tk ? Tokens.mono : "monospace"
                            font.pixelSize: tk ? Tokens.fMicro : 11
                            font.letterSpacing: tk ? Tokens.trackMark : 2.2
                            font.weight: Font.DemiBold
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: (page.root.widgetPaletteId(page.colorGid) === "inherit" && !page.root.widgetGeomCustomized(page.colorGid)) ? I18n.tr("INHERIT") : I18n.tr("RESET")
                            color: resetMa.containsMouse ? (tk ? Tokens.ink : "#cdc4ba") : (tk ? Tokens.inkFaint : "#7a756e")
                            font.family: tk ? Tokens.mono : "monospace"
                            font.pixelSize: tk ? Tokens.fTiny : 9
                        }
                        MouseArea {
                            id: resetMa
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: tk ? Tokens.ctlH * 2 : 48
                            height: parent.height
                            enabled: page.root.widgetPaletteId(page.colorGid) !== "inherit" || page.root.widgetGeomCustomized(page.colorGid)
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { page.root.resetWidgetColor(page.colorGid); page.root.resetWidgetGeom(page.colorGid) }
                        }
                    }

                    // palette swatches (colors.toml palette, 8 across). The colour
                    // is the data, so the swatch keeps its hue; a bone ring marks
                    // the current pick.
                    Grid {
                        width: parent.width
                        columns: 8
                        columnSpacing: tk ? tk.gap / 2 : 4
                        rowSpacing: tk ? tk.gap / 2 : 4
                        Repeater {
                            model: page.root.barColorOptions
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool selected:
                                    page.root.widgetPaletteId(page.colorGid) === modelData
                                width: page.root.evenW((menuCol.width - 7 * (tk ? tk.gap / 2 : 4)) / 8)
                                height: tk ? Tokens.ctlH : 26
                                radius: tk ? Tokens.radius : 6
                                color: page.root.paletteColor(modelData)
                                border.color: selected ? (tk ? Tokens.bone : "#cdc4ba") : (tk ? Tokens.line : "#333333")
                                border.width: selected ? 2 : 1
                                scale: swatchMa.containsMouse ? 1.06 : 1.0
                                z: swatchMa.containsMouse ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: tk ? Tokens.snap : 90; easing.type: Easing.OutCubic } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData === "foreground" ? I18n.tr("F") : modelData.slice(-1)
                                    color: page.root.paletteContrastColor(modelData)
                                    font.family: tk ? Tokens.mono : "monospace"
                                    font.pixelSize: tk ? Tokens.fTiny : 9
                                    font.weight: Font.Medium
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

                    // frame (border) toggle - a bone plate when on, inversion, not
                    // a tint.
                    Rectangle {
                        width: parent.width
                        height: tk ? Tokens.ctlH : 26
                        radius: tk ? Tokens.radius : 6
                        readonly property bool outlineOn: page.root.widgetHasBorder(page.colorGid)
                        color: outlineOn ? (tk ? Tokens.bone : "#cdc4ba")
                            : borderMa.containsMouse ? (tk ? Tokens.tint5 : "#111111") : "transparent"
                        border.color: outlineOn ? "transparent" : (tk ? Tokens.line : "#333333")
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: tk ? Tokens.snap : 90 } }
                        UiText {
                            anchors.centerIn: parent
                            text: I18n.tr("Frame")
                            color: parent.outlineOn ? (tk ? Tokens.inkOnBone : "#000000") : (tk ? Tokens.ink : "#cdc4ba")
                            font.family: tk ? Tokens.mono : "monospace"
                            font.pixelSize: tk ? Tokens.fSmall : 13
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

                    FrameWidthRow {
                        glabel: I18n.tr("WIDTH")
                        visible: page.root.widgetHasBorder(page.colorGid)
                        opts: [{ v: 0.5, label: "0.5" }, { v: 1, label: "1" }, { v: 1.5, label: "1.5" }, { v: 2, label: "2" }]
                    }
                    FrameColorRow {
                        glabel: I18n.tr("COLOUR")
                        visible: page.root.widgetHasBorder(page.colorGid)
                    }

                    // content tone - only meaningful when the group carries a fill
                    Row {
                        width: parent.width
                        spacing: tk ? tk.gap / 3 : 4
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
                                width: page.root.evenW((menuCol.width - 2 * (tk ? tk.gap / 3 : 4)) / 3)
                                height: tk ? Tokens.ctlH : 26
                                radius: tk ? Tokens.radius : 6
                                color: selected ? (tk ? Tokens.bone : "#cdc4ba")
                                    : toneMa.containsMouse ? (tk ? Tokens.tint5 : "#111111") : "transparent"
                                border.color: selected ? "transparent" : (tk ? Tokens.line : "#333333")
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: tk ? Tokens.snap : 90 } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: I18n.tr(modelData.label)
                                    color: parent.selected ? (tk ? Tokens.inkOnBone : "#000000") : (tk ? Tokens.ink : "#cdc4ba")
                                    font.family: tk ? Tokens.mono : "monospace"
                                    font.pixelSize: tk ? Tokens.fSmall : 13
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

                    Rectangle { width: parent.width; height: 1; color: tk ? Tokens.line : "#333333" }
                    GeomRow {
                        glabel: "OPACITY"
                        gkey: "opacity"
                        opts: [{ v: 1, label: "100" }, { v: 0.85, label: "85" }, { v: 0.7, label: "70" }, { v: 0.5, label: "50" }]
                    }
                    GeomRow {
                        glabel: "CORNERS"
                        gkey: "radius"
                        opts: [{ v: 0, label: "0" }, { v: 4, label: "4" }, { v: 8, label: "8" }, { v: 12, label: "12" }]
                    }
                    GeomRow {
                        glabel: "PADDING"
                        gkey: "pad"
                        opts: [{ v: 0, label: "0" }, { v: 2, label: "2" }, { v: 4, label: "4" }, { v: 6, label: "6" }]
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
