import QtQuick
import "../kit"
import "../../modules"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Bar editor route on the Shell Studio kit. A live bar-surface panel: every
// control writes straight to `root` (the qsbar Theme), so the running bar
// updates live and mirrors to Bar Studio. Root reads stay null-guarded - the
// page may briefly exist before `root` is assigned, and some tokens live on the
// V2 Theme first (guard the barShellStyleValid call in particular).
Item {
    id: page
    property var root: null
    property var cc: null
    readonly property var tk: page.cc ? page.cc.tokens : null

    // The content column is capped so a label and its control stay related. This
    // cap is the fix for the old panel's 600px voids: never stretch a row to the
    // panel's full width.
    readonly property real colW: Math.min(page.width, page.tk ? page.tk.contentW : 640)
    implicitHeight: col.implicitHeight

    // the five bar forms + their captions (drives the FORM grid)
    readonly property var formModel: [
        { form: "islands", label: "Islands", detail: "Split pills" },
        { form: "full",    label: "Full",    detail: "Edge to edge" },
        { form: "fit",     label: "Fit",     detail: "Inset frame" },
        { form: "dock",    label: "Dock",    detail: "Open edge" },
        { form: "notch",   label: "Notch",   detail: "Flowing shoulders" }
    ]

    // One shape picker over the single bar: islands is the split-pill form, the
    // rest are the continuous shell forms. Selecting a form just records it.
    readonly property string activeForm:
        page.root && page.root.barShellStyle ? String(page.root.barShellStyle) : "full"
    function selectForm(f) {
        if (page.root && page.root.barShellStyleValid && page.root.barShellStyleValid(f))
            page.root.barShellStyle = f
    }

    // gap-animation mode: each option sets barAnim to its exact mode value (0-8).
    readonly property int curAnim: (page.root && page.root.barAnim !== undefined) ? page.root.barAnim : -1
    function setAnim(v) { if (page.root && page.root.barAnim !== undefined) page.root.barAnim = v }

    // gap-animation presets, label <-> mode value both ways (mirrors the Hub).
    readonly property var animModes: [
        { v: 0, label: "Off" },
        { v: 1, label: "Stream" },
        { v: 2, label: "Surge" },
        { v: 3, label: "Bolt" },
        { v: 7, label: "Reactor" },
        { v: 8, label: "Quotes" }
    ]
    function animLabel(v) {
        for (var i = 0; i < page.animModes.length; i++)
            if (page.animModes[i].v === v) return page.animModes[i].label;
        return "";
    }
    function animValue(label) {
        for (var i = 0; i < page.animModes.length; i++)
            if (page.animModes[i].label === label) return page.animModes[i].v;
        return 0;
    }

    // Restore-layout arms on the first click and fires on the second, so a
    // mis-aimed pointer never wipes the layout; it disarms itself after a beat.
    property bool armedRestore: false
    Timer { id: restoreDisarm; interval: 2600; onTriggered: page.armedRestore = false }

    // The last palette slot the bar actually wore, so switching Follow wallpaper
    // off puts back the colour that was there instead of a default.
    property string pinnedSlot: "color01"
    Binding {
        target: page
        property: "pinnedSlot"
        value: page.root ? page.root.barColor : "color01"
        when: page.root && !page.root.barColorIsAccent
        restoreMode: Binding.RestoreNone
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: console.log("[cy] " + Math.round(contentY) + " ch=" + Math.round(contentHeight))

        Column {
            id: col
            width: page.colW
            spacing: page.tk ? page.tk.sectionGap : 16

            // ── live bar preview: a single full-width plate over the sections ──
            Rectangle {
                width: page.colW
                height: sil.implicitHeight + (page.tk ? page.tk.gap * 2 : 24)
                radius: page.tk ? Tokens.radius : 6
                color: page.tk ? Tokens.paperLift : "#161616"
                border.width: 1
                border.color: page.tk ? Tokens.line : "#333333"

                BarSilhouette {
                    id: sil
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: page.tk ? page.tk.pad : 24
                    anchors.rightMargin: page.tk ? page.tk.pad : 24
                    root: page.root
                    form: page.activeForm
                }
            }

            // ── POSITION ──
            Entrance {
                width: page.colW
                index: 0
                SettingCard {
                    width: page.colW
                    title: "POSITION"
                    kana: "\u4f4d\u7f6e"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        controlWidth: 130
                        label: I18n.tr("Edge")
                        source: "shell.json"
                        Seg {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["top", "bottom"]
                            current: page.root ? page.root.barPosition : "top"
                            onChose: key => { if (page.root) page.root.barPosition = key }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Auto-hide")
                        desc: I18n.tr("Reveal on edge hover")
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.root ? page.root.barAutoHide === true : false
                            onToggled: value => { if (page.root && page.root.barAutoHide !== undefined) page.root.barAutoHide = value }
                        }
                    }
                }
            }

            // ── FORM: one row of named tiles, the way the Hub picks a bar style.
            // The live silhouette sits at the top of this page already, so a tile
            // only has to name the shape; five schematics of it were five copies
            // of the same drawing and most of the panel's height.
            Entrance {
                width: page.colW
                index: 1
                SettingCard {
                    width: page.colW
                    title: "FORM"
                    kana: "\u5f62"

                    Item {
                    width: parent.width
                        height: formRow.height + (page.tk ? page.tk.gap * 2 : 24)

                        Row {
                            id: formRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: page.tk ? page.tk.gap : 12
                            anchors.rightMargin: page.tk ? page.tk.gap : 12
                            spacing: Tokens.s2
                            readonly property real cellW: (width - (page.formModel.length - 1) * Tokens.s2)
                                / Math.max(1, page.formModel.length)

                            Repeater {
                                model: page.formModel

                                delegate: Rectangle {
                                    id: ftile
                                    required property var modelData
                                    readonly property bool on: page.activeForm === modelData.form

                                width: formRow.cellW
                                    height: Tokens.px(58)
                                    radius: Tokens.radius
                                    color: ftile.on ? Tokens.bone : (fma.containsMouse ? Tokens.tint5 : "transparent")
                                    border.width: Tokens.border
                                    border.color: ftile.on ? Tokens.bone : Tokens.line
                                    Behavior on color { ColorAnimation { duration: Tokens.snap } }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: Tokens.s3
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        UiText {
                                        width: parent.width
                                            text: I18n.tr(ftile.modelData.label).toUpperCase()
                                            color: ftile.on ? Tokens.inkOnBone : Tokens.inkDim
                                            elide: Text.ElideRight
                                            font.family: Tokens.ui
                                            font.pixelSize: Tokens.fSmall
                                            font.weight: Font.Medium
                                            font.letterSpacing: Tokens.trackLabel
                                        }
                                        UiText {
                                        width: parent.width
                                            text: I18n.tr(ftile.modelData.detail)
                                            color: ftile.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                                            elide: Text.ElideRight
                                            font.family: Tokens.mono
                                            font.pixelSize: Tokens.fTiny
                                        }
                                    }

                                    MouseArea {
                                        id: fma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.selectForm(ftile.modelData.form)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── SURFACE ──
            Entrance {
                width: page.colW
                index: 2
                SettingCard {
                    width: page.colW
                    title: "SURFACE"
                    kana: "\u8868\u9762"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        controlWidth: 54
                        label: I18n.tr("Bar border")
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.root ? page.root.barBorderEnabled === true : false
                            onToggled: value => { if (page.root && page.root.barBorderEnabled !== undefined) page.root.barBorderEnabled = value }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 58
                        label: I18n.tr("Corners")
                        unit: "px"
                        value: String(page.root ? page.root.barCornerRadius : 0)
                        source: "shell.json"
                        Step {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 40
                            value: page.root ? page.root.barCornerRadius : 0
                            onModified: v => { if (page.root && page.root.barCornerRadius !== undefined) page.root.barCornerRadius = v }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Panel + tooltip")
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.root ? page.root.panelTooltipBorderEnabled === true : false
                            onToggled: value => { if (page.root && page.root.panelTooltipBorderEnabled !== undefined) page.root.panelTooltipBorderEnabled = value }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Depth")
                        desc: I18n.tr("Soft shadow")
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.root ? page.root.barShadowEnabled === true : false
                            onToggled: value => { if (page.root && page.root.barShadowEnabled !== undefined) page.root.barShadowEnabled = value }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: I18n.tr("Frost")
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.root ? page.root.barFrostEnabled === true : false
                            onToggled: value => { if (page.root && page.root.barFrostEnabled !== undefined) page.root.barFrostEnabled = value }
                        }
                    }
                }
            }

            // ── GAPS: how far the shell stays off each output edge ──
            Entrance {
                width: page.colW
                index: 3
                SettingCard {
                    width: page.colW
                    title: "GAPS"
                    kana: "\u9593\u9694"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        controlWidth: 58
                        label: I18n.tr("Top")
                        unit: "px"
                        value: String(page.root && page.root.barGapTop !== undefined ? page.root.barGapTop : 0)
                        source: "shell.json"
                        Step {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 64
                            stepBy: 1
                            value: page.root && page.root.barGapTop !== undefined ? page.root.barGapTop : 0
                            onModified: v => { if (page.root && page.root.barGapTop !== undefined) page.root.barGapTop = v }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 58
                        label: I18n.tr("Bottom")
                        unit: "px"
                        value: String(page.root && page.root.barGapBottom !== undefined ? page.root.barGapBottom : 0)
                        source: "shell.json"
                        Step {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 64
                            stepBy: 1
                            value: page.root && page.root.barGapBottom !== undefined ? page.root.barGapBottom : 0
                            onModified: v => { if (page.root && page.root.barGapBottom !== undefined) page.root.barGapBottom = v }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 58
                        label: I18n.tr("Left")
                        unit: "px"
                        value: String(page.root && page.root.barGapLeft !== undefined ? page.root.barGapLeft : 0)
                        source: "shell.json"
                        Step {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 64
                            stepBy: 1
                            value: page.root && page.root.barGapLeft !== undefined ? page.root.barGapLeft : 0
                            onModified: v => { if (page.root && page.root.barGapLeft !== undefined) page.root.barGapLeft = v }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 58
                        label: I18n.tr("Right")
                        unit: "px"
                        value: String(page.root && page.root.barGapRight !== undefined ? page.root.barGapRight : 0)
                        source: "shell.json"
                        Step {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            from: 0
                            to: 64
                            stepBy: 1
                            value: page.root && page.root.barGapRight !== undefined ? page.root.barGapRight : 0
                            onModified: v => { if (page.root && page.root.barGapRight !== undefined) page.root.barGapRight = v }
                        }
                    }
                }
            }

            // ── ACCENT: the bar's data colour, so the swatches keep their hue ──
            Entrance {
                width: page.colW
                index: 4
                SettingCard {
                    width: page.colW
                    title: "ACCENT"
                    kana: "\u8272"

                    // Following the wallpaper is the honest default: matugen already
                    // derives an accent from the image, and "accent" is a real stored
                    // value, not a fixed slot pretending to track the picture.
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        controlWidth: 54
                        label: I18n.tr("Follow wallpaper")
                        desc: I18n.tr("Wear the accent the wallpaper produced.")
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.root ? page.root.barColorIsAccent : false
                            // turning it off restores the slot that was pinned before,
                            // not a hardcoded colour01: the switch must not eat a choice
                            onToggled: v => { if (page.root) page.root.barColor = v ? "accent" : page.pinnedSlot }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        block: true
                        label: I18n.tr("Slot")
                        desc: I18n.tr("Or pin one colour out of the palette.")
                        source: "shell.json"
                        enabled: page.root ? !page.root.barColorIsAccent : true
                        CcSwatchGrid {
                            id: accentGrid
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            root: page.root
                            tk: page.tk
                            options: page.root ? page.root.barColorOptions : []
                            current: page.root ? page.root.barColor : ""
                            onChose: id => { if (page.root) page.root.barColor = id }
                        }
                    }
                }
            }

            // ── MOTION: the stream flowing in the gaps between widgets ──
            Entrance {
                width: page.colW
                index: 5
                SettingCard {
                    width: page.colW
                    title: "MOTION"
                    kana: "\u52d5\u304d"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        block: true
                        label: I18n.tr("Gap animation")
                        source: "shell.json"
                        Seg {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            options: page.animModes.map(m => m.label)
                            current: page.animLabel(page.curAnim)
                            onChose: key => page.setAnim(page.animValue(key))
                        }
                    }
                }
            }

            // ── LAYOUT: unlock to arrange, or restore the defaults ──
            Entrance {
                width: page.colW
                index: 6
                SettingCard {
                    width: page.colW
                    title: "LAYOUT"
                    kana: "\u914d\u7f6e"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        footH: 32
                        label: I18n.tr("Edit layout")
                        Btn {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("EDIT LAYOUT")
                            onAct: {
                                if (page.root) page.root.barUnlocked = true
                                if (page.cc) page.cc.close()
                            }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        footH: 32
                        label: I18n.tr("Restore layout")
                        Btn {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.armedRestore ? I18n.tr("Confirm") : I18n.tr("RESTORE LAYOUT")
                            onAct: {
                                if (!page.armedRestore) { page.armedRestore = true; restoreDisarm.restart(); return }
                                page.armedRestore = false
                                restoreDisarm.stop()
                                if (page.root && page.root.resetAllBarLayouts) page.root.resetAllBarLayouts()
                            }
                        }
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; tk: page.tk; flick: flick; z: 5 }
}
