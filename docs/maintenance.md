# Maintenance Guide

How to maintain the Ryoku Arch repository: branch topology, shipping changes to users, tracking upstream Omarchy, and safety rules.

## How changes reach users

Ryoku has two code paths that apply to user systems. Know the difference before editing.

### Fresh-install path (`install/`)

Scripts under `install/` run **once**, when a user bootstraps Ryoku for the first time via `boot.sh`. They do not re-run during `ryoku-update`. Anything you add here reaches new installs only; existing installs will not pick it up.

Examples: `install/packaging/base.sh`, `install/login/sddm.sh`, `install/config/theme.sh`.

### Update path (`migrations/<unix-ts>.sh`)

Migrations under `migrations/` run during `ryoku-update` (via `ryoku-migrate`) in timestamp order. Each migration runs **once per machine** (tracked via markers under `~/.local/state/ryoku/migrations/`). Migrations reach existing installs.

Every migration must be idempotent - re-running a migration on a machine that already applied it must be a no-op. Use a marker under `~/.local/state/ryoku/independence-cutover.<name>.done` for guard gates on cutover-style migrations.

### Commands (`bin/`)

Scripts under `bin/` are invoked by users or other scripts. Adding a new command, or changing an existing one, takes effect on the next `ryoku-update` (which pulls the new file into `~/.local/share/ryoku/bin/`).

### When to pick each

| Intent | Mechanism |
|---|---|
| Change what future fresh installs do | `install/` |
| Converge existing installs to a new state | `migrations/` |
| Give users a new command to run on demand | `bin/` |
| Any of the above that is interactive or heavy | `bin/` + docs nudge, optionally invoked by `install/` (fresh) and nudged by a migration (existing) |

A change that needs to reach both fresh installs and existing installs needs an entry in both `install/` and `migrations/`.

Default app replacements should not silently rewrite existing user choices. Add the new default to the fresh install path, then use `ryoku-default-app-migrate <kind> <target> [yes|no|ask]` from a migration so existing users can accept or keep their current app.

## Repo topology

### Remotes

| Remote | URL | Role |
|---|---|---|
| `origin` | `https://github.com/neur0map/ryoku-arch.git` | The Ryoku Arch repo. All pushes go here. |
| `upstream` | `https://github.com/basecamp/omarchy.git` | The omarchy upstream. Read-only reference. |

### Branches

| Branch | Local or remote | Tracks | Role |
|---|---|---|---|
| `main` | local + `origin/main` | `origin/main` | The Ryoku Arch tip. Users pull this via `ryoku-update`. |
| `upstream-dev` | local only | `upstream/dev` | A passive mirror of omarchy's `dev` branch. Used for browsing upstream state and cherry-picking. Configured `pushRemote=no_push` so it cannot be pushed to `origin` by accident. |
| `upstream-master` | local only | `upstream/master` | Same as above but for omarchy's stable `master` branch. Configured `pushRemote=no_push`. |

`upstream-dev` and `upstream-master` are zero-cost: each is just a pointer to a commit. They are not additional copies of the working tree. Switching to them via `git checkout` swaps the working tree to that state; switching back to `main` restores Ryoku state.

### Tags

| Tag | Points to | Role |
|---|---|---|
| `upstream-baseline` | The omarchy `dev` tip at the moment Ryoku Arch was forked | Annotated tag. Historical anchor for "what omarchy looked like when we forked." Useful for `git log upstream-baseline..upstream/dev` to see what upstream has accumulated since. |

## The update loop

The short version: push to `origin/main`, users run `ryoku-update`, changes apply.

### What `ryoku-update` does

When a user runs `ryoku-update` on their Ryoku Arch system:

1. Prompts for confirmation (or `-y` skips).
2. Takes a btrfs snapshot via `ryoku-snapshot create` for rollback insurance.
3. Runs `ryoku-update-git`: `git -C ~/.local/share/ryoku pull --autostash`. This pulls new commits from `origin/main` (which is Ryoku Arch).
4. Runs `ryoku-update-perform`, which in sequence runs:
   - `ryoku-update-keyring`: refreshes Arch signing keys.
   - `ryoku-update-system-pkgs`: pacman system upgrade.
   - `install/packaging/base.sh`: installs required repo packages.
   - `ryoku-update-aur-pkgs` and `install/packaging/aur-core.sh`: AUR package upgrade and required AUR packages.
   - `install/config/shell.sh`: syncs the Ryoku shell into the user's Quickshell config.
   - `ryoku-migrate`: scans `migrations/*.sh`, runs any new ones, marks them applied.
   - Orphan-package checks, post-update hooks, log analysis, and restart prompts.
5. Restarts affected components (Niri config reload, shell restart, etc.) if needed.

Because `git pull` pulls from whatever `origin` points at, and the live clone's `origin` was repointed to `neur0map/ryoku-arch` during the scaffolding pass, your pushes flow through automatically. No user action required to "opt in" to Ryoku changes beyond the initial migration.

### Three categories of changes

| Kind of change | What you do | How it reaches the user |
|---|---|---|
| New or modified command in `bin/` | Add or edit a file under `bin/`, commit, push | Immediately after `git pull`. The installer put `$RYOKU_PATH/bin` on `PATH`, so the new command is live instantly. |
| New theme, asset, or default-config template | Add file under `themes/`, `default/`, or similar | File is present after pull. If it is a default config or template, the user's `~/.config/` is NOT auto-updated. They must opt in via `ryoku-refresh-config <path>`, or you ship a migration that does the copy with backup. |
| System state change (package install, service enable, systemd unit, config modification) | Write a migration script at `migrations/<unix-timestamp>.sh` | Picked up automatically by `ryoku-migrate` during the next `ryoku-update`. Runs once per user by convention. If the change replaces a user-facing default app, preserve custom choices and prompt existing installs before switching. |

### What will NOT auto-propagate

- **Config files the user has customized.** If they edited `~/.config/niri/config.kdl` or a file under `~/.config/niri/config.d/` and you ship a new default, they keep their version. Use a migration to offer a merge or document a refresh command.
- **Changes outside `~/.local/share/ryoku/`.** System services, `/etc/` configs, boot config, kernel params. Touch via a migration script that uses sudo.
- **User-installed binaries outside the clone.** Not affected by updates.

## Shipping your own changes

### Simple change (command, doc, config template)

```bash
cd $HOME/prowl/ryoku-arch
# edit files
git add <specific paths>
git commit -m "<type>: <description>"
git push origin main
```

Commit message types follow the pattern already in history: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `scaffold:`, etc. No authorship trailers. No heredoc commit-message block. Plain `-m` flags only.

### Adding a migration (install a tool, enable a service, etc.)

Example: ship `nmap` to all Ryoku Arch users.

1. Create the migration file named after the current unix timestamp, using the Ryoku helper:

```bash
cd $HOME/prowl/ryoku-arch
ryoku-dev-add-migration --no-edit
```

This creates `migrations/<unix-timestamp>.sh`.

2. Edit the new file. Migration format:
   - No shebang line.
   - Start with `echo` describing what the migration does.
   - Use `$RYOKU_PATH` to reference the repository root on the user's machine.
   - Be idempotent: running the migration twice should be harmless.

```bash
echo "Install nmap for Ryoku cybersec baseline"
ryoku-pkg-add nmap
```

3. Commit and push:

```bash
git add migrations/<timestamp>.sh
git commit -m "feat: add nmap to baseline tooling"
git push origin main
```

4. On the user's next `ryoku-update`, `ryoku-migrate` runs the new migration, installs nmap, records the migration as applied, and moves on.

Tip: test the migration on your own live clone before pushing by pulling and running `ryoku-update` locally.

### Testing the update loop

Run a probe whenever you want to verify that pushes flow to the live system:

```bash
# Dev folder
cd $HOME/prowl/ryoku-arch
printf "\n<!-- probe: %s -->\n" "$(date -u +%Y%m%dT%H%M%SZ)" >> README.md
git commit -am "test: update-loop probe"
git push origin main

# Live clone
cd ~/.local/share/ryoku
git pull
tail -1 README.md    # the probe line should appear

# Revert
cd $HOME/prowl/ryoku-arch
git revert --no-edit HEAD
git push origin main

cd ~/.local/share/ryoku
git pull
```

