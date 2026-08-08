function classes(clients) {
    const seen = {};
    const result = [];
    for (const client of Array.isArray(clients) ? clients : []) {
        const className = client && typeof client.className === "string" ? client.className : "";
        if (className && !seen[className]) {
            seen[className] = true;
            result.push(className);
        }
    }
    return result;
}

function pin(pinned, className) {
    const result = Array.isArray(pinned) ? pinned.filter(value => typeof value === "string" && value) : [];
    return typeof className === "string" && className && !result.includes(className) ? result.concat(className) : result;
}

function unpin(pinned, className) {
    return (Array.isArray(pinned) ? pinned : []).filter(value => value !== className);
}

function resolve(pinned, activeClients) {
    const active = classes(activeClients);
    const configured = Array.isArray(pinned) ? pinned.filter(value => typeof value === "string" && value) : [];
    const result = [];
    for (const className of configured)
        if (!result.includes(className)) result.push(className);
    for (const className of active)
        if (!result.includes(className)) result.push(className);
    return result;
}

if (typeof module !== "undefined" && module.exports) module.exports = { pin, unpin, resolve };
