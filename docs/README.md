# Documentation

Developer-facing documentation for Ryoku Arch.

## Contents

- `vision.md`: project goals, audience, and non-goals in long form.
- `maintenance.md`: how to maintain the repo. Branch topology, shipping changes, cherry-picking from upstream, safety rules. Read this first if you are about to make a change.
- `rebrand-inventory.md`: catalog of remaining legacy Omarchy references still in the tree, categorized by whether they are compatibility bridges, package-name deferments, or historical/legal references.
- `customization-inventory.md`: exhaustive inventory of shipped text-based customization surfaces, with repo-safe locations and short descriptions.
- `specs/`: design specs. One file per change, dated `YYYY-MM-DD-*.md`.
- `plans/`: step-by-step implementation plans produced from specs.

Specs precede plans precede code. Every non-trivial change leaves a spec in `specs/` and a plan in `plans/` behind.
