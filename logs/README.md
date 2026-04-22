# Session Logs

Per-session handoff notes. One file per working session. Individual session files are gitignored; only `README.md` and `TEMPLATE.md` ship in the repo.

## Why

Ryoku Arch work moves across different sessions, sometimes across different working environments. A structured log per session lets the next session orient itself in under a minute: what was changed, what was verified, what the next step is.

## Naming

`YYYY-MM-DD-session-NN.md`, where `NN` is zero-padded (`01`, `02`, `03`). Local date. If a session crosses midnight, use the date the session started.

## Status vocabulary

- `in-progress`: the session is active. Update the log as you go.
- `handed-off`: the session paused mid-task. The `Next:` field names the concrete next action for the following session.
- `done`: closed, no follow-up needed.

## Reading order

New sessions read the latest log first. Older logs are historical context, not active state.

## Format

Copy `TEMPLATE.md` to a new file when starting a session. The template contains the expected fields and section headings.
