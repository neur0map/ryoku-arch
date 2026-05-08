# Listening Ports Hover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a rich hover popup to the three-island SecPulse listening indicator so the TCP listener count shows ports, processes or services, and purpose hints without requiring elevated process access.

**Architecture:** Move `ss -lntpeH` parsing into a small JavaScript helper under `shell/services/`, call it from `RyokuSecPulse.qml`, and render `RyokuSecPulse.listeningPorts` in `SecPulseIndicator.qml` with `StyledPopup`. Keep the listener poll gated by `bar.secPulse.showListening`.

**Tech Stack:** Quickshell QML, Qt Quick Layouts, Node for parser regression testing, Bash test harness.

---

### Task 1: Parser Contract

**Files:**
- Create: `tests/ryoku-sec-pulse-listeners.sh`
- Create: `shell/services/ryoku_sec_pulse.js`
- Modify: `shell/services/RyokuSecPulse.qml`

- [ ] **Step 1: Write the failing test**

Create `tests/ryoku-sec-pulse-listeners.sh` with samples for IPv4, IPv6, wildcard TCP listeners, cgroup service metadata, hidden process details, and known purpose hints.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ryoku-sec-pulse-listeners.sh`

Expected: FAIL because `shell/services/ryoku_sec_pulse.js` does not exist.

- [ ] **Step 3: Write minimal parser implementation**

Create `shell/services/ryoku_sec_pulse.js` with `parseListeningSockets(raw)`, `parseEndpoint(value)`, `inferPurpose(port, processName)`, service label extraction, and CommonJS export support for the test.

- [ ] **Step 4: Wire service state**

Import the helper in `RyokuSecPulse.qml`, add `property var listeningPorts: []`, change the command to `ss -lntpeH`, parse stdout, and set `listeningCount` from parsed listeners.

- [ ] **Step 5: Run parser test to verify it passes**

Run: `bash tests/ryoku-sec-pulse-listeners.sh`

Expected: PASS.

### Task 2: Rich Hover Popup

**Files:**
- Modify: `shell/modules/bar/threeIsland/SecPulseIndicator.qml`
- Modify: `tests/topbar-three-island.sh`

- [ ] **Step 1: Extend static regression coverage**

Add assertions that `SecPulseIndicator.qml` uses `StyledPopup`, binds to `RyokuSecPulse.listeningPorts`, caps visible rows, and that `RyokuSecPulse.qml` calls `parseListeningSockets`.

- [ ] **Step 2: Run topbar test to verify it fails**

Run: `bash tests/topbar-three-island.sh`

Expected: FAIL because the popup UI is not implemented yet.

- [ ] **Step 3: Implement popup UI**

Wrap the listening count row in an `Item` with a hover `MouseArea`, attach `StyledPopup`, use 16/12 rich tooltip padding, render up to 12 rows, and show `+N more` when needed.

- [ ] **Step 4: Run tests**

Run:

```bash
bash tests/ryoku-sec-pulse-listeners.sh
bash tests/topbar-three-island.sh
```

Expected: both tests PASS.

### Task 3: Runtime Sync Check

**Files:**
- Runtime mirrors described in `docs/ui-patterns.md`

- [ ] **Step 1: Check touched shell files**

List touched QML and JS files.

- [ ] **Step 2: Sync or report**

If runtime mirror paths are writable, copy touched shell files into the live mirror, shell path, and Quickshell runtime path. If they are outside the writable sandbox, report that runtime sync was not performed.
