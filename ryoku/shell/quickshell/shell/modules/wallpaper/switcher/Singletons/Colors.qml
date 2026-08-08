pragma Singleton
import QtQuick
import Quickshell

// Colour categories, the skwd-wall idea in our language: a wallpaper's average
// hue and saturation sort it into one of twelve hue groups or a neutral bin, and
// the switcher's colour strip filters by that. bucket() mirrors the reference so
// the grouping feels the same; group 99 is neutral (near-greyscale).
Singleton {
    readonly property int neutral: 99

    // hue in degrees (0-360), sat in percent (0-100).
    function bucket(hue, sat) {
        if (sat < 10) return 99;
        if (hue >= 340 || hue < 25) return 0;
        return Math.floor((hue - 25) / 30) + 1;
    }

    // swatch fill for a group id: an even rainbow for the hues, grey for neutral.
    function swatch(id) {
        if (id === 99) return Qt.hsla(0, 0, 0.52, 1);
        return Qt.hsla(id / 12, 0.62, 0.52, 1);
    }

    // hue groups in rainbow order, neutral last.
    readonly property var order: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 99]

    readonly property var names: ({
        0: "Red", 1: "Orange", 2: "Amber", 3: "Lime", 4: "Green",
        5: "Teal", 6: "Cyan", 7: "Sky", 8: "Blue", 9: "Violet",
        10: "Magenta", 11: "Pink", 99: "Neutral"
    })
}
