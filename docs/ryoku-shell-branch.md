# Branch model: ISO + shell on main, generated `ryoku-shell` for standalone

This is the runbook for the agreed branch layout (Option A). It explains what
each branch is, why `ryoku-shell` is *generated* rather than developed on, the
exact rename steps, and how the lean shell branch is published.

> **Status (live as of 2026-06-03):** this model is instantiated on the remote.
> `origin/main` + `origin/unstable-dev` carry the full product (ISO + shell);
> `origin/ryoku-shell` is the generated shell-only branch (`main` minus `iso/`);
> the old `shell-install` branch has been removed. `shell-install/boot.sh`
> defaults `RYOKU_REF` to `ryoku-shell`. The steps below are kept as the
> reference for how it was done and how to re-publish.

## The layout

| Branch | Contents | Role |
|---|---|---|
| `main` | full repo: shell (`shell/`) + OS/ISO layer (`iso/`, `install/`, `bin/`, `config/`, ...) | stable line. ISO builds from here; the source of truth for everything. |
| `unstable-dev` | same shape as `main` | bleeding-edge integration line. |
| `ryoku-shell` (renamed from `shell-install`) | `main` minus `iso/` (the ISO builder / archinstall) and repo meta | **generated** lean branch for standalone, non-Arch installs via `shell-install/`. No ISO. |

Develop everything (shell + the keybinds/config/install glue that expose it) on
`main`/`unstable-dev`, in one change. The ISO and the shell ship from the same
tree, so they cannot drift. `ryoku-shell` is a published artifact, not a place
you commit to.

### Why generated/downstream, not a dev branch

The shell is not a standalone island: `shell.qml` and the runtime reach into
`bin/ryoku-*`, `config/hypr/`, `lib/runtime-env.sh`, the package lists, and the
systemd unit. The standalone installer (`shell-install/lib/deploy.sh`) deploys
the repo **minus** `iso/`, `shell-install/`, `legacy/`, `distro/`, `tests/`,
`docs/`, `videowalls/` and reuses `install/config/`. So a shell install needs
most of the repo anyway. If shell development happened on a separate branch and
only periodically merged into `main`, `main` (and the ISO) would lag the shell:
exactly the drift this project is trying to kill. Keeping one source of truth
and generating `ryoku-shell` downstream makes drift structurally impossible.

## What goes in `ryoku-shell`

Authoritative scope = what `shell-install/lib/deploy.sh:rsi_deploy_payload`
already deploys for a standalone install. The generated branch is:

```
main, with these removed:
  iso/            # ISO builder + archinstall (the whole point of "no ISO")
  .git internals  # (handled by the publish mechanism)
```

Everything else stays, because the standalone installer (`shell-install/`)
reuses it: `shell/`, `shell-install/`, `install/` (notably `install/config/`),
`bin/`, `config/`, `lib/`, `migrations/`, `default/`, `themes/`, `vendor/`.

### Open scope decision (v1 vs deeper)

- **v1 (recommended):** drop only `iso/`. Simple, correct, and the standalone
  installer works unchanged. `install/` still carries OS-only phases
  (disk/bootloader/SDDM under `install/preflight`, `install/login`) that are
  inert for a shell-only install but present.
- **Deeper purification (follow-up):** split `install/config/` (the shared
  config/shell deployment the standalone path reuses) out of the OS installer
  so `ryoku-shell` can also drop the OS-only `install/` phases. This is a
  refactor; do it only if the lingering inert code is a real problem.

Start with v1.

## Rename `shell-install` -> `ryoku-shell` (maintainer, GitHub)

Nothing references the `shell-install` *branch* by name (verified: every
installer uses branch `main`/`RYOKU_REF` + the `shell-install/` *directory*),
and that branch currently has zero unique commits, so the rename is safe.

**This was executed** (2026-06-03): `ryoku-shell` was generated from `main` via
the `publish-ryoku-shell` workflow and the old `shell-install` branch was
deleted (`git push origin :shell-install`). `git branch -m` was unnecessary
because `ryoku-shell` is generated, not a true rename.

```bash
# GitHub UI: Settings > Branches, or:
git branch -m shell-install ryoku-shell        # if you have it checked out
git push origin :shell-install ryoku-shell     # delete old remote ref, push new
git push origin -u ryoku-shell
```

The `shell-install/` directory is unchanged: only the branch name moves.

After the rename, point the standalone installer at the lean branch so non-Arch
users do not download the ISO builder. In `shell-install/boot.sh`, default the
ref to `ryoku-shell` (the root `boot.sh`, used by the full OS install, stays on
`main`):

```bash
RYOKU_REF="${RYOKU_REF:-ryoku-shell}"
```

## Publish (generate `ryoku-shell` from `main`)

`.github/workflows/publish-ryoku-shell.yml` regenerates the branch. It is
`workflow_dispatch` only (manual) so a maintainer reviews before the first
publish; flip on the `push: branches: [main]` trigger once it is trusted.

Manual equivalent:

```bash
git fetch origin main
git switch --force-create ryoku-shell origin/main
git rm -r --quiet iso
git commit -m "publish: ryoku-shell from main@$(git rev-parse --short origin/main) (drop iso/)"
git push --force-with-lease origin ryoku-shell
git switch main
```

Because the branch is generated, force-push is expected; never commit shell
changes directly to `ryoku-shell` (they would be overwritten on the next
publish). Land shell changes on `main`/`unstable-dev`.

## What needs the maintainer (ongoing)

The branch model is live (see Status at the top). What remains is ongoing
maintenance, not one-time setup:

- **Re-publish `ryoku-shell`** after shell-affecting changes land on `main`: run
  the `publish-ryoku-shell` workflow (or the manual equivalent above). Optionally
  flip on its automatic `push: { branches: [main] }` trigger once trusted, so it
  regenerates on every `main` push.
- Confirm the v1 scope (drop `iso/` only) or schedule the deeper `install/` split.
