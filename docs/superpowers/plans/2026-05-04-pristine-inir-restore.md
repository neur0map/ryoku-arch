# Pristine iNiR Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-shot Ryoku migration that wipes the current Ryoku-touched iNiR install and re-bootstraps a pristine upstream iNiR install via `github.com/snowarch/iNiR.git`.

**Architecture:** Single new shell script under `migrations/`. Uses iNiR's own `./setup uninstall -y` for cleanup, then `git clone` + `./setup install -y` for the fresh install. Repo branding script and JSON overrides stay untouched: the user takes ownership after the wipe. The migration self-marks via the existing `bin/ryoku-migrate` state directory.

**Tech Stack:** Bash, systemd (user units), git, iNiR's own `setup` shell installer.

**Spec:** `docs/superpowers/specs/2026-05-04-pristine-inir-restore-design.md`

**Pre-commit hooks to know about (from prior session, will reject the commit if violated):**
- No em-dash (`U+2014`) characters in committed files. Use `:` or `,` or `.`.
- No `Co-Authored-By:` trailer in commit messages.

---

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `migrations/1778000000.sh` | Create | One-shot wipe-and-restore migration. Runs once via `bin/ryoku-migrate`. |

That's it. No edits to any existing file. No dedicated test file (the migration is a one-shot; static syntax check is sufficient).

**Filename rationale:** `1778000000` is the next round-number after the most recent migration `1777960000.sh`. Sorts alphanumerically after all existing migrations so the runner picks it up last during a backlog run. Existing migrations stay marked-applied on every system; only this new one runs.

---

## Task 1: Create the migration script

**Files:**
- Create: `migrations/1778000000.sh`

- [ ] **Step 1: Verify the target filename does not already exist**

```bash
ls migrations/1778000000.sh 2>&1
```

Expected: `ls: cannot access 'migrations/1778000000.sh': No such file or directory`

If the file exists, pick the next round number (`1778100000`, etc.) and substitute it everywhere in this plan.

- [ ] **Step 2: Write the migration script**

Create `migrations/1778000000.sh` with exactly this content:

```bash
#!/bin/bash
# Wipe Ryoku-touched iNiR state and re-bootstrap a pristine upstream
# install from github.com/snowarch/iNiR.git. See spec at
# docs/superpowers/specs/2026-05-04-pristine-inir-restore-design.md.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

INIR_PATH="$HOME/.local/share/inir"
USER_CONFIG="$HOME/.config/inir/config.json"
RYOKU_ICON="$HOME/.local/share/icons/hicolor/scalable/apps/ryoku.svg"
WANTS_DIR="$HOME/.config/systemd/user/niri.service.wants"
SERVICE_UNIT="$HOME/.config/systemd/user/inir.service"

# Phase 1: Banner
printf '\n'
printf '\033[1;33mWiping iNiR completely and reinstalling fresh upstream.\033[0m\n'
printf 'Desktop chrome (bar, sidebars, lock UI) will be unavailable for ~1-3 min.\n'
printf 'Existing windows persist (niri keeps running). Do NOT lock the screen.\n'
printf '\n'

# Phase 2: Pre-flight. If iNiR is already absent, exit cleanly.
if [[ ! -x $INIR_PATH/setup ]]; then
  echo "iNiR setup script missing at $INIR_PATH/setup; nothing to wipe."
  exit 0
fi

# Phase 3: Backup user config to a path outside the wipe scope.
ts=$(date +%s)
backup_dir="$RYOKU_STATE_PATH/inir-restore-backup"
mkdir -p "$backup_dir"
if [[ -f $USER_CONFIG ]]; then
  cp "$USER_CONFIG" "$backup_dir/config.json.$ts"
  echo "Backed up user config to $backup_dir/config.json.$ts"
fi

# Phase 4: Stop iNiR services so the unit files can be safely removed.
systemctl --user stop inir.service inir-super-overview.service 2>/dev/null || true

# Phase 5: Run iNiR's own uninstall to remove every iNiR-tracked file.
"$INIR_PATH/setup" uninstall -y

# Phase 6: Wipe the source tree itself (uninstall does not remove its own repo).
rm -rf "$INIR_PATH"

# Phase 7: Wipe Ryoku-only artifacts that iNiR's manifest does not track.
rm -f "$RYOKU_ICON"

# Phase 8: Clone fresh upstream iNiR.
git clone https://github.com/snowarch/iNiR.git "$INIR_PATH"

# Phase 9: Run iNiR's installer with non-interactive flags.
"$INIR_PATH/setup" install -y --skip-deps --skip-sysupdate

# Phase 10: Re-create the niri.service.wants symlink so iNiR auto-starts.
mkdir -p "$WANTS_DIR"
ln -sf "$SERVICE_UNIT" "$WANTS_DIR/inir.service"

# Phase 11: Reload user units and start iNiR.
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user start inir.service

echo
echo "Pristine iNiR restore complete."
echo "Backup of prior config: $backup_dir/config.json.$ts"
```

- [ ] **Step 3: Verify the file was written and has bash shebang**

Run: `head -1 migrations/1778000000.sh`
Expected output: `#!/bin/bash`

- [ ] **Step 4: Static syntax check with `bash -n`**

Run: `bash -n migrations/1778000000.sh && echo OK`
Expected output: `OK`

If `bash -n` reports an error, fix the syntax and re-run before continuing.

- [ ] **Step 5: Verify required content via grep**

Run each of these and confirm exit code 0 (match found):

