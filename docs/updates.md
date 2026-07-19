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
- The user overlay (`~/.config/ryoku/user_edits`, mirroring `~/.config`) is laid
  on top last, so a file there wins at its mirrored path; see below. Anything the
  package never ships (`hypr/user.lua`, `kitty/user.conf`, a forked module) is
  left alone regardless.

So the QML and the `Config.qml` defaults reach users on every update. A **new**
`shell.json` key is safe: the user's file lacks it, and the shell reads the new
`Config.qml` default.

## user_edits: your edits, kept apart

Ryoku-owned config and user edits live in separate trees, so an update refreshes
the base freely while your edits stand. The base is the restore point; the
overlay is yours.

- **base** `/usr/share/ryoku/config` (the checkout on a dev box): pristine,
  re-laid in full on every update, so every fix and addition lands first.
- **user_edits** `~/.config/ryoku/user_edits`, mirroring `~/.config`, sparse:
  only what you changed. `materialize` overlays it last, so a file here wins at
  its mirrored path. Empty means pure base and the overlay is a no-op.

Two ways to override, neither of which blocks a fix:

- **Overlay (default).** The tool's own last-wins include: Hyprland loads the
  base modules, then `settings.lua` and `user.lua` last; kitty `globinclude`s
  `user.conf`. The base loads underneath, so a new upstream keybind still arrives
  while your file wins on what it sets.
- **Fork (opt-in).** A whole copy of a shipped file shadows the base one. You own
  it now, so an upstream fix to that file will not reach you automatically. Your
  forks are the files you see in the overlay; `ryoku reset <path>` takes the new
  base.

Ryoku Settings writes its generated `hypr/settings.lua` and `hypr/rebinds.lua`
into the overlay (authored under `user_edits`, reflected live). Its other state
(bar, colours, launcher) it keeps under `~/.config/ryoku`, GUI-managed and
update-safe. `ryoku reset` drops an override; `ryoku recovery` is the last
resort, wiping the overlay and that state back to shipped defaults.

## doctor: converging what materialize can't

`ryoku doctor` runs convergent reconcilers for the stateful drift materialize
can't state declaratively (disk, boot, session, and the user-owned
`~/.config/ryoku/*.json` materialize never rewrites). Reconcilers stand in for a
migration ledger: each is idempotent and safe on every update, and is retired
once every supported install has run it. `reconcileShellConfig` migrates a stale
`shell.json` (drops retired keys, revives the bar, clamps geometry).
`reconcileUserEditsAdopt` seeds the how-to guide and moves a machine's legacy
loose files (`hypr/user.lua`, `hypr/monitors_user.lua`, `kitty/user.conf`) into
the overlay. Idempotent.

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
- **A user override belongs in `~/.config/ryoku/user_edits`, never in a shipped
  path.** The base still ships every file (the delivery check stays green) and
  the overlay wins on top. A whole-file fork opts out of upstream fixes for that
  one file, so prefer an overlay for anything additive.
- **A change reaches users only after `main` fast-forwards.** Keep the gap small;
  the delivery check reports it on every push.

## Checks

- `bin/ryoku-dev-verify-delivery` flags orphan configs (hard fail) and reports
  the publish lag. It runs in `pre-commit`, `post-commit`, and the Delivery check
  workflow.
- The install-test workflow builds the ISO and runs a real, unattended install in
  a VM, then verifies the desktop comes up, so a broken install or a missing
  package is caught before a user hits it.
