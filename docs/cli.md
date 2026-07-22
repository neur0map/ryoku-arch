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
|`rollback [id]`|Guide restoring a snapshot from the boot menu (no id: list them)|both|you|
|`snapshots`|List snapper snapshots|both|you|
|`reload`|Restart the shell and reload Hyprland|both|you|
|`materialize`|Lay the base configs into `~/.config`|packaged install|the updater/installer|
|`reset [path]`|Drop a `user_edits` override, back to the Ryoku default|both|you|
|`deploy`|Build and lay the desktop from a checkout|dev checkout|a maintainer|
|`recovery`|Last resort: reset to main and redeploy|both|you, when broken|
|`doctor`|Run idempotent reconcilers for stateful drift|both|you, the updater|

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

Guide restoring a snapper snapshot. With no id it lists the snapshots so you can
pick one. Ryoku boots the `@` subvolume directly (`rootflags=subvol=@`), a layout
`snapper rollback` cannot restore (it flips the btrfs default subvolume, which a
pinned `subvol=` ignores), so the restore runs from the boot menu: reboot, boot
the snapshot under the Limine Snapshots menu, and run `sudo
limine-snapper-restore` there; it copies the booted snapshot (and its matching
kernels on the ESP) back onto `@`.

### `ryoku snapshots`

List the snapper snapshots (`sudo snapper list`). Requires snapper.

### `ryoku reload`

Restart the shell and reload Hyprland, by handing off to `ryoku-shell reload`.
Use it after changing config that is already in place.

### `ryoku reset [path]`

Drop a user override and go back to the Ryoku default. With a path (relative to
`~/.config`, e.g. `hypr/modules/binds.lua`) it resets that file; with none, and
after a confirm (`-y` skips it), the whole `user_edits` overlay. It removes only
overlay files, not Ryoku Settings' stores. On a packaged box it re-lays the base
at once; on a dev checkout it drops the override and leaves the re-lay to
`ryoku deploy`.

## Production internals

### `ryoku materialize`

Lays Ryoku's base configs into `~/.config`, declaratively and override-safe. It
copies every file the package ships under the base config dir (clobbering the
previous Ryoku copy), prunes files a past release shipped but this one dropped
(tracked by a manifest at `~/.local/state/ryoku/materialized`), and never touches
files the package never shipped your own overrides like `hypr/user.lua`,
`hypr/monitors_user.lua`, `kitty/user.conf`, `fish/user.fish` are left alone.

After the base is laid, materialize overlays your edits: every file under
`~/.config/ryoku/user_edits` (mirroring `~/.config`) is copied on top, so a file
there wins at its mirrored path. The overlay is sparse, so a new base file still
lands; a whole-file fork shadows its base copy (visible in the overlay, `ryoku
reset` hands it back). See `docs/updates.md`.

Per-machine generated drop-ins (`hypr/monitors.lua` written by `ryoku-monitor`,
`hypr/gpu.lua` by `ryoku-gpu`) are seeded only when absent and never clobbered or
pruned, so an update refreshes the shipped config without ever resetting your
display layout, GPU pin, or any setting.

The base dir is `/usr/share/ryoku/config`, shipped by the `ryoku-desktop`
package. This command is the packaged-install replacement for `deploy.sh`'s
config copy: it is run for you by `ryoku update` and by the installer's deploy
step, not usually by hand. **On a dev checkout it fails** (`base config dir not
found: /usr/share/ryoku/config`) because that path only exists once the package
is installed; use `ryoku deploy` there instead. To point it at a base tree
yourself, set `RYOKU_CONFIG_BASE`.

## Keyring

### `ryoku keyring`

Chooses how the GNOME keyring unlocks your saved passwords and secrets at
sign-in, so browsers and apps stop prompting. **The default is `never-ask`: out
of the box no app ever prompts.** First login runs `ryoku keyring init`, which
records the mode and seeds a blank, passwordless default keyring; from then on
every libsecret app (browsers, editors, the SSH agent) uses it silently, and it
persists across reboots. Three modes:

- `never-ask` (default) the default keyring is blank (stored in plaintext), so it
  is already unlocked and nothing ever prompts. Works the same under SDDM
  autologin or a password login, and is seeded automatically at first login.
- `unlock-on-login` PAM unlocks (or creates) the login keyring with your login
  password at sign-in; the store stays encrypted at rest and the desktop never
  prompts. Opt in for an encrypted store. The default keyring points at `login`.
- `ask` the store stays locked until an app asks, and gnome-keyring prompts then.

`ryoku keyring init` is the first-login default, run from the Hyprland autostart:
idempotent, it records the inferred mode and seeds the never-ask keyring, is a
no-op once you have chosen a mode, and never destroys a pre-existing encrypted
keyring (it records the policy and points you at `set --reset` instead).