```bash
grep -q '^set -euo pipefail$' migrations/1778000000.sh && echo "set -euo pipefail OK"
grep -q '^source "\$(cd -- "\$(dirname -- "\${BASH_SOURCE\[0\]}")/\.\." && pwd)/lib/runtime-env\.sh"$' migrations/1778000000.sh && echo "runtime-env source OK"
grep -q '"\$INIR_PATH/setup" uninstall -y' migrations/1778000000.sh && echo "uninstall step OK"
grep -q 'git clone https://github\.com/snowarch/iNiR\.git "\$INIR_PATH"' migrations/1778000000.sh && echo "clone step OK"
grep -q '"\$INIR_PATH/setup" install -y --skip-deps --skip-sysupdate' migrations/1778000000.sh && echo "install step OK"
grep -q '^systemctl --user start inir\.service$' migrations/1778000000.sh && echo "service start OK"
grep -q '"\$RYOKU_ICON"' migrations/1778000000.sh && echo "ryoku.svg removal step OK"
grep -q '"\$backup_dir/config\.json\.\$ts"' migrations/1778000000.sh && echo "backup step OK"
```

Expected output: all eight `OK` lines printed.

- [ ] **Step 6: Optional shellcheck if available**

Run: `command -v shellcheck >/dev/null && shellcheck migrations/1778000000.sh || echo "shellcheck not installed, skipping"`

If shellcheck is installed and reports issues, judge whether they are spurious (e.g., `SC1091` for the dynamically-resolved `runtime-env.sh` source path is expected and can be ignored) versus real bugs. Fix real bugs.

- [ ] **Step 7: Confirm no em-dash characters (pre-commit hook protection)**

The repo's pre-commit hook rejects any commit that introduces em-dash characters (Unicode `U+2014`). To detect them in a way that does not put the character itself into this plan file:

```bash
grep -cP '\x{2014}' migrations/1778000000.sh
```

Expected output: `0`

If the count is nonzero, replace each em-dash with `:` or `,` or `.` (per the hook's guidance) before committing.

---

## Task 2: Commit the migration

**Files:**
- Stage: `migrations/1778000000.sh`

- [ ] **Step 1: Stage the new migration**

Run: `git add migrations/1778000000.sh && git status`
Expected: status shows the file under "Changes to be committed".

- [ ] **Step 2: Commit (no Co-Authored-By trailer)**

Run:

```bash
git commit -m "feat(migrations): pristine iNiR restore migration

Wipes Ryoku-touched iNiR state via iNiR's own setup uninstall -y,
then re-clones from github.com/snowarch/iNiR.git and installs fresh.
Repo branding script and config overrides intentionally untouched.

See docs/superpowers/specs/2026-05-04-pristine-inir-restore-design.md."
```

If the commit-msg hook rejects the message, read the rejection text. The hook in this repo rejects any `Co-Authored-By:` trailer; do not add one.

- [ ] **Step 3: Verify the commit landed**

Run: `git log -1 --format='%h %s'`
Expected output: a short SHA followed by `feat(migrations): pristine iNiR restore migration`.

- [ ] **Step 4: Confirm working tree is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean`.

---

## Post-implementation: handing the migration to the user

The plan ends at the commit. The user will:

1. Pull/checkout the branch on their machine (it is the current dev machine, so the file is already present locally after commit).
2. Optionally run `bin/ryoku-migrate` to execute the migration immediately, or wait for it to run on the next install/update pass.
3. Watch the disruption window (~1-3 min of no desktop chrome).
4. After the script reports `Pristine iNiR restore complete.`, verify:
   - `git -C ~/.local/share/inir log -1 --format='%H %s'` shows upstream HEAD.
   - `git -C ~/.local/share/inir status` is clean.
   - `grep -c ryokuTopbarHugFrame ~/.config/quickshell/inir/modules/bar/BarContent.qml` returns `0`.
   - `systemctl --user is-active inir.service` returns `active`.
   - The Settings UI Bar tab toggles for Battery, Clock, sysTray, etc. visibly affect the running bar.

These steps are NOT part of the implementation work; they are the user's own validation.

---

## Spec coverage check (self-review)

| Spec section | Plan coverage |
|---|---|
| Goals: one-shot migration | Task 1 creates the migration; runner self-tracks state. |
| Goals: use `./setup uninstall -y` | Phase 5 of the script. |
| Goals: remove source tree + Ryoku-only extras | Phases 6 and 7. |
| Goals: backup user config outside wipe scope | Phase 3 (writes to `$RYOKU_STATE_PATH/inir-restore-backup/`). |
| Goals: self-mark via `bin/ryoku-migrate` state dir | Achieved by being placed under `migrations/`; runner handles tracking. No code needed. |
| Non-Goals: no edits to branding script / overrides JSON / inir.sh | File Structure has only the new migration. |
| Non-Goals: no edits to existing specs / memory | Confirmed: only `migrations/1778000000.sh` is touched. |
| Non-Goals: no niri / quickshell / hypridle touch | Confirmed in the script body. |
| Non-Goals: no SDDM theme touch | Confirmed; no sudo invoked. |
| Non-Goals: shared configs preserved | iNiR's `-y` uninstall preserves them; we do not override that. |
| Architecture: phases 1-11 | All 11 phases appear in the script in the spec's order. |
| Failure handling: `set -euo pipefail` | Step 5 grep-asserts presence. |
| Failure handling: pre-flight exit 0 if no iNiR | Phase 2 implements this. |
| Testing: bash -n | Step 4. |
| Testing: shellcheck if available | Step 6. |
| Testing: `set -euo pipefail` presence | Step 5. |
