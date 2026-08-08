function clamp01(value, fallback) {
    var number = Number(value);
    if (!isFinite(number))
        number = fallback;
    return Math.max(0, Math.min(1, number));
}

function cover(frameWidth, frameHeight, imageWidth, imageHeight, focalX, focalY) {
    var fw = Number(frameWidth);
    var fh = Number(frameHeight);
    var iw = Number(imageWidth);
    var ih = Number(imageHeight);
    if (!(fw > 0) || !(fh > 0) || !(iw > 0) || !(ih > 0))
        return { width: 0, height: 0, x: 0, y: 0 };

    var scale = Math.max(fw / iw, fh / ih);
    var width = iw * scale;
    var height = ih * scale;
    var x = (fw - width) * clamp01(focalX, 0.5);
    var y = (fh - height) * clamp01(focalY, 0.5);
    x = x === 0 ? 0 : x;
    y = y === 0 ? 0 : y;
    return { width: width, height: height, x: x, y: y };
}

function dragFocal(start, translation, overflow) {
    var origin = clamp01(start, 0.5);
    var distance = Number(translation);
    var available = Number(overflow);
    if (!(available > 0) || !isFinite(distance))
        return origin;
    return clamp01(origin - distance / available, origin);
}

function selectSource(source, fallbackSource) {
    if (source !== undefined && source !== null && String(source).length > 0)
        return source;
    if (fallbackSource !== undefined && fallbackSource !== null)
        return fallbackSource;
    return "";
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { cover, dragFocal, selectSource };
