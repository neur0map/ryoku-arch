var PHASES = Object.freeze({
  CLOSED: "closed",
  PRELUDE: "prelude",
  OPENING: "opening",
  OPEN: "open",
  CLOSING: "closing"
});

var CAPTURE = Object.freeze({
  IDLE: "idle",
  PENDING: "pending",
  READY: "ready",
  SKIPPED: "skipped",
  TIMED_OUT: "timed-out",
  FAILED: "failed",
  CANCELLED: "cancelled"
});

function number(value, fallback) {
  var parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function positiveHeight(value, fallback) {
  return Math.max(0, number(value, fallback));
}

function surfaceBudget(options) {
  var source = options || {};
  var screenWidth = positiveHeight(source.screenWidth, 0);
  var screenHeight = positiveHeight(source.screenHeight, 0);
  var topMargin = positiveHeight(source.topMargin, 0);
  var shadowPadX = positiveHeight(source.shadowPadX, 0);
  var shadowPadTop = positiveHeight(source.shadowPadTop, 0);
  var shadowPadBottom = positiveHeight(source.shadowPadBottom, 0);
  var bottomSafeMargin = positiveHeight(source.bottomSafeMargin, 0);
  var compressedHeroHeight = positiveHeight(
    source.compressedHeroHeight, 0);
  var maxCardHeight = Math.max(0,
    screenHeight - topMargin - shadowPadTop
      - shadowPadBottom - bottomSafeMargin);

  return {
    workAreaWidth: Math.max(0, screenWidth - shadowPadX * 2),
    // results.cardGeometry reserves its own 32px work margin.
    workAreaHeight: maxCardHeight + 32,
    maxCardHeight: maxCardHeight,
    maxDrawerHeight: Math.max(0,
      maxCardHeight - compressedHeroHeight)
  };
}

function shadowEnvelope(options) {
  var source = options || {};
  var blur = positiveHeight(source.blur, 0);
  var spread = positiveHeight(source.spread, 0);
  var offsetY = positiveHeight(source.shadowOffsetY, 0);
  var openUp = positiveHeight(source.openTranslateUp, 0);
  var closeDown = positiveHeight(source.closeTranslateDown, 0);
  return {
    top: blur + spread + openUp,
    bottom: blur + spread + offsetY + closeDown,
    side: blur + spread
  };
}

function frostPresentation(options) {
  var source = options || {};
  var maxDrawerHeight = positiveHeight(source.maxDrawerHeight, 0);
  var sourceHeight = positiveHeight(source.sourceHeight, 0);
  var drawerHeight = Math.min(
    maxDrawerHeight, positiveHeight(source.drawerHeight, 0));
  var opacity = Math.max(0, Math.min(
    1, number(source.drawerOpacity, 0)));
  var active = Boolean(source.frostActive)
    && drawerHeight > 0
    && opacity > 0
    && sourceHeight > 0;

  if (!active) {
    return {
      active: false,
      drawerHeight: 0,
      textureHeight: 0
    };
  }

  return {
    active: true,
    drawerHeight: drawerHeight,
    textureHeight: Math.min(sourceHeight,
      drawerHeight
        + positiveHeight(source.bleedTop, 0)
        + positiveHeight(source.bleedBottom, 0)),
    opacity: opacity
  };
}

function frostBackdropOpacity(active) {
  return active ? 0.72 : 1;
}

function initialState() {
  return {
    phase: PHASES.CLOSED,
    generation: 0,
    monitor: "",
    pendingMonitor: "",
    pendingHeight: 0,
    pendingFrostEligible: false,
    mapped: false,
    focusHeld: false,
    capture: CAPTURE.IDLE,
    captureDeadlineMs: 50,
    preludeTicks: 0,
    closeTicks: 0,
    closeDeadlineMs: 50,
    closeStage: "",
    visualTransparent: true,
    unmapRequested: false,
    targetHeight: 0,
    outerHeight: 0,
    visibleHeight: 0,
    maskHeight: 0,
    pendingMaskHeight: 0,
    pendingOuterHeight: 0,
    geometryStage: "stable",
    geometryDuration: 0,
    growTickReady: false,
    outerConfigured: false
  };
}

function closedState(generation) {
  var next = initialState();
  next.generation = generation;
  return next;
}

function invocation(state, monitor, height, frostEligible) {
  var target = positiveHeight(height, 0);
  return {
    phase: PHASES.PRELUDE,
    generation: state.generation + 1,
    monitor: String(monitor || ""),
    pendingMonitor: "",
    pendingHeight: 0,
    pendingFrostEligible: false,
    mapped: true,
    focusHeld: true,
    capture: frostEligible ? CAPTURE.PENDING : CAPTURE.SKIPPED,
    captureDeadlineMs: 50,
    preludeTicks: 0,
    closeTicks: 0,
    closeDeadlineMs: 50,
    closeStage: "",
    visualTransparent: true,
    unmapRequested: false,
    targetHeight: target,
    outerHeight: target,
    visibleHeight: target,
    maskHeight: target,
    pendingMaskHeight: target,
    pendingOuterHeight: target,
    geometryStage: "stable",
    geometryDuration: 0,
    growTickReady: false,
    outerConfigured: true
  };
}

function captureTerminal(capture) {
  return capture === CAPTURE.READY
    || capture === CAPTURE.SKIPPED
    || capture === CAPTURE.TIMED_OUT
    || capture === CAPTURE.FAILED
    || capture === CAPTURE.CANCELLED;
}

function promotePrelude(state) {
  if (state.phase !== PHASES.PRELUDE
      || state.preludeTicks < 2
      || !captureTerminal(state.capture)) {
    return state;
  }
  return Object.assign({}, state, {
    phase: PHASES.OPENING,
    visualTransparent: false
  });
}

function generationMatches(state, event) {
  return Number(event.generation) === state.generation;
}

function planGeometry(state, height, growing, duration) {
  var target = positiveHeight(height, state.targetHeight);
  var geometryDuration = Math.max(0, number(duration, 0));

  if (growing) {
    if (target <= state.visibleHeight && target <= state.outerHeight)
      return Object.assign({}, state, {
        targetHeight: target,
        geometryDuration: geometryDuration
      });
    return Object.assign({}, state, {
      targetHeight: target,
      outerHeight: Math.max(state.outerHeight, target),
      pendingMaskHeight: target,
      pendingOuterHeight: target,
      geometryStage: "grow-outer",
      geometryDuration: geometryDuration,
      growTickReady: false,
      outerConfigured: false
    });
  }

  if (target >= state.outerHeight && target >= state.visibleHeight)
    return planGeometry(state, target, true, geometryDuration);
  return Object.assign({}, state, {
    targetHeight: target,
    visibleHeight: target,
    maskHeight: target,
    pendingMaskHeight: target,
    pendingOuterHeight: target,
    geometryStage: "shrink-card",
    geometryDuration: geometryDuration,
    growTickReady: false,
    outerConfigured: true
  });
}

function settleGrow(state) {
  if (state.geometryStage === "grow-outer"
      && state.growTickReady && state.outerConfigured) {
    return Object.assign({}, state, {
      outerHeight: state.pendingOuterHeight,
      visibleHeight: state.pendingMaskHeight,
      maskHeight: state.pendingMaskHeight,
      geometryStage: "stable",
      growTickReady: false
    });
  }
  return state;
}

function settleGeometryTick(state) {
  if (state.geometryStage === "grow-outer") {
    return settleGrow(Object.assign({}, state, {
      growTickReady: true
    }));
  }
  if (state.geometryStage === "shrink-wait-tick") {
    return Object.assign({}, state, {
      outerHeight: state.pendingOuterHeight,
      geometryStage: "stable",
      growTickReady: false
    });
  }
  return state;
}

function beginClose(state, pendingMonitor, pendingHeight, pendingFrostEligible) {
  var prelude = state.phase === PHASES.PRELUDE;
  return Object.assign({}, state, {
    phase: PHASES.CLOSING,
    pendingMonitor: String(pendingMonitor || ""),
    pendingHeight: positiveHeight(pendingHeight, 0),
    pendingFrostEligible: Boolean(pendingFrostEligible),
    capture: prelude && state.capture === CAPTURE.PENDING
      ? CAPTURE.CANCELLED : state.capture,
    closeTicks: 0,
    closeStage: prelude || state.visualTransparent
      ? "transparent" : "visual",
    visualTransparent: prelude || state.visualTransparent,
    unmapRequested: false,
    focusHeld: true
  });
}

function reopenMapped(state, event) {
  var capture = state.capture === CAPTURE.CANCELLED
    ? CAPTURE.SKIPPED : state.capture;
  var preludeReady = state.preludeTicks >= 2 && captureTerminal(capture);
  var next = Object.assign({}, state, {
    phase: preludeReady ? PHASES.OPENING : PHASES.PRELUDE,
    pendingMonitor: "",
    pendingHeight: 0,
    pendingFrostEligible: false,
    mapped: true,
    focusHeld: true,
    capture: capture,
    closeTicks: 0,
    closeStage: "",
    visualTransparent: !preludeReady,
    unmapRequested: false
  });
  return next;
}

function finishUnmap(state) {
  if (state.pendingMonitor) {
    return invocation(
      state,
      state.pendingMonitor,
      state.pendingHeight,
      state.pendingFrostEligible
    );
  }
  return closedState(state.generation);
}

function reduce(state, event) {
  var current = state || initialState();
  var change = event || {};

  switch (change.type) {
  case "show": {
    var monitor = String(change.monitor || current.monitor || "");
    var height = positiveHeight(change.height, current.targetHeight);
    var frostEligible = change.frostEligible !== false;

    if (current.phase === PHASES.CLOSED)
      return invocation(current, monitor, height, frostEligible);

    if (monitor && monitor !== current.monitor) {
      if (current.phase === PHASES.CLOSING) {
        return Object.assign({}, current, {
          pendingMonitor: monitor,
          pendingHeight: height,
          pendingFrostEligible: frostEligible
        });
      }
      return beginClose(current, monitor, height, frostEligible);
    }

    if (current.phase === PHASES.CLOSING)
      return reopenMapped(current, change);
    return current;
  }

  case "hide":
    if (current.phase === PHASES.CLOSED)
      return current;
    if (current.phase === PHASES.CLOSING) {
      if (!current.pendingMonitor)
        return current;
      return Object.assign({}, current, {
        pendingMonitor: "",
        pendingHeight: 0,
        pendingFrostEligible: false
      });
    }
    return beginClose(current, "", 0, false);

  case "reverse":
    if (current.phase === PHASES.CLOSING) {
      return reopenMapped(current, {
        height: current.targetHeight
      });
    }
    if (current.phase === PHASES.PRELUDE
        || current.phase === PHASES.OPENING
        || current.phase === PHASES.OPEN) {
      return beginClose(current, "", 0, false);
    }
    return current;

  case "captureReady":
    if (current.phase !== PHASES.PRELUDE
        || current.capture !== CAPTURE.PENDING
        || !generationMatches(current, change))
      return current;
    return promotePrelude(Object.assign({}, current, {
      capture: CAPTURE.READY
    }));

  case "captureTimeout":
    if (current.phase !== PHASES.PRELUDE
        || current.capture !== CAPTURE.PENDING
        || !generationMatches(current, change))
      return current;
    return promotePrelude(Object.assign({}, current, {
      capture: CAPTURE.TIMED_OUT
    }));

  case "captureFailed":
  case "captureUnavailable":
    if (current.phase !== PHASES.PRELUDE
        || current.capture !== CAPTURE.PENDING
        || !generationMatches(current, change))
      return current;
    return promotePrelude(Object.assign({}, current, {
      capture: CAPTURE.FAILED
    }));

  case "frameTick": {
    if (!generationMatches(current, change))
      return current;
    var ticked = settleGeometryTick(current);
    if (ticked.phase === PHASES.PRELUDE) {
      return promotePrelude(Object.assign({}, ticked, {
        preludeTicks: Math.min(2, ticked.preludeTicks + 1)
      }));
    }
    if (ticked.phase === PHASES.CLOSING
        && ticked.closeStage === "transparent"
        && !ticked.unmapRequested) {
      var closeTicks = Math.min(2, ticked.closeTicks + 1);
      return Object.assign({}, ticked, {
        closeTicks: closeTicks,
        unmapRequested: closeTicks >= 2
      });
    }
    return ticked;
  }

  case "openComplete":
    if (current.phase !== PHASES.OPENING
        || !generationMatches(current, change))
      return current;
    return Object.assign({}, current, { phase: PHASES.OPEN });

  case "visualHidden":
    if (current.phase !== PHASES.CLOSING
        || current.closeStage !== "visual"
        || !generationMatches(current, change))
      return current;
    return Object.assign({}, current, {
      closeStage: "transparent",
      visualTransparent: true,
      closeTicks: 0,
      unmapRequested: false
    });

  case "closeFallback":
    if (current.phase !== PHASES.CLOSING
        || current.closeStage !== "transparent"
        || !generationMatches(current, change))
      return current;
    return Object.assign({}, current, { unmapRequested: true });

  case "unmapped":
    if (current.phase !== PHASES.CLOSING
        || !current.unmapRequested
        || !generationMatches(current, change))
      return current;
    return finishUnmap(current);

  case "closeComplete":
    if (current.phase !== PHASES.CLOSING
        || !generationMatches(current, change))
      return current;
    return finishUnmap(current);

  case "grow":
    if (current.phase === PHASES.CLOSED
        || !generationMatches(current, change))
      return current;
    return planGeometry(current, change.height, true, change.duration);

  case "shrink":
    if (current.phase === PHASES.CLOSED
        || !generationMatches(current, change))
      return current;
    return planGeometry(current, change.height, false, change.duration);

  case "outerConfigured":
    if (current.phase === PHASES.CLOSED
        || current.geometryStage !== "grow-outer"
        || !generationMatches(current, change))
      return current;
    if (positiveHeight(change.height, 0) < current.targetHeight)
      return current;
    return settleGrow(Object.assign({}, current, {
      outerConfigured: true
    }));

  case "growFallback": {
    if (current.phase === PHASES.CLOSED
        || current.geometryStage !== "grow-outer"
        || !generationMatches(current, change))
      return current;
    var safeHeight = Math.max(
      current.visibleHeight,
      Math.min(current.targetHeight, positiveHeight(change.height, 0))
    );
    return Object.assign({}, current, {
      visibleHeight: safeHeight,
      maskHeight: safeHeight,
      pendingMaskHeight: safeHeight,
      pendingOuterHeight: safeHeight,
      geometryStage: "stable",
      growTickReady: false,
      outerConfigured: false
    });
  }

  case "shrinkVisualComplete":
    if (current.phase === PHASES.CLOSED
        || current.geometryStage !== "shrink-card"
        || !generationMatches(current, change))
      return current;
    return Object.assign({}, current, {
      geometryStage: "shrink-wait-tick"
    });

  case "surfaceLost": {
    if (current.phase === PHASES.CLOSED
        || !generationMatches(current, change)
        || String(change.monitor || "") !== current.monitor)
      return current;
    return closedState(current.generation);
  }

  default:
    return current;
  }
}

function mapsMonitor(state, monitor) {
  return Boolean(state && state.mapped
    && state.phase !== PHASES.CLOSED
    && String(state.monitor || "") === String(monitor || ""));
}

function recoveryMonitor(options) {
  var source = options || {};
  var available = Array.isArray(source.availableMonitors)
    ? source.availableMonitors.map(function (monitor) {
      return String(monitor || "");
    }) : [];
  var candidates = [
    source.pendingMonitor,
    source.requestedMonitor,
    source.focusedMonitor,
    source.currentMonitor
  ];

  for (var index = 0; index < candidates.length; index++) {
    var candidate = String(candidates[index] || "");
    if (candidate && available.indexOf(candidate) !== -1)
      return candidate;
  }
  return available.length > 0 ? available[0] : "";
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    CAPTURE: CAPTURE,
    PHASES: PHASES,
    frostBackdropOpacity: frostBackdropOpacity,
    frostPresentation: frostPresentation,
    initialState: initialState,
    mapsMonitor: mapsMonitor,
    recoveryMonitor: recoveryMonitor,
    reduce: reduce,
    shadowEnvelope: shadowEnvelope,
    surfaceBudget: surfaceBudget
  };
}
