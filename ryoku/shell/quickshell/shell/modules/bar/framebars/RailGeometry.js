function edgeRect(edge, thickness, width, height) {
    if (edge === "top") return { x: 0, y: 0, width: width, height: thickness };
    if (edge === "bottom") return { x: 0, y: height - thickness, width: width, height: thickness };
    if (edge === "left") return { x: 0, y: 0, width: thickness, height: height };
    if (edge === "right") return { x: width - thickness, y: 0, width: thickness, height: height };
    return { x: 0, y: 0, width: 0, height: 0 };
}

function reserve(edge, frameLip, railThickness, enabled) {
    return enabled && (edge === "top" || edge === "bottom" || edge === "left" || edge === "right")
        ? frameLip + railThickness
        : 0;
}

if (typeof module !== "undefined" && module.exports) module.exports = { edgeRect, reserve };
