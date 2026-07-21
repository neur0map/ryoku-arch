pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../Singletons"
import ".."
import "../lib/weather.js" as WxModel

// calendar popout content: a faithful port of ilyamiro's CalendarPopup as
// transparent content drawn on Ryoku's frame blob. three regions on the blob:
// a left month grid (today = bone chip with dark ink), a centre big clock +
// date with an hourly weather sun-arc bowing above it, and a 2x2 of condition
// rings (Canvas arcs). ilyamiro's outer window/panel fill, ambient blobs, 3D
// orbit wobble and schedule wing are dropped (the blob IS the surface); the
// inner content is compacted from ilyamiro's raw px (its 1450x510 hero) into a
// popout-sized dashboard, every value = raw base px * root.s.
//
// data: the Weather singleton fetches temperature / weather_code / is_day /
// relative_humidity / wind_speed / apparent_temperature (current) plus hourly
// precip probability, so all four rings carry a real reading -- WIND, HUMID,
// RAIN (chance this hour) and FEELS. the sun-arc reads Weather.hourly; with no
// hourly forecast it degrades to a single 'now' bubble from the current reading.
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitWidth: 820 * s
    implicitHeight: 300 * s
    anchors.fill: parent

    // live clock; stop ticking while the popout is closed (nothing to draw).
    SystemClock {
        id: clk
        precision: SystemClock.Seconds
        enabled: root.open
    }

    readonly property date now: clk.date
    readonly property var loc: Qt.locale("en_US")

    // Weather model glyph name -> Material Symbol, mirroring BarWeather so the
    // sun-arc icons match the bar's weather iconography.
    readonly property var symFor: ({
        "sun": "clear_day", "cloud": "cloud", "fog": "foggy",
        "rain": "rainy", "snow": "weather_snowy", "storm": "thunderstorm"
    })

    // ---- month grid model (current month only, Monday-first) ---------------
    // blank lead/trail cells keep the neighbour-month date math out (only real
    // days carry a number). rebuilt once per day (keyed off dayKey), not every
    // tick, so the 42 grid delegates are not churned every second.
    readonly property string dayKey: root.loc.toString(root.now, "yyyy-MM-dd")
    property var monthCells: []
    function buildMonth(d) {
        var year = d.getFullYear(), month = d.getMonth(), today = d.getDate();
        var first = new Date(year, month, 1).getDay();      // 0 = Sunday
        var lead = (first === 0) ? 6 : first - 1;           // shift to Monday-first
        var dim = new Date(year, month + 1, 0).getDate();
        var cells = [];
        for (var i = 0; i < lead; i++)
            cells.push({ day: "", cur: false, today: false });
        for (var n = 1; n <= dim; n++)
            cells.push({ day: String(n), cur: true, today: n === today });
        while (cells.length % 7 !== 0)
            cells.push({ day: "", cur: false, today: false });
        return cells;
    }
    onDayKeyChanged: monthCells = buildMonth(root.now)
    Component.onCompleted: monthCells = buildMonth(root.now)

    // ---- hourly sun-arc model ---------------------------------------------
    // next 7 hours from the current hour; the first entry is 'now' (verm mark).
    // keyed off curHour + the Weather fields so it rebuilds hourly / on fetch,
    // not every tick. empty when no reading has landed; a present-but-empty
    // hourly array folds to one 'now' bubble from the current reading (never
    // fabricated hours).
    readonly property int curHour: root.now.getHours()
    readonly property var arcHours: {
        if (!Weather.available)
            return [];
        var h = Weather.hourly;
        var ch = root.curHour;
        if (!h || h.length === 0)
            return [{ hour: (ch < 10 ? "0" + ch : "" + ch), temp: Weather.tempNow, glyph: Weather.glyph, now: true }];
        var start = 0;
        for (var i = 0; i < h.length; i++) {
            if (parseInt(h[i].hour, 10) === ch) { start = i; break; }
        }
        var out = [];
        var count = Math.min(6, h.length - start);
        for (var j = 0; j < count; j++) {
            var e = h[start + j];
            out.push({ hour: e.hour, temp: e.temp, glyph: WxModel.glyphFor(e.code), now: j === 0 });
        }
        return out;
    }

    // sun-arc ellipse geometry, shared by the guide path and the bubbles.
    readonly property real arcRx: (arcArea.width - 46 * root.s) / 2
    readonly property real arcRy: 34 * root.s
    readonly property real arcCy: 78 * root.s

    // reveal ramp: the sun-arc cards fade in staggered when the dashboard opens.
    property real reveal: root.open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Motion.emphasized; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedCurve } }

    // ring fills, unit-aware so the arc means something: wind maxes near a stiff
    // breeze (30 mph / 50 km/h); feels maps the comfortable-to-hot band.
    readonly property bool wxF: Weather.unit === "fahrenheit"
    readonly property real windFrac: Weather.available ? Math.min(1, Weather.wind / (wxF ? 30 : 50)) : 0
    readonly property real feelsFrac: {
        if (!Weather.available)
            return 0;
        var lo = wxF ? 20 : -5, hi = wxF ? 110 : 45;
        return Math.max(0, Math.min(1, (Weather.feels - lo) / (hi - lo)));
    }
    // chance of rain this hour = the hourly precip-probability at curHour.
    readonly property int rainChance: {
        if (!Weather.available)
            return 0;
        var h = Weather.hourly;
        for (var i = 0; h && i < h.length; i++)
            if (parseInt(h[i].hour, 10) === root.curHour)
                return h[i].precip || 0;
        return 0;
    }

    // ---- condition rings --------------------------------------------------
    // all four carry real current readings now: wind, humidity, rain-chance
    // (hourly precip probability at this hour) and apparent temperature.
    readonly property var rings: [
        { lbl: "WIND",  sym: "air",                 val: Weather.available ? "" + Weather.wind : "--",       frac: root.windFrac,                                  has: Weather.available },
        { lbl: "HUMID", sym: "humidity_percentage", val: Weather.available ? Weather.humidity + "%" : "--",  frac: Weather.available ? Weather.humidity / 100 : 0, has: Weather.available },
        { lbl: "RAIN",  sym: "rainy",               val: Weather.available ? root.rainChance + "%" : "--",   frac: Weather.available ? root.rainChance / 100 : 0,  has: Weather.available },
        { lbl: "FEELS", sym: "thermostat",          val: Weather.available ? Weather.feels + "\u00b0" : "--", frac: root.feelsFrac,                                has: Weather.available }
    ]

    // =======================================================================
    // LEFT: month grid
    // =======================================================================
    Column {
        id: calCol
        anchors.left: parent.left
        anchors.leftMargin: 26 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 246 * root.s
        spacing: 9 * root.s

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.loc.toString(root.now, "MMMM yyyy").toUpperCase()
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 13.5 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 2 * root.s
        }

        Row {
            width: parent.width
            Repeater {
                model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                delegate: Text {
                    required property var modelData
                    width: calCol.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.Medium
                }
            }
        }

        Grid {
            width: parent.width
            columns: 7
            columnSpacing: 0
            rowSpacing: 3 * root.s

            Repeater {
                model: root.monthCells
                delegate: Item {
                    required property var modelData
                    width: calCol.width / 7
                    height: 26 * root.s

                    // today = bone chip; a pill so it reads as a marked cell.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28 * root.s
                        height: 22 * root.s
                        radius: height / 2
                        visible: parent.modelData.today
                        color: Theme.bright
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.day
                        color: parent.modelData.today ? Theme.paper
                             : (parent.modelData.cur ? Theme.cream : Theme.faint)
                        font.family: Theme.mono
                        font.pixelSize: 11.5 * root.s
                        font.weight: parent.modelData.today ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }

    // =======================================================================
    // CENTRE: sun-arc + clock + date
    // =======================================================================
    Item {
        id: midCol
        anchors.left: calCol.right
        anchors.leftMargin: 10 * root.s
        anchors.right: ringGrid.left
        anchors.rightMargin: 10 * root.s
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Column {
            anchors.centerIn: parent
            spacing: 10 * root.s

            // ---- hourly weather sun-arc ----
            Item {
                id: arcArea
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(300 * root.s, midCol.width)
                height: 116 * root.s

                // faint dashed ellipse the bubbles rest on (static geometry).
                Canvas {
                    id: guide
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (root.arcRx <= 0)
                            return;
                        var cx = width / 2;
                        ctx.beginPath();
                        for (var a = 0; a <= Math.PI + 0.001; a += 0.04) {
                            var xx = cx + Math.cos(a) * root.arcRx;
                            var yy = root.arcCy - Math.sin(a) * root.arcRy;
                            if (a === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                        }
                        ctx.strokeStyle = Theme.hair;
                        ctx.lineWidth = Math.max(1, 1.5 * root.s);
                        ctx.setLineDash([3 * root.s, 7 * root.s]);
                        ctx.stroke();
                    }
                }

                Repeater {
                    model: root.arcHours
                    delegate: Item {
                        id: bub
                        required property int index
                        required property var modelData

                        // even horizontal spacing (cos-projection on the ellipse
                        // bunched the end cards); y still follows the arc so the
                        // row bows up through the middle. single bubble = peak.
                        readonly property real t: root.arcHours.length > 1 ? index / (root.arcHours.length - 1) : 0.5
                        readonly property real dx: (t * 2 - 1) * root.arcRx
                        readonly property real ang: Math.acos(Math.max(-1, Math.min(1, dx / root.arcRx)))

                        width: 42 * root.s
                        height: 58 * root.s
                        x: arcArea.width / 2 + dx - width / 2
                        y: root.arcCy - Math.sin(ang) * root.arcRy - height / 2
                        // staggered fade-in on open; the 'now' card also breathes
                        // slowly so the current hour reads as the live mark.
                        opacity: Math.max(0, Math.min(1, root.reveal * (root.arcHours.length + 1) - index))
                        scale: bub.modelData.now ? bub.pulse : 1.0
                        property real pulse: 1.08
                        SequentialAnimation on pulse {
                            running: bub.modelData.now && root.open && !Motion.reduce
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.08; to: 1.13; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.13; to: 1.08; duration: 1400; easing.type: Easing.InOutSine }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: (Theme.radius > 0 ? Theme.radius : 8 * root.s) + 4 * root.s
                            // the 'now' bubble is the verm signature; the rest
                            // stay monochrome cards.
                            color: bub.modelData.now ? Theme.verm : Theme.cardTop
                            border.width: 1
                            border.color: bub.modelData.now ? "transparent" : Theme.hair

                            Column {
                                anchors.centerIn: parent
                                spacing: 2 * root.s
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: bub.modelData.hour
                                    color: bub.modelData.now ? Theme.paper : Theme.dim
                                    font.family: Theme.mono
                                    font.pixelSize: 9 * root.s
                                    font.weight: Font.Medium
                                }
                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.symFor[bub.modelData.glyph] || "cloud"
                                    fill: 1
                                    color: bub.modelData.now ? Theme.paper : Theme.subtle
                                    font.pixelSize: 15 * root.s
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: bub.modelData.temp + "\u00b0"
                                    color: bub.modelData.now ? Theme.paper : Theme.cream
                                    font.family: Theme.mono
                                    font.pixelSize: 11 * root.s
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }

                // graceful empty state before any reading lands.
                Text {
                    anchors.centerIn: parent
                    visible: root.arcHours.length === 0
                    text: "forecast unavailable"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }
            }

            // ---- big clock ----
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3 * root.s
                Text {
                    anchors.bottom: parent.bottom
                    text: Qt.formatTime(root.now, "HH:mm")
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 50 * root.s
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8 * root.s
                    text: Qt.formatTime(root.now, ":ss")
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 20 * root.s
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.loc.toString(root.now, "dddd, d MMMM").toUpperCase()
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 12 * root.s
                font.weight: Font.Medium
                font.letterSpacing: 2 * root.s
            }
        }
    }

    // =======================================================================
    // RIGHT: condition rings (Canvas arcs)
    // =======================================================================
    Grid {
        id: ringGrid
        anchors.right: parent.right
        anchors.rightMargin: 26 * root.s
        anchors.verticalCenter: parent.verticalCenter
        columns: 2
        columnSpacing: 12 * root.s
        rowSpacing: 12 * root.s

        Repeater {
            model: root.rings
            delegate: Item {
                id: rc
                required property var modelData
                width: 66 * root.s
                height: 82 * root.s

                Column {
                    anchors.centerIn: parent
                    spacing: 6 * root.s

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 54 * root.s
                        height: 54 * root.s

                        Canvas {
                            id: ring
                            anchors.fill: parent
                            rotation: -90     // start the value arc at 12 o'clock
                            property real prog: (root.open && rc.modelData.has) ? rc.modelData.frac : 0
                            Behavior on prog { NumberAnimation { duration: Motion.reduce ? 0 : 900; easing.type: Easing.OutExpo } }
                            onProgChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var r = width / 2;
                                var lw = 4 * root.s;
                                ctx.beginPath();
                                ctx.arc(r, r, r - lw, 0, 2 * Math.PI);
                                ctx.strokeStyle = Theme.hair;
                                ctx.lineWidth = lw;
                                ctx.stroke();
                                if (prog > 0) {
                                    ctx.beginPath();
                                    ctx.arc(r, r, r - lw, 0, prog * 2 * Math.PI);
                                    ctx.strokeStyle = Theme.bright;   // bone value arc
                                    ctx.lineWidth = lw;
                                    ctx.lineCap = "round";
                                    ctx.stroke();
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: rc.modelData.val
                            color: rc.modelData.has ? Theme.cream : Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 11 * root.s
                            font.weight: Font.DemiBold
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3 * root.s
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: rc.modelData.sym
                            fill: rc.modelData.has ? 1 : 0
                            color: rc.modelData.has ? Theme.subtle : Theme.faint
                            font.pixelSize: 11 * root.s
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: rc.modelData.lbl
                            color: Theme.dim
                            font.family: Theme.mono
                            font.pixelSize: 9 * root.s
                            font.weight: Font.Medium
                            font.letterSpacing: 1 * root.s
                        }
                    }
                }
            }
        }
    }
}
