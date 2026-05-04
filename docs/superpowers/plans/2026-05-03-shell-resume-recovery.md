# Shell Resume Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a long-running user-level systemd service that listens for `org.freedesktop.login1.Manager.PrepareForSleep` on the system bus and runs `ryoku-session-recover --quiet --resume` on every resume edge, so the topbar reliably comes back after every lid close, suspend, hibernate, or hybrid-sleep.

**Architecture:** One bash listener (`bin/ryoku-resume-listener`) shells out to `gdbus monitor` and pattern-matches the falsey signal argument. One user-level systemd unit (`config/systemd/user/ryoku-resume-listener.service`) starts the listener with the same lifecycle as `inir.service` (`PartOf=graphical-session.target`). One installer (`install/config/ryoku-resume-listener.sh`) copies the unit, runs `daemon-reload`, and enables-and-starts it. The installer is chained into `install/config/all.sh` and re-invoked from a new migration so existing installs pick up the listener on next update. The existing recovery binary (`bin/ryoku-session-recover`) is reused verbatim.

**Tech Stack:** Bash 5, `gdbus` (from glib2), systemd-user, static bash test assertions following the pattern in `tests/ryoku-shell-branding.sh`.

**Pre-change baseline:** commit `4590c3d4` (the spec amendment). Revert with `git reset --hard 4590c3d4` if anything goes wrong.

---

## File Structure

**New:**
- `bin/ryoku-resume-listener` : bash script. Subscribes to logind `PrepareForSleep` via `gdbus monitor`, invokes `ryoku-session-recover --quiet --resume` on the resume edge.
- `config/systemd/user/ryoku-resume-listener.service` : user-level systemd unit. `Type=simple`, `Restart=on-failure`, `PartOf=graphical-session.target`.
- `install/config/ryoku-resume-listener.sh` : installer. Copies the unit, daemon-reloads, enable-and-starts.
- `tests/ryoku-resume-listener.sh` : static bash assertions for all of the above.
- `migrations/1777856216.sh` : migration that re-invokes the installer for existing installs (timestamp matches the last commit at plan-write time, `4590c3d4`).

**Modified:**
- `install/config/all.sh` : add one `run_logged` line for the new installer.

**Untouched (do NOT edit):**
- `bin/ryoku-session-recover` : reused verbatim, no changes.
- `bin/ryoku-restart-ui`, `bin/ryoku-restart-shell`, `bin/ryoku-shell-cleanup-orphans` : no changes.
- `default/systemd/system-sleep/ryoku-session-recover` : the broken root-side hook stays in place as a fallback.
- `~/.config/systemd/user/inir.service` and its drop-ins : no changes.

---

### Task 1: Listener bash script + first test assertions

The listener subscribes to logind on the system bus, watches for the resume edge of `PrepareForSleep`, and forks `ryoku-session-recover --quiet --resume` into the background so a long recovery does not block the read loop. The script exits non-zero if `gdbus` is missing or the bus disconnects, and systemd's `Restart=on-failure` (added in Task 2) brings it back.

**Files:**
- Create: `tests/ryoku-resume-listener.sh`
- Create: `bin/ryoku-resume-listener`

- [ ] **Step 1: Write the failing test file**

Create `tests/ryoku-resume-listener.sh` with the listener-specific assertions:

```bash
#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_listener_script() {
  assert_executable "bin/ryoku-resume-listener"
  assert_contains "bin/ryoku-resume-listener" 'gdbus monitor' \
    "Listener should use gdbus monitor to read the system bus"
  assert_contains "bin/ryoku-resume-listener" '--system' \
    "Listener should subscribe on the system bus"
  assert_contains "bin/ryoku-resume-listener" '--dest org\.freedesktop\.login1' \
    "Listener should target the systemd-logind destination"
  assert_contains "bin/ryoku-resume-listener" 'PrepareForSleep' \
    "Listener should match the PrepareForSleep signal name"
  assert_contains "bin/ryoku-resume-listener" '\(false,\)' \
    "Listener should match the falsey (resume) argument shape"
  assert_contains "bin/ryoku-resume-listener" 'ryoku-session-recover --quiet --resume' \
    "Listener should invoke ryoku-session-recover with --quiet and --resume"
}

assert_listener_script

echo "PASS: ryoku resume listener"
```

