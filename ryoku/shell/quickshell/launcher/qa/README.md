# Launcher QA

Live end-to-end scenario suite for the Ryoku launcher. `run.sh` drives the
resident launcher (command socket + wtype keyboard synthesis), dumps the
launcher's `state` JSON after each scenario, screenshots the screen, and
evaluates the scenario's assertions.

## Success criteria (the quality bar)

A scenario **passes** iff, run under the uniform protocol below:

1. every `asserts[]` jq expression evaluates to exactly `true` against the
   final `state.json`, and
2. every `shell_asserts[]` command exits 0 (used for side effects: window
   spawned, clipboard content, file opened), and
3. no step errors.

Binary pass/fail: no partial credit. A run of the full suite is **green**
only when all scenarios pass. Visual quality is additionally reviewed from the
per-scenario screenshots against the design rubric: no clipped or overlapping
text, consistent spacing/alignment, theme-consistent colors, readable
contrast, and the empty/loading states render intentionally.

## Uniform conditions

Every scenario starts from launcher hidden + 0.5s settle; `show` resets the
query, selection, grid/help modes (Launcher.onShownChanged). Async providers
are waited on with `settle` (polls `state.busy || state.searching`, max 8s).
Network-dependent scenarios (web answers, YT Music, weather) are marked
`"network": true` in the suite; they legitimately fail offline.

## Files

- `scenarios.json`: the suite; each: id, name, covers, steps, asserts,
  shell_asserts, teardown.
- `run.sh [suite] [only-ids]`: runner; evidence to `/tmp/launcher-qa/run-*/`
  (`$QA_OUT` overrides): per-scenario `state.json`, `screen.png`,
  `steps.log`, and a run-level `results.tsv`.

Step DSL: `show`, `hide`, `type <text>`, `key <keysym…>`, `ctrl <key>`,
`sleep <s>`, `settle`, `sh <command>`.
