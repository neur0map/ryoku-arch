# Ryoku Shell Resume Recovery Design

## Context

Ryoku ships an iNiR Quickshell-based topbar managed by the user-level
`inir.service` systemd unit. After closing and reopening the laptop lid (or any
other suspend/resume cycle), the topbar's layer-shell surfaces sometimes lose
their attachment to niri and stop painting. The shell process itself stays
alive and QML keeps running (weather refreshes, lock surface still present),
but the bar PanelWindow no longer renders, leaving the user without a topbar
until they manually restart `inir.service`.

A recovery chain already exists:

1. `/usr/lib/systemd/system-sleep/ryoku-session-recover` (root, post-resume)
2. invokes per-user `bin/ryoku-session-recover --quiet --resume` via `sudo -u`
   with a freshly-rebuilt environment.
3. which calls `ryoku-restart-ui --quiet`,
4. which calls `ryoku-restart-shell`,
5. which runs `systemctl --user try-restart inir.service`.

This chain did not run during the observed lid-close incident on 2026-05-03 at
20:16:57. No `ryoku-session-recover` lines appeared in the journal between
the suspend and the manual restart. The chain swallows errors at every level
(`>/dev/null 2>&1 || true`), so the precise failure mode is invisible. The
likely culprit is the root-to-user privilege juggling in the system-sleep
hook: it derives `RYOKU_PATH` by running `systemctl --user show-environment`
under `sudo -u`, which can fail silently if the user's systemd environment is
not yet importable, and the per-user invocation backgrounds itself
(`(sleep 1; run_recovery) &`) so the parent exits before the work runs.

## Goals

- Ensure that after every suspend, hibernate, hybrid-sleep, or umbrella sleep
  resume, `bin/ryoku-session-recover --quiet --resume` actually runs in the
  user session and recovers the shell.
- Keep the change additive: do not remove or modify the existing system-sleep
  hook, the existing per-user recovery scripts, or `inir.service`.
- Reuse the existing recovery binary verbatim.
- Have the unit installed and enabled out-of-the-box on fresh installs and on
  upgrades of existing installs.
- Make the trigger observable in the journal under a known unit name so future
  failures are diagnosable.

## Non-Goals

- Do not redesign or replace the existing recovery chain. The system-sleep
  hook stays installed.
- Do not change `bin/ryoku-session-recover`, `bin/ryoku-restart-ui`,
  `bin/ryoku-restart-shell`, or `inir.service`.
- Do not address the underlying layer-shell re-attach behaviour in QML or in
  niri.
- Do not add a new daemon or DBus listener.
- Do not change the system-level sleep target wiring.

## Architecture

The fix is one new user-level systemd unit, one new install script, one new
migration, and one new test.

```
config/systemd/user/ryoku-shell-resume.service          (new)
install/config/ryoku-shell-resume.sh                    (new)
migrations/<timestamp>.sh                               (new)
tests/ryoku-shell-resume.sh                             (new)
```

Nothing existing is modified except `install/config/inir.sh`, which already
chains `install/config/ryoku-shell-branding.sh` at lines 74 and 91 and which
gets one extra invocation of the new install script.

### Component: `ryoku-shell-resume.service`

```ini
[Unit]
Description=Ryoku post-resume shell recovery
After=suspend.target sleep.target hibernate.target hybrid-sleep.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
ExecStart=%h/.local/share/ryoku/bin/ryoku-session-recover --quiet --resume

[Install]
WantedBy=suspend.target sleep.target hibernate.target hybrid-sleep.target
```

User-level systemd manages the unit. `WantedBy=` pulls the unit in whenever
any of the listed sleep targets activates. `After=` orders this unit to start
once those targets complete, i.e., after the sleep returns. `Type=oneshot`
runs the recovery binary to completion and lets the unit settle into
`inactive (dead)` until the next resume.

`%h` expands to the user's home directory at unit-load time, which keeps the
unit user-agnostic.

`StopWhenUnneeded=yes` lets the unit garbage-collect cleanly when the sleep
target deactivates, so the unit's status reflects the most recent resume run.

### Component: `install/config/ryoku-shell-resume.sh`

An idempotent installer that:

- Copies `$RYOKU_PATH/config/systemd/user/ryoku-shell-resume.service` to
  `${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-shell-resume.service`.
- Runs `systemctl --user daemon-reload`.
- Runs `systemctl --user enable ryoku-shell-resume.service` (re-enable is a
  no-op when already enabled).