- [ ] **Step 2: Make the test file executable and run it to confirm it fails**

Run:

```bash
chmod +x tests/ryoku-resume-listener.sh
bash tests/ryoku-resume-listener.sh
```

Expected: `FAIL: bin/ryoku-resume-listener should exist`. The listener script does not exist yet.

- [ ] **Step 3: Create `bin/ryoku-resume-listener`**

Create `bin/ryoku-resume-listener` with this content:

```bash
#!/bin/bash

# Listen for systemd-logind PrepareForSleep(false) and run
# ryoku-session-recover --resume in the user session. Pure user-space
# fallback for the broken root-side system-sleep hook.

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

RECOVER_BIN="$RYOKU_PATH/bin/ryoku-session-recover"
[[ -x $RECOVER_BIN ]] || RECOVER_BIN="$HOME/.local/share/ryoku/bin/ryoku-session-recover"

if ! ryoku-cmd-present gdbus; then
  echo "ryoku-resume-listener: gdbus is required (install glib2)" >&2
  exit 1
fi

# gdbus monitor exits on bus disconnect; systemd Restart=on-failure recovers.
gdbus monitor \
  --system \
  --dest org.freedesktop.login1 \
  --object-path /org/freedesktop/login1 \
| while IFS= read -r line; do
    case "$line" in
      *PrepareForSleep*\(false,\)*)
        if [[ -x $RECOVER_BIN ]]; then
          "$RECOVER_BIN" --quiet --resume &
        fi
        ;;
    esac
  done
```

- [ ] **Step 4: Make the listener executable and re-run the test**

Run:

```bash
chmod +x bin/ryoku-resume-listener
bash tests/ryoku-resume-listener.sh
```

Expected: `PASS: ryoku resume listener`.

- [ ] **Step 5: Sanity-check `gdbus` invocation manually**

Run:

```bash
timeout 1 gdbus monitor --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 2>&1 | head -3
```

Expected: the command runs for ~1 second without printing an error, then `timeout` kills it. Empty output is fine (no signal fired in 1 second). If you see `Error subscribing` or similar, stop and report : the listener will not work.

- [ ] **Step 6: Commit**

```bash
git add tests/ryoku-resume-listener.sh bin/ryoku-resume-listener
git commit -m "feat(resume): add gdbus-based logind PrepareForSleep listener"
```

---

### Task 2: User-level systemd service unit + assertions

The unit follows the same lifecycle pattern as `inir.service`: it lives for the duration of the graphical session and restarts on failure with a five-second backoff.

**Files:**
- Create: `config/systemd/user/ryoku-resume-listener.service`
- Modify: `tests/ryoku-resume-listener.sh` (extend with unit-file assertions)

- [ ] **Step 1: Extend the test with unit-file assertions**

Open `tests/ryoku-resume-listener.sh` and add this function above the `assert_listener_script` call, then call it before that:

```bash
assert_listener_unit() {
  assert_file "config/systemd/user/ryoku-resume-listener.service"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'Description=' \
    "Unit should have a Description"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'Type=simple' \
    "Unit should be Type=simple (gdbus monitor is long-running)"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'Restart=on-failure' \
    "Unit should restart on failure so a bus disconnect recovers"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'RestartSec=5' \
    "Unit should back off 5 seconds before restarting"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'After=graphical-session\.target' \
    "Unit should be ordered after the graphical session"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'PartOf=graphical-session\.target' \
    "Unit should be PartOf the graphical session so it stops with it"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'WantedBy=graphical-session\.target' \
    "Unit should be WantedBy the graphical session for enable-time wiring"
  assert_contains "config/systemd/user/ryoku-resume-listener.service" 'ExecStart=.*ryoku-resume-listener$' \
    "Unit ExecStart should point at the ryoku-resume-listener binary"
}
```

Then immediately above `assert_listener_script`, add:

```bash
assert_listener_unit
```

- [ ] **Step 2: Run the test to verify the unit-file assertions fail**

Run:

```bash
bash tests/ryoku-resume-listener.sh
```

