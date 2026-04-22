# Documentation

Developer-facing documentation for Ryoku Arch.

## Contents

- `vision.md`: project goals, audience, and non-goals in long form.
- `maintenance.md`: how to maintain the repo. Branch topology, shipping changes, cherry-picking from upstream, safety rules. Read this first if you are about to make a change.
- `rebrand-inventory.md`: catalog of every `omarchy` reference still in the tree, categorized by the kind of change each needs.
- `specs/`: design specs. One file per change, dated `YYYY-MM-DD-*.md`.
- `plans/`: step-by-step implementation plans produced from specs.

Specs precede plans precede code. Every non-trivial change leaves a spec in `specs/` and a plan in `plans/` behind.
