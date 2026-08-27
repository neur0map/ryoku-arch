pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// A full-bleed wallpaper surface that REVEALS each new image over the current one
// through a GPU shader mask (reveal.frag.qsb). The daemon publishes, per revision,
// a transition {kind, angle, waveAmp, originX, originY, bezier, edgeSoftness,
// durationMs}; the shader reveals newTex over oldTex along that mask with the
// preset's cubic-bezier timing and feathered edge, over the shared 2.2 s. This
// restores the wallpaper-daemon transition set in-shell. fade is a plain eased
// crossfade; init and the live still-frame (a null transition) also just crossfade.
//
// Two image buffers ping-pong: the just-shown image becomes the base of the next
// reveal. A revision arriving mid-reveal commits the in-flight reveal instantly
// (the incoming image becomes the committed base with no seam left behind), then
// the next reveal grows from that image, so rapid Super+Shift+W never flashes.
Item {
    id: view

    // The full file url the surface paints (path + cache-busting revision), "" until
    // the first frame; the window's paper colour shows through until then and in the
    // letterbox margins of a Contain / ScaleDown fit.
    property string url: ""

    // content_fit -> Image.fillMode. ScaleDown is Contain that never upscales, which
    // QML has no fillMode for, so a picture smaller than the surface is padded and a
    // larger one is fit.
    property string fit: "Cover"

    // The reveal preset for the current revision (null -> plain crossfade). Set by
    // the shell root from the topic frame just before `url`, so onUrlChanged reads
    // the matching transition.
    property var transition: null

    // Which buffer currently holds the committed (front) image; the other is the
    // load target for the incoming image.
    property bool aFront: true

    function fillModeFor(img) {
        switch (view.fit) {
        case "Contain":
            return Image.PreserveAspectFit;
        case "Fill":
            return Image.Stretch;
        case "ScaleDown":
            return (img.sourceSize.width <= view.width && img.sourceSize.height <= view.height) ? Image.Pad : Image.PreserveAspectFit;
        default:
            return Image.PreserveAspectCrop; // Cover
        }
    }

    function kindCode(k) {
        switch (k) {
        case "fade":
            return 0;
        case "wipe":
            return 1;
        case "wave":
            return 2;
        case "center":
            return 3;
        case "grow":
            return 4;
        case "any":
            return 5;
        case "outer":
            return 6;
        case "pixelate":
            return 7;
        case "dissolve":
            return 8;
        case "ripple":
            return 9;
        case "shatter":
            return 10;
        case "glitch":
            return 11;
        case "crt":
            return 12;
        case "stripes":
            return 13;
        case "melt":
            return 14;
        case "peel":
            return 15;
        }
        return 0;
    }

    onUrlChanged: view.beginReveal()

    // Load `url` into the back buffer and, once decoded, start the reveal. A reveal
    // already running is committed instantly first, so the new reveal starts from a
    // whole image rather than a frozen half-mask.
    function beginReveal() {
        if (view.url === "")
            return;
        if (revealAnim.running)
            view.commitInstant();
        const back = view.aFront ? imgB : imgA;
        if (back.source == view.url) {
            if (back.status === Image.Ready)
                view.startReveal();
            return;
        }
        back.source = view.url; // startReveal fires from the back buffer's onStatusChanged when Ready
    }

    // Commit the current front/back pair: the back (incoming) image becomes the new
    // committed front, and the reveal front resets so the shader shows that image
    // whole. Used both when a reveal finishes and, via commitInstant, when one is
    // interrupted.
    function commit() {
        view.aFront = !view.aFront;
        reveal.progress = 0;
        // Drop the outgoing image: it was only needed for the reveal, and held
        // a second full decode of the wallpaper for the rest of the session.
        const stale = view.aFront ? imgB : imgA;
        stale.source = "";
    }

    function commitInstant() {
        revealAnim.stop(); // an explicit stop emits no `finished`, so commit runs once
        view.commit();
    }

    // Configure the shader + animation for the current transition and run it. A null
    // transition (init / live still-frame) or reduce-motion collapses to a plain
    // eased crossfade (instant when motion is reduced).
    function startReveal() {
        const t = view.transition;
        if (Motion.reduce || !t) {
            reveal.kind = 0;
            reveal.angle = 0;
            reveal.waveAmp = 0;
            reveal.originX = 0.5;
            reveal.originY = 0.5;
            reveal.edgeSoftness = 0.002;
            reveal.seed = 0;
            revealAnim.easing.type = Easing.InOutQuad;
            revealAnim.duration = Motion.reduce ? 0 : Motion.wallpaperFade;
            revealAnim.restart();
            return;
        }
        reveal.kind = view.kindCode(t.kind);
        reveal.angle = t.angle !== undefined ? t.angle : 0;
        reveal.waveAmp = t.waveAmp !== undefined ? t.waveAmp : 0;
        reveal.originX = t.originX !== undefined ? t.originX : 0.5;
        reveal.originY = t.originY !== undefined ? t.originY : 0.5;
        reveal.edgeSoftness = t.edgeSoftness !== undefined ? t.edgeSoftness : 0.002;
        // Fresh per switch so the noise kinds (dissolve/shatter/glitch/melt) never
        // replay one pattern; fall back to a local roll if the daemon sent none.
        reveal.seed = t.seed !== undefined ? t.seed : Math.random();
        const b = t.bezier;
        if (b && b.length === 4) {
            revealAnim.easing.type = Easing.Bezier;
            revealAnim.easing.bezierCurve = [b[0], b[1], b[2], b[3], 1, 1];
        } else {
            revealAnim.easing.type = Easing.InOutCubic;
        }
        revealAnim.duration = t.durationMs > 0 ? t.durationMs : 2200;
        revealAnim.restart();
    }

    // The two ping-pong image buffers. Each renders (with its fill mode) only into
    // its ShaderEffectSource; the shader composites the sources, so the raw Images
    // are hidden. A buffer fires startReveal once its incoming image is decoded, but
    // only while it is the back buffer (imgA is back when !aFront, imgB when aFront).
    Image {
        id: imgA
        anchors.fill: parent
        cache: false
        asynchronous: true
        fillMode: view.fillModeFor(imgA)
        onStatusChanged: {
            if (status === Image.Ready)
                srcA.scheduleUpdate();
            if (status === Image.Ready && source == view.url && !view.aFront)
                view.startReveal();
        }
    }
    Image {
        id: imgB
        anchors.fill: parent
        cache: false
        asynchronous: true
        fillMode: view.fillModeFor(imgB)
        onStatusChanged: {
            if (status === Image.Ready)
                srcB.scheduleUpdate();
            if (status === Image.Ready && source == view.url && view.aFront)
                view.startReveal();
        }
    }

    // live:false + an explicit scheduleUpdate() on load: re-capture only when the
    // image content actually changes, not every frame forever on a static wallpaper.
    ShaderEffectSource {
        id: srcA
        sourceItem: imgA
        hideSource: true
        live: false
    }
    ShaderEffectSource {
        id: srcB
        sourceItem: imgB
        hideSource: true
        live: false
    }

    // The reveal: mix(oldTex, newTex, mask) over the shared duration. oldTex is the
    // committed front buffer, newTex the incoming back buffer; they swap on commit,
    // so at rest (progress 0) the shader simply shows the committed image.
    ShaderEffect {
        id: reveal
        anchors.fill: parent

        property variant oldTex: view.aFront ? srcA : srcB
        property variant newTex: view.aFront ? srcB : srcA
        property real progress: 0
        property int kind: 0
        property real angle: 0
        property real waveAmp: 0
        property real originX: 0.5
        property real originY: 0.5
        property real edgeSoftness: 0.002
        property real seed: 0
        property vector2d res: Qt.vector2d(width, height)

        fragmentShader: "reveal.frag.qsb"

        NumberAnimation {
            id: revealAnim
            target: reveal
            property: "progress"
            from: 0
            to: 1
            onFinished: view.commit()
        }
    }
}