## Tracking upstream omarchy

Omarchy ships new work on `basecamp/omarchy`. You decide commit-by-commit whether to adopt any of it. Do not merge upstream wholesale: after the rename pass the merge conflicts become unmanageable, and you will end up with upstream-specific choices you did not want (branding updates, mirror changes).

### See what's new

```bash
cd $HOME/prowl/ryoku-arch
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
cd $HOME/prowl/ryoku-arch
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
cd $HOME/prowl/ryoku-arch
git stash push -m "wip"    # if there are uncommitted changes
git checkout upstream-dev
# ...browse, read, inspect files...
git checkout main
git stash pop              # if you stashed
```

### Cherry-pick a clean upstream commit

When upstream has a bug fix or feature you want to adopt:

```bash
cd $HOME/prowl/ryoku-arch
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
cd $HOME/prowl/ryoku-arch
git cherry-pick --no-commit <sha>     # stage the changes, do not commit
# inspect the staged changes
git status
# manually port the fix to the renamed file
# example: upstream changed the legacy command path, we keep the Ryoku rename
git restore --staged bin/legacy-tool
# edit bin/ryoku-tool to include the equivalent fix
git add bin/ryoku-tool
git commit -m "backport: <description> (from omarchy <short-sha>)"
git push origin main
```

### Grab a single file from upstream

If you want one file from upstream wholesale, without a cherry-pick commit:

```bash
cd $HOME/prowl/ryoku-arch
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
- Features that conflict with Ryoku's direction (e.g., a Basecamp-specific shortcut, an upstream community link).
- Changes to `boot.sh` defaults where we've already decided to diverge (the `RYOKU_REPO` default, pacman-mirror URL rewrites).
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
4. **Cherry-pick preserves authorship.** `git cherry-pick <sha>` creates a new commit on Ryoku with DHH as the author and you as the committer. Do not amend to change author. Do not add extra authorship trailers.
5. **Commit identity.** Commits authored from the dev folder use `user.name = "Carlos Mejia (neur0map)"` and a GitHub no-reply email. Local-only git config. Do not lift this to global scope unless you want all repos on this machine to inherit it.
6. **No generated-content attribution.** Commit messages and shipped files should describe the work, not the tools used to produce it.
7. **No em-dashes.** Use colons, commas, periods, or parens. This applies to anything committed: commits, docs, code comments, the README.
8. **No personal machine paths.** Repo files should use portable paths like `$HOME`, `~`, `$RYOKU_PATH`, repo-relative paths, or runtime discovery. Do not commit hardcoded user home paths, runtime UID paths, per-run logs, or machine-id boot paths unless a historical recovery document explicitly needs them.

## Repo layout

Keep the repo root limited to project entrypoints and repo metadata. Brand images, SVGs, and text art live in `assets/brand/`. Maintainer task tracking lives in `docs/TODO.md` with the rest of the project docs.

Use `shell/VERSION` as the single tracked release version file. The bundled Quickshell setup, packaging, and update code expects an uppercase `VERSION` inside the shell tree, so Ryoku-level version consumers should read `shell/VERSION` instead of adding another root `VERSION` or `version` file.

## Git hooks

Ryoku Arch ships a set of git hooks that enforce the safety rules above mechanically. They live in `.githooks/` at the repo root and get activated per-clone via `core.hooksPath`.

### What's enforced

- **commit-msg:** rejects a commit if its message contains authorship trailers, generated-content attribution phrases, or any em-dash (U+2014).
- **pre-commit:** before the commit is recorded, scans staged text files for personal machine path leaks, scans staged text files (`.md`, `.txt`, `.sh`, config files, LICENSE, NOTICE, README, AGENTS.md) for em-dashes, and runs `bash -n` on staged shell scripts. Blocks the commit on any finding.
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

## CI checks

`.github/workflows/shellcheck.yml` runs ShellCheck on shell files changed by a pull request or push to `main`. This keeps new shell changes linted without blocking the repo on historical ShellCheck debt. Maintainers can run the workflow manually with `scope = all` when doing a cleanup pass.

`.github/workflows/codeql.yml` runs CodeQL on GitHub Actions workflows, JavaScript/TypeScript, Python, and Go. It runs on pull requests, pushes to `main`, a weekly schedule, and manual dispatch. Shell remains covered by ShellCheck, not CodeQL.

`.github/workflows/qmllint.yml` runs Qt's official `qmllint` against changed QML files in the bundled Quickshell tree. It installs Ubuntu's `qt6-declarative-dev` package, resolves `/usr/lib/qt6/bin/qmllint`, and exposes `shell/` as the `qs` import root for local modules. `.qmllint.ini` intentionally suppresses missing-type/import noise from Quickshell-specific modules that are not available on the GitHub runner; this keeps the first pass useful for syntax and low-noise QML validation. Keep warning policy in `.qmllint.ini` because Ubuntu's Qt 6.4.2 `qmllint` does not support newer warning-limit CLI flags.

`.github/workflows/inclusive-language.yml` runs `woke` on changed text files with GitHub Actions annotations. It pins `woke` so upstream rule updates do not create surprise failures, uses `.woke.yml` for repo-specific ignores, and avoids inherited shell sources, binary assets, media, signing keys, and technical modprobe directives. Maintainers can run the workflow manually with `scope = all` when doing a language cleanup pass.

`.github/workflows/trivy.yml` runs Trivy against the repository filesystem for dependency vulnerabilities, exposed secrets, and configuration mistakes. It uploads a SARIF report for GitHub code scanning, blocks high/critical secret findings, and blocks critical vulnerability or misconfiguration findings. The Trivy action is pinned to a full commit SHA because security scanners are part of the CI attack surface.

`.github/workflows/build-iso.yml` also runs Trivy after the ISO is built. It mounts the ISO's SquashFS live root, scans that root filesystem, uploads a `trivy-iso` SARIF report, and blocks signing, uploading, and Discord release announcements when critical CVEs or misconfigurations are found in the built image.

False-positive rule: prefer narrowing the scanned file set before adding broad ignores. Technical terms required by upstream config formats, generated files, binary assets, package caches, media, and vendored/inherited documentation should be skipped explicitly instead of making the linter less strict everywhere.

`.github/workflows/docs-sync.yml` keeps Mintlify-facing docs honest. It checks that `docs/keybindings.md` was regenerated from `config/niri/config.d/70-binds.kdl`, parses `docs.json`, then runs the Mintlify CLI validation and broken-link checks. `.mintignore` excludes vendored shell docs that are not part of the public docs site. If you edit keybindings, run:

```bash
bin/ryoku-dev-generate-keybindings-docs
```

The hosted docs are connected through the Mintlify GitHub App. GitHub deployments show `mintlify[bot]` deploying `main` to `https://docs.ryoku.dev`; that deployment happens after committed changes reach the connected branch. The repo-side job above catches stale generated docs before Mintlify deploys them.

## Snyk

Recommended setup is Snyk's GitHub integration, imported from the Snyk Web UI, rather than a token-based GitHub Actions workflow at first. Import `neur0map/ryoku-arch`, enable PR checks for open-source and code analysis if available on the account, and keep automatic fix or upgrade PRs conservative until the signal is useful.

The repo currently has limited dependency manifests, mainly `shell/go.mod`, so Snyk should complement CodeQL, ShellCheck, and the shell-script alert instead of replacing them. If Snyk is later run from GitHub Actions, add a `SNYK_TOKEN` repository secret and document the severity threshold before making that workflow blocking.

## Discord notifications

Ryoku uses `.github/workflows/discord-notifications.yml` to post Discord messages when someone opens a new issue or pull request. Issue notifications use the brand orange accent, pull request notifications use the Greek Noir muted green-gray accent, and both use the Ryoku mark from `assets/brand/logo-mark.png`.

Setup:

1. Create or choose the Discord channel for Ryoku repository activity.
2. In Discord, open the channel settings, then Integrations, then Webhooks, and create a webhook.
3. In GitHub, open the Ryoku repository settings, then Secrets and variables, then Actions.
4. Add a repository secret named `DISCORD_WEBHOOK_URL` with the webhook URL as the value.
5. Run the `Discord Notifications` workflow manually with `preview = both` to verify the channel receives separate issue and pull request preview messages.

