import QtQuick
import "../kit"
import "../../modules"

// Bars editor route: a scrollable live bar-surface panel ported from Shibumi's
// ActiveBarSettingsPage / BarSurfaceSettings / BarStylePreviewCard, wearing
// qsbar's dark skin. Every control writes straight to `root` (the qsbar Theme),
// so the running bar updates live and mirrors to Bar Studio. Null-guarded — the
// page may briefly exist before `root` is assigned, and some tokens live on the
// V2 Theme first (guard the barShellStyleValid function call in particular).
Item {
    id: page
    property var root: null
    property var cc: null

    // ── null-safe token shortcuts (fallbacks match the kit primitives' own) ──
    readonly property color cAccent: page.root ? page.root.seal : "#c4746e"
    readonly property color cInk: page.root ? page.root.ink : "#dddddd"
    readonly property color cSumi: page.root ? page.root.sumi : "#888888"
    readonly property color cSep: page.root ? page.root.sep : "#333333"
    readonly property color cIdle: page.root ? page.root.fillIdle : "#1a1a1a"
    readonly property string fontMono: page.root ? page.root.mono : "monospace"
    readonly property int rTile: page.root ? page.root.tileRadius : 6
    readonly property real aActive: page.root ? page.root.fillActiveAlpha : 0.22
    readonly property real aHover: page.root ? page.root.fillHoverAlpha : 0.10

    readonly property int gap: (page.cc && page.cc.tokens) ? page.cc.tokens.gap : 10
    readonly property int sectionGap: (page.cc && page.cc.tokens) ? page.cc.tokens.sectionGap : 16

    // Variant capability gates. V1 (island) exposes the style* surface toggles;
    // V2 (continuous) exposes the shell forms and the two-border surface. Each
    // section gates on these so a control only shows under the variant it drives,
    // matching upstream Rise: V2-only forms/borders never render under V1.
    readonly property bool isV1: !!(page.root && page.root.styleFrost !== undefined)
    readonly property bool isV2: !!(page.root && page.root.barShellStyleValid !== undefined)

    // the four V2 bar forms + their captions (drives the header + the FORM grid)
    readonly property var formModel: [
        { form: "full",  label: "Full",  detail: "Edge to edge" },
        { form: "fit",   label: "Fit",   detail: "Inset rounded frame" },
        { form: "dock",  label: "Dock",  detail: "Open desktop edge" },
        { form: "notch", label: "Notch", detail: "Flowing shoulders" }
    ]
    function formInfo(f) {
        for (var i = 0; i < formModel.length; i++)
            if (formModel[i].form === f) return formModel[i]
        return null
    }

    // header strings, derived live off the running variant + active form
    readonly property string variantLabel:
        (page.root && page.root.variantHost && page.root.variantHost.runningVariant)
            ? String(page.root.variantHost.runningVariant).toUpperCase() : ""
    readonly property string formCaption: {
        if (!page.root || !page.root.barShellStyle)
            return "Live bar surface"
        var fi = page.formInfo(String(page.root.barShellStyle))
        return fi ? (fi.label + " · " + fi.detail) : String(page.root.barShellStyle)
    }

    // guard the validator: on a Theme that predates the shared shell-style tokens
    // the function is absent, so this no-ops instead of throwing.
    function setForm(f) {
        if (page.root && page.root.barShellStyleValid && page.root.barShellStyleValid(f))
            page.root.barShellStyle = f
    }

    // ── gap-animation mode selection (restores the old ControlPanel's picker) ──
    // Direct-select: each tile sets barAnim to its exact mode value (0-8).
    readonly property int curAnim: (page.root && page.root.barAnim !== undefined) ? page.root.barAnim : -1
    function setAnim(v) { if (page.root && page.root.barAnim !== undefined) page.root.barAnim = v }

    component AnimTile: Rectangle {
        property string caption: ""
        property bool on: false
        signal act()
        readonly property color hf: Qt.rgba(page.cInk.r, page.cInk.g, page.cInk.b, 0.06)
        readonly property color hb: Qt.rgba(page.cInk.r, page.cInk.g, page.cInk.b, 0.28)
        height: 32
        radius: page.rTile
        color: on ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.14)
                  : (tileMa.containsMouse ? hf : page.cIdle)
        border.width: 1
        border.color: on ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.52)
                         : (tileMa.containsMouse ? hb : page.cSep)
        Behavior on color { ColorAnimation { duration: 120 } }
        UiText {
            anchors.centerIn: parent
            text: parent.caption
            color: parent.on ? page.cAccent : page.cInk
            font.family: page.fontMono
            font.pixelSize: 11
            font.weight: parent.on ? Font.DemiBold : Font.Normal
        }
        MouseArea { id: tileMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.act() }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            spacing: page.sectionGap

            // ── header card: V<n> ACTIVE + active form caption + LIVE dot ──
            Rectangle {
                width: col.width
                height: 62
                radius: page.rTile
                color: page.root
                    ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.09)
                    : page.cIdle
                border.width: 1
                border.color: page.root
                    ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.5)
                    : page.cSep

                Row {
                    id: liveRow
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: page.cAccent
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation { from: 1.0; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LIVE"
                        color: page.cAccent
                        font.family: page.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 0.8
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: liveRow.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 3

                    UiText {
                        text: (page.variantLabel === "" ? "BAR" : page.variantLabel) + " ACTIVE"
                        color: page.cInk
                        font.family: page.fontMono
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    UiText {
                        width: parent.width
                        text: page.formCaption
                        color: page.cSumi
                        elide: Text.ElideRight
                        font.family: page.fontMono
                        font.pixelSize: 11
                    }
                }
            }

            // ── POSITION ──
            CcSection {
                width: col.width
                root: page.root
                title: "POSITION"

                CcSeg {
                    root: page.root
                    options: [{ key: "top", label: "Top" }, { key: "bottom", label: "Bottom" }]
                    current: page.root ? page.root.barPosition : "top"
                    onChose: k => { if (page.root) page.root.barPosition = k }
                }
            }

            // ── STYLE (V1 island surface) ──
            CcSection {
                width: col.width
                root: page.root
                title: "STYLE"
                visible: page.isV1

                CcRow {
                    root: page.root
                    label: "Bar border"
                    desc: "Outline the pill surfaces"
                    controlWidth: 108
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.styleBorder) ? "on" : "off"
                        onChose: k => { if (page.root && page.root.styleBorder !== undefined) page.root.styleBorder = (k === "on") }
                    }
                }
                CcRow {
                    root: page.root
                    label: "Frost"
                    desc: "Lower the island opacity so blur shows through"
                    controlWidth: 108
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.styleFrost) ? "on" : "off"
                        onChose: k => { if (page.root && page.root.styleFrost !== undefined) page.root.styleFrost = (k === "on") }
                    }
                }
                CcRow {
                    root: page.root
                    label: "Shadow"
                    desc: "Cast a soft shadow under the pills"
                    controlWidth: 108
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.styleShadow) ? "on" : "off"
                        onChose: k => { if (page.root && page.root.styleShadow !== undefined) page.root.styleShadow = (k === "on") }
                    }
                }
            }

            // ── BAR SURFACE ──
            CcSection {
                width: col.width
                root: page.root
                title: "BAR SURFACE"
                visible: page.isV2

                CcRow {
                    root: page.root
                    label: "Bar border"
                    desc: "Outline the bar shell"
                    controlWidth: 108

                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.barBorderEnabled) ? "on" : "off"
                        onChose: k => { if (page.root && page.root.barBorderEnabled !== undefined) page.root.barBorderEnabled = (k === "on") }
                    }
                }
                CcRow {
                    root: page.root
                    label: "Panel + tooltip"
                    desc: "Outline panels and tooltips"
                    controlWidth: 108

                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.panelTooltipBorderEnabled) ? "on" : "off"
                        onChose: k => { if (page.root && page.root.panelTooltipBorderEnabled !== undefined) page.root.panelTooltipBorderEnabled = (k === "on") }
                    }
                }
            }

            // ── BAR FORM (2×2 selectable silhouette cards) ──
            CcSection {
                width: col.width
                root: page.root
                title: "BAR FORM"
                visible: page.isV2

                Grid {
                    id: formGrid
                    width: col.width
                    columns: 2
                    columnSpacing: page.gap
                    rowSpacing: page.gap

                    Repeater {
                        model: page.formModel

                        delegate: Rectangle {
                            id: fcard
                            required property var modelData
                            readonly property bool on:
                                page.root && String(page.root.barShellStyle) === modelData.form
                            readonly property bool hovered: fma.containsMouse

                            width: (formGrid.width - formGrid.columnSpacing) / 2
                            height: 96
                            radius: page.rTile
                            color: fcard.on
                                ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, page.aActive)
                                : fcard.hovered
                                    ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, page.aHover)
                                    : page.cIdle
                            border.width: fcard.on ? 2 : 1
                            border.color: (fcard.on || fcard.hovered) ? page.cAccent : page.cSep
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Item {
                                id: preview
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                height: 42
                                clip: true

                                BarSilhouette {
                                    anchors.fill: parent
                                    root: page.root
                                    form: fcard.modelData.form
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.bottomMargin: 8
                                spacing: 6

                                Column {
                                    width: parent.width - mark.width - parent.spacing
                                    spacing: 1

                                    UiText {
                                        width: parent.width
                                        text: fcard.modelData.label
                                        color: fcard.on ? page.cAccent : page.cInk
                                        elide: Text.ElideRight
                                        font.family: page.fontMono
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                    UiText {
                                        width: parent.width
                                        text: fcard.modelData.detail
                                        color: page.cSumi
                                        elide: Text.ElideRight
                                        font.family: page.fontMono
                                        font.pixelSize: 10
                                    }
                                }
                                UiText {
                                    id: mark
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: fcard.on ? "●" : ""
                                    color: page.cAccent
                                    font.family: page.fontMono
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                id: fma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setForm(fcard.modelData.form)
                            }
                        }
                    }
                }
            }

            // ── BAR ACCENT ──
            CcSection {
                width: col.width
                root: page.root
                title: "BAR ACCENT"

                CcSwatchGrid {
                    root: page.root
                    options: page.root ? page.root.barColorOptions : []
                    current: page.root ? page.root.barColor : ""
                    onChose: id => { if (page.root) page.root.barColor = id }
                }
            }

            // ── GAP ANIMATION (the stream in the gaps) ──
            CcSection {
                width: col.width
                root: page.root
                title: "GAP ANIMATION"

                UiText {
                    width: col.width
                    text: "The stream flowing in the gaps between widgets · pick a mode"
                    color: page.cSumi
                    font.family: page.fontMono
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Flow {
                    width: col.width
                    spacing: page.gap
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: "Off";        on: page.curAnim === 0; onAct: page.setAnim(0) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: "Stream";     on: page.curAnim === 1; onAct: page.setAnim(1) }
                    AnimTile { visible: page.isV1; width: (col.width - 2 * page.gap) / 3; caption: "Stream · 2"; on: page.curAnim === 5; onAct: page.setAnim(5) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: "Surge";      on: page.curAnim === 2; onAct: page.setAnim(2) }
                    AnimTile { visible: page.isV1; width: (col.width - 2 * page.gap) / 3; caption: "Surge · 2";  on: page.curAnim === 6; onAct: page.setAnim(6) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: "Bolt";       on: page.curAnim === 3; onAct: page.setAnim(3) }
                    AnimTile { visible: page.isV1; width: (col.width - 2 * page.gap) / 3; caption: "Bolt · 2";   on: page.curAnim === 4; onAct: page.setAnim(4) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: "Reactor";    on: page.curAnim === 7; onAct: page.setAnim(7) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: "Quotes";     on: page.curAnim === 8; onAct: page.setAnim(8) }
                }
            }

            // ── action tiles ──
            Row {
                width: col.width
                spacing: page.gap

                CcTile {
                    width: (parent.width - parent.spacing) / 2
                    root: page.root
                    icon: "splitscreen"
                    label: "Edit layout"
                    sub: "Unlock the bar to drag & arrange"
                    onActivated: {
                        if (page.root) page.root.barUnlocked = true
                        if (page.cc) page.cc.close()
                    }
                }
                CcTile {
                    width: (parent.width - parent.spacing) / 2
                    root: page.root
                    icon: "restart_alt"
                    label: "Restore layout"
                    sub: "Reset slots, order & splits"
                    onActivated: {
                        if (page.root && page.root.resetAllBarLayouts) page.root.resetAllBarLayouts()
                    }
                }
            }
        }
    }
}