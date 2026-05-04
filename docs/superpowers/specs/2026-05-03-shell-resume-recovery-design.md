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
- Do not change the system-level sleep target wiring.
- Do not gate or modify the lock-surface behaviour during the restart
  window. The exposure documented under Risks stays as-is for this
  iteration.

## Architecture

User-level systemd does not expose `sleep.target`, `suspend.target`,
`hibernate.target`, or `hybrid-sleep.target`. Verified on the live system
with `systemctl --user show sleep.target` returning `LoadState=not-found`.
Those targets exist only in the system systemd manager. A user unit ordered
against any of them never fires.

The recovery is therefore implemented as a long-running user-level service
that listens for the system-bus signal
`org.freedesktop.login1.Manager.PrepareForSleep(b)`. systemd-logind emits
this signal twice per sleep cycle:

- `PrepareForSleep(true)` just before the kernel suspends.
- `PrepareForSleep(false)` immediately after resume, before user code starts
  running again.

The listener only acts on the `false` (resume) edge. On every resume it
invokes `ryoku-session-recover --quiet --resume`, which is the same recovery
binary the existing system-sleep hook tries to call.

```
bin/ryoku-resume-listener                               (new)
config/systemd/user/ryoku-resume-listener.service       (new)
install/config/ryoku-resume-listener.sh                 (new)
migrations/<timestamp>.sh                               (new)
tests/ryoku-resume-listener.sh                          (new)
```

Nothing existing is modified except `install/config/inir.sh`, which already
chains `install/config/ryoku-shell-branding.sh` at lines 74 and 91 and which
gets one extra invocation of the new install script.

### Component: `bin/ryoku-resume-listener`

A bash script that uses `gdbus monitor` to subscribe to
`org.freedesktop.login1.Manager.PrepareForSleep` on the system bus, parses
the truthy/falsey argument out of the textual line `gdbus` prints, and
invokes the recovery binary on the falsey (resume) edge. `gdbus` is part of
`glib2`, which is already a transitive dependency of every Quickshell-based
desktop and is therefore available on every Ryoku install.

The listener uses no Python interpreter, no extra runtime, and shells out to
the existing recovery binary using `&` so that long recovery work does not
block the listener loop. If `gdbus` exits (bus disconnect, etc.), the
script exits and systemd's `Restart=on-failure` brings it back.

A representative shape (final wording lives in the implementation plan):

```bash
#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

RECOVER_BIN="$RYOKU_PATH/bin/ryoku-session-recover"
[[ -x $RECOVER_BIN ]] || RECOVER_BIN="$HOME/.local/share/ryoku/bin/ryoku-session-recover"

ryoku-cmd-present gdbus || {
  echo "ryoku-resume-listener: gdbus is required (install glib2)" >&2
  exit 1
}

gdbus monitor \
  --system \
  --dest org.freedesktop.login1 \
  --object-path /org/freedesktop/login1 \
| while IFS= read -r line; do
    case "$line" in
      *PrepareForSleep*\(false,\)*)
        [[ -x $RECOVER_BIN ]] && "$RECOVER_BIN" --quiet --resume &
        ;;
    esac
  done
```

### Component: `config/systemd/user/ryoku-resume-listener.service`

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

The unit follows the same lifecycle pattern as `inir.service`: `PartOf=` and
`After=graphical-session.target` so the listener exists for the duration of
the user's graphical session. `Type=simple` because `gdbus monitor` is a
long-running process that does not daemonise. `Restart=on-failure` plus a
five-second backoff catches transient bus failures.

`%h` expands to the user's home directory at unit-load time.

### Component: `install/config/ryoku-resume-listener.sh`

An idempotent installer that:

- Copies `$RYOKU_PATH/config/systemd/user/ryoku-resume-listener.service` to
  `${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/ryoku-resume-listener.service`.
- Runs `systemctl --user daemon-reload`.
- Runs `systemctl --user enable --now ryoku-resume-listener.service`. Both
  `enable` and `--now` are idempotent: re-enable is a no-op when already
  enabled, and `--now` only starts the service if it is not already
  running.

The script takes the `set -euo pipefail` boilerplate, sources
`lib/runtime-env.sh`, and uses the standard `install -m 0644` and
`mkdir -p` idioms used by `apply_replacements_to_file` and other Ryoku
installers.

`bin/ryoku-resume-listener` is installed via Ryoku's existing `bin/`
sync mechanism (the same one that lays down `bin/ryoku-session-recover`,
`bin/ryoku-restart-shell`, and friends into `~/.local/share/ryoku/bin/`),
so the install script does not have to copy it separately.

### Component: Migration

A new file at `migrations/<unix-timestamp-of-last-commit>.sh` that runs
`install/config/ryoku-resume-listener.sh`, following the existing migration
convention (no shebang, leading `echo`, references `$RYOKU_PATH`,
finishes with `systemctl --user daemon-reload >/dev/null 2>&1 || true`).

### Component: Tests

Static bash assertions in `tests/ryoku-resume-listener.sh`. The test
verifies the shape of the listener, the unit, and the install script
without booting systemd:

- `bin/ryoku-resume-listener` exists, is executable, references
  `gdbus monitor`, references `--dest org.freedesktop.login1`, references
  `PrepareForSleep`, references the falsey-argument match
  (`(false,)`), and invokes `ryoku-session-recover --quiet --resume`.
