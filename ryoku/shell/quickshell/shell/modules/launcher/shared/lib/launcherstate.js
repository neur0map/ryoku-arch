var MODES = Object.freeze({
  REST: "rest",
  FEDERATED: "federated",
  ALL: "all",
  IMAGE: "image",
  FILE: "file",
  RECENT: "recent",
  HELP: "help",
  SPECIAL: "special"
});

var SCOPED_MODES = new Set([
  MODES.ALL,
  MODES.IMAGE,
  MODES.FILE,
  MODES.RECENT
]);

var BODY_MODES = new Set([
  MODES.FEDERATED,
  MODES.ALL,
  MODES.IMAGE,
  MODES.FILE,
  MODES.RECENT,
  MODES.HELP,
  MODES.SPECIAL
]);

// ActionShelf must keep one packed layout object while open. Recreating it
// between key events intentionally resets the odd final row's return column.
var returnColumns = new WeakMap();

function text(value) {
  return String(value == null ? "" : value);
}

function recognizedPrefix(query, prefixes) {
  const source = text(query);
  let match = "";

  if (!Object.prototype.hasOwnProperty.call(prefixes || {}, source)) {
    for (const candidate of Object.keys(prefixes || {})) {
      if (candidate.length > source.length && candidate.startsWith(source))
        return "";
    }
  }

  for (const prefix of Object.keys(prefixes || {})) {
    if (!prefix || !source.startsWith(prefix) || prefix.length <= match.length) continue;

    const tokenNeedsBoundary = /\w$/.test(prefix);
    const next = source.charAt(prefix.length);
    if (tokenNeedsBoundary && next && !/\s/.test(next)) continue;
    match = prefix;
  }

  return match;
}

function selectMode(mode, visibleQuery, prefixes) {
  const source = text(visibleQuery);
  const prefix = recognizedPrefix(source, prefixes);
  const query = prefix
    ? source.slice(prefix.length).replace(/^\s+/, "")
    : source;
  return { mode, query };
}

function routeForMode(mode, query) {
  const visibleQuery = text(query);

  switch (mode) {
  case MODES.ALL:
    return { providerId: "apps", prefix: "", query: visibleQuery };
  case MODES.IMAGE:
    return { providerId: "find", prefix: "/image", query: visibleQuery };
  case MODES.FILE:
    return { providerId: "find", prefix: "/file", query: visibleQuery };
  case MODES.RECENT:
    return { providerId: "recent", prefix: "", query: visibleQuery };
  case MODES.HELP:
    return { providerId: "help", prefix: "", query: visibleQuery };
  default:
    return { providerId: null, prefix: "", query: visibleQuery };
  }
}

function resolveTypedPrefix(mode, query, prefixes) {
  const visibleQuery = text(query);
  if (recognizedPrefix(visibleQuery, prefixes)) {
    return { mode: MODES.SPECIAL, query: visibleQuery };
  }

  if (SCOPED_MODES.has(mode)) return { mode, query: visibleQuery };
  if (visibleQuery.length === 0) return { mode: MODES.REST, query: "" };
  return { mode: MODES.FEDERATED, query: visibleQuery };
}

function acceptEvaluationSnapshot(
  requestGeneration,
  currentGeneration,
  requestToken,
  currentToken
) {
  return requestGeneration === currentGeneration
    && text(requestToken) === text(currentToken);
}

function snapshotMatchesToken(snapshotToken, currentToken) {
  const snapshot = text(snapshotToken);
  return snapshot.length > 0 && snapshot === text(currentToken);
}

function planOuterGeometry(currentHeight, desiredHeight, generation) {
  const current = Number(currentHeight);
  const target = Number(desiredHeight);
  const nextGeneration = Number(generation) + 1;

  if (target >= current) {
    return {
      generation: nextGeneration,
      pendingHeight: target,
      cancelShrink: true,
      armShrink: false,
      requestHeight: target > current ? target : 0,
      growing: target > current
    };
  }

  return {
    generation: nextGeneration,
    pendingHeight: target,
    cancelShrink: false,
    armShrink: true,
    requestHeight: 0,
    growing: false
  };
}

function acceptOuterShrink(
  timerGeneration,
  currentGeneration,
  pendingHeight,
  desiredHeight,
  currentHeight
) {
  return timerGeneration === currentGeneration
    && Number(pendingHeight) === Number(desiredHeight)
    && Number(desiredHeight) < Number(currentHeight);
}

function synchronizeOuterGeometry(options) {
  const source = options || {};
  const observedGeneration = Number(source.observedGeneration);
  const lifecycleGeneration = Number(source.lifecycleGeneration);
  if (observedGeneration === lifecycleGeneration) return null;

  const parsedHeight = Number(source.lifecycleOuterHeight);
  const height = Number.isFinite(parsedHeight) ? Math.max(0, parsedHeight) : 0;
  const localGeneration = Number(source.outerGeometryGeneration);
  return {
    observedGeneration: lifecycleGeneration,
    outerGeometryGeneration: (Number.isFinite(localGeneration)
      ? localGeneration : 0) + 1,
    lastOuterHeight: height,
    pendingOuterHeight: height,
    lastBodyOpenForGeometry: Boolean(source.bodyOpen),
    lastShelfOpenForGeometry: Boolean(source.shelfOpen)
  };
}

