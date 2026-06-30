pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Tune mode: the left column when you're shaping the look. Presets up top, then
// the mood axes, then a saturation knob, with the finer wallust controls behind
// an Advanced drawer. Every change drives the live preview on the right.
Item {
    id: tune

    property bool advancedOpen: false

    readonly property var presets: [
        { label: "Muted Dark",    tone: "dark",  character: "pastel",  comp: false, cs: "lab",      sat: 0 },
        { label: "Vivid Dark",    tone: "dark",  character: "vivid",   comp: false, cs: "lch",      sat: 85 },
        { label: "Complementary", tone: "dark",  character: "natural", comp: true,  cs: "lch",      sat: 80 },
        { label: "Salient Pop",   tone: "dark",  character: "salient", comp: false, cs: "salience", sat: 70 },
        { label: "Pastel Light",  tone: "light", character: "pastel",  comp: false, cs: "lab",      sat: 0 }
    ]

    function set(key, val) {
        Wallhaven.settings[key] = val;
        Wallhaven.saveSettings();
    }
    function applyPreset(p) {
        var c = Wallhaven.settings;
        c.tone = p.tone;
        c.character = p.character;
        c.comp = p.comp;
        c.colorspace = p.cs;
        c.backend = "";
        c.saturation = p.sat;
        c.threshold = 0;
        c.contrast = false;
        Wallhaven.saveSettings();
    }
    function presetActive(p) {
        var c = Wallhaven.settings;
        return c.tone === p.tone && c.character === p.character && c.comp === p.comp
            && c.colorspace === p.cs && c.saturation === p.sat;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: flick.width
            spacing: 17

            // eyebrow: TUNE + the wallpaper being shaped.
            Item {
                width: parent.width
                height: 16
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Rectangle { width: 5; height: 5; radius: 1; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Tune"; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallhaven.selected ? Wallhaven.selected.resolution : ""
                    color: Theme.subtle
                    font.family: Theme.mono
                    font.pixelSize: 11
                }
            }

            SectionHead { text: "Presets" }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: tune.presets
                    delegate: PresetChip {
                        required property var modelData
                        preset: modelData
                    }
                }
            }

            SectionHead { text: "Mood" }
            SubLabel { text: "Tone" }
            Segmented {
                width: parent.width
                segW: (width - 8) / model.length
                model: [{ key: "dark", label: "Dark" }, { key: "light", label: "Light" }]
                current: Wallhaven.settings.tone
                onSelected: (k) => tune.set("tone", k)
            }
            SubLabel { text: "Character" }
            Segmented {
                width: parent.width
                segW: (width - 8) / model.length
                model: [{ key: "natural", label: "Natural" }, { key: "vivid", label: "Vivid" }, { key: "pastel", label: "Pastel" }, { key: "salient", label: "Salient" }]
                current: Wallhaven.settings.character
                onSelected: (k) => tune.set("character", k)
            }
            ToggleRow {
                label: "Complementary"
                can: Wallhaven.compAvailable
                on: Wallhaven.settings.comp
                onToggled: (v) => tune.set("comp", v)
            }

            SectionHead { text: "Adjust" }
            SliderRow {
                width: parent.width
                label: "Saturation"
                from: 0; to: 100; step: 1; decimals: 0
                autoText: "Auto"
                value: Wallhaven.settings.saturation
                onModified: (v) => tune.set("saturation", Math.round(v))
            }

            // advanced drawer.
            Item {
                width: parent.width
                height: 22
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron-right"
                        size: 12
                        tint: ah.hovered ? Theme.cream : Theme.subtle
                        rotation: tune.advancedOpen ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Advanced"; color: ah.hovered ? Theme.cream : Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
                }
                HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: tune.advancedOpen = !tune.advancedOpen }
            }
            Column {
                width: parent.width
                spacing: 12
                visible: tune.advancedOpen
                SubLabel { text: "Style" }
                Segmented {
                    width: parent.width
                    segW: (width - 8) / model.length
                    model: [{ key: "", label: "Auto" }, { key: "full", label: "Precise" }, { key: "kmeans", label: "Diverse" }, { key: "wal", label: "Pywal" }]
                    current: Wallhaven.settings.backend
                    onSelected: (k) => tune.set("backend", k)
                }
                SubLabel { text: "Colorspace" }
                Segmented {
                    width: parent.width
                    segW: (width - 8) / model.length
                    model: [{ key: "", label: "Auto" }, { key: "lab", label: "Lab" }, { key: "lch", label: "Lch" }, { key: "salience", label: "Salient" }]
                    current: Wallhaven.settings.colorspace
                    onSelected: (k) => tune.set("colorspace", k)
                }
                SliderRow {
                    width: parent.width
                    label: "Threshold"
                    from: 0; to: 100; step: 1; decimals: 0
                    autoText: "Auto"
                    value: Wallhaven.settings.threshold
                    onModified: (v) => tune.set("threshold", Math.round(v))
                }
                ToggleRow {
                    label: "Contrast-safe"
                    on: Wallhaven.settings.contrast
                    onToggled: (v) => tune.set("contrast", v)
                }
            }

            // reset.
            Item {
                width: parent.width
                height: 20
                visible: Wallhaven.tuned
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "close"; size: 11; tint: rh.hovered ? Theme.ember : Theme.faint }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Reset to default"; color: rh.hovered ? Theme.ember : Theme.faint; font.family: Theme.font; font.pixelSize: 12; Behavior on color { ColorAnimation { duration: Theme.quick } } }
                }
                HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { Wallhaven.resetTune(); tune.advancedOpen = false; } }
            }
        }
    }

    component SectionHead: Row {
        id: sh
        property string text: ""
        spacing: 7
        Rectangle { width: 5; height: 5; radius: 1; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
        Text { anchors.verticalCenter: parent.verticalCenter; text: sh.text; color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
    }

    component SubLabel: Text {
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 10
        font.letterSpacing: 1.5
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
    }

    component PresetChip: Rectangle {
        id: chip
        property var preset
        readonly property bool on: tune.presetActive(chip.preset)
        implicitWidth: pt.implicitWidth + 22
        height: 30
        radius: height / 2
        color: chip.on ? Theme.frameBg : Theme.surfaceLo
        border.width: 1
        border.color: chip.on ? Theme.ember : (ph.hovered ? Qt.alpha(Theme.ember, 0.5) : Theme.line)
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        Text { id: pt; anchors.centerIn: parent; text: chip.preset.label; color: chip.on ? Theme.ember : Theme.cream; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
        HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tune.applyPreset(chip.preset) }
    }

    component ToggleRow: Item {
        id: tr
        property string label: ""
        property bool on: false
        property bool can: true
        signal toggled(bool v)
        width: parent.width
        height: 26
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: tr.label; color: tr.can ? Theme.cream : Theme.faint; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
        Toggle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; enabled: tr.can; on: tr.on; onToggled: (v) => tr.toggled(v) }
    }
}
