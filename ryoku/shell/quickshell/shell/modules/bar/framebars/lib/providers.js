var layouts = ["dwindle", "master", "scrolling", "monocle"];

function lines(output) {
    return typeof output === "string" ? output.split("\n") : [];
}

function parseVpn(output) {
    for (const line of lines(output)) {
        const parts = line.split(":");
        if (parts[0] === "vpn" && parts[1] === "connected" && parts.length > 2) {
            const name = parts.slice(2).join(":").trim();
            if (name) return { active: true, name: name };
        }
    }
    return { active: false, name: "" };
}

function parseProfiles(output) {
    const result = [];
    for (const line of lines(output)) {
        const match = line.trim().match(/^(?:[-*]\s*)?([a-z-]+):?$/);
        const profile = match ? match[1] : "";
        if (profile && !result.includes(profile)) result.push(profile);
    }
    return result;
}

function parseLayouts(output) {
    const result = [];
    for (const line of lines(output)) {
        const layout = line.trim();
        if (layouts.includes(layout) && !result.includes(layout)) result.push(layout);
    }
    return result;
}

if (typeof module !== "undefined" && module.exports) module.exports = { layouts, parseVpn, parseProfiles, parseLayouts };
