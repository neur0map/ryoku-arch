# Documentation

Developer-facing documentation for Ryoku Arch.

## Contents

- `vision.md`: project goals, audience, non-goals.
- `maintenance.md`: how to maintain the repo. Branch topology, shipping changes, cherry-picking from upstream, safety rules. Read this first if you are about to make a change.
- `branding.md`: visual + verbal identity. Brand colors (Greek Noir palette), logo files and how to regenerate them, where the brand surfaces, don't-do list.
- `iso-build-recipe.md`: working recipe for building the offline ISO end-to-end, list of fixes that have to stay applied, harmless chroot warnings to ignore, verification commands.
- `release-pipeline.md`: how Ryoku ISOs get built, signed, and pushed to Cloudflare R2 via GitHub Actions. Secrets to configure, R2 bucket setup, GPG key generation, how users verify a downloaded ISO.
- `TODO.md`: project-level work queued but not yet promoted to a plan or spec.
- `rebrand-inventory.md`: remaining legacy Omarchy references in the tree, by category.
- `customization-inventory.md`: shipped text-based customization surfaces with repo-safe locations.
- `superpowers/specs/`: design specs for in-progress work. One file per change, dated `YYYY-MM-DD-*.md`. Files are removed once the work lands and the recipe / TODO docs absorb the relevant context.
- `superpowers/plans/`: step-by-step plans produced from those specs. Same lifecycle as specs.

Specs precede plans precede code. Every non-trivial change leaves a spec and a plan behind for the duration of the work, then both get removed once the change has shipped.