- `config/systemd/user/ryoku-resume-listener.service` exists and contains
  `Type=simple`, `Restart=on-failure`, `After=graphical-session.target`,
  `PartOf=graphical-session.target`, `WantedBy=graphical-session.target`,
  and `ExecStart=` ending in `ryoku-resume-listener`.
- `install/config/ryoku-resume-listener.sh` is executable, references the
  unit source path, performs `systemctl --user daemon-reload`, performs
  `systemctl --user enable --now ryoku-resume-listener.service`, and
  copies the unit to a `${XDG_CONFIG_HOME:-...}/systemd/user/` target.
- The migration file references `install/config/ryoku-resume-listener.sh`.

The test is added to the central test runner alongside
`ryoku-shell-branding.sh`.

## Data Flow

1. User logs in -> graphical-session.target activates ->
   `ryoku-resume-listener.service` starts ->
   `bin/ryoku-resume-listener` execs `gdbus monitor --system` and
   blocks reading the bus.
2. User closes lid -> systemd-logind initiates suspend -> emits
   `org.freedesktop.login1.Manager.PrepareForSleep(true)` on the system bus.
3. The listener parses the line, sees the truthy argument, and ignores it.
4. The kernel suspends. Time passes.
5. User reopens lid -> kernel resumes -> systemd-logind emits
   `org.freedesktop.login1.Manager.PrepareForSleep(false)`.
6. The listener parses the line, sees the falsey argument, and forks
   `ryoku-session-recover --quiet --resume` into the background.
7. `ryoku-session-recover` sleeps 1s (giving niri a moment to settle),
   refreshes the activation environment, powers on niri monitors, cleans
   orphan helpers, and try-restarts `inir.service` via
   `ryoku-restart-shell`.
8. `inir.service` restarts; the new shell process re-establishes its
   layer-shell surfaces and the topbar is back.

The existing system-sleep hook continues to run in parallel. Its work is
either redundant (try-restart on an already-restarting service is a no-op)
or already-failing-silently. Either way, no new conflict is introduced.

## Error Handling

- Listener crashes surface in
  `journalctl --user -u ryoku-resume-listener.service` and trigger a
  five-second `Restart=on-failure` cycle.
- If `gdbus` is missing at start time, the listener prints a stderr message
  and exits non-zero; systemd reports the failure and stops trying after
  the default start-limit.
- The recovery binary already swallows individual step failures with
  `|| true`, so listener-level success means "the binary was forked", not
  "every recovery step succeeded". This is the same semantics the existing
  chain has and is acceptable here.
- The install script's `systemctl --user daemon-reload` and `enable --now`
  calls use no special error handling; if they fail, the install fails
  loud, which matches Ryoku's other installers.
- If the user is on a desktop without a user systemd manager (effectively
  not a target environment for Ryoku), the install fails. This is
  acceptable; the README and the live-system installer already assume
  systemd-user is available.

## Testing

Static tests live in `tests/ryoku-resume-listener.sh` and run as part of the
existing test runner. No live integration test is added; manual verification
is one suspend/resume cycle followed by checking
`journalctl --user -u ryoku-resume-listener.service` for the listener
running across the cycle and `inir.service` for a fresh PID after the
resume.

## Migration

A new `migrations/<timestamp>.sh` re-invokes
`install/config/ryoku-resume-listener.sh` so already-installed systems pick
up the listener on next update. The migration matches the shape of
`migrations/1777766309.sh` and `migrations/1777852554.sh`.

## Risks

- **Race with the system-sleep hook**: both the listener and the old chain
  may try to restart `inir.service` concurrently. Mitigated by
  `try-restart`'s idempotent semantics and by the old chain's silent
  no-op behaviour. No new race surface is introduced.
- **`%h` semantics**: `%h` is resolved at unit-load time, not at exec time.
  This is fine for Ryoku because the recovery binary path is stable across
  the user's lifetime.
- **Lock-screen exposure window**: when the user resumes from suspend, iNiR
  shows its lock surface. The recovery restarts `inir.service`, which
  briefly tears down the lock surface before the fresh shell process
  re-establishes it. For the (sub-second) restart window, the actual
  desktop is visible behind the disappearing lock. This is the same hole
  the existing recovery chain would have had if it were running, so the
  listener does not introduce the risk, only makes it reproducible.
  Mitigation is out of scope for this spec; a future iteration can either
  gate the restart on lock state or hand off to `swaylock` during the
  window.
- **Start-limit interaction with `inir.service`**: `inir.service` has
  `StartLimitIntervalSec=30` and `StartLimitBurst=3`. Three rapid
  suspend/resume cycles within 30 s could push the service past its
  start limit and leave it stopped. Unlikely in normal lid usage.
- **`gdbus` text-format parsing**: the listener matches a substring on
  `gdbus monitor`'s textual output. The format is stable across glib2
  versions, but a future glib2 release that re-formats signal output
  could break the substring match. Mitigation: a downstream switch to a
  Python `dbus`-based listener is straightforward if needed.
- **Listener missing the resume edge during its own restart**: if the
  listener crashes and is being restarted by `Restart=on-failure` exactly
  when a resume edge fires, the recovery would not run. The five-second
  backoff means the window is small but real. Acceptable for a fix
  whose existing alternative is "the chain never runs at all".
- **Long-running daemon footprint**: the listener is a permanent
  long-running process (one bash process plus the `gdbus` subprocess).
  Resource use is negligible : both processes sleep on the bus socket
  and consume effectively no CPU or memory.
