# Documentation

Documentation for Ryoku Arch.

## Contents

- `vision.md`: project goals, audience, non-goals.
- `maintenance.md`: how to maintain the repo. Branch topology, shipping changes, cherry-picking from upstream, safety rules. Read this first if you are about to make a change.
- `branding.md`: visual + verbal identity. Brand colors (Greek Noir palette), logo files and how to regenerate them, where the brand surfaces, don't-do list.
- `iso-build-recipe.md`: working recipe for building the offline ISO end-to-end, list of fixes that have to stay applied, harmless chroot warnings to ignore, verification commands.
- `release-pipeline.md`: how Ryoku ISOs get built, signed, and pushed to Cloudflare R2 via GitHub Actions. Secrets to configure, R2 bucket setup, GPG key generation, how users verify a downloaded ISO.
- `keybindings.md`: current Niri and shell keyboard reference generated from the shipped Niri config.
- `ui-patterns.md`: rules and footguns for working on the Quickshell desktop. Padding tokens, primitive reuse map, peer pattern map, the 4-tree sync, when to stop and rethink. Read this before touching anything in `shell/`.
- `omarchy-heritage.md`: user-facing explanation of what remains from upstream Omarchy and what has been removed.
- `customization-inventory.md`: shipped text-based customization surfaces with repo-safe locations.
- `../CONTRIBUTING.md`: focused ways to help while Ryoku is early.
- `../SECURITY.md`: private reporting path for security-sensitive issues.
