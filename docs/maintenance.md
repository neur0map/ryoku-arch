# Maintenance Guide

How to maintain the Ryoku Arch repository: branch topology, shipping changes to users, tracking upstream omarchy, and safety rules.

## Repo topology

### Remotes

| Remote | URL | Role |
|---|---|---|
| `origin` | `https://github.com/neur0map/ryoku-arch.git` | The Ryoku Arch repo. All pushes go here. |
| `upstream` | `https://github.com/basecamp/omarchy.git` | The omarchy upstream. Read-only reference. |

### Branches

| Branch | Local or remote | Tracks | Role |
|---|---|---|---|
| `main` | local + `origin/main` | `origin/main` | The Ryoku Arch tip. Users pull this via `omarchy-update`. |
| `upstream-dev` | local only | `upstream/dev` | A passive mirror of omarchy's `dev` branch. Used for browsing upstream state and cherry-picking. Configured `pushRemote=no_push` so it cannot be pushed to `origin` by accident. |
| `upstream-master` | local only | `upstream/master` | Same as above but for omarchy's stable `master` branch. Configured `pushRemote=no_push`. |

`upstream-dev` and `upstream-master` are zero-cost: each is just a pointer to a commit. They are not additional copies of the working tree. Switching to them via `git checkout` swaps the working tree to that state; switching back to `main` restores Ryoku state.

### Tags

| Tag | Points to | Role |
|---|---|---|
| `upstream-baseline` | The omarchy `dev` tip at the moment Ryoku Arch was forked | Annotated tag. Historical anchor for "what omarchy looked like when we forked." Useful for `git log upstream-baseline..upstream/dev` to see what upstream has accumulated since. |

## The update loop

The short version: push to `origin/main`, users run `omarchy-update`, changes apply.

### What `omarchy-update` does

When a user runs `omarchy-update` on their Ryoku Arch system:

1. Prompts for confirmation (or `-y` skips).
2. Takes a btrfs snapshot via `omarchy-snapshot create` for rollback insurance.
3. Runs `omarchy-update-git`: `git -C ~/.local/share/omarchy pull --autostash`. This pulls new commits from `origin/main` (which is Ryoku Arch).
4. Runs `omarchy-update-perform`, which in sequence runs:
   - `omarchy-migrate`: scans `migrations/*.sh`, runs any new ones, marks them applied.
   - `omarchy-update-system-pkgs`: pacman system upgrade.
   - `omarchy-update-aur-pkgs`: AUR package upgrade.
   - Keyring, firmware, orphan-package checks.
5. Restarts affected components (Hyprland reload, etc.) if needed.

Because `git pull` pulls from whatever `origin` points at, and the live clone's `origin` was repointed to `neur0map/ryoku-arch` during the scaffolding pass, your pushes flow through automatically. No user action required to "opt in" to Ryoku changes beyond the initial migration.

### Three categories of changes

| Kind of change | What you do | How it reaches the user |
|---|---|---|
| New or modified command in `bin/` | Add or edit a file under `bin/`, commit, push | Immediately after `git pull`. The installer put `$OMARCHY_PATH/bin` on `PATH`, so the new command is live instantly. |
| New theme, asset, or default-config template | Add file under `themes/`, `default/`, or similar | File is present after pull. If it is a default template (e.g., `default/hypr/*.tpl`), the user's `~/.config/` is NOT auto-updated. They must opt in via `omarchy-refresh-config <path>`, or you ship a migration that does the copy with backup. |
| System state change (package install, service enable, systemd unit, config modification) | Write a migration script at `migrations/<unix-timestamp>.sh` | Picked up automatically by `omarchy-migrate` during the next `omarchy-update`. Runs once per user by convention. |

### What will NOT auto-propagate