The script takes the `set -euo pipefail` boilerplate, sources
`lib/runtime-env.sh`, and uses the standard `install -m 0644` and
`mkdir -p` idioms used by `apply_replacements_to_file` and other Ryoku
installers.

### Component: Migration

A new file at `migrations/<unix-timestamp-of-last-commit>.sh` that runs
`install/config/ryoku-shell-resume.sh`, following the existing migration
convention (no shebang, leading `echo`, references `$RYOKU_PATH`,
finishes with `systemctl --user daemon-reload >/dev/null 2>&1 || true`).

### Component: Tests

Static bash assertions in `tests/ryoku-shell-resume.sh`. The test verifies the
shape of the unit and the install script without booting systemd:

- `config/systemd/user/ryoku-shell-resume.service` exists and contains
  `After=suspend.target sleep.target hibernate.target hybrid-sleep.target`,
  `WantedBy=` with the same set, `Type=oneshot`, and an `ExecStart=` ending
  in `ryoku-session-recover --quiet --resume`.
- `install/config/ryoku-shell-resume.sh` is executable, references the unit
  source path, performs `systemctl --user daemon-reload`, performs
  `systemctl --user enable ryoku-shell-resume.service`, and copies the unit
  to a `${XDG_CONFIG_HOME:-...}/systemd/user/` target.
- The migration file references `install/config/ryoku-shell-resume.sh`.

The test is added to the central test runner alongside
`ryoku-shell-branding.sh`.

## Data Flow

1. User closes lid -> systemd-logind initiates suspend -> `sleep.target` (and
   `suspend.target`) activate.
2. User reopens lid -> systemd resumes -> the sleep targets deactivate.
3. The deactivation orders `ryoku-shell-resume.service` to start (per
   `After=` and `WantedBy=`).
4. The unit runs `ryoku-session-recover --quiet --resume` once.
5. `ryoku-session-recover` sleeps 1s, refreshes the activation environment,
   powers on niri monitors, cleans orphan helpers, and try-restarts
   `inir.service` via `ryoku-restart-shell`.
6. `inir.service` restarts; the new shell process re-establishes its
   layer-shell surfaces and the topbar is back.

The existing system-sleep hook continues to run in parallel. Its work is
either redundant (try-restart on an already-restarting service is a no-op)
or already-failing-silently. Either way, no new conflict is introduced.

## Error Handling

- Unit failure surfaces in `journalctl --user -u ryoku-shell-resume.service`
  with stderr from the recovery binary. `--quiet` suppresses informational
  prints, so only meaningful errors appear.
- The recovery binary already swallows individual step failures with
  `|| true`, so unit-level success means "the binary ran to completion",
  not "every recovery step succeeded". This is the same semantics the
  existing chain has and is acceptable here.
- The install script's `systemctl --user daemon-reload` and `enable` calls
  use no special error handling; if they fail, the install fails loud,
  which matches Ryoku's other installers.
- If the user is on a desktop without a user systemd manager (effectively
  not a target environment for Ryoku), the install fails. This is
  acceptable; the README and the live-system installer already assume
  systemd-user is available.

## Testing

Static tests live in `tests/ryoku-shell-resume.sh` and run as part of the
existing test runner. No live integration test is added; manual verification
is one suspend/resume cycle followed by checking
`journalctl --user -u ryoku-shell-resume.service` for a `Started` entry and
`inir.service` for a fresh PID.

## Migration

A new `migrations/<timestamp>.sh` re-invokes
`install/config/ryoku-shell-resume.sh` so already-installed systems pick up
the new unit on next update. The migration matches the shape of
`migrations/1777766309.sh` and `migrations/1777852554.sh`.

## Risks

- **Race with the system-sleep hook**: both the new unit and the old chain
  may try to restart `inir.service` concurrently. Mitigated by
  `try-restart`'s idempotent semantics and by the old chain's silent
  no-op behaviour. No new race surface is introduced.
- **`%h` semantics**: `%h` is resolved at unit-load time, not at exec time.
  This is fine for Ryoku because the recovery binary path is stable across
  the user's lifetime.
- **Sleep-target ordering**: if a future systemd version changes how
  `WantedBy=sleep.target` interacts with the umbrella, the unit might fire
  twice (once for `suspend.target`, once for the umbrella `sleep.target`).
  This is harmless because the recovery binary is idempotent (try-restart
  on a freshly-restarted service is a no-op).