function compositionKeyDisposition(preeditActive, escapeKey) {
  if (!preeditActive) return "launcher";
  return escapeKey ? "cancel" : "input";
}

function toggleFocusRegion(region, hasWindows) {
  if (!hasWindows) return "results";
  return text(region) === "windows" ? "results" : "windows";
}

function activationTarget(region, hasWindows) {
  return hasWindows && text(region) === "windows" ? "window" : "result";
}

function moveResultIndex(index, count, key) {
  const length = Math.max(0, Number(count) | 0);
  if (length === 0) return -1;
  const requested = Number(index) | 0;
  if (requested < 0) return 0;
  const current = Math.max(0, Math.min(length - 1, requested));
  if (key === "Up") return Math.max(0, current - 2);
  if (key === "Down") return Math.min(length - 1, current + 2);
  if (key === "Left") return current % 2 === 0 ? current : current - 1;
  if (key === "Right") return current % 2 === 0 && current + 1 < length
    ? current + 1 : current;
  return current;
}

function escape(state) {
  const current = Object.assign({}, state);

  if (current.preeditActive) {
    return Object.assign(current, {
      consumed: true,
      cancelPreedit: true
    });
  }

  if (current.shelfOpen) {
    return Object.assign(current, {
      shelfOpen: false,
      actionFocusId: "",
      consumed: true,
      focusQuery: true
    });
  }

  const phase = text(current.phase).toLowerCase();
  if (phase === "prelude") {
    return Object.assign(current, {
      consumed: true,
      closeRequested: true,
      cancelCapture: true
    });
  }

  if (BODY_MODES.has(current.mode)) {
    return Object.assign(current, {
      mode: MODES.REST,
      query: "",
      consumed: true,
      focusQuery: true
    });
  }

  if (phase === "closed") {
    return Object.assign(current, { consumed: false });
  }
  return Object.assign(current, {
    consumed: true,
    closeRequested: true
  });
}

function rowsFor(layout) {
  const source = Array.isArray(layout)
    ? layout
    : layout && Array.isArray(layout.rows) ? layout.rows : [];

  return source.map(row => {
    const actions = Array.isArray(row)
      ? row
      : row && Array.isArray(row.actions) ? row.actions : [];
    return {
      actions: actions.filter(action => action && text(action.id).length > 0),
      fullWidth: Boolean(row && row.fullWidth)
    };
  }).filter(row => row.actions.length > 0);
}

function rememberReturnColumn(layout, actionId, column) {
  if (!layout || (typeof layout !== "object" && typeof layout !== "function")) return;
  let columns = returnColumns.get(layout);
  if (!columns) {
    columns = new Map();
    returnColumns.set(layout, columns);
  }
  columns.set(actionId, column);
}

function recalledReturnColumn(layout, actionId) {
  if (!layout || (typeof layout !== "object" && typeof layout !== "function")) return 0;
  const columns = returnColumns.get(layout);
  return columns && columns.has(actionId) ? columns.get(actionId) : 0;
}

function moveActionFocus(layout, actionId, key) {
  const rows = rowsFor(layout);
  const flat = [];
  for (const row of rows) {
    for (const action of row.actions)
      flat.push(action);
  }
  if (flat.length === 0) return "";

  const currentId = text(actionId);
  const flatIndex = flat.findIndex(action => text(action.id) === currentId);
  if (flatIndex === -1) return text(flat[0].id);

  if (key === "Tab") {
    return text(flat[(flatIndex + 1) % flat.length].id);
  }
  if (key === "Shift+Tab" || key === "Backtab") {
    return text(flat[(flatIndex - 1 + flat.length) % flat.length].id);
  }

  let rowIndex = -1;
  let columnIndex = -1;
  for (let index = 0; index < rows.length; index += 1) {
    const found = rows[index].actions.findIndex(action => text(action.id) === currentId);
    if (found !== -1) {
      rowIndex = index;
      columnIndex = found;
      break;
    }
  }

  const row = rows[rowIndex];
  if (key === "Left") {
    return columnIndex > 0 ? text(row.actions[columnIndex - 1].id) : currentId;
  }
  if (key === "Right") {
    return columnIndex + 1 < row.actions.length
      ? text(row.actions[columnIndex + 1].id) : currentId;
  }
  if (key !== "Up" && key !== "Down") return currentId;

  const targetRowIndex = rowIndex + (key === "Up" ? -1 : 1);
  if (targetRowIndex < 0 || targetRowIndex >= rows.length) return currentId;

  const targetRow = rows[targetRowIndex];
  if (targetRow.fullWidth || targetRow.actions.length === 1) {
    const targetId = text(targetRow.actions[0].id);
    rememberReturnColumn(layout, targetId, columnIndex);
    return targetId;
  }

  const desiredColumn = row.fullWidth || row.actions.length === 1
    ? recalledReturnColumn(layout, currentId)
    : columnIndex;
  const targetColumn = Math.min(desiredColumn, targetRow.actions.length - 1);
  return text(targetRow.actions[targetColumn].id);
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    MODES,
    selectMode,
    routeForMode,
    resolveTypedPrefix,
    acceptEvaluationSnapshot,
    snapshotMatchesToken,
    planOuterGeometry,
    acceptOuterShrink,
    synchronizeOuterGeometry,
    compositionKeyDisposition,
    toggleFocusRegion,
    activationTarget,
    moveResultIndex,
    escape,
    moveActionFocus
  };
}