Expected: `FAIL: config/systemd/user/ryoku-resume-listener.service should exist`.

- [ ] **Step 3: Create the unit file**

Create `config/systemd/user/ryoku-resume-listener.service` with this content:

```ini
[Unit]
Description=Ryoku resume listener (logind PrepareForSleep)
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/share/ryoku/bin/ryoku-resume-listener
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
```

- [ ] **Step 4: Re-run the test**

Run:

```bash
bash tests/ryoku-resume-listener.sh
```

Expected: `PASS: ryoku resume listener`.

- [ ] **Step 5: Commit**

```bash
git add tests/ryoku-resume-listener.sh config/systemd/user/ryoku-resume-listener.service
git commit -m "feat(resume): add user-level systemd unit for the listener"
```

---

### Task 3: Installer script + assertions

The installer copies the unit file from the repo into `~/.config/systemd/user/`, reloads the user manager, and enables-and-starts the service. Idempotent: re-runs on already-installed systems do not error.

**Files:**
- Create: `install/config/ryoku-resume-listener.sh`
- Modify: `tests/ryoku-resume-listener.sh` (extend with installer assertions)

- [ ] **Step 1: Extend the test with installer assertions**

Open `tests/ryoku-resume-listener.sh` and add this function above the `assert_listener_unit` call, then call it before that:

```bash
assert_listener_installer() {
  assert_executable "install/config/ryoku-resume-listener.sh"
  assert_contains "install/config/ryoku-resume-listener.sh" 'config/systemd/user/ryoku-resume-listener\.service' \
    "Installer should reference the unit source file in the repo"
  assert_contains "install/config/ryoku-resume-listener.sh" 'systemd/user/ryoku-resume-listener\.service' \
    "Installer should reference the unit destination filename"
  assert_contains "install/config/ryoku-resume-listener.sh" '\$\{XDG_CONFIG_HOME:-\$HOME/\.config\}/systemd/user' \
    "Installer should target the user systemd directory under XDG_CONFIG_HOME"
  assert_contains "install/config/ryoku-resume-listener.sh" 'systemctl --user daemon-reload' \
    "Installer should reload the user systemd manager"
  assert_contains "install/config/ryoku-resume-listener.sh" 'systemctl --user enable --now ryoku-resume-listener\.service' \
    "Installer should enable and immediately start the listener service"
}
```

Then immediately above `assert_listener_unit`, add:

```bash
assert_listener_installer
```

- [ ] **Step 2: Run the test to verify the installer assertions fail**

Run:

```bash
bash tests/ryoku-resume-listener.sh
```

Expected: `FAIL: install/config/ryoku-resume-listener.sh should exist`.

- [ ] **Step 3: Create the installer**

Create `install/config/ryoku-resume-listener.sh` with this content:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

UNIT_SRC="$RYOKU_PATH/config/systemd/user/ryoku-resume-listener.service"
UNIT_DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_DEST="$UNIT_DEST_DIR/ryoku-resume-listener.service"

if [[ ! -f $UNIT_SRC ]]; then
  echo "ryoku-resume-listener: unit source missing: $UNIT_SRC" >&2
  exit 1
fi

mkdir -p "$UNIT_DEST_DIR"
install -m 0644 "$UNIT_SRC" "$UNIT_DEST"

