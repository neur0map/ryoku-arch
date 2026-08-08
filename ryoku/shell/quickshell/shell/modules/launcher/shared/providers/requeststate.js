var IDLE = "idle";
var DEBOUNCING = "debouncing";
var RUNNING = "running";
var SETTLED = "settled";

function initial() {
    return { key: "", generation: 0, phase: IDLE };
}

function generationAfter(state) {
    return state && typeof state.generation === "number"
        ? state.generation + 1 : 1;
}

function isBusy(state) {
    return !!state
        && (state.phase === DEBOUNCING || state.phase === RUNNING);
}

function isCurrent(state, key, generation) {
    return !!state
        && state.key === String(key || "")
        && state.generation === generation;
}

function begin(state, key) {
    var requestKey = String(key || "");
    if (requestKey.length === 0)
        return clear(state);
    if (state && state.key === requestKey && state.phase !== IDLE)
        return state;
    return {
        key: requestKey,
        generation: generationAfter(state),
        phase: DEBOUNCING
    };
}

function markRunning(state, key, generation) {
    if (!isCurrent(state, key, generation) || state.phase !== DEBOUNCING)
        return state;
    return {
        key: state.key,
        generation: state.generation,
        phase: RUNNING
    };
}

function settle(state, key, generation) {
    if (!isCurrent(state, key, generation) || !isBusy(state))
        return state;
    return {
        key: state.key,
        generation: state.generation,
        phase: SETTLED
    };
}

function adoptSettled(state, key) {
    var requestKey = String(key || "");
    if (requestKey.length === 0)
        return clear(state);
    if (state && state.key === requestKey && state.phase !== IDLE)
        return state;
    return {
        key: requestKey,
        generation: generationAfter(state),
        phase: SETTLED
    };
}

function clear(state) {
    if (state && state.key === "" && state.phase === IDLE)
        return state;
    return {
        key: "",
        generation: generationAfter(state),
        phase: IDLE
    };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        initial,
        isBusy,
        isCurrent,
        begin,
        markRunning,
        settle,
        adoptSettled,
        clear
    };
}
