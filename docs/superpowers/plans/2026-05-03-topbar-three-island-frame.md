# Topbar Hug-Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the rejected floating-pill topbar with a Brain_Shell-style top-attached hug frame while preserving existing Ryoku/iNiR bar interactions.

**Architecture:** Update static branding tests first, then set Ryoku bar defaults for Hug mode and patch `BarContent.qml` through the existing branding overlay. The patch draws one Canvas frame with left, center, and right notches; it hides the full-width `barBackground` only inside `BarContent.qml` while keeping `bar.showBackground=true` so `Bar.qml` still renders Hug corner decorators.

**Tech Stack:** Bash 5, Perl one-shot QML patching, JSON config overlay, Quickshell QML Canvas, existing Ryoku static shell-branding tests.

---

## File Structure

- Modify: `tests/ryoku-shell-branding.sh`
  - Static contract for the Ryoku hug-frame overlay and config defaults.
- Modify: `default/ryoku-shell/config-overrides.json`
  - Enables `bar.ryokuTopbarHugFrame`, keeps Hug mode, and hides noisy modules.
- Modify: `install/config/ryoku-shell-branding.sh`
  - Applies the idempotent Canvas frame patch to source and runtime `BarContent.qml`.
  - Upgrades the old rejected `ryokuThreeIslandFrame` live patch in-place.

---

### Task 1: Correct The Static Contract

**Files:**
- Modify: `tests/ryoku-shell-branding.sh`
- Test: `tests/ryoku-shell-branding.sh`

- [x] Add assertions for `apply_topbar_hug_frame_to_file()`, the `ryokuTopbarHugFrame` marker, one Canvas frame layer, content-sized left/center/right notch widths, `ctx.arcTo()` rounded transitions, source/runtime `BarContent.qml` patching, and no `ScreenCorners.qml` patching.
- [x] Assert `bar.ryokuTopbarHugFrame=true`, `bar.cornerStyle=0`, `bar.showBackground=true`, and `bar.borderless=true`.
- [x] Assert hidden topbar modules stay hidden and requested modules stay enabled.
- [x] Run `tests/ryoku-shell-branding.sh` and verify it fails against the old pill implementation.

### Task 2: Update Ryoku Bar Defaults

**Files:**
- Modify: `default/ryoku-shell/config-overrides.json`
- Test: `jq empty default/ryoku-shell/config-overrides.json`
- Test: `tests/ryoku-shell-branding.sh`

- [x] Add `bar.ryokuTopbarHugFrame=true`.
- [x] Set `bar.cornerStyle=0` and `bar.showBackground=true` to keep Hug decorators alive.
- [x] Set `bar.borderless=true` so existing BarGroup backgrounds do not create pills.
- [x] Keep active window, left sidebar button, workspaces, right sidebar button, and weather enabled.
- [x] Keep resources, media, util buttons, clock, battery, and tray disabled.

### Task 3: Patch BarContent With A Canvas Hug Frame

**Files:**
- Modify: `install/config/ryoku-shell-branding.sh`
- Test: `bash -n install/config/ryoku-shell-branding.sh`
- Test: `tests/ryoku-shell-branding.sh`

- [x] Rename the overlay function to `apply_topbar_hug_frame_to_file()`.
- [x] Add the QML marker `readonly property bool ryokuTopbarHugFrame`.
- [x] Add `component RyokuTopbarHugFrame: Canvas` based on Brain_Shell's seamless notch path.
- [x] Insert `RyokuTopbarHugFrame { id: ryokuTopbarHugFrameCanvas }` behind the bar content.
- [x] Hide the full-width `barBackground` only while `root.ryokuTopbarHugFrame` is active.
- [x] Hide old borderless separators while the frame is active.
- [x] Keep center spacer groups laid out but transparent.
- [x] Hide timer and shell update indicators from the topbar.
- [x] Upgrade legacy `root.ryokuThreeIslandFrame` references in live files.

### Task 4: Verify Patch Application And Live Shell

**Files:**
- Source/runtime shell trees outside the repo, patched by the branding script.

- [x] Dry-run the branding script against a clean temp `BarContent.qml` from upstream `HEAD`.
- [x] Dry-run the branding script against the live legacy pill-patched `BarContent.qml`.
- [x] Run the branding script against the live source/runtime shell trees.
- [x] Restart the shell.
- [x] Check service status and logs for QML parser/load errors.
- [x] Capture a screenshot and inspect the topbar geometry.