- **Config files the user has customized.** If they edited `~/.config/hypr/hyprland.conf` and you ship a new default, they keep their version. Use a migration to offer a merge or document a refresh command.
- **Changes outside `~/.local/share/omarchy/`.** System services, `/etc/` configs, boot config, kernel params. Touch via a migration script that uses sudo.
- **User-installed binaries outside the clone.** Not affected by updates.

## Shipping your own changes

### Simple change (command, doc, config template)

```bash
cd /home/omi/prowl/ryoku-arch
# edit files
git add <specific paths>
git commit -m "<type>: <description>"
git push origin main
```

Commit message types follow the pattern already in history: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `scaffold:`, etc. No `Co-Authored-By` trailer. No heredoc commit-message block. Plain `-m` flags only.

### Adding a migration (install a tool, enable a service, etc.)

Example: ship `nmap` to all Ryoku Arch users.

1. Create the migration file named after the current unix timestamp, using omarchy's helper:

```bash
cd /home/omi/prowl/ryoku-arch
omarchy-dev-add-migration --no-edit
```

This creates `migrations/<unix-timestamp>.sh`.

2. Edit the new file. Migration format (inherited from omarchy convention):
   - No shebang line.
   - Start with `echo` describing what the migration does.
   - Use `$OMARCHY_PATH` to reference the repository root on the user's machine.
   - Be idempotent: running the migration twice should be harmless.

```bash
echo "Install nmap for Ryoku cybersec baseline"
omarchy-pkg-add nmap
```

3. Commit and push:

```bash
git add migrations/<timestamp>.sh
git commit -m "feat: add nmap to baseline tooling"
git push origin main
```

4. On the user's next `omarchy-update`, `omarchy-migrate` runs the new migration, installs nmap, records the migration as applied, and moves on.

Tip: test the migration on your own live clone before pushing by pulling and running `omarchy-update` locally.

### Testing the update loop

Run a probe whenever you want to sanity-check that pushes flow to the live system:

```bash
# Dev folder
cd /home/omi/prowl/ryoku-arch
printf "\n<!-- probe: %s -->\n" "$(date -u +%Y%m%dT%H%M%SZ)" >> README.md
git commit -am "test: update-loop probe"
git push origin main

# Live clone
cd ~/.local/share/omarchy
git pull
tail -1 README.md    # the probe line should appear

# Revert
cd /home/omi/prowl/ryoku-arch
git revert --no-edit HEAD
git push origin main

cd ~/.local/share/omarchy
git pull
```

## Tracking upstream omarchy

Omarchy ships new work on `basecamp/omarchy`. You decide commit-by-commit whether to adopt any of it. Do not merge upstream wholesale: after the rename pass the merge conflicts become unmanageable, and you will end up with omarchy-specific choices you did not want (branding updates, mirror changes).

### See what's new

```bash
cd /home/omi/prowl/ryoku-arch
git fetch upstream

# Every commit omarchy has made since we forked
git log --oneline upstream-baseline..upstream/dev

# Same for their stable branch
git log --oneline upstream-baseline..upstream/master

# Narrow to a specific subsystem
git log upstream-baseline..upstream/dev -- bin/
git log upstream-baseline..upstream/dev -- install/
```

### Refresh the local upstream branches

To pull the latest upstream state into the local `upstream-dev` and `upstream-master` branches:

```bash
cd /home/omi/prowl/ryoku-arch
git fetch upstream

# Update the local upstream branches to match remote
git branch -f upstream-dev upstream/dev
git branch -f upstream-master upstream/master
```

Or if you prefer to check them out:

```bash
git checkout upstream-dev && git pull
git checkout upstream-master && git pull
git checkout main
```

### Switch the working tree to upstream

To browse omarchy's state as if you were on omarchy:

```bash
cd /home/omi/prowl/ryoku-arch
git stash push -m "wip"    # if there are uncommitted changes
git checkout upstream-dev
# ...browse, read, inspect files...
git checkout main
git stash pop              # if you stashed
```

### Cherry-pick a clean upstream commit

