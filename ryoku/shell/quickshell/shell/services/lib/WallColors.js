.pragma library

// Colour categories for the wallpaper filter, the skwd-wall idea in our
// language: a wallpaper's average hue + saturation sort it into one of twelve
// hue groups or a neutral bin (group 99, near-greyscale). bucket() mirrors the
// index.sh reading so the grouping feels the same across the switcher and here.
// swatchHsl returns an [h, s, l] triple the caller turns into a colour with
// Qt.hsla (a .pragma library has no Qt context to build colours itself).

function bucket(hue, sat) {
    if (sat < 10) return 99;
    if (hue >= 340 || hue < 25) return 0;
    return Math.floor((hue - 25) / 30) + 1;
}

var order = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 99];

var names = {
    0: "Red", 1: "Orange", 2: "Amber", 3: "Lime", 4: "Green",
    5: "Teal", 6: "Cyan", 7: "Sky", 8: "Blue", 9: "Violet",
    10: "Magenta", 11: "Pink", 99: "Neutral"
};

function swatchHsl(id) {
    if (id === 99)
        return [0, 0, 0.52];
    return [id / 12, 0.62, 0.52];
}
