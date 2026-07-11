# Updates and delivery

How a change in this repo reaches a running machine, and the contract that keeps
a user's install a mirror of a dev checkout. Read this before adding a config
file, a `shell.json` key, or anything a user must receive.

## Two worlds, one result

- A **dev box** runs the checkout: `ryoku deploy` builds the binaries and lays
  `ryoku/` into `~/.config`. `ryoku update` on it tracks `origin/main` (the git
  channel) and redeploys.
- A **user box** runs signed packages: `ryoku update` runs `pacman -Syu` from the
  `[ryoku]` repo, then `ryoku materialize`, then `ryoku doctor`.

They must converge. A change that lands on one but not the other is the bug this
page exists to prevent.

## `ryoku update`

Snapper pre-snapshot, then the channel (git fast-forward, or `pacman -Syu` from
`[ryoku]`), then stage2 through the just-installed binary: quiesce the shell,
`ryoku materialize`, reload Hyprland, restart the shell, `ryoku doctor`, snapper
post-snapshot. Each stage publishes to `$XDG_RUNTIME_DIR/ryoku-update.json` (the
ordered steps, the current label, a live log tail, and, on failure, the error
and the pre-update snapshot), so the update island and the Hub's Updates page
render a determinate run and a one-click rollback.

## materialize: the config a user receives

`ryoku materialize` lays the package's base config (`/usr/share/ryoku/config`,
mirrored by `ryoku/shell/deploy.sh` on a dev box) into `~/.config`:

- Every shipped file is copied over on every update (the previous Ryoku copy is
  clobbered) and files dropped from a release are pruned; `~/.config/quickshell`
  is converged wholesale.
- A short **seed list** (`generatedSeed` in `ryoku/cli/materialize.go`:
  `hypr/monitors.lua`, `hypr/gpu.lua`, `hypr/keyboard.lua`,
  `fastfetch/config.jsonc`, `kitty/current-theme.conf`) is copied only when
  absent, never clobbered: per-machine or user-owned state an update must keep.
- User files the package never ships (`hypr/user.lua`, `kitty/user.conf`, ...)
  are left alone.

So the QML and the `Config.qml` defaults reach users on every update. A **new**
`shell.json` key is safe: the user's file lacks it, and the shell reads the new
`Config.qml` default.

## doctor: converging what materialize can't

`ryoku doctor` runs convergent reconcilers for the stateful drift materialize
can't state declaratively (disk, boot, session, and the user-owned
`~/.config/ryoku/*.json` materialize never rewrites). Reconcilers stand in for a
migration ledger: each is idempotent and safe on every update, and is retired
once every supported install has run it. `reconcileShellConfig` migrates a stale
`shell.json` (drops retired keys, revives the bar, clamps geometry).

## Publishing: how a commit becomes a user update

The `[ryoku]` repo publishes on a push to `main` (or a release tag). `main`
advances only when a maintainer fast-forwards it from `unstable-dev` or runs the
stable release. Each advance rebuilds the packages with a strictly increasing
version (`core.r<commit-count>.g<sha>`) that `pacman -Syu` upgrades to.

**Work on `unstable-dev` does not reach users until `main` fast-forwards.**

## The contract

- **A user-facing config file must be delivered by a path a user runs**: shipped
  in a package (then materialized) or seeded by the installer. A file only
  `deploy.sh` lays, or one no path lays, reaches no user. `ryoku-dev-verify-delivery`
  fails the commit on such an orphan.
- **A removed or renamed `shell.json` key, or a changed default that must reach
  existing users, needs a `doctor` reconciler** (materialize never edits a user's
  `shell.json`). An additive key needs nothing.
- **A change reaches users only after `main` fast-forwards.** Keep the gap small;
  the delivery check reports it on every push.

## Checks

- `bin/ryoku-dev-verify-delivery` flags orphan configs (hard fail) and reports
  the publish lag. It runs in `pre-commit`, `post-commit`, and the Delivery check
  workflow.
- The install-test workflow builds the ISO and runs a real, unattended install in
  a VM, then verifies the desktop comes up, so a broken install or a missing
  package is caught before a user hits it.