When upstream has a bug fix or feature you want to adopt:

```bash
cd /home/omi/prowl/ryoku-arch
git fetch upstream
git checkout main
git cherry-pick <sha>                 # preserves DHH's authorship on the new commit
# or with provenance annotation:
git cherry-pick -x <sha>              # adds "(cherry picked from commit <sha>)" to message
git push origin main
```

### Cherry-pick with manual edit (for diverged files)

After the command rename pass, many upstream commits will touch paths we have renamed. Cherry-pick in stages:

```bash
cd /home/omi/prowl/ryoku-arch
git cherry-pick --no-commit <sha>     # stage the changes, do not commit
# inspect the staged changes
git status
# manually port the fix to the renamed file
# example: upstream changed bin/omarchy-foo, we have bin/ryoku-foo
git restore --staged bin/omarchy-foo
# edit bin/ryoku-foo to include the equivalent fix
git add bin/ryoku-foo
git commit -m "backport: <description> (from omarchy <short-sha>)"
git push origin main
```

### Grab a single file from upstream

If you want one file from upstream wholesale, without a cherry-pick commit:

```bash
cd /home/omi/prowl/ryoku-arch
git fetch upstream
git checkout main
git checkout upstream-dev -- bin/some-new-tool
git add bin/some-new-tool
git commit -m "import: some-new-tool from upstream"
git push origin main
```

## What to cherry-pick vs skip

### Usually cherry-pick

- Bug fixes to code Ryoku Arch still shares with omarchy.
- Security patches.
- New features that fit Ryoku's scope (hardware support, new widgets, new utilities).
- Migration-framework improvements.
- Bash cleanups in shared files.

### Usually skip

- Omarchy branding changes (logo, README text, copyright-year bumps).
- Features that conflict with Ryoku's direction (e.g., a Basecamp-specific shortcut, an omarchy-community link).
- Changes to `boot.sh` defaults where we've already decided to diverge (the `OMARCHY_REPO` default, pacman-mirror URL rewrites).
- Upstream version bumps on files we have forked heavily.

### Case by case

- New default apps or theme defaults: decide per change whether it fits Ryoku's aesthetic.
- Config refreshes that touch `~/.config/`: evaluate whether they fight Ryoku-specific changes.
- Large refactors upstream: sometimes easier to reimplement than to cherry-pick.

## Watching upstream

Options, from least to most automated:

- **Manual**: `git fetch upstream && git log upstream-baseline..upstream/dev` every week or two.
- **GitHub watch**: click "Watch" on `basecamp/omarchy`, pick "All activity" or "Custom" and subscribe to commits or releases.
- **RSS**: subscribe to `https://github.com/basecamp/omarchy/commits/master.atom` or `.../commits/dev.atom` in a feed reader.
- **Scripted (future)**: once divergence is significant, write `bin/ryoku-dev-upstream-scan` that fetches, lists new commits, flags which touch renamed files, and outputs a triage report. Not worth building until you feel the manual pain.

## Safety rules

1. **Never push `upstream-dev` or `upstream-master` to `origin`.** `pushRemote=no_push` is configured to prevent this. If you ever see a push attempt targeting `no_push`, git will error out; that is the safety net working. Do not clear the config.
2. **Never push `--all` or `--mirror`.** These push every local branch to `origin`, which would include the upstream branches. Always specify the branch: `git push origin main`.
3. **Never rebase or force-push `main`.** The live clones of everyone running Ryoku Arch pull from `origin/main`. Rewriting that history breaks their updates.
4. **Cherry-pick preserves authorship.** `git cherry-pick <sha>` creates a new commit on Ryoku with DHH as the author and you as the committer. Do not amend to change author. Do not add `Co-Authored-By` trailers.
5. **Commit identity.** Commits authored from the dev folder use `user.name = "Carlos Mejia (neur0map)"` and a GitHub no-reply email. Local-only git config. Do not lift this to global scope unless you want all repos on this machine to inherit it.
6. **No AI attribution.** No `Co-Authored-By: Claude`, no "Generated with", no mention of Claude/Anthropic/AI/LLM in commit messages, code comments, or documentation that ships with the repo.
7. **No em-dashes.** Use colons, commas, periods, or parens. This applies to anything committed: commits, docs, code comments, the README.

