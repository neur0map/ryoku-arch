# Ryoku config architecture: rice vs. user config

> Design doc. Goal: a crystal-clear separation between **Ryoku default config
> ("the rice" - exactly how Ryoku ships)** and **user-owned config**, so that
> every push automatically ships in the next ISO, and existing users only ever
> get a change when it is explicitly a `[global]` one. Modeled on Omarchy
> (migrations + a default tree), adapted to Ryoku's multi-layer shell.

## The two rules (what we are committing to)

1. **Fresh ISO / fresh install = always the latest.** Every push/edit you make
   is what the next ISO ships. (Already true: `ryoku-iso-make --local-source`
   tar-syncs the working tree, and `install/preflight/migrations.sh` marks all
   migrations "done" on a fresh install so a clean machine just *is* current.)

2. **Existing user update = never touch user config, unless `[global]`.** A
   `ryoku-update` leaves the user's live config alone. The *only* way an update
   changes an existing user's config is a **migration** shipped for a `[global]`
   change. No migration ⇒ existing users keep what they have; the change still
   reaches every *fresh* install.

The impact label is the contract: `[global]` = "this should reach existing
users" ⇒ it must ship a migration. Everything else is fresh-install-only.

## Why it doesn't work today (the muddle)

The "default config" is spread across three shell layers with no single home,
and the only thing that force-applies on update is a tiny override file:

| Layer | Default lives in | Read by | Ships on fresh? | Reaches existing users? |
|---|---|---|---|---|
| ambxst (active desktop: bar, dock, **desktop widgets/clock**) | `shell/ambxst/config/defaults/*.js` | `~/.config/ryoku-shell/config.json` | yes | only if a migration writes it |
| noctalia (settings UI, version) | `Settings.qml` defaults + `Assets/settings-default.json` | `settings.json` (not even present on disk → code defaults) | yes | no path |
| Ryoku override | `default/ryoku-shell/config-overrides.json` (force-merged into `config.json` every install **and** update) + `shell.json` | `config.json` / `shell.json` | yes | **yes (force)** |

So today the **only** settings that reach existing users are the handful in
`config-overrides.json` (`hotspot`, `dock`, `enabledPanels`). Desktop widgets,
the clock, and the version string are not there, so:
- a fresh install shows the *upstream* defaults (clock off, Noctalia version),
- and existing users get nothing.

That is the "I push changes and it does nothing" symptom.

## Target model

### A. ONE path is the whole Ryoku system (rice = the path)
There is a **single source-of-truth path** that contains *everything* that makes
Ryoku Ryoku - the **integrated Ryoku components** live here too:

```
shell/                         # <- THE path. Edit anything here to rice Ryoku.
  ambxst/      noctalia/        #   integrated Ryoku components (fully editable)
  services/  modules/  scripts/ #   Ryoku's own shell code
  rice/                         #   the default config = "how Ryoku ships"
    config.json                 #     full desktop config (bar, dock,
                                #     desktopWidgets + clock ON, panels)
    settings.json               #     noctalia/settings defaults + Ryoku version
    overrides.json              #     NARROW force-on-every-update set
    branding-replacements.tsv
  README.md                     #   "this is the Ryoku rice; edit here"
```

Today the rice base is scattered: ambxst `config/defaults/*.js`, noctalia
`Settings.qml` + `settings-default.json`, and `default/ryoku-shell/`. We
**consolidate** the Ryoku default/rice into `shell/rice/` (moving
`default/ryoku-shell/*` in) so there is exactly **one path** - `shell/` - that
holds the integrated components, the Ryoku code, and the defaults together. A user (or you)
rices by editing files under `shell/`; nothing lives anywhere else.

On a machine this whole tree deploys to **`~/.config/quickshell/ryoku-shell/`**
(already does), so an installed user finds the *same* one path - components,
code, and rice - all editable in place. The live user config
(`~/.config/ryoku-shell/`) is the only thing outside it, and is clearly the
"yours, not Ryoku's" layer.

The built-in component defaults still apply as a fallback, but the
**Ryoku rice in `shell/rice/` is authoritative** and is what ships.

### B. Fresh-install path (the rice is applied in full)
`install/config/ryoku-shell-branding.sh` seeds the user config from
`default/ryoku-shell/config.json` (+ `settings.json`) as the **base**, then
applies `config-overrides.json`. Fresh installs therefore get the complete rice.
(No behavior change for the build - it already ships the working tree.)