`ryoku keyring status [--json]` reports the configured (or, when unset, inferred)
mode, whether `/etc/pam.d/sddm` carries `pam_gnome_keyring`, whether autologin is
configured, whether the keyring daemon is running, and each keyring file's format
(encrypted, plaintext, or absent). `ryoku keyring set <mode>` records the choice
in `~/.config/ryoku/keyring.json`, converges the keyring files over D-Bus, and
escalates the root PAM edit through `pkexec` (`--convert` rekeys an encrypted
keyring, reading passwords on stdin; `--reset` backs the files up and starts
fresh). The Hub's Lockscreen page drives all of this; `ryoku doctor` watches for
drift. `$RYOKU_PAM_FILE` overrides the PAM path for tests.

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

## Self-healing

### `ryoku doctor`

Runs the convergent reconcilers: idempotent checks (and, where it is safe, fixes)
for stateful drift the package and config layers cannot express. Each reconciler
reports `ok` when the machine matches the desired state, otherwise it converges,
proposes the exact fix, or flags it for a human. A healthy machine is quiet;
`--check` (or `-n`) shows the full list without changing anything, and `--json`
emits the findings as a machine-readable array (name, status, detail, remedy)
for a GUI. `ryoku update` runs `ryoku doctor` itself, so healing is seamless and
a finding never aborts the update.

Current reconcilers (in `ryoku/cli/internal/doctor/`): swap kept out of snapshots,
snapper config consistency, stale pacman lock, the ryoku package channel + keyring,
desktop session components, the keyring unlock policy (how the GNOME keyring
unlocks at sign-in; see `ryoku keyring`), Hyprland config integrity (revalidates and repairs the
generated monitors.lua/gpu.lua drop-ins so a corrupt one cannot strand the desktop
in emergency mode), the shell daemon, failed services, btrfs device health, display
backlight (catches a missing interface, missing brightnessctl, or a hybrid-GPU
firmware-only backlight), pending `.pacnew` config, and orphaned packages.
Reconcilers retire once every supported install has run them, so the set stays
small rather than growing like an ordered migration list.

**When doctor cannot fix something** (or finds an unknown problem), it writes a
single shareable text report and points you to it. Generate one any time with
`ryoku doctor --report [file]`: it bundles the findings with system state (btrfs
usage and device errors, `/proc/swaps`, failed units, recent journal errors,
pacman state, the ryoku channel state, session env, and hardware: backlight
devices, GPU drivers, kernel cmdline, recent display-driver log) into one `.txt`
the maintainers can read. It contains no passwords or keys.

**When you want it to reason, not just match rules**, `ryoku doctor --explain`
sends that same report to a cloud model and prints its root-cause analysis and fix
steps. This is the long tail the reconcilers cannot pre-encode: it reasons over
the evidence the way a human would, then tells you what to change (including
hardware/BIOS causes it cannot touch). It is strictly **advisory and read-only**,
it never runs anything, so a wrong answer can only mislead. It is opt-in and uses
**your own key**: nothing is sent unless you set one. Defaults target Groq (free,
fast); OpenRouter's free models work by overriding the URL and model. See the
environment variables below.

## Environment and state

Overrides (mostly for `deploy` and tests):

- `RYOKU_REPO` the checkout root. Required by `deploy`; also lets `status`,
  `update`, and `recovery` find the repo explicitly.
- `RYOKU_CONFIG_BASE` overrides the `materialize` base dir
  (default `/usr/share/ryoku/config`).
- `RYOKU_CHANNEL` overrides the update-channel branch (default `main`; used by
  tests).

AI reasoning for `doctor --explain` (opt-in; the report is sent only when a key is
set). Any OpenAI-compatible endpoint works:

- `RYOKU_AI_KEY` your provider key, or write it to `~/.config/ryoku/ai-key`.
- `RYOKU_AI_URL` the API base (default `https://api.groq.com/openai/v1`; for
  OpenRouter use `https://openrouter.ai/api/v1`).
- `RYOKU_AI_MODEL` the model (Groq default `llama-3.3-70b-versatile`; an
  OpenRouter free model is e.g. `meta-llama/llama-3.3-70b-instruct:free`).

State the CLI keeps under `$XDG_STATE_HOME/ryoku` (default `~/.local/state/ryoku`):

- `repo` the checkout root the last deploy recorded.
- `deployed` the commit the last deploy laid down; the baseline `status`
  measures the channel against.
- `materialized` the manifest of Ryoku-owned files, so the next `materialize`
  can prune cleanly.
- `doctor-report.txt` the latest diagnostic report `doctor` wrote (also the
  default target of `ryoku doctor --report`).

Runtime: `$XDG_RUNTIME_DIR/ryoku-update.json` is the update island's progress
file, written by `update`.
