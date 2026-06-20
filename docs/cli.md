# The `ryoku` command

The user-facing control CLI (`ryoku/cli/`, one Go program). It is the front door
to updates, rollback, status, and the shell; it orchestrates pacman, yay, and
snapper rather than reimplementing them. This is the per-command reference: what
each command does, where it is meant to run, and who runs it.

## Two worlds

Every command behaves with respect to one of two ways Ryoku can exist on a
machine. Most confusion about the CLI comes from mixing them up.

- **A packaged install** the normal case. The desktop is installed from the
  `[ryoku]` pacman repo; `ryoku-desktop` ships the base config under
  `/usr/share/ryoku/config`, and there is no git checkout and no build toolchain.
- **A dev checkout** a clone of this repo on a maintainer's machine. There is no
  `/usr/share/ryoku/config`; the desktop is laid down from the checkout by
  `ryoku/shell/deploy.sh` (via `ryoku deploy`). The deploy records the checkout
  root and the commit it laid down under `~/.local/state/ryoku/`, which is how
  the deployed `ryoku` binary later finds the repo again.

`ryoku update` auto-detects which world it is in (a recorded checkout means the
git path, otherwise the pacman path), so the same command is correct on both. A
few commands belong to only one world; that is called out per command below.

## At a glance

|Command|What it does|Where|Who|
|---|---|---|---|
|`update`|Snapshot, then bring the system current and redeploy|both|you|
|`status [--json]`|Version, how far behind, snapshot count|both|you, the Hub|
|`rollback [id]`|Restore a snapper snapshot (no id: list them)|both|you|
|`snapshots`|List snapper snapshots|both|you|
|`reload`|Restart the shell and reload Hyprland|both|you|
|`materialize`|Lay the base configs into `~/.config`|packaged install|the updater/installer|
|`deploy`|Build and lay the desktop from a checkout|dev checkout|a maintainer|
|`recovery`|Last resort: reset to main and redeploy|both|you, when broken|

## Everyday commands

These are user-facing and work on any install.

### `ryoku update`

The full, safe update, wrapped in a snapper pre/post snapshot pair (best-effort:
an unconfigured snapper never blocks the update, but a failed step aborts before
anything else changes). What it actually runs depends on the world:

- **Dev checkout:** updates through the git channel. It fetches the channel
  branch (`main` for everyone), fast-forwards the checkout when it is sitting
  cleanly on that branch, and redeploys with `deploy.sh`. A feature branch or a
  dirty tree is left to git only the redeploy runs.
- **Packaged install:** `sudo pacman -Syu`, then `yay -Sua` if yay is present,
  then `ryoku materialize`, then a shell reload.

Throughout, it publishes progress to `$XDG_RUNTIME_DIR/ryoku-update.json` so the
shell's update island can show the run.

### `ryoku status [--json]`

A read-only report. It always prints the active config base. On a checkout it
shows the channel, the deployed commit (`installed`), and how many commits behind
the channel you are; on a packaged install it shows the installed `ryoku-desktop`
version, what the `[ryoku]` repo offers, and the count of pending package updates
(via `checkupdates` from `pacman-contrib`). It ends with the snapshot count.

`--json` is the data seam the Hub and the update island read; it is not meant for
humans.

### `ryoku rollback [id]`

Restore a snapper snapshot. With no id it lists the snapshots so you can pick one
(the same snapshots are selectable from the Limine boot menu); with an id it runs
`sudo snapper rollback <id>`.

### `ryoku snapshots`

List the snapper snapshots (`sudo snapper list`). Requires snapper.

### `ryoku reload`

Restart the shell and reload Hyprland, by handing off to `ryoku-shell reload`.
Use it after changing config that is already in place.

## Production internals

### `ryoku materialize`

Lays Ryoku's base configs into `~/.config`, declaratively and override-safe. It
copies every file the package ships under the base config dir (clobbering the
previous Ryoku copy), prunes files a past release shipped but this one dropped
(tracked by a manifest at `~/.local/state/ryoku/materialized`), and never touches
files the package never shipped your own overrides like `hypr/user.lua`,
`kitty/user.conf`, `fish/user.fish` are left alone.

The base dir is `/usr/share/ryoku/config`, shipped by the `ryoku-desktop`
package. This command is the packaged-install replacement for `deploy.sh`'s
config copy: it is run for you by `ryoku update` and by the installer's deploy
step, not usually by hand. **On a dev checkout it fails** (`base config dir not
found: /usr/share/ryoku/config`) because that path only exists once the package
is installed; use `ryoku deploy` there instead. To point it at a base tree
yourself, set `RYOKU_CONFIG_BASE`.

## Developer-only commands

### `ryoku deploy`

The dev loop, never used on production installs. It builds the Go binaries and
the QML plugin and lays the repo into `~/.config` from a checkout, by running
`ryoku/shell/deploy.sh`. It requires `RYOKU_REPO` to point at the checkout and
errors otherwise. The deploy also records the checkout root and the commit it
laid down under `~/.local/state/ryoku/`, which is what lets `status` and `update`
track the git channel afterwards.

## Emergency command

### `ryoku recovery`

The last resort when the desktop is too broken to update normally: it resets the
checkout to `main` and redeploys, **overwriting configs**. It hands off to
`bin/ryoku-recovery`, preferring the copy in a local checkout and otherwise
fetching the canonical script from the repo over the network, so it still works
when the local build is broken.

## Environment and state

Overrides (mostly for `deploy` and tests):

- `RYOKU_REPO` the checkout root. Required by `deploy`; also lets `status`,
  `update`, and `recovery` find the repo explicitly.
- `RYOKU_CONFIG_BASE` overrides the `materialize` base dir
  (default `/usr/share/ryoku/config`).
- `RYOKU_CHANNEL` overrides the update-channel branch (default `main`; used by
  tests).

State the CLI keeps under `$XDG_STATE_HOME/ryoku` (default `~/.local/state/ryoku`):

- `repo` the checkout root the last deploy recorded.
- `deployed` the commit the last deploy laid down; the baseline `status`
  measures the channel against.
- `materialized` the manifest of Ryoku-owned files, so the next `materialize`
  can prune cleanly.

Runtime: `$XDG_RUNTIME_DIR/ryoku-update.json` is the update island's progress
file, written by `update`.
