var LAYOUT = Object.freeze({
  baseWidth: 720,
  workMargin: 32,
  heroRest: 250,
  heroCompressed: 126,
  leadHeight: 82,
  ledgerRowHeight: 44,
  actionRowHeight: 38,
  shelfMaxHeight: 114
});

function resultKey(providerId, id) {
  return JSON.stringify([String(providerId), String(id)]);
}

function normalizeAction(action) {
  return Object.assign({}, action, {
    id: String(action.id),
    enabled: action.enabled !== false,
    closeOnExecute: action.closeOnExecute !== false
  });
}

function normalizeRows(providerId, rows) {
  return (Array.isArray(rows) ? rows : [])
    .filter(row => row && String(row.id || "").length > 0)
    .map(row => {
      const raw = Array.isArray(row.actions) ? row.actions : [];
      const primary = raw[0];
      const primaryValid = primary && String(primary.id || "").length > 0
        && typeof primary.execute === "function" && primary.enabled !== false;
      const actions = raw.slice(1).filter(action =>
        action && String(action.id || "").length > 0
        && typeof action.execute === "function" && action.enabled !== false);

      return Object.assign({}, row, {
        providerId,
        resultKey: resultKey(providerId, row.id),
        primaryAction: primaryValid ? normalizeAction(primary) : null,
        secondaryActions: primaryValid ? actions.map(normalizeAction) : [],
        disabled: !primaryValid
      });
    });
}

function secondaryActions(result) {
  return result && Array.isArray(result.secondaryActions)
    ? result.secondaryActions : [];
}

function actionSignature(result) {
  return JSON.stringify(secondaryActions(result).map(action => action.id));
}

function packActions(actions) {
  const source = Array.isArray(actions) ? actions : [];
  if (source.length === 0) return [];
  if (source.length === 1) return [{ actions: source.slice(), fullWidth: true }];
  if (source.length <= 3) return [{ actions: source.slice(), fullWidth: false }];

  const rows = [];
  for (let index = 0; index < source.length; index += 2) {
    const row = source.slice(index, index + 2);
    rows.push({ actions: row, fullWidth: row.length === 1 });
  }
  return rows;
}

function cardGeometry(workWidth, workHeight, scale, drawerRequested) {
  const factor = Math.max(0, Number(scale) || 1);
  const width = Math.max(0, Math.min(
    LAYOUT.baseWidth * factor,
    Math.max(0, Number(workWidth) - LAYOUT.workMargin)
  ));
  const drawer = Math.max(0, Number(drawerRequested) || 0) * factor;
  const heroHeight = (drawer > 0 ? LAYOUT.heroCompressed : LAYOUT.heroRest) * factor;
  const availableHeight = Math.max(
    heroHeight,
    Number(workHeight) - LAYOUT.workMargin
  );
  const height = Math.min(heroHeight + drawer, availableHeight);

  return {
    width,
    height,
    heroHeight,
    bodyHeight: Math.max(0, height - heroHeight)
  };
}

function shelfGeometry(actionCount, scale) {
  const count = Math.max(0, Math.floor(Number(actionCount) || 0));
  const factor = Math.max(0, Number(scale) || 1);
  const rowCount = count === 0 ? 0 : (count <= 3 ? 1 : Math.ceil(count / 2));
  const contentHeight = rowCount * LAYOUT.actionRowHeight * factor;

  return {
    rowCount,
    contentHeight,
    viewportHeight: Math.min(contentHeight, LAYOUT.shelfMaxHeight * factor)
  };
}

function reconcileSelection(rows, selectedResultKey, fallbackIndex) {
  const source = Array.isArray(rows) ? rows : [];
  const selectedIndex = source.findIndex(row => row && row.resultKey === selectedResultKey);
  if (selectedIndex !== -1) {
    return { key: source[selectedIndex].resultKey, index: selectedIndex };
  }
  if (source.length === 0) return { key: "", index: -1 };

  const priorIndex = Number.isInteger(fallbackIndex) ? fallbackIndex : 0;
  const index = Math.min(Math.max(priorIndex, 0), source.length - 1);
  return { key: source[index].resultKey, index };
}

function hideDuplicateWindowRows(rows) {
  const source = Array.isArray(rows) ? rows : [];
  const hasApp = source.some(row => row && String(row.providerId || "") === "apps");
  return hasApp ? source.filter(row => String(row && row.providerId || "") !== "windows")
    : source;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    LAYOUT,
    resultKey,
    normalizeRows,
    secondaryActions,
    actionSignature,
    packActions,
    cardGeometry,
    shelfGeometry,
    reconcileSelection,
    hideDuplicateWindowRows
  };
}