systemctl --user daemon-reload
systemctl --user enable --now ryoku-resume-listener.service
```

- [ ] **Step 4: Make the installer executable and re-run the test**

Run:

```bash
chmod +x install/config/ryoku-resume-listener.sh
bash tests/ryoku-resume-listener.sh
```

Expected: `PASS: ryoku resume listener`.

- [ ] **Step 5: Commit**

```bash
git add tests/ryoku-resume-listener.sh install/config/ryoku-resume-listener.sh
git commit -m "feat(resume): add installer for the listener unit"
```

---

### Task 4: Wire the installer into `install/config/all.sh`

Fresh installs need the listener to be enabled out of the box. Adding one `run_logged` line below the existing `session-recover.sh` line keeps the resume-related installers grouped.

**Files:**
- Modify: `install/config/all.sh` (one new line)
- Modify: `tests/ryoku-resume-listener.sh` (one new assertion)

- [ ] **Step 1: Add the test assertion**

Open `tests/ryoku-resume-listener.sh` and add a new function near the bottom (above the final `echo`):

```bash
assert_installer_chained() {
  assert_contains "install/config/all.sh" 'run_logged \$RYOKU_INSTALL/config/ryoku-resume-listener\.sh' \
    "Installer should be chained into install/config/all.sh so fresh installs enable the listener"
}
```

Then call it after `assert_listener_installer`:

```bash
assert_installer_chained
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ryoku-resume-listener.sh
```

Expected: `FAIL: Installer should be chained into install/config/all.sh ...`.

- [ ] **Step 3: Edit `install/config/all.sh`**

Open `install/config/all.sh` and find the line:

```
run_logged $RYOKU_INSTALL/config/session-recover.sh
```

Add a new line immediately after it:

```
run_logged $RYOKU_INSTALL/config/ryoku-resume-listener.sh
```

The two resume-related installers now sit together.

- [ ] **Step 4: Re-run the test**

Run:

```bash
bash tests/ryoku-resume-listener.sh
```

Expected: `PASS: ryoku resume listener`.

- [ ] **Step 5: Commit**

```bash
git add tests/ryoku-resume-listener.sh install/config/all.sh
git commit -m "feat(resume): chain listener installer into install/config/all.sh"
```

---

### Task 5: Migration for existing installs

Existing Ryoku installs predate the listener. A migration that re-invokes the new installer pulls them up to the current state on the next `ryoku-update`.

**Files:**
- Create: `migrations/1777856216.sh` (timestamp matches plan-write commit `4590c3d4`)
- Modify: `tests/ryoku-resume-listener.sh` (one new assertion)

- [ ] **Step 1: Add the test assertion**

Open `tests/ryoku-resume-listener.sh` and add a new function:

```bash
assert_migration_present() {
  assert_file "migrations/1777856216.sh"
  assert_contains "migrations/1777856216.sh" 'install/config/ryoku-resume-listener\.sh' \
    "Migration should re-invoke the listener installer for existing installs"
}
```

Then call it after `assert_installer_chained`:

```bash
assert_migration_present
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/ryoku-resume-listener.sh
```

Expected: `FAIL: migrations/1777856216.sh should exist`.

- [ ] **Step 3: Create the migration**

Create `migrations/1777856216.sh` with this content (no shebang, leading `echo`, references `$RYOKU_PATH`, daemon-reload at the end : matches the convention used in `migrations/1777766309.sh` and `migrations/1777852554.sh`):

```bash
echo "Install Ryoku resume listener (user-level systemd unit watching logind PrepareForSleep)"

