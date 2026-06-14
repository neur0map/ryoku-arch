import QtQuick

// Pixel art cat companion - walks, sleeps, idles
Item {
    id: root

    // Each art-pixel = ps real pixels; auto-scales to fit
    property int ps: Math.min(8, Math.max(3, Math.floor(Math.min(width, height) / 16)))
    readonly property int sw: 14
    readonly property int sh: 14

    // State: "idle" | "walk" | "sleep"
    property string catState: "idle"
    property int    frameIdx: 0
    property real   catX: (width - sw * ps) / 2
    property int    walkDir: 1   // 1=right, -1=left

    Behavior on catX { NumberAnimation { duration: 120; easing.type: Easing.Linear } }

    // ── Palette ──────────────────────────────────────────────
    readonly property var pal: ({
        "#": "#1e1e2e",
        "b": "#e8a87c",
        "p": "#f0b0c0",
        "w": "#fae3c8",
        "e": "#2d5a3e",
        "n": "#e880a0",
        "c": "#1e1e2e",
        "s": "#c87840",
    })

    // ── Sprite frames (14×14) ────────────────────────────────
    // idle: front-facing sitting cat
    readonly property var fIdleOpen: [
        "   ##   ##    ",
        "  #pp# #pp#   ",
        "  #bbbbbbbb#  ",
        " #bbbbbbbbbb# ",
        " #bbebbebbb#  ",
        " #bbbnnbbbbb# ",
        " #bbbbbbbbb#  ",
        "  ##########  ",
        " #bbbbbbbbb#  ",
        " #bwwwwwwwb#  ",
        " ##bbbbbbb##  ",
        "  #bb   bb#   ",
        "  ##     ##   ",
        "              "
    ]
    readonly property var fIdleBlink: [
        "   ##   ##    ",
        "  #pp# #pp#   ",
        "  #bbbbbbbb#  ",
        " #bbbbbbbbbb# ",
        " #bbbbbbbbb#  ",
        " #bbbnnbbbbb# ",
        " #bbbbbbbbb#  ",
        "  ##########  ",
        " #bbbbbbbbb#  ",
        " #bwwwwwwwb#  ",
        " ##bbbbbbb##  ",
        "  #bb   bb#   ",
        "  ##     ##   ",
        "              "
    ]
    // walk: right paw / left paw alternating
    readonly property var fWalkA: [
        "   ##   ##    ",
        "  #pp# #pp#   ",
        "  #bbbbbbbb#  ",
        " #bbbbbbbbbb# ",
        " #bbebbebbb#  ",
        " #bbbnnbbbbb# ",
        " #bbbbbbbbb#  ",
        "  ##########  ",
        " #bbbbbbbbb#  ",
        " #bwwwwwwwb#  ",
        " ##bbbbbbb##  ",
        "  #b     b##  ",
        "  ##      #   ",
        "              "
    ]
    readonly property var fWalkB: [
        "   ##   ##    ",
        "  #pp# #pp#   ",
        "  #bbbbbbbb#  ",
        " #bbbbbbbbbb# ",
        " #bbebbebbb#  ",
        " #bbbnnbbbbb# ",
        " #bbbbbbbbb#  ",
        "  ##########  ",
        " #bbbbbbbbb#  ",
        " #bwwwwwwwb#  ",
        " ##bbbbbbb##  ",
        "  ##b     b#  ",
        "   #      ##  ",
        "              "
    ]
    // sleep: lying on side, head left
    readonly property var fSleep: [
        "              ",
        "  ##          ",
        " #ppb         ",
        " #bbb######## ",
        "#bccbbwwwwwwb#",
        "#bbbbbwwwwwwb#",
        " ############ ",
        "          ### ",
        "         ##   ",
        "              ",
        "              ",
        "              ",
        "              ",
        "              "
    ]

    readonly property var allFrames: ({
        "idle":  [fIdleOpen, fIdleOpen, fIdleOpen, fIdleBlink],
        "walk":  [fWalkA, fWalkB],
        "sleep": [fSleep]
    })

    // ── Canvas ───────────────────────────────────────────────
    Canvas {
        id: canvas
        width:  root.sw * root.ps
        height: root.sh * root.ps
        x: root.catX
        y: {
            if (root.catState === "sleep")
                return root.height * 0.55 - height / 2
            return root.height / 2 - height / 2
        }

        Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        // Flip horizontally when walking left; no flip for sleep
        transform: Scale {
            xScale: (root.catState !== "sleep" && root.walkDir < 0) ? -1 : 1
            origin.x: canvas.width / 2
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var stFrames = root.allFrames[root.catState];
            if (!stFrames || stFrames.length === 0) return;
            var sprite = stFrames[root.frameIdx % stFrames.length];
            if (!sprite) return;
            var p = root.ps;
            for (var row = 0; row < sprite.length; row++) {
                var line = sprite[row];
                for (var col = 0; col < line.length; col++) {
                    var ch = line[col];
                    if (ch === " ") continue;
                    var clr = root.pal[ch];
                    if (!clr) continue;
                    ctx.fillStyle = clr;
                    ctx.fillRect(col * p, row * p, p, p);
                }
            }
        }
    }

    // ── Floating Z's during sleep ────────────────────────────
    Repeater {
        model: 3
        delegate: Text {
            id: zz
            text:            ["z","z","Z"][index]
            font.family:     "JetBrains Mono"
            font.pixelSize:  root.ps * (2 + index)
            color:           "#9090b0"
            opacity:         0
            visible:         root.catState === "sleep"
            x: canvas.x + canvas.width * 0.6 + index * root.ps * 2
            y: canvas.y

            SequentialAnimation {
                running: root.catState === "sleep"
                loops:   Animation.Infinite

                PauseAnimation { duration: index * 1000 }

                ScriptAction {
                    script: {
                        zz.y       = canvas.y + canvas.height * 0.2;
                        zz.opacity = 0;
                    }
                }
                ParallelAnimation {
                    NumberAnimation { target: zz; property: "opacity"; to: 0.85; duration: 500 }
                    NumberAnimation { target: zz; property: "y"; to: canvas.y - root.ps * 8; duration: 2800; easing.type: Easing.OutCubic }
                }
                NumberAnimation { target: zz; property: "opacity"; to: 0; duration: 500 }
                PauseAnimation { duration: 400 }
            }
        }
    }

    // ── Frame timer ──────────────────────────────────────────
    Timer {
        id: frameTick
        interval: root.catState === "walk"  ? 200 :
                  root.catState === "sleep" ? 9999 : 350
        running: true; repeat: true
        onTriggered: {
            var frames = root.allFrames[root.catState];
            root.frameIdx = (root.frameIdx + 1) % (frames ? frames.length : 1);
            canvas.requestPaint();

            if (root.catState === "walk") {
                var step = root.walkDir * root.ps;
                var nx   = root.catX + step;
                var maxX = root.width - root.sw * root.ps;
                if (nx <= 0)    { nx = 0;    root.walkDir =  1; }
                if (nx >= maxX) { nx = maxX; root.walkDir = -1; }
                root.catX = nx;
            }
        }
    }

    // ── State machine ────────────────────────────────────────
    Timer {
        id: stateTick
        running: true; repeat: false
        interval: 3000 + Math.random() * 3000
        onTriggered: nextState()
    }

    function nextState() {
        var roll = Math.random();
        if (catState === "idle") {
            if (roll < 0.45) {
                catState = "walk";
                stateTick.interval = 2500 + Math.random() * 4000;
            } else if (roll < 0.70) {
                catState = "sleep";
                stateTick.interval = 6000 + Math.random() * 10000;
            } else {
                stateTick.interval = 2000 + Math.random() * 3000;
            }
        } else if (catState === "walk") {
            catState = "idle";
            stateTick.interval = 3000 + Math.random() * 4000;
        } else {
            catState = "idle";
            stateTick.interval = 4000 + Math.random() * 4000;
        }
        frameIdx = 0;
        canvas.requestPaint();
        stateTick.restart();
    }
}