## Git hooks

Ryoku Arch ships a set of git hooks that enforce the safety rules above mechanically. They live in `.githooks/` at the repo root and get activated per-clone via `core.hooksPath`.

### What's enforced

- **commit-msg:** rejects a commit if its message contains a `Co-Authored-By` trailer, a term like `Claude`, `Anthropic`, `ChatGPT`, `GPT-N`, `LLM`, or `assistant`, phrasing like "generated with", or any em-dash (U+2014).
- **pre-commit:** before the commit is recorded, scans staged text files (`.md`, `.txt`, `.sh`, config files, LICENSE, NOTICE, README, AGENTS.md) for em-dashes and runs `bash -n` on staged shell scripts. Blocks the commit on any finding.
- **pre-push:** refuses to push `upstream-dev` or `upstream-master` to `origin` (belt-and-suspenders on top of the `pushRemote=no_push` config), and blocks force-pushes to `main` that would rewrite published history.

### Activation

Clone a fresh copy of the repo, then run:

```bash
cd ryoku-arch
bin/ryoku-dev-install-hooks
```

That sets `core.hooksPath = .githooks` in the local clone's config and makes every hook executable. Re-run it after pulling new hooks. Setup is idempotent.

Verify the hooks are active:

```bash
git config --get core.hooksPath        # should print: .githooks
ls -la .githooks                       # all files executable
```

### Bypass paths (use sparingly)

- `git commit --no-verify` skips `commit-msg` and `pre-commit` for one invocation. Do not use habitually.
- `git push --no-verify` skips `pre-push` for one invocation.
- `RYOKU_ALLOW_FORCE_MAIN=1 git push origin main` explicitly opts in to a force-push to main. Use only for deliberate history rewrites you have thought through, and prefer to coordinate with anyone who has a live clone first.

### Extending

To add a new check, edit the relevant hook file in `.githooks/`, commit, push. Contributors pulling the change then re-run `bin/ryoku-dev-install-hooks` to pick up the new `chmod +x` if needed (no config change required; `core.hooksPath` stays the same).

## Rollback

### Revert a pushed commit

For a reversible mistake on `main`:

```bash
cd /home/omi/prowl/ryoku-arch
git revert --no-edit <bad-sha>
git push origin main
```

Users get the revert on their next `omarchy-update`.

### Revert the Ryoku Arch migration on a user system

If something catastrophic ships and a user needs to fall back to upstream omarchy:

```bash
cd ~/.local/share/omarchy
git remote set-url origin https://github.com/basecamp/omarchy.git
git fetch origin
git checkout -b master --track origin/master   # or whatever upstream branch they want
git branch -D main
```

Or restore from the btrfs snapshot taken before the migration:

```bash
omarchy-snapshot list
omarchy-snapshot restore <snapshot-id>
```

(Exact rollback command depends on the omarchy snapshot tooling; check `omarchy-snapshot` usage on the target system.)

## Session logs and decisions

Working notes for each session go in `logs/YYYY-MM-DD-session-NN.md`. These files are gitignored. They are meant as handoff notes between sessions, not as project history.

For observations that should persist beyond a session (architecture decisions, unexpected constraints, rejected approaches), add them to a committed doc:

- `docs/vision.md` for large-scope intent.
- `docs/rebrand-inventory.md` for rename-related decisions.
- A future `docs/decisions/` folder can hold architecture decision records (ADRs) if the project grows enough to need them.

Session logs can point at committed docs, but should not be the sole home for anything the next maintainer needs.