Keep these notifications on-brand and public-channel safe: no emoji, no extra accent colors, no generated-content attribution, and no internal workflow-run links. The pull request trigger uses `pull_request_target` so forked pull requests can notify the channel. Keep that workflow limited to reading `$GITHUB_EVENT_PATH` and sending the webhook. Do not add checkout, build, install, or script execution steps to that workflow.

## Rollback

### Revert a pushed commit

For a reversible mistake on `main`:

```bash
cd $HOME/prowl/ryoku-arch
git revert --no-edit <bad-sha>
git push origin main
```

Users get the revert on their next `ryoku-update`.

### Revert the Ryoku Arch migration on a user system

If something catastrophic ships and a user needs to fall back to upstream omarchy:

```bash
cd ~/.local/share/ryoku
git remote set-url origin https://github.com/basecamp/omarchy.git
git fetch origin
git checkout -b master --track origin/master   # or whatever upstream branch they want
git branch -D main
```

Or restore from the btrfs snapshot taken before the migration:

```bash
ryoku-snapshot list
ryoku-snapshot restore <snapshot-id>
```

(Exact rollback command depends on the omarchy snapshot tooling; check `ryoku-snapshot` usage on the target system.)

## Mirrorlist refresh

The Ryoku default mirrorlists in `default/pacman/mirrorlist-{stable,rc,edge}` are snapshots of Arch Linux mirror-status-filtered HTTPS mirrors. All three files are byte-identical today; the three filenames survive as channel scaffolding, not as distinct upstreams.

Regenerate when a visible mirror regression appears or at least quarterly. Two options:

**Option A (no extra package, uses curl):**

```bash
curl -sf 'https://archlinux.org/mirrorlist/?country=US&protocol=https&use_mirror_status=on' -o /tmp/arch-mirrorlist-raw
# Uncomment the top 20 Server entries, preserve the ## country headers above them:
python3 -c '
import re
with open("/tmp/arch-mirrorlist-raw") as f: lines = f.readlines()
kept, country, active = [], None, 0
for l in lines:
    if l.startswith("##"): kept.append(l); continue
    if l.startswith("## "): country = l; continue
    m = re.match(r"^#Server\s*=\s*(https://\S+)", l)
    if m and active < 20:
        if country: kept.append(country); country = None
        kept.append(f"Server = {m.group(1)}\n"); active += 1
with open("/tmp/ryoku-mirrorlist", "w") as f: f.write("".join(kept))
'
cp /tmp/ryoku-mirrorlist default/pacman/mirrorlist-stable
cp /tmp/ryoku-mirrorlist default/pacman/mirrorlist-rc
cp /tmp/ryoku-mirrorlist default/pacman/mirrorlist-edge
git add default/pacman/mirrorlist-* && git commit -m "chore: refresh arch mirrorlist snapshot"
```

**Option B (with reflector):**

```bash
sudo pacman -S --needed reflector
sudo reflector --country 'United States' --age 12 --protocol https --sort rate --save /tmp/ryoku-mirrorlist
cp /tmp/ryoku-mirrorlist default/pacman/mirrorlist-stable
cp /tmp/ryoku-mirrorlist default/pacman/mirrorlist-rc
cp /tmp/ryoku-mirrorlist default/pacman/mirrorlist-edge
git add default/pacman/mirrorlist-* && git commit -m "chore: refresh arch mirrorlist snapshot"
```

Adjust `--country` to your own location if you are generating for a non-US audience. Record the exact command and date in the commit message.

## Session logs and decisions

Working notes for each session go in `logs/YYYY-MM-DD-session-NN.md`. These files are gitignored. They are meant as handoff notes between sessions, not as project history.

For observations that should persist beyond a session (architecture decisions, unexpected constraints, rejected approaches), add them to a committed doc:

- `docs/vision.md` for large-scope intent.
- A future `docs/decisions/` folder can hold architecture decision records (ADRs) if the project grows enough to need them.

Session logs can point at committed docs, but should not be the sole home for anything the next maintainer needs.