### C. Existing-user path (migrations, gated on `[global]`)
For a `[global]` rice change that must reach existing users, ship a
`migrations/<unix-ts>.sh` that applies *just that delta* with `jq` (idempotent,
respects an explicit user opt-out where it matters). `ryoku-migrate` (update
stage 8) runs only un-run migrations; fresh installs have them pre-marked.
Non-`[global]` changes ship no migration and touch no existing user.

### D. The separation, made legible
- **Ryoku rice** = `default/ryoku-shell/` (in the repo, version-controlled).
- **User config** = `~/.config/ryoku-shell/` (on the machine).
- An update reads the rice, writes the user dir **only** via (a) fresh-install
  seeding or (b) a `[global]` migration. A `ryoku-doctor` check can report
  "user config diverged from rice in keys X, Y" so the two are always
  distinguishable.

## Implementation plan
1. **Consolidate the path.**
   `git mv default/ryoku-shell/{shell.json,config-overrides.json,branding-replacements.tsv} shell/rice/`,
   then repoint the only three referencers (verified by grep; `config.sh` and
   `ensure-shell-deployment.sh` do NOT reference these despite earlier notes):
   `install/config/ryoku-shell-branding.sh` lines 9-11 (`REPLACEMENTS_FILE`,
   `CONFIG_OVERRIDES_FILE`, `NATIVE_CONFIG_DEFAULTS_FILE`),
   `tests/ryoku-shell-branding.sh`, and `tests/ryoku-native-shell-config-defaults.sh`.
   This move is non-behavioral (branding reads the same files from the new
   path), so it needs no VM: verify locally that `grep -rn default/ryoku-shell`
   returns nothing and both tests pass. Add `shell/rice/README.md` ("this is the
   Ryoku rice"). Net: one path - `shell/` - holds the integrated components + Ryoku code + rice.
2. **Make `shell/rice/config.json` the real rice base** the active shell reads,
   with `desktopWidgets.enabled: true` + the clock widget on, applied as the
   base on fresh install (then `overrides.json` on top).
3. **Migration for existing users** (`[global]`): `migrations/<ts>.sh` enables
   clock+widgets for users who haven't explicitly disabled them.
4. **Version surface** shows a Ryoku version, not Noctalia `4.7.8`.
5. **Doctor check** that reports keys where `~/.config/ryoku-shell/` (user) has
   diverged from `shell/rice/` (Ryoku), so the two layers stay distinguishable.
6. **VM-verify** all three guarantees: fresh ISO ships clock+widgets; simulated
   existing-user update applies the migration; a non-`[global]` edit does **not**
   touch user config.

## Resolved decisions
- Single path home = **`shell/`** (integrated components + code + `shell/rice/`),
  not a separate `default/`/`rice/` top-level. The integrated components are part
  of Ryoku and editable in place.
- `overrides.json` stays the **narrow** force-on-every-update set; the broad
  rice ships via fresh-install seeding + `[global]` migrations.

## Enforcement and related work

The two rules are now backed by automation and docs:

- **`[global]` ⇒ migration** is CI-enforced: `.github/workflows/config-migration.yml`
  fails a PR whose commit subject carries `[global]` without an accompanying
  `migrations/<unix-ts>.sh`. Non-`[global]` changes stay fresh-install-only.
- **Canonical layers** (where new config/UI/IPC go) are stated in the root
  `AGENTS.md` ("Ryoku shell: one product, canonical layers"): new user-facing
  keys use `Ryoku.Config`; the existing ambxst/noctalia desktop config and its
  rice defaults are what this doc consolidates into `shell/rice/`.
- **Shell IPC <-> keybind parity** is gated by `.github/workflows/shell-ipc-parity.yml`
  (via `ryoku-dev-audit-shell-binds`), so a keybind can never dispatch to a
  missing handler.
- **Branch model** for the shipped-vs-standalone split lives in
  `docs/ryoku-shell-branch.md`.

Open: the local `.githooks/pre-commit` step 4 still requires a migration for any
`config/hypr|default/*` change (migration-by-default), which is stricter than
the `[global]`-by-default contract above. Reconcile the hook to the `[global]`
rule (or decide the hook is intentionally stricter) before relying on it.
