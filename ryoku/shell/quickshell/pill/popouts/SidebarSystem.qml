pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import ".."
import "../Singletons"
import "../lib/weather.js" as Wx

// the RIGHT sidebar's content = "System": the unified control centre over a
// data-driven glance rail. a plain transparent Item -- the frame blob behind it
// IS the surface, so this only fills its parent. a fixed header (力 clock +
// weather, the full DeckControls centre, a volume fader) sits over a tab rail
// whose panes are chosen by the `panes` array: the notification digest, the
// month calendar, the now-playing player, the weather forecast, and screen
// recording. `open` + `effectivePane` gate the live work so a hidden pane costs
// nothing; the shell owns `pane` and hears `paneSelected` on a tab tap.
Item {
    id: root

    property real s: 1
    property bool open: false
    // full-span sidebar: the blob fills the frame top-to-bottom, so these insets
    // push the content clear of a top bar and the bottom frame.
    property real topInset: 20 * s
    property real botInset: 20 * s

    // enabled pane keys, in display order (from Config), and the shell-owned
    // current pane; the tab rail reports taps back up via paneSelected.
    property var panes: []
    property string pane: ""
    signal paneSelected(string key)
    // the tools strip dismisses the sidebar when a capture grabs the screen; the
    // clipboard button asks the shell to open the clipboard-history popout.
    signal dismiss()
    signal clipboardRequested()

    anchors.fill: parent
    implicitWidth: 340 * s

    readonly property var loc: Qt.locale("en_US")

    // every glance pane this sidebar knows how to show, in canonical order. the
    // enabled subset (`tabs`) is `panes` mapped over this in the caller's order;
    // effectivePane falls back to the first enabled tab when `pane` is unset or
    // no longer enabled, so the rail is never left pointing at nothing.
    readonly property var catalog: [
        { key: "notifications", glyph: "notifications" },
        { key: "calendar",      glyph: "calendar_month" },
        { key: "media",         glyph: "music_note" },
        { key: "weather",       glyph: "cloud" },
        { key: "recording",     glyph: "screen_record" }
    ]
    readonly property var catalogByKey: {
        var m = ({});
        for (var i = 0; i < root.catalog.length; i++)
            m[root.catalog[i].key] = root.catalog[i];
        return m;
    }
    readonly property var tabs: root.panes.map(k => root.catalogByKey[k]).filter(Boolean)
    readonly property string effectivePane: (root.panes.indexOf(root.pane) >= 0)
        ? root.pane
        : (root.tabs.length > 0 ? root.tabs[0].key : "")

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var r = t % 60;
        return m + ":" + (r < 10 ? "0" + r : r);
    }

    SystemClock { id: sys; precision: SystemClock.Minutes; enabled: root.open }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.hair
    }

    // one media transport control: a stroked glyph that lifts on hover, dims when
    // the player can't act on it. the play/pause lead is the vermilion one.
    component MBtn: Item {
        id: mb
        property string glyph: ""
        property bool on: true
        property bool accent: false
        signal act()
        width: 34 * root.s
        height: 34 * root.s
        GlyphIcon {
            anchors.centerIn: parent
            width: (mb.accent ? 24 : 18) * root.s
            height: (mb.accent ? 24 : 18) * root.s
            name: mb.glyph
            color: !mb.on ? Theme.faint
                 : mb.accent ? (mbHov.hovered ? Theme.vermLit : Theme.brand)
                 : (mbHov.hovered ? Theme.bright : Theme.cream)
            stroke: 2
            Behavior on color { ColorAnimation { duration: Motion.hover } }
        }
        HoverHandler { id: mbHov; enabled: mb.on; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: mb.on; onTapped: mb.act() }
    }

    // tab-rail button: a Material glyph that fills and lights, with an accent
    // underline, when its pane is the one showing. a tap reports the key up to
    // the shell, which flips `pane` back down.
    component Tab: Item {
        id: tb
        property string glyph: ""
        property string key: ""
        readonly property bool sel: root.effectivePane === tb.key
        height: 40 * root.s
        MaterialIcon {
            anchors.centerIn: parent
            text: tb.glyph
            fill: tb.sel ? 1 : 0
            color: tb.sel ? Theme.brand : (tbHov.hovered ? Theme.cream : Theme.iconDim)
            font.pixelSize: 20 * root.s
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16 * root.s
            height: 2 * root.s
            radius: Theme.radius
            color: Theme.brand
            visible: tb.sel
        }
        HoverHandler { id: tbHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.paneSelected(tb.key) }
    }

    // ── control header: masthead, control centre, volume ───────────────────
    Column {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.topInset
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        spacing: 14 * root.s

        Item {
            width: parent.width
            height: mast.implicitHeight

            Column {
                id: mast
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 3 * root.s
                Eyebrow { label: "System"; s: root.s }
                Text {
                    text: Qt.formatTime(sys.date, "HH:mm")
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: 36 * root.s
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    text: root.loc.toString(sys.date, "dddd, d MMMM")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.Medium
                }
            }

            Column {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2 * root.s
                spacing: 3 * root.s
                visible: Weather.available
                GlyphIcon {
                    anchors.right: parent.right
                    width: 24 * root.s
                    height: 24 * root.s
                    name: Weather.glyph
                    color: Theme.cream
                    stroke: 1.6
                }
                Text {
                    anchors.right: parent.right
                    text: Weather.temp
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 14 * root.s
                    font.weight: Font.DemiBold
                }
            }
        }

        // the full control centre: Keep-Awake / Game session tiles over the
        // wifi / bluetooth / mic / dnd / night quick-toggles. self-sizing, and
        // its probes only poll while the sidebar is open.
        DeckControls {
            width: parent.width
            s: root.s
            active: root.open
        }

        // quick actions: the screen-capture tools (they grab the screen, so a
        // launch dismisses the sidebar) and a clipboard-history button, grouped
        // right under the control toggles.
        DeckTools {
            width: parent.width
            s: root.s
            onRequestClose: root.dismiss()
            onClipboardRequested: root.clipboardRequested()
        }

        // volume, wired straight to the default sink.
        HFader {
            width: parent.width
            s: root.s
            icon: "speaker"
            lit: root.open
            value: Audio.sink ? Audio.sink.audio.volume : 0
            muted: Audio.sink ? Audio.sink.audio.muted : false
            valueLabel: !Audio.sink ? "" : (Audio.sink.audio.muted ? "off" : Math.round(Audio.sink.audio.volume * 100) + "%")
            onMoved: (v) => { if (Audio.sink) Audio.sink.audio.volume = v; }
            onIconTapped: { if (Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
        }
    }

    // ── tab rail: data-driven from `panes`, swaps the content pane below ─────
    Row {
        id: tabRail
        anchors.top: head.bottom
        anchors.topMargin: 14 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        readonly property real tabW: root.tabs.length > 0 ? width / root.tabs.length : width
        Repeater {
            model: root.tabs
            delegate: Tab {
                required property var modelData
                width: tabRail.tabW
                glyph: modelData.glyph
                key: modelData.key
            }
        }
    }

    Divider {
        id: railDiv
        anchors.top: tabRail.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
    }

    // ── content area: the selected pane fills the rest ─────────────────────
    Item {
        id: content
        anchors.top: railDiv.bottom
        anchors.topMargin: 14 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        anchors.bottomMargin: root.botInset

        // ── notifications digest ───────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: root.effectivePane === "notifications"

            Item {
                id: notifHead
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 14 * root.s
                MicroLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Recent"
                    s: root.s
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.groups.length > 0
                    text: "Clear"
                    color: clearHov.hovered ? Theme.brand : Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6 * root.s
                    font.capitalization: Font.AllUppercase
                    HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Notifs.clearAll() }
                }
            }

            Text {
                anchors.top: notifHead.bottom
                anchors.topMargin: 16 * root.s
                anchors.left: parent.left
                anchors.right: parent.right
                visible: Notifs.groups.length === 0
                text: "No notifications"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.Medium
            }

            ListView {
                anchors.top: notifHead.bottom
                anchors.topMargin: 12 * root.s
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                spacing: 10 * root.s
                visible: Notifs.groups.length > 0
                model: (root.open && root.effectivePane === "notifications") ? Notifs.groups : []
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: nrow
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: nbody.implicitHeight

                    Item {
                        id: ndismiss
                        width: 22 * root.s
                        height: 22 * root.s
                        anchors.right: parent.right
                        anchors.top: parent.top
                        GlyphIcon {
                            anchors.centerIn: parent
                            width: 12 * root.s
                            height: 12 * root.s
                            name: "close"
                            color: ndHov.hovered ? Theme.brand : Theme.faint
                            stroke: 1.8
                        }
                        HoverHandler { id: ndHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Notifs.dismissApp(nrow.modelData.app) }
                    }

                    Column {
                        id: nbody
                        anchors.left: parent.left
                        anchors.right: ndismiss.left
                        anchors.rightMargin: 8 * root.s
                        spacing: 3 * root.s

                        Row {
                            width: parent.width
                            spacing: 6 * root.s
                            Text {
                                text: nrow.modelData.app
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 8 * root.s
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.2 * root.s
                                font.capitalization: Font.AllUppercase
                            }
                            Text {
                                visible: nrow.modelData.count > 1
                                text: "×" + nrow.modelData.count
                                color: Theme.brand
                                font.family: Theme.mono
                                font.pixelSize: 8 * root.s
                                font.weight: Font.DemiBold
                            }
                            Item { width: 1; height: 1 }
                            Text {
                                text: Notifs.ageLabel(nrow.modelData.preview)
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 8 * root.s
                            }
                        }
                        Text {
                            width: parent.width
                            text: nrow.modelData.preview ? (nrow.modelData.preview.summary || "") : ""
                            elide: Text.ElideRight
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.Medium
                        }
                        Text {
                            width: parent.width
                            visible: nrow.modelData.preview ? (nrow.modelData.preview.body || "").length > 0 : false
                            text: nrow.modelData.preview ? (nrow.modelData.preview.body || "") : ""
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                        }
                    }
                }
            }
        }

        // ── calendar (the pill's month surface, reused) ────────────────────
        Calendar {
            anchors.fill: parent
            visible: root.effectivePane === "calendar"
            s: root.s
            open: root.open && root.effectivePane === "calendar"
            shown: root.open && root.effectivePane === "calendar"
            openProgress: 1
            openW: width
            openH: height
        }

        // ── now playing ─────────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: root.effectivePane === "media"

            Text {
                anchors.centerIn: parent
                visible: !Media.present
                text: "Nothing playing"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.Medium
            }

            Timer {
                interval: 500
                running: root.open && root.effectivePane === "media" && Media.playing
                repeat: true
                onTriggered: if (Media.player) Media.player.positionChanged()
            }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 11 * root.s
                visible: Media.present

                MicroLabel { label: "Now Playing"; s: root.s }
                Marquee {
                    width: parent.width
                    text: Media.player ? (Media.player.trackTitle || "") : ""
                    color: Theme.bright
                    pixelSize: 15 * root.s
                    weight: Font.DemiBold
                    active: root.open && root.effectivePane === "media"
                }
                Text {
                    width: parent.width
                    text: Media.player ? Theme.joinArtists(Media.player.trackArtists, Media.player.trackArtist) : ""
                    elide: Text.ElideRight
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }

                Item {
                    width: parent.width
                    height: elapsed.implicitHeight
                    readonly property real len: (Media.player && Media.player.length > 0) ? Media.player.length : 0
                    readonly property real pos: Media.player ? Media.player.position : 0
                    Text {
                        id: elapsed
                        anchors.left: parent.left
                        // a live radio has no elapsed: the tally lamp stands in.
                        text: Media.radio ? "● LIVE" : root.fmt(parent.pos)
                        color: Media.radio ? Theme.vermLit : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10 * root.s
                        SequentialAnimation on opacity {
                            running: Media.radio && Media.playing && root.open
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                            onStopped: elapsed.opacity = 1
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        text: Media.radio ? "24/7" : root.fmt(parent.len)
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10 * root.s
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 3 * root.s
                    radius: Theme.radius
                    color: Qt.alpha(Theme.bright, 0.14)
                    // flat while the radio broadcasts: a buffer length is not a
                    // position, and a creeping bar on a 24/7 stream is a lie.
                    readonly property real frac: (!Media.radio && Media.player && Media.player.length > 0)
                        ? Math.max(0, Math.min(1, Media.player.position / Media.player.length)) : 0
                    Rectangle {
                        width: parent.width * parent.frac
                        height: parent.height
                        radius: Theme.radius
                        color: Theme.brand
                        Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.Linear } }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 6 * root.s
                    spacing: 22 * root.s
                    MBtn {
                        glyph: "prev"
                        on: Media.player ? Media.player.canGoPrevious : false
                        onAct: if (Media.player) Media.player.previous()
                    }
                    MBtn {
                        glyph: Media.playing ? "pause" : "play"
                        accent: true
                        on: Media.player ? Media.player.canTogglePlaying : false
                        onAct: Media.toggle()
                    }
                    MBtn {
                        glyph: "next"
                        on: Media.player ? Media.player.canGoNext : false
                        onAct: if (Media.player) Media.player.next()
                    }
                }
            }
        }

        // ── weather forecast ────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: root.effectivePane === "weather"

            Text {
                anchors.centerIn: parent
                visible: !Weather.available
                text: "Weather unavailable"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.Medium
            }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 16 * root.s
                visible: Weather.available

                Row {
                    width: parent.width
                    spacing: 13 * root.s
                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40 * root.s
                        height: 40 * root.s
                        name: Weather.glyph
                        color: Theme.cream
                        stroke: 1.5
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * root.s
                        Text {
                            text: Weather.temp
                            color: Theme.bright
                            font.family: Theme.display
                            font.pixelSize: 26 * root.s
                            font.weight: Font.Medium
                        }
                        Text {
                            text: Weather.condition + (Weather.city.length ? "  ·  " + Weather.city : "")
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 9 * root.s
                    MicroLabel { label: "Next hours"; s: root.s }
                    Row {
                        width: parent.width
                        Repeater {
                            model: Math.min(6, Weather.hourly.length)
                            Item {
                                id: hcell
                                required property int index
                                width: parent.width / 6
                                height: hcol.implicitHeight
                                Column {
                                    id: hcol
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 5 * root.s
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Weather.hourly[hcell.index].hour
                                        color: Theme.faint
                                        font.family: Theme.mono
                                        font.pixelSize: 8.5 * root.s
                                    }
                                    GlyphIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 18 * root.s
                                        height: 18 * root.s
                                        name: Wx.glyphFor(Weather.hourly[hcell.index].code)
                                        color: Theme.subtle
                                        stroke: 1.5
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Weather.hourly[hcell.index].temp + "\u00b0"
                                        color: Theme.cream
                                        font.family: Theme.mono
                                        font.pixelSize: 10 * root.s
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 7 * root.s
                    MicroLabel { label: "Forecast"; s: root.s }
                    Repeater {
                        model: Math.min(5, Weather.daily.length)
                        Item {
                            id: dcell
                            required property int index
                            width: parent.width
                            height: 22 * root.s
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46 * root.s
                                text: Weather.daily[dcell.index].day
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                            }
                            GlyphIcon {
                                anchors.centerIn: parent
                                width: 16 * root.s
                                height: 16 * root.s
                                name: Wx.glyphFor(Weather.daily[dcell.index].code)
                                color: Theme.subtle
                                stroke: 1.5
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: Weather.daily[dcell.index].hi + "\u00b0  " + Weather.daily[dcell.index].lo + "\u00b0"
                                color: Theme.dim
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                            }
                        }
                    }
                }
            }
        }

        // ── screen recording (capture control + recordings list) ────────────
        Item {
            anchors.fill: parent
            visible: root.effectivePane === "recording"

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 12 * root.s

                MicroLabel { label: "Recording"; s: root.s }
                DeckRecord {
                    width: parent.width
                    s: root.s
                    active: root.open && root.effectivePane === "recording"
                    onRequestClose: root.dismiss()
                }
            }
        }
    }
}
