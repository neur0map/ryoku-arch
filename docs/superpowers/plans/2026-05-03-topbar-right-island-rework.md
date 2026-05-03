# Topbar Right-Island Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the `Workspaces` widget out of the center notch into the right notch (adjacent to `rightSidebarButton`, inside the dark notch interior), un-hide `TimerIndicator` and `ShellUpdateIndicator` so they render on demand inside the right notch, and turn the now-empty center notch into a fixed-width placeholder. The three-notch hug-frame shape stays intact.

**Architecture:** All runtime QML changes are produced by the `apply_topbar_hug_frame_to_file()` perl-regex patch inside `install/config/ryoku-shell-branding.sh`. The repo never edits the iNiR `BarContent.qml` directly : it patches both `$SHELL_PATH/.../BarContent.qml` and `$RUNTIME_SHELL_PATH/.../BarContent.qml` in place. Every patch operation must remain idempotent (re-runs produce no further change). A new migration re-invokes the branding script so live systems pick up the move on update. The `Workspaces.qml` component is **not** touched : only the *instance* of `Workspaces { id: workspacesWidget … }` is relocated.

**Tech Stack:** Bash 5, Perl `-0pi -e` (slurp-mode in-place regex), iNiR/Quickshell QML, jq for JSON merge, static bash test assertions.

**Pre-change baseline:** `24aa93f0` ("Merge branch 'topbar-three-island-frame' into niri-inir-transition"). Revert with `git reset --hard 24aa93f0` if the rework breaks the bar.

---

## File Structure

**Modified:**
- `install/config/ryoku-shell-branding.sh` : `apply_topbar_hug_frame_to_file()` perl block (lines 369–436) and the `frame_properties` heredoc (lines 247–270).
- `tests/ryoku-shell-branding.sh` : `assert_topbar_frame_overlay()` (lines 98–189): drop force-hide assertions, add relocation/un-hide assertions.

**New:**
- `migrations/<unix-timestamp>.sh` : re-runs `install/config/ryoku-shell-branding.sh` so existing installs pick up the relocation.

**Untouched (do NOT edit):**
- `default/ryoku-shell/config-overrides.json` : config overlay unchanged.
- `~/.local/share/inir/modules/bar/Workspaces.qml` : component code stays as-is.
- `docs/superpowers/specs/2026-05-03-topbar-three-island-frame-design.md` : already amended in commit `41420d8`.

---

### Task 1: Un-hide `TimerIndicator` slot under the hug frame

The current patch inserts `visible: !root.ryokuTopbarHugFrame` into `TimerIndicator { … }` whenever the hug frame is on. We want the indicator to render whenever it has a reason to (active timer); hug-frame state should not gate it. The patch must also *regress* (remove) any `visible: !root.ryokuTopbarHugFrame` line that earlier versions of the script already injected on live systems.

**Files:**
- Modify: `tests/ryoku-shell-branding.sh:157-158` (drop force-hide assertion, add regression assertion)
- Modify: `install/config/ryoku-shell-branding.sh:427-429` (replace insertion regex with regression regex)

- [ ] **Step 1: Update the failing test**

In `tests/ryoku-shell-branding.sh`, replace the assertion at lines 157–158:

```bash
  assert_contains_multiline "install/config/ryoku-shell-branding.sh" 'TimerIndicator \{\n\s*visible: !root\.ryokuTopbarHugFrame' \
    "Topbar frame patch should hide the timer indicator from the bar"
```

with:

```bash
  assert_not_contains_multiline "install/config/ryoku-shell-branding.sh" 'TimerIndicator \{\n\s*visible: !root\.ryokuTopbarHugFrame\n\/s;' \
    "Topbar frame patch should no longer force-hide the timer indicator under the hug frame"
  assert_contains "install/config/ryoku-shell-branding.sh" '# Regress force-hide: TimerIndicator' \
    "Topbar frame patch should regress (remove) any previously-injected TimerIndicator force-hide line"
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: FAIL with one of the two new assertions (the regression marker comment doesn't exist yet, and the force-hide insertion still does).

- [ ] **Step 3: Replace the force-hide insertion with a regression substitution**

In `install/config/ryoku-shell-branding.sh`, find the block currently at lines 427–429:

```perl
    s/            TimerIndicator \{\n(?!                visible:)/            TimerIndicator {
                visible: !root.ryokuTopbarHugFrame
/s;
```

Replace it with:

```perl
    # Regress force-hide: TimerIndicator visible whenever its own logic says so
    s/(            TimerIndicator \{\n)                visible: !root\.ryokuTopbarHugFrame\n/$1/s;
```

Note: this is a single-line `s/.../.../s;` (no embedded newline in the replacement). The `(?!…)` lookahead is gone because we no longer insert anything; we only remove an injected line if it is present. On a fresh source file with no force-hide line, the regex matches nothing and is a no-op.

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: PASS (both new assertions hold; the rest of the suite is unaffected).

- [ ] **Step 5: Commit**

```bash
git add tests/ryoku-shell-branding.sh install/config/ryoku-shell-branding.sh
git commit -m "feat(topbar): stop force-hiding TimerIndicator under hug frame"
```

---

### Task 2: Un-hide `ShellUpdateIndicator` slot under the hug frame

Same change as Task 1, applied to `ShellUpdateIndicator`. This is the "update arrow" the user explicitly wants visible inside the right notch when an iNiR shell update is pending.

**Files:**
- Modify: `tests/ryoku-shell-branding.sh:159-160` (drop force-hide assertion, add regression assertion)
- Modify: `install/config/ryoku-shell-branding.sh:430-432` (replace insertion regex with regression regex)

- [ ] **Step 1: Update the failing test**

In `tests/ryoku-shell-branding.sh`, replace the assertion at lines 159–160:

```bash
  assert_contains_multiline "install/config/ryoku-shell-branding.sh" 'ShellUpdateIndicator \{\n\s*visible: !root\.ryokuTopbarHugFrame' \
    "Topbar frame patch should hide the shell update indicator from the bar"
```

with:

```bash
  assert_not_contains_multiline "install/config/ryoku-shell-branding.sh" 'ShellUpdateIndicator \{\n\s*visible: !root\.ryokuTopbarHugFrame\n\/s;' \
    "Topbar frame patch should no longer force-hide the shell update indicator under the hug frame"
  assert_contains "install/config/ryoku-shell-branding.sh" '# Regress force-hide: ShellUpdateIndicator' \
    "Topbar frame patch should regress (remove) any previously-injected ShellUpdateIndicator force-hide line"
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: FAIL with one of the two new assertions.

- [ ] **Step 3: Replace the force-hide insertion with a regression substitution**

In `install/config/ryoku-shell-branding.sh`, find the block currently at lines 430–432:

```perl
    s/            ShellUpdateIndicator \{\n(?!                visible:)/            ShellUpdateIndicator {
                visible: !root.ryokuTopbarHugFrame
/s;
```

Replace it with:

```perl
    # Regress force-hide: ShellUpdateIndicator visible whenever its own logic says so
    s/(            ShellUpdateIndicator \{\n)                visible: !root\.ryokuTopbarHugFrame\n/$1/s;
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/ryoku-shell-branding.sh install/config/ryoku-shell-branding.sh
git commit -m "feat(topbar): stop force-hiding ShellUpdateIndicator under hug frame"
```

---

### Task 3: Widen the right notch math (include Workspaces, raise cap)

Update the `frame_properties` heredoc so `ryokuRightContentWidth` accounts for `workspacesWidget`'s implicit width plus the layout spacing, and `ryokuRightNotchWidth`'s upper cap goes from `360` to `480`. Because the existing patch logic *replaces* the live properties block on every run (lines 382–386 of the install script), updating the heredoc updates already-patched live trees automatically.

**Files:**
- Modify: `tests/ryoku-shell-branding.sh` (add two assertions inside `assert_topbar_frame_overlay`)
- Modify: `install/config/ryoku-shell-branding.sh:258-262` (`frame_properties` heredoc)

- [ ] **Step 1: Update the failing test**

In `tests/ryoku-shell-branding.sh`, inside `assert_topbar_frame_overlay()`, after the existing `ryokuRightContentWidth` assertion at line 119–120, add:

```bash
  assert_contains "install/config/ryoku-shell-branding.sh" 'workspacesWidget\.visible \? workspacesWidget\.implicitWidth' \
    "Topbar frame patch should include workspaces in the right-notch content width"
  assert_contains "install/config/ryoku-shell-branding.sh" 'ryokuRightContentWidth \+ Appearance\.rounding\.screenRounding \+ ryokuNotchPadding, 150\), 480' \
    "Topbar frame patch should cap the right-notch width at 480 (raised from 360 to fit workspaces + status indicators)"
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: FAIL on both new assertions.

- [ ] **Step 3: Update the `frame_properties` heredoc**

In `install/config/ryoku-shell-branding.sh`, find the `frame_properties` heredoc at lines 247–270. Replace the two relevant lines (currently lines 258–259 and 262):

```
    readonly property int ryokuRightContentWidth: (rightSidebarButton.visible ? rightSidebarButton.implicitWidth : 0)
        + (weatherBarLoader.visible ? weatherBarLoader.implicitWidth + rightSectionRowLayout.spacing : 0)
```

with:

```
    readonly property int ryokuRightContentWidth: (rightSidebarButton.visible ? rightSidebarButton.implicitWidth : 0)
        + (workspacesWidget.visible ? workspacesWidget.implicitWidth + rightSectionRowLayout.spacing : 0)
        + (weatherBarLoader.visible ? weatherBarLoader.implicitWidth + rightSectionRowLayout.spacing : 0)
```

And replace:

```
    readonly property int ryokuRightNotchWidth: Math.min(Math.max(ryokuRightContentWidth + Appearance.rounding.screenRounding + ryokuNotchPadding, 150), 360)
```

with:

```
    readonly property int ryokuRightNotchWidth: Math.min(Math.max(ryokuRightContentWidth + Appearance.rounding.screenRounding + ryokuNotchPadding, 150), 480)
```

(QML id resolution is file-scoped, so `workspacesWidget` resolves whether it lives inside `middleCenterGroup` or `rightSectionRowLayout`. The reference is safe even before Task 5 runs.)

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/ryoku-shell-branding.sh install/config/ryoku-shell-branding.sh
git commit -m "feat(topbar): widen right notch to fit workspaces + indicators"
```

---

### Task 4: Replace `middleCenterGroup.implicitWidth` with a fixed `100`

After Task 5 moves Workspaces out of `middleCenterGroup`, the existing `implicitWidth` formula (`Math.min(workspacesWidget.implicitWidth + middleCenterGroup.padding * 2, 180)`) no longer reflects what the empty center notch should be. Replace it with a fixed `100` while the hug frame is active. This resolves through `ryokuCenterNotchWidth = Math.min(Math.max(100 + 40, 96), 220) = 140` : wide enough to read as a real notch, compact enough to leave room for future content. The patch must handle both fresh source files (no `implicitWidth` line yet) and already-patched files (existing formula).

**Files:**
- Modify: `tests/ryoku-shell-branding.sh` (add assertion inside `assert_topbar_frame_overlay`)
- Modify: `install/config/ryoku-shell-branding.sh:419` (replace the existing perl substitution)

- [ ] **Step 1: Update the failing test**

In `tests/ryoku-shell-branding.sh`, inside `assert_topbar_frame_overlay()`, add:

```bash
  assert_contains "install/config/ryoku-shell-branding.sh" 'implicitWidth: root\.ryokuTopbarHugFrame \? 100 : 0' \
    "Topbar frame patch should set middleCenterGroup to a fixed 100px placeholder under the hug frame"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'implicitWidth: root\.ryokuTopbarHugFrame \? Math\.min\(workspacesWidget\.implicitWidth' \
    "Topbar frame patch should no longer derive middleCenterGroup width from workspacesWidget"
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: FAIL on the new assertions (the old formula still appears in the script).

- [ ] **Step 3: Replace the perl substitution**

In `install/config/ryoku-shell-branding.sh`, find the current substitution at line 419:

```perl
    s/(        BarGroup \{\n            id: middleCenterGroup\n)(?!            implicitWidth: root\.ryokuTopbarHugFrame)/$1            implicitWidth: root.ryokuTopbarHugFrame ? Math.min(workspacesWidget.implicitWidth + middleCenterGroup.padding * 2, 180) : workspacesWidget.implicitWidth + middleCenterGroup.padding * 2\n            clip: root.ryokuTopbarHugFrame\n/s;
```

Replace it with two substitutions: one for already-patched files (overwrite the old formula), one for fresh source files (insert the new line):

```perl
    # Already-patched: replace old workspacesWidget-derived formula with fixed placeholder
    s/(            id: middleCenterGroup\n            )implicitWidth: root\.ryokuTopbarHugFrame \? Math\.min\(workspacesWidget\.implicitWidth \+ middleCenterGroup\.padding \* 2, 180\) : workspacesWidget\.implicitWidth \+ middleCenterGroup\.padding \* 2\n/$1implicitWidth: root.ryokuTopbarHugFrame ? 100 : 0\n/s;
    # Fresh source: insert fixed implicitWidth + clip
    s/(        BarGroup \{\n            id: middleCenterGroup\n)(?!            implicitWidth: )/$1            implicitWidth: root.ryokuTopbarHugFrame ? 100 : 0\n            clip: root.ryokuTopbarHugFrame\n/s;
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/ryoku-shell-branding.sh install/config/ryoku-shell-branding.sh
git commit -m "feat(topbar): replace middleCenterGroup width with fixed placeholder"
```

---

### Task 5: Move the `Workspaces` block from `middleCenterGroup` to `rightSectionRowLayout`

Extract the `Workspaces { id: workspacesWidget … }` block (including its inner `MouseArea`) from `middleCenterGroup` and re-insert it into `rightSectionRowLayout` immediately before `SysTray { … }`. With `layoutDirection: Qt.RightToLeft`, that places `Workspaces` visually adjacent to (one slot left of) `rightSidebarButton`, inside the dark notch interior. Use a sentinel comment line (`// Ryoku: workspaces relocated to right notch`) to make the move idempotent.

**Files:**
- Modify: `tests/ryoku-shell-branding.sh` (add assertions inside `assert_topbar_frame_overlay`)
- Modify: `install/config/ryoku-shell-branding.sh:419-420` (add a relocate block to the perl substitution chain)

- [ ] **Step 1: Update the failing test**

In `tests/ryoku-shell-branding.sh`, inside `assert_topbar_frame_overlay()`, add:

```bash
  assert_contains "install/config/ryoku-shell-branding.sh" '// Ryoku: workspaces relocated to right notch' \
    "Topbar frame patch should mark the Workspaces relocation with a sentinel comment for idempotency"
  assert_contains "install/config/ryoku-shell-branding.sh" 'unless \(/\\/\\/ Ryoku: workspaces relocated to right notch/\)' \
    "Topbar frame patch should guard the Workspaces relocation behind its sentinel comment"
  assert_contains "install/config/ryoku-shell-branding.sh" 'SysTray \\\{' \
    "Topbar frame patch should target the SysTray declaration as the right-section anchor for relocation"
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: FAIL on the three new assertions.

- [ ] **Step 3: Add the relocation perl block**

In `install/config/ryoku-shell-branding.sh`, find the `apply_topbar_hug_frame_to_file()` perl block. After the existing line that inserts `clip: root.ryokuTopbarHugFrame` into the Workspaces block (was line 420 pre-Task-4; locate it by searching for `Workspaces \{\\n                id: workspacesWidget`), add the following relocation block before the `s/(            BarGroup \{\n                id: rightCenterGroupContent\n)…` substitution:

```perl
    # Move Workspaces from middleCenterGroup to rightSectionRowLayout (idempotent via sentinel).
    # In RTL layout, the second declared child of rightSectionRowLayout renders one slot
    # left of the first; placing Workspaces immediately before SysTray puts it visually
    # adjacent to rightSidebarButton, inside the dark notch interior.
    unless (/\/\/ Ryoku: workspaces relocated to right notch/) {
        my $workspaces_block = "";
        if (s{\n(            Workspaces \{\n                id: workspacesWidget\n(?:                [^\n]*\n)+?            \})\n}{\n}s) {
            $workspaces_block = $1;
        }
        if ($workspaces_block) {
            my $insertion = "\n            // Ryoku: workspaces relocated to right notch\n${workspaces_block}\n";
            s/(\n            SysTray \{)/$insertion$1/s;
        }
    }
```

The non-greedy `(?:                [^\n]*\n)+?` inside the capture matches every line that starts with at least 16 spaces : the entire Workspaces body including the nested `MouseArea`. The first line that starts with only 12 spaces (`            }`) terminates the match. The closing `}` of the block is therefore the next line outside the capture and is consumed by the trailing `\n            \}\n` of the regex.

- [ ] **Step 4: Dry-run sanity check**

Confirm the regex matches the expected source structure without actually mutating any live file. Run:

```bash
perl -0ne '
    if (/\n(            Workspaces \{\n                id: workspacesWidget\n(?:                [^\n]*\n)+?            \})\n/s) {
        print "MATCH:\n", $1, "\n";
    } else {
        print "NO MATCH\n";
    }
' ~/.local/share/inir/modules/bar/BarContent.qml
```

Expected: prints `MATCH:` followed by the full `Workspaces { … }` block (including the nested `MouseArea`). If it prints `NO MATCH`, double-check the indent levels (the runtime file should have 12-space indent for the closing `}` of the block). Do not proceed without a matching block.

- [ ] **Step 5: Run tests to verify pass**

Run:

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: PASS.

- [ ] **Step 6: Apply the patch to the live tree and inspect the result**

Run:

```bash
bash install/config/ryoku-shell-branding.sh
```

Then inspect the result:

```bash
grep -n 'Workspaces \{' ~/.local/share/inir/modules/bar/BarContent.qml
grep -n 'workspacesWidget' ~/.local/share/inir/modules/bar/BarContent.qml
grep -n 'workspaces relocated' ~/.local/share/inir/modules/bar/BarContent.qml
```

Expected:
- Exactly one `Workspaces {` declaration.
- `id: workspacesWidget` appears once, between `id: rightSidebarButton` and `SysTray {` in source order.
- The sentinel comment `// Ryoku: workspaces relocated to right notch` appears immediately above the moved block.
- `middleCenterGroup` no longer contains a `Workspaces` child (only its outer `BarGroup { id: middleCenterGroup }` declaration remains, with the new fixed `implicitWidth`).

- [ ] **Step 7: Re-run the patch to confirm idempotency**

Run:

```bash
bash install/config/ryoku-shell-branding.sh
diff <(grep -n 'Workspaces \{\|workspacesWidget\|workspaces relocated' ~/.local/share/inir/modules/bar/BarContent.qml) <(grep -n 'Workspaces \{\|workspacesWidget\|workspaces relocated' ~/.local/share/inir/modules/bar/BarContent.qml)
```

Expected: the second run produces an identical file (the sentinel guard prevents a second move; the `diff` is empty).

- [ ] **Step 8: Commit**

```bash
git add tests/ryoku-shell-branding.sh install/config/ryoku-shell-branding.sh
git commit -m "feat(topbar): relocate Workspaces from center notch to right notch"
```

---

### Task 6: Migration to re-run branding on existing installs

Existing Ryoku installs already have the older patch state (workspaces inside `middleCenterGroup`, `TimerIndicator`/`ShellUpdateIndicator` force-hidden). A migration that re-invokes `install/config/ryoku-shell-branding.sh` lets them pick up the relocation and the un-hidden indicator slots automatically on the next update.

**Files:**
- Create: `migrations/<unix-timestamp>.sh` (timestamp generated from the previous commit's time by the helper)

- [ ] **Step 1: Generate the migration scaffold**

Run:

```bash
ryoku-dev-add-migration --no-edit
ls -t migrations/ | head -1
```

Expected: a new file `migrations/<TIMESTAMP>.sh` printed by `ls`. Note the path; subsequent steps refer to it as `<MIGRATION>`.

- [ ] **Step 2: Populate the migration**

Open `<MIGRATION>` and write:

```bash
echo "Re-run Ryoku shell branding to relocate workspaces and un-hide indicator slots in the topbar right island"

if [[ -x $RYOKU_PATH/install/config/ryoku-shell-branding.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
```

(No shebang line, per `AGENTS.md`. `$RYOKU_PATH` is provided by the migration runner. The `daemon-reload` line mirrors `migrations/1777766309.sh` and is harmless if no service file changed.)

- [ ] **Step 3: Smoke-test the migration**

Run:

```bash
bash -n <MIGRATION>
RYOKU_PATH=. bash <MIGRATION>
```

Expected: the `bash -n` syntax check is silent, and the second run prints the migration's `echo` line followed by `Ryoku shell branding: applied`. Re-running it must remain idempotent (no further `git diff` on the live tree).

- [ ] **Step 4: Commit**

```bash
git add <MIGRATION>
git commit -m "chore(migrations): re-run shell branding for right-island rework"
```

---

### Task 7: Manual verification

Static tests confirm the patch *shape* but not the runtime appearance. Restart the live shell and verify the bar visually before considering the rework complete.

**Files:** none modified.

- [ ] **Step 1: Confirm the patch is applied to both source and runtime trees**

Run:

```bash
grep -c 'workspaces relocated to right notch' \
  ~/.local/share/inir/modules/bar/BarContent.qml \
  ~/.config/quickshell/inir/modules/bar/BarContent.qml 2>/dev/null
```

Expected: `1` for both files (or for `~/.local/share/inir/...` only if `~/.config/quickshell/inir/...` does not exist on this machine : the runtime path is optional).

- [ ] **Step 2: Restart the shell**

Run (if the shell is managed by systemd, the safest restart is via the user unit):

```bash
systemctl --user restart inir.service
```

Expected: the bar disappears for ~1 second, then re-renders.

- [ ] **Step 3: Visually verify the right notch**

Look at the topbar's right island and confirm:

- Workspace numbers are visible inside the dark notch interior, immediately to the left of the right sidebar button (the volume/mic/wifi/bluetooth cluster).
- Weather (temperature + cloud) sits at the inner (left) edge of the right notch.
- The notch's top frame still hugs the right screen corner : i.e., the rework did not break the seamless Canvas frame shape.
- The center notch is still drawn (smaller, ~140 px wide) and is empty : no widget content, no visible label.
- The left notch (logo + active window title) is unchanged.

- [ ] **Step 4: Verify on-demand indicators**

Trigger one or both of:

- `iNiR shell update`: run `ryoku-shell-update --check` (or whatever surfaces a pending update on this system) and confirm the `ShellUpdateIndicator` arrow renders inside the right notch, between `Workspaces` and `WeatherBar`, without overlapping either.
- `Timer`: start a short timer through the iNiR cheatsheet/sidebar and confirm the `TimerIndicator` renders in the same band when the timer is active.

If either indicator appears but pushes neighbouring content out of the notch, raise the `ryokuRightNotchWidth` upper cap further (e.g., 480 → 520) and re-run Tasks 3 + 6.

- [ ] **Step 5: Verify scroll and click affordances**

Confirm the existing right-side scroll-to-volume and right-click-for-context-menu behaviour still works on the right notch. Confirm the top-left hot corner still opens the left sidebar. (No code in this rework changes those handlers, but RowLayout reordering can subtly shift hit zones, so smoke-test it.)

- [ ] **Step 6: Final commit (optional)**

If manual verification surfaces a small follow-up tweak (e.g., bumping the cap, adjusting spacing), make the change as a small follow-up commit on the same branch. If everything looks correct, the rework is complete : no commit needed for this step.

---

## Self-Review

**Spec coverage**:
- Goal "Place workspace numbers in the right notch" → Task 5.
- Goal "center notch as an empty placeholder (fixed width)" → Task 4.
- Goal "Reserve layout space for TimerIndicator and ShellUpdateIndicator" → Tasks 1, 2, 3.
- Architecture "Workspaces.qml itself is unchanged" → enforced by the move-only regex (no edits to `Workspaces.qml`).
- Architecture "Re-runs of the script must remain a no-op" → sentinel comment in Task 5, deterministic heredoc replacement in Task 3, dual-branch substitution in Task 4.
- Testing assertions list (lines 144–162 of the amended spec) → covered by the new assertions added in Tasks 1, 2, 3, 4, 5.
- Manual verification list (lines 164–170 of the amended spec) → Task 7.

**Placeholder scan**: every step has concrete code or a concrete command. The only deferred decision is the timestamped migration filename, which `ryoku-dev-add-migration --no-edit` produces, captured as `<MIGRATION>` in Task 6.

**Type/symbol consistency**: `workspacesWidget` is the QML id used throughout; `middleCenterGroup`, `rightSectionRowLayout`, `rightSidebarButton`, `weatherBarLoader` are the existing ids referenced in the heredoc and substitutions. `ryokuTopbarHugFrame`, `ryokuRightContentWidth`, `ryokuRightNotchWidth`, `ryokuCenterNotchWidth`, `ryokuNotchPadding`, `ryokuFrameHeight` are the patch's existing property names : all preserved as-is. No renames.
