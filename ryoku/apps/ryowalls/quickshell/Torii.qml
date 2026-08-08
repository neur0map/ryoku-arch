import QtQuick
import Ryoku.Ui.Singletons

// The app mark: a torii gate. A gate frames a view, which is what a wallpaper
// browser does. Drawn in ink strokes rather than shipped as a bitmap so it
// stays monochrome and crisp at any size (the recraft/regrade pipeline that
// makes the other app marks is not run here; the shape is simple line-art).
Canvas {
    id: torii
    property color ink: Tokens.inkFaint
    property real weight: Math.max(2, width / 32)

    onPaint: {
        var c = getContext("2d");
        c.reset();
        c.strokeStyle = torii.ink;
        c.fillStyle = torii.ink;
        c.lineWidth = torii.weight;
        c.lineCap = "square";

        var w = width, h = height, lw = torii.weight;
        var left = w * 0.16, right = w * 0.84;
        var postW = w * 0.11;
        var topY = h * 0.14;          // kasagi (top lintel) upper edge
        var lintel2 = h * 0.34;       // nuki (second lintel)
        var footY = h * 0.94;

        // kasagi: the top lintel, overhanging and slightly upswept at the ends.
        c.beginPath();
        c.moveTo(w * 0.06, topY + lw * 0.5);
        c.lineTo(w * 0.94, topY + lw * 0.5);
        c.lineWidth = lw * 1.4;
        c.stroke();
        // the shimaki fillet just under the kasagi.
        c.lineWidth = lw * 0.7;
        c.beginPath();
        c.moveTo(w * 0.10, topY + lw * 1.8);
        c.lineTo(w * 0.90, topY + lw * 1.8);
        c.stroke();

        // nuki: the lower tie-beam, held inside the posts.
        c.lineWidth = lw;
        c.beginPath();
        c.moveTo(left - postW * 0.4, lintel2);
        c.lineTo(right + postW * 0.4, lintel2);
        c.stroke();

        // the two posts, tapering is faked by simple verticals.
        c.beginPath();
        c.moveTo(left, topY + lw * 1.8);
        c.lineTo(left, footY);
        c.moveTo(right, topY + lw * 1.8);
        c.lineTo(right, footY);
        c.stroke();

        // the gakuzuka: the short strut between the two lintels on the centreline.
        c.lineWidth = lw * 0.7;
        c.beginPath();
        c.moveTo(w * 0.5, topY + lw * 1.8);
        c.lineTo(w * 0.5, lintel2);
        c.stroke();
    }
    Component.onCompleted: requestPaint()
    onInkChanged: requestPaint()
}