if [[ -x $RYOKU_PATH/install/config/ryoku-resume-listener.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-resume-listener.sh"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
```

- [ ] **Step 4: Smoke-test the migration in isolation**

Run:

```bash
bash -n migrations/1777856216.sh
RYOKU_PATH="$(pwd)" bash migrations/1777856216.sh
```

Expected: `bash -n` produces no output (syntax OK). The actual run prints the migration's `echo` line and then either copies the unit file and enables the service (first run) or is a no-op (subsequent runs).

- [ ] **Step 5: Re-run the unit tests**

Run:

```bash
bash tests/ryoku-resume-listener.sh
```

Expected: `PASS: ryoku resume listener`.

- [ ] **Step 6: Commit**

```bash
git add tests/ryoku-resume-listener.sh migrations/1777856216.sh
git commit -m "chore(migrations): install resume listener on existing systems"
```

---

### Task 6: Live-system verification

Static tests confirm the shape of the change. End-to-end behavior needs an actual suspend/resume cycle.

**Files:** none modified.

- [ ] **Step 1: Confirm the unit is enabled and active**

Run:

```bash
systemctl --user is-enabled ryoku-resume-listener.service
systemctl --user is-active ryoku-resume-listener.service
```

Expected: `enabled` and `active`. If `inactive`, restart manually: `systemctl --user restart ryoku-resume-listener.service`. If `not-found`, the migration did not run : execute it manually with `bash $RYOKU_PATH/install/config/ryoku-resume-listener.sh`.

- [ ] **Step 2: Confirm the listener process is running**

Run:

```bash
pgrep -af 'ryoku-resume-listener|gdbus monitor.*login1'
```

Expected: two PIDs : one bash (the listener wrapper), one `gdbus monitor` (the actual subscription).

- [ ] **Step 3: Trigger a suspend cycle and observe**

Open a journal tail in one terminal:

```bash
journalctl --user -u ryoku-resume-listener.service -u inir.service --follow
```

In another terminal (or via the lid), suspend the system:

```bash
systemctl suspend
```

Wake the system (lid open or power button).

Expected in the journal:
- `inir.service` logs a `Stopping Ryoku shell...` and then `Started Ryoku shell.` after the resume edge.
- `ryoku-resume-listener.service` stays `active (running)` across the cycle (no restart, because gdbus does not disconnect on suspend on a typical setup; if it does, you will see a fresh `Started`).

- [ ] **Step 4: Verify the topbar is back**

Visually confirm the topbar reappeared after the resume. The bar should show the wallpaper-tinted weather, workspaces, and right-side icons exactly as it did before the suspend.

- [ ] **Step 5: If the topbar did not come back**

Diagnose in this order:

1. `journalctl --user -u ryoku-resume-listener.service --since "5 minutes ago"` : look for stderr from the listener.
2. `journalctl --user -u inir.service --since "5 minutes ago"` : look for whether `try-restart` was attempted at all.
3. `pgrep -af gdbus` : confirm `gdbus monitor` is still running. If not, the unit's `Restart=on-failure` is being suppressed by the unit's start-limit; check `systemctl --user status ryoku-resume-listener.service` for the recent failure pattern.
4. Manually run `bash bin/ryoku-resume-listener` in a foreground terminal and trigger another suspend to see the parsed line on stdout. The matching pattern is `*PrepareForSleep*\(false,\)*` : if logind is emitting a different shape on this kernel, the case match will need adjusting.

- [ ] **Step 6: No commit needed unless step 5 surfaces a fix**

If the live verification is clean, the rework is complete. If step 5 surfaces a fix, make it on a small follow-up commit on the same branch (e.g., a wider `case` pattern or a dependency adjustment).

---

## Self-Review

**Spec coverage:**

- Spec goal "fire on every resume from suspend/hibernate/hybrid-sleep" : Tasks 1+2 wire a listener that subscribes regardless of sleep mode (logind emits PrepareForSleep for every kernel sleep mode).
- Spec goal "additive, do not modify existing scripts/units" : Tasks 1-5 only create new files except for one append to `install/config/all.sh`. None of the existing recovery binaries, the existing system-sleep hook, or `inir.service` are touched.
- Spec goal "reuse the existing recovery binary verbatim" : Task 1's listener invokes `ryoku-session-recover --quiet --resume` and nothing else.
- Spec goal "installed and enabled out of the box" : Task 4 chains the installer into `install/config/all.sh`. Task 5 adds the migration for existing installs.
- Spec goal "observable in the journal" : Task 6 step 3 walks through reading `journalctl --user -u ryoku-resume-listener.service`.
- Spec component "bin/ryoku-resume-listener" : Task 1.
- Spec component "config/systemd/user/ryoku-resume-listener.service" : Task 2.
- Spec component "install/config/ryoku-resume-listener.sh" : Task 3.
- Spec component "migration" : Task 5.
- Spec component "tests/ryoku-resume-listener.sh" : Tasks 1-5 each extend it.
- Spec data flow steps 1-8 : implemented and verified by Task 6.

**Placeholder scan:** every step has concrete code or a concrete shell command. The migration filename (`1777856216.sh`) is fixed to the timestamp of the last commit at plan-write time (`4590c3d4`). All test assertions list explicit grep patterns and failure messages.

**Type/symbol consistency:** the unit name `ryoku-resume-listener.service` and the binary name `ryoku-resume-listener` appear identically in every task and assertion. The destination path `${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/` and the source path `config/systemd/user/ryoku-resume-listener.service` are consistent. The recovery binary is always invoked as `ryoku-session-recover --quiet --resume`.
