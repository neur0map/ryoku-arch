pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Ryoku.Config
import Ryoku.Internal
import Ryoku.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper

    readonly property bool shouldBeActive: Config.background.visualiser.enabled && (!Config.background.visualiser.autoHide || (Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true))
    property real offset: shouldBeActive ? 0 : screen.height * 0.2

    opacity: shouldBeActive ? 1 : 0

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.opacity > 0 && Config.background.visualiser.blur

        sourceComponent: MultiEffect {
            source: root.wallpaper
            maskSource: wrapper
            maskEnabled: true
            blurEnabled: true
            blur: 1
            blurMax: 32
            autoPaddingEnabled: false
        }
    }

    Item {
        id: wrapper

        anchors.fill: parent
        layer.enabled: true

        Loader {
            asynchronous: true
            anchors.fill: parent
            anchors.topMargin: root.offset
            anchors.bottomMargin: -root.offset

            active: root.opacity > 0

            sourceComponent: Item {
                ServiceRef {
                    service: Audio.cava
                }

                Item {
                    id: field

                    anchors.fill: parent
                    anchors.margins: Config.border.thickness
                    anchors.leftMargin: Visibilities.bars.get(root.screen).exclusiveZone + Tokens.spacing.small * Config.background.visualiser.spacing

                    Behavior on anchors.leftMargin {
                        Anim {}
                    }

                    // Painted styles (bars / mirrored / dots) come from the C++
                    // VisualiserBars renderer.
                    Loader {
                        anchors.fill: parent
                        active: Config.background.visualiser.style !== "skyline"

                        sourceComponent: Item {
                            VisualiserBars {
                                id: bars

                                anchors.fill: parent

                                values: Audio.cava.values
                                primaryColor: Qt.alpha(Colours.palette.m3primary, 0.7)
                                secondaryColor: Qt.alpha(Colours.palette.m3inversePrimary, 0.7)
                                rounding: Tokens.rounding.small * Config.background.visualiser.rounding
                                spacing: Tokens.spacing.small * Config.background.visualiser.spacing
                                style: Config.background.visualiser.style
                                animationDuration: Tokens.anim.durations.normal
                            }

                            FrameAnimation {
                                running: root.opacity > 0 && !bars.settled
                                onTriggered: bars.advance(frameTime)
                            }
                        }
                    }

                    // "skyline" style: a continuous, symmetric filled silhouette with a
                    // glowing top edge. Rendered in QML so the rim bloom can use
                    // MultiEffect over the live wallpaper.
                    Loader {
                        anchors.fill: parent
                        active: Config.background.visualiser.style === "skyline"

                        sourceComponent: Skyline {
                            anchors.fill: parent
                            barValues: Audio.cava.values
                        }
                    }
                }
            }
        }
    }

    component Skyline: Item {
        id: sky

        required property var barValues

        readonly property int bandCount: barValues ? barValues.length : 0
        // Render far more columns than there are cava bands so the contour is finely
        // stepped (many thin lines) instead of a few big blocky squares.
        readonly property int cols: Math.max(120, bandCount)
        readonly property real maxBarHeight: height * 0.52
        readonly property real glowWidth: Math.max(2, height * 0.0035)
        // Round the step corners by the slider, using the same 12x scale the C++ bars
        // use so "Rounding" stays consistent and looks smooth at the default (1);
        // 0 keeps crisp stair-steps, higher values smooth the contour further.
        readonly property real cornerR: Tokens.rounding.small * Config.background.visualiser.rounding

        readonly property color accent: Colours.palette.m3primary
        readonly property color glowColor: Qt.lighter(accent, 1.25)
        readonly property color coreColor: Qt.tint("#ffffff", Qt.alpha(accent, 0.12))
        readonly property color fillTop: Qt.alpha(Qt.darker(accent, 2.4), 0.5)
        readonly property color fillMid: Qt.alpha(Qt.darker(accent, 4.0), 0.55)
        readonly property color fillBottom: Qt.alpha(Colours.palette.m3scrim, 0.6)

        // Auto-hide on silence. cava decays to ~0 when nothing is playing, so without
        // this the glow/core strokes (and their bloom) trace the flat contour along the
        // bottom edge and leave a persistent neon line. The 0.02 floor matches the dots
        // renderer in visualiserbars.cpp so every visualiser style hides consistently.
        readonly property real peak: {
            const v = sky.barValues;
            if (!v || v.length === 0)
                return 0;
            let m = 0;
            for (let i = 0; i < v.length; ++i) {
                const x = v[i] ?? 0;
                if (x > m)
                    m = x;
            }
            return m;
        }
        readonly property bool hasSignal: sky.peak > 0.02

        opacity: sky.hasSignal ? 1 : 0
        visible: sky.opacity > 0

        Behavior on opacity {
            Anim {}
        }

        // Interpolated symmetric spectrum at any column: bass swells from the centre
        // outward (a dome growing from the middle), highs taper to the edges.
        function levelAtCol(i: int): real {
            const n = sky.bandCount;
            if (n < 1)
                return 0;
            if (n === 1)
                return Math.max(0, Math.min(1, sky.barValues[0] ?? 0));
            const px = (i + 0.5) / sky.cols;
            const d = Math.abs(px - 0.5) * 2;      // 0 centre, 1 edge
            const bandPos = d * (n - 1);           // centre -> band 0 (bass)
            const b0 = Math.floor(bandPos);
            const b1 = Math.min(n - 1, b0 + 1);
            const f = bandPos - b0;
            const v = (sky.barValues[b0] ?? 0) * (1 - f) + (sky.barValues[b1] ?? 0) * f;
            return Math.max(0, Math.min(1, v));
        }

        // Round the hard 90° step corners by cornerR so the "Rounding" slider
        // de-blockifies the skyline. Baked into the points so the dark fill rounds too,
        // not just the glow stroke.
        function roundCorners(pts, r) {
            const n = pts.length;
            if (n < 3 || r < 0.5)
                return pts;
            const out = [pts[0]];
            for (let i = 1; i < n - 1; ++i) {
                const a = pts[i - 1], c = pts[i], b = pts[i + 1];
                const v1x = c.x - a.x, v1y = c.y - a.y;
                const v2x = b.x - c.x, v2y = b.y - c.y;
                const l1 = Math.hypot(v1x, v1y) || 1, l2 = Math.hypot(v2x, v2y) || 1;
                const rr = Math.min(r, l1 / 2, l2 / 2);
                if (rr < 0.5) {
                    out.push(c);
                    continue;
                }
                const ax = c.x - v1x / l1 * rr, ay = c.y - v1y / l1 * rr;
                const bx = c.x + v2x / l2 * rr, by = c.y + v2y / l2 * rr;
                out.push(Qt.point(ax, ay));
                for (let k = 1; k < 3; ++k) {
                    const t = k / 3, mt = 1 - t;
                    out.push(Qt.point(mt * mt * ax + 2 * mt * t * c.x + t * t * bx, mt * mt * ay + 2 * mt * t * c.y + t * t * by));
                }
                out.push(Qt.point(bx, by));
            }
            out.push(pts[n - 1]);
            return out;
        }

        // Fine stepped top contour — two points per column so there are lots of thin
        // steps and it reads smooth rather than blocky.
        readonly property var topPts: {
            const c = sky.cols;
            if (sky.bandCount < 1)
                return [];
            const w = sky.width, h = sky.height, bw = w / c, mh = sky.maxBarHeight;
            const p = [];
            for (let i = 0; i < c; ++i) {
                const y = h - sky.levelAtCol(i) * mh;
                p.push(Qt.point(i * bw, y));
                p.push(Qt.point((i + 1) * bw, y));
            }
            return p;
        }

        // Contour with corners rounded per the slider; drives every layer below.
        readonly property var topLine: sky.roundCorners(sky.topPts, sky.cornerR)

        // Closed silhouette polygon (gapless dark body).
        readonly property var fillPts: {
            const t = sky.topLine;
            return t.length ? [Qt.point(0, sky.height)].concat(t, [Qt.point(sky.width, sky.height)]) : [];
        }

        // 1. Dark, semi-transparent body so the wallpaper shows through.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                fillGradient: LinearGradient {
                    x1: 0
                    y1: sky.height - sky.maxBarHeight
                    x2: 0
                    y2: sky.height
                    GradientStop { position: 0.0; color: sky.fillTop }
                    GradientStop { position: 0.45; color: sky.fillMid }
                    GradientStop { position: 1.0; color: sky.fillBottom }
                }
                startX: sky.fillPts.length ? sky.fillPts[0].x : 0
                startY: sky.fillPts.length ? sky.fillPts[0].y : 0
                PathPolyline { path: sky.fillPts }
            }
        }

        // 2. Soft neon bloom behind the rim for the pop.
        MultiEffect {
            anchors.fill: parent
            source: contour
            blurEnabled: true
            blur: 1
            blurMax: 64
            brightness: 0.45
            autoPaddingEnabled: false
        }

        // 3. Wide colour glow tracing the whole fine contour; feeds the bloom.
        Shape {
            id: contour

            anchors.fill: parent
            layer.enabled: true
            z: 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: sky.glowColor
                strokeWidth: sky.glowWidth * 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: sky.topLine.length ? sky.topLine[0].x : 0
                startY: sky.topLine.length ? sky.topLine[0].y : 0
                PathPolyline { path: sky.topLine }
            }
        }

        // 4. Hot near-white core on top of the glow.
        Shape {
            anchors.fill: parent
            z: 2
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: sky.coreColor
                strokeWidth: Math.max(1, sky.glowWidth)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: sky.topLine.length ? sky.topLine[0].x : 0
                startY: sky.topLine.length ? sky.topLine[0].y : 0
                PathPolyline { path: sky.topLine }
            }
        }
    }

    Behavior on offset {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }
}
