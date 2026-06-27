pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "Singletons"

// The storefront detail for one plugin, built like the Profile showcase: an
// ambient backdrop (warm glow blooms, a faint spec grid, an edge vignette, corner
// ticks) frames a big hero preview on the left and a dossier on the right - name,
// author, description, the hosts it supports, dependencies - with a single ember
// Install action. A screenshot strip under the hero swaps the main preview. This
// is the first thing a user sees when they open a plugin, so it is meant to read
// as a featured app-store page, not a form.
Item {
    id: detail

    property var plugin: ({})
    property bool installed: false
    property bool busy: false

    signal back()
    signal install(string id)
    signal remove(string id)

    readonly property var shots: {
        var s = [];
        if (detail.plugin.preview) s.push(detail.plugin.preview);
        var ss = detail.plugin.screenshots || [];
        for (var i = 0; i < ss.length; i++) if (ss[i] !== detail.plugin.preview) s.push(ss[i]);
        return s;
    }
    property int shotIndex: 0
    readonly property string hero: detail.shots.length > 0 ? detail.shots[Math.min(detail.shotIndex, detail.shots.length - 1)] : ""

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
    }

    // ── Ambient glow blooms ─────────────────────────────────────────────────
    Canvas {
        anchors.fill: parent
        property string warm: detail.rgba(Theme.brand, 0.11)
        property string cream: detail.rgba(Theme.cream, 0.05)
        property string deep: detail.rgba(Theme.ember, 0.05)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            function radial(cx, cy, r, color) {
                let g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                g.addColorStop(0, color);
                g.addColorStop(1, "rgba(0,0,0,0)");
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            }
            ctx.globalCompositeOperation = "screen";
            radial(width * 0.30, height * 0.42, height * 0.78, warm);
            radial(width * 0.78, height * 0.26, width * 0.40, cream);
            radial(width * 0.50, height * 1.05, width * 0.55, deep);
        }
    }

    // ── Faint spec grid ─────────────────────────────────────────────────────
    Canvas {
        anchors.fill: parent
        property string tint: detail.rgba(Theme.cream, 0.02)
        readonly property real step: 34
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = tint;
            ctx.lineWidth = 1;
            for (let x = 0; x <= width; x += step) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke(); }
            for (let y = 0; y <= height; y += step) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke(); }
        }
    }

    // ── Vignette ────────────────────────────────────────────────────────────
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            let r = Math.max(width, height) * 0.82;
            let g = ctx.createRadialGradient(width / 2, height * 0.44, r * 0.36, width / 2, height * 0.44, r);
            g.addColorStop(0, "rgba(0,0,0,0)");
            g.addColorStop(1, "rgba(0,0,0,0.24)");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
    }

    // ── Corner ticks ────────────────────────────────────────────────────────
    Repeater {
        model: 4
        Item {
            id: tick
            required property int index
            readonly property bool onLeft: index % 2 === 0
            readonly property bool onTop: index < 2
            readonly property real len: 20
            width: len; height: len
            anchors.left: onLeft ? parent.left : undefined
            anchors.right: onLeft ? undefined : parent.right
            anchors.top: onTop ? parent.top : undefined
            anchors.bottom: onTop ? undefined : parent.bottom
            anchors.margins: 10
            Rectangle {
                width: tick.len; height: 1.5; color: Theme.line
                anchors.top: tick.onTop ? parent.top : undefined
                anchors.bottom: tick.onTop ? undefined : parent.bottom
                anchors.left: tick.onLeft ? parent.left : undefined
                anchors.right: tick.onLeft ? undefined : parent.right
            }
            Rectangle {
                width: 1.5; height: tick.len; color: Theme.line
                anchors.top: tick.onTop ? parent.top : undefined
                anchors.bottom: tick.onTop ? undefined : parent.bottom
                anchors.left: tick.onLeft ? parent.left : undefined
                anchors.right: tick.onLeft ? undefined : parent.right
            }
        }
    }

    // ── Back, top-left ──────────────────────────────────────────────────────
    Rectangle {
        id: backBtn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 22
        width: backRow.implicitWidth + 22
        height: 34
        radius: 17
        color: backHover.hovered ? Theme.surface : Theme.surfaceLo
        border.width: 1
        border.color: backHover.hovered ? Theme.ember : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        Row {
            id: backRow
            anchors.centerIn: parent
            spacing: 6
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevron"; size: 14; weight: 2; rotation: 90; tint: backHover.hovered ? Theme.ember : Theme.subtle }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Store"; color: backHover.hovered ? Theme.bright : Theme.subtle; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
        }
        HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: detail.back() }
    }

    // ── Content: hero left, dossier right ───────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.topMargin: 72
        anchors.bottomMargin: 30
        anchors.leftMargin: 30
        anchors.rightMargin: 30

        readonly property real heroW: Math.round(Math.min(width * 0.56, 620))

        // Hero preview + screenshot strip.
        Column {
            id: heroCol
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.heroW
            spacing: 14

            Rectangle {
                id: heroFrame
                width: parent.width
                height: parent.height - (detail.shots.length > 1 ? 96 : 0)
                radius: 18
                color: Theme.surfaceLo
                border.width: 1
                border.color: Theme.line
                clip: true

                Image {
                    id: heroImg
                    anchors.fill: parent
                    anchors.margins: 1
                    source: detail.hero
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 1400
                    Behavior on opacity { NumberAnimation { duration: Theme.medium } }
                }
                // placeholder
                Icon {
                    anchors.centerIn: parent
                    name: detail.plugin.icon || "widgets"
                    size: 44; weight: 1.5; tint: Theme.faint
                    visible: heroImg.status !== Image.Ready
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.5)
                    shadowBlur: 1.0
                    shadowVerticalOffset: 14
                    autoPaddingEnabled: true
                }
            }

            // Screenshot strip (only when there's more than one).
            Row {
                visible: detail.shots.length > 1
                spacing: 10
                Repeater {
                    model: detail.shots
                    Rectangle {
                        id: thumb
                        required property int index
                        required property var modelData
                        readonly property bool sel: detail.shotIndex === index
                        width: 128; height: 82; radius: 10
                        color: Theme.surfaceLo
                        border.width: sel ? 2 : 1
                        border.color: sel ? Theme.ember : Theme.line
                        clip: true
                        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                        Image {
                            anchors.fill: parent; anchors.margins: sel ? 2 : 1
                            source: thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            sourceSize.width: 280
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: detail.shotIndex = thumb.index }
                    }
                }
            }
        }

        // Dossier.
        Column {
            anchors.left: heroCol.right
            anchors.leftMargin: 40
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // Brand mark + official badge.
            Row {
                spacing: 10
                Text { text: "\u529b"; color: Theme.brand; font.family: Theme.fontJp; font.pixelSize: 22 }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: badgeRow.implicitWidth + 16; height: 22; radius: 11
                    color: detail.plugin.official ? Qt.rgba(Theme.brand.r, Theme.brand.g, Theme.brand.b, 0.16) : Theme.keyBot
                    border.width: 1
                    border.color: detail.plugin.official ? Theme.brand : Theme.line
                    Row {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: 5
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: detail.plugin.official ? "verified" : "users"; size: 11; weight: 2; tint: detail.plugin.official ? Theme.ember : Theme.subtle }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: detail.plugin.official ? "Official" : "Community"; color: detail.plugin.official ? Theme.ember : Theme.subtle; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.3 }
                    }
                }
            }

            Text {
                topPadding: 14
                text: detail.plugin.name || detail.plugin.id || ""
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 34
                font.weight: Font.DemiBold
                font.letterSpacing: 0.2
            }

            Text {
                topPadding: 6
                width: parent.width
                text: detail.plugin.tagline || ""
                visible: (detail.plugin.tagline || "") !== ""
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }

            Text {
                topPadding: 4
                text: detail.plugin.author ? ("by " + detail.plugin.author) : ""
                visible: (detail.plugin.author || "") !== ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12
            }

            // Install / installed action.
            Item { width: 1; height: 22 }
            Row {
                spacing: 14
                // Dossier-stamp actions, matching the update consent prompt: a flat
                // ember stamp for the live action, hairline ghost stamps for the
                // rest. Mono, uppercase, letterspaced; no icons.
                Rectangle {
                    id: actionBtn
                    readonly property bool isInstalled: detail.installed
                    readonly property bool actionable: !actionBtn.isInstalled && !detail.busy
                    height: 32
                    width: actLabel.implicitWidth + 30
                    radius: 3
                    color: actionBtn.isInstalled
                        ? (actMa.containsMouse ? Theme.keyTop : "transparent")
                        : (actMa.containsMouse ? Qt.lighter(Theme.ember, 1.08) : Theme.ember)
                    border.width: actionBtn.isInstalled ? 1 : 0
                    border.color: actMa.containsMouse ? Theme.ember : Theme.line
                    opacity: detail.busy ? 0.7 : 1
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                    Text {
                        id: actLabel
                        anchors.centerIn: parent
                        text: detail.busy ? "WORKING" : (actionBtn.isInstalled ? "INSTALLED" : "INSTALL")
                        color: actionBtn.isInstalled ? Theme.dim : Theme.onAccent
                        font.family: Theme.mono
                        font.pixelSize: 12
                        font.weight: actionBtn.isInstalled ? Font.DemiBold : Font.Bold
                        font.letterSpacing: 2
                    }
                    MouseArea {
                        id: actMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: actionBtn.actionable
                        cursorShape: Qt.PointingHandCursor
                        onClicked: detail.install(detail.plugin.id)
                    }
                }
                // Remove, only when installed: a ghost stamp whose hairline warms to
                // the fault red on hover.
                Rectangle {
                    visible: detail.installed && !detail.busy
                    height: 32
                    width: rmLabel.implicitWidth + 22
                    radius: 3
                    color: "transparent"
                    border.width: 1
                    border.color: rmMa.containsMouse ? Theme.bad : Theme.line
                    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                    Text {
                        id: rmLabel
                        anchors.centerIn: parent
                        text: "REMOVE"
                        color: rmMa.containsMouse ? Theme.bad : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }
                    MouseArea {
                        id: rmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: detail.remove(detail.plugin.id)
                    }
                }
            }

            // Divider.
            Item { width: 1; height: 24 }
            Rectangle { width: parent.width; height: 1; color: Theme.hair }
            Item { width: 1; height: 20 }

            // Description.
            Text {
                width: parent.width
                text: detail.plugin.description || detail.plugin.tagline || ""
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 14
                lineHeight: 1.45
                wrapMode: Text.WordWrap
            }

            // Hosts it supports.
            Item { width: 1; height: 22 }
            Text { text: "PLACES WHERE IT LIVES"; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 1.6 }
            Item { width: 1; height: 10 }
            Row {
                spacing: 8
                Repeater {
                    model: detail.plugin.hosts || []
                    Rectangle {
                        id: hostChip
                        required property var modelData
                        height: 30
                        width: hb.implicitWidth + 28
                        radius: 8
                        color: Theme.keyBot
                        border.width: 1
                        border.color: Theme.line
                        Row {
                            id: hb
                            anchors.centerIn: parent
                            spacing: 7
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: hostChip.modelData === "desktopWidget" ? "widgets" : "window"
                                size: 13; weight: 1.8; tint: Theme.cream
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: hostChip.modelData === "framePopout" ? "Frame popout"
                                    : hostChip.modelData === "desktopWidget" ? "Desktop widget"
                                    : hostChip.modelData
                                color: Theme.cream
                                font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
}
