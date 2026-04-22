# Ryoku Arch Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the Ryoku Arch repository from the upstream omarchy codebase so the dev loop works end to end: edit in `/home/omi/prowl/ryoku-arch/`, push to `neur0map/ryoku-arch`, pull on the live system via `omarchy-update`.

**Architecture:** Preserve upstream omarchy history verbatim on `main`. Tag the pre-Ryoku tip as `upstream-baseline`. Add one Ryoku-authored scaffolding commit on top that introduces branding (README, LICENSE, NOTICE) and developer documentation (docs/, logs/) without touching any functional code. Migrate the live clone at `~/.local/share/omarchy/` by repointing its remote.

**Tech Stack:** bash, git, GitHub CLI (`gh`), ripgrep (`rg`).

**Source spec:** `docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md`.

**Non-negotiable constraints:**
- No `Co-Authored-By` trailer on any commit. Plain `git commit -m` only.
- No mention of AI, Claude, Anthropic, or LLMs in any committed artifact (commit messages, README, docs, comments, this plan).
- Destructive operations (`gh repo delete`, `rm -rf`, live-clone branch swap) require explicit user confirmation at execution time. These are gates, not auto-runs.

---

## Task 1: Pre-flight verification

**Files:** none modified. Read-only state checks.

- [ ] **Step 1.1: Verify dev working folder is clean (tracked files only)**

Run:
```bash
cd /home/omi/prowl/omarchy
git diff --quiet && git diff --cached --quiet && echo "clean tracked state" || echo "DIRTY, abort"
```
Expected output: `clean tracked state`. Untracked files under `docs/specs/` and `docs/plans/` are expected and allowed. If dirty, stop and resolve before proceeding.

- [ ] **Step 1.2: Record current HEAD SHA for the baseline tag**

Run:
```bash
cd /home/omi/prowl/omarchy
git rev-parse HEAD
git rev-parse --short HEAD
```
Record the short SHA. Expected at plan time: full SHA `27779668...`, short SHA `27779668`. If different, use whatever `git rev-parse --short HEAD` returns. Save this value for Task 4.

Do **not** run `git fetch upstream`. Baselining the currently-cloned SHA keeps the reset deterministic.

- [ ] **Step 1.3: Verify `gh` authentication and user**

Run:
```bash
gh auth status
gh api user --jq .login
```
Expected:
- `gh auth status` reports "Logged in to github.com" with token scopes including `repo` and `delete_repo`.
- `gh api user --jq .login` outputs exactly `neur0map`.

If the login is not `neur0map`, stop: the wrong account would delete and recreate the wrong repo.

- [ ] **Step 1.4: Confirm target deletion URL**

Run:
```bash
gh repo view neur0map/project-i-a-m --json nameWithOwner,url --jq '.nameWithOwner + " " + .url'
```
Expected: `neur0map/project-i-a-m https://github.com/neur0map/project-i-a-m`. If the command errors with "not found," the repo is already gone; note this and skip the deletion sub-step in Task 2.

- [ ] **Step 1.5: Verify stale sibling folder is clean**

Run:
```bash
cd /home/omi/prowl/project-i-a-m
git status -s
git rev-parse --abbrev-ref HEAD
```
Expected: `git status -s` returns empty output (clean tree). Branch should be `main`. If dirty, stop and ask the user what to preserve before deletion.

**Rollback note for Task 1:** no state changed. Nothing to roll back.

---

## Task 2: GitHub repo reset (DESTRUCTIVE GATE)

**Files:** none local. GitHub state only.

- [ ] **Step 2.1: Prompt user to confirm GitHub deletion**

Show the user the exact commands about to run. Wait for explicit approval before proceeding. Say:

> About to delete `neur0map/project-i-a-m` from GitHub. This is irreversible. All stars, issues, forks, and metadata will be lost. Confirm?

Do not execute Step 2.2 without explicit approval.

- [ ] **Step 2.2: Delete `neur0map/project-i-a-m`**

Run:
```bash
gh repo delete neur0map/project-i-a-m --yes
```
Expected: command returns with no error. Verify with:
```bash
gh repo view neur0map/project-i-a-m 2>&1 | head -1
```
Expected: `GraphQL: Could not resolve to a Repository with the name 'neur0map/project-i-a-m'.` (or similar "not found" message).

- [ ] **Step 2.3: Create `neur0map/ryoku-arch`**

Run:
```bash
gh repo create neur0map/ryoku-arch \
  --public \
  --description "Opinionated Arch Linux: rice + cybersecurity"
```
Expected: `https://github.com/neur0map/ryoku-arch` printed to stdout. No prompt for clone or push (we push from the existing local folder later).

- [ ] **Step 2.4: Verify the new repo exists and is empty**

Run:
```bash
gh repo view neur0map/ryoku-arch --json nameWithOwner,isEmpty,defaultBranchRef \
  --jq '"\(.nameWithOwner) empty=\(.isEmpty) default=\(.defaultBranchRef.name // "none")"'
```
Expected: `neur0map/ryoku-arch empty=true default=none` (or default may be `main` depending on GitHub account defaults; either is acceptable since we push `main` next).

**Rollback note for Task 2:** deletion is irreversible on GitHub. Recreation is idempotent: if aborted partway, rerun Step 2.3 with `--confirm` if needed. The old repo cannot be restored.

---

## Task 3: Local folder reshape (PARTIAL DESTRUCTIVE GATE)

**Files:**
- Rename: `/home/omi/prowl/omarchy/` to `/home/omi/prowl/ryoku-arch/`
- Delete: `/home/omi/prowl/project-i-a-m/`

- [ ] **Step 3.1: Rename the working folder**

Run:
```bash
mv /home/omi/prowl/omarchy /home/omi/prowl/ryoku-arch
ls -ld /home/omi/prowl/ryoku-arch /home/omi/prowl/omarchy 2>&1
```
Expected: first `ls` line shows `drwxr-xr-x ... /home/omi/prowl/ryoku-arch`. Second `ls` line reports `cannot access ... No such file or directory`.

- [ ] **Step 3.2: Reconfigure remotes in the renamed folder**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git remote rename origin upstream
git remote add origin https://github.com/neur0map/ryoku-arch.git
git remote -v
```
Expected:
```
origin   https://github.com/neur0map/ryoku-arch.git (fetch)
origin   https://github.com/neur0map/ryoku-arch.git (push)
upstream https://github.com/basecamp/omarchy.git (fetch)
upstream https://github.com/basecamp/omarchy.git (push)
```

- [ ] **Step 3.3: Rename the local branch from `dev` to `main`**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git branch -m dev main
git branch --show-current
```
Expected output: `main`.

- [ ] **Step 3.4: Prompt user to confirm deletion of stale sibling**

Show the user:

> About to `rm -rf /home/omi/prowl/project-i-a-m/`. The folder is confirmed clean (Step 1.5). Confirm?

Do not execute Step 3.5 without explicit approval.

- [ ] **Step 3.5: Delete the stale sibling folder**

Run:
```bash
rm -rf /home/omi/prowl/project-i-a-m
ls -ld /home/omi/prowl/project-i-a-m 2>&1
```
Expected: `ls: cannot access '/home/omi/prowl/project-i-a-m': No such file or directory`.

**Rollback note for Task 3:**
- Step 3.1: `mv /home/omi/prowl/ryoku-arch /home/omi/prowl/omarchy` reverts.
- Step 3.2: reverse the remote commands.
- Step 3.3: `git branch -m main dev` reverts.
- Step 3.5: not recoverable. The folder had no unique state (it was a clone of a repo that no longer exists on GitHub after Task 2.2). If it must be recreated, `git clone https://github.com/basecamp/omarchy.git /home/omi/prowl/project-i-a-m` gives you omarchy, but the old iam contents are gone forever.

---

## Task 4: Baseline tag

**Files:** git tag only, no tracked files modified.

- [ ] **Step 4.1: Create the `upstream-baseline` annotated tag**

Run (substitute `<short-sha>` with the value from Step 1.2):
```bash
cd /home/omi/prowl/ryoku-arch
SHORT_SHA=$(git rev-parse --short HEAD)
git tag -a upstream-baseline -m "omarchy ${SHORT_SHA} at Ryoku Arch fork point" HEAD
git show-ref upstream-baseline
```
Expected: one line matching `<full-sha> refs/tags/upstream-baseline`, where the SHA matches Step 1.2's full SHA.

**Rollback note for Task 4:** `git tag -d upstream-baseline` removes the tag locally. If already pushed (Task 7), also run `git push origin :refs/tags/upstream-baseline`.

---

## Task 5: Write scaffolding files

**Files:**
- Create: `/home/omi/prowl/ryoku-arch/NOTICE`
- Create: `/home/omi/prowl/ryoku-arch/.gitignore`
- Create: `/home/omi/prowl/ryoku-arch/docs/README.md`
- Create: `/home/omi/prowl/ryoku-arch/docs/vision.md`
- Create: `/home/omi/prowl/ryoku-arch/docs/rebrand-inventory.md`
- Create: `/home/omi/prowl/ryoku-arch/logs/README.md`
- Create: `/home/omi/prowl/ryoku-arch/logs/TEMPLATE.md`
- Modify: `/home/omi/prowl/ryoku-arch/README.md` (full rewrite)
- Modify: `/home/omi/prowl/ryoku-arch/LICENSE` (prepend a copyright line)
- Modify: `/home/omi/prowl/ryoku-arch/docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md` (one row added to the deliverables table so it lists the plan file)

All files already in the working tree before this task:
- `/home/omi/prowl/ryoku-arch/docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md` (written during brainstorming)
- `/home/omi/prowl/ryoku-arch/docs/plans/2026-04-22-ryoku-arch-scaffolding-plan.md` (this file, written during plan authoring)

- [ ] **Step 5.1: Rewrite `README.md`**

Overwrite `/home/omi/prowl/ryoku-arch/README.md` with:

```markdown
# Ryoku Arch

力と美のために: For the sake of power and beauty.

An opinionated Arch Linux distribution combining desktop ricing with a cybersecurity tooling focus. Intended for people studying or working in security who also care about how their machine looks.

## Status

Pre-alpha. Not installable as a standalone distribution yet. The repository currently tracks a working fork of omarchy with Ryoku-specific documentation and branding. See `docs/vision.md` for the north star and `docs/rebrand-inventory.md` for the list of pending rename work.

## Credit

Ryoku Arch is built on top of [Omarchy](https://github.com/basecamp/omarchy) by DHH. The install framework, update mechanism, theme system, and configuration conventions are inherited from omarchy; Ryoku Arch layers on a security tooling focus and a distinct aesthetic identity.

## Migrating an existing omarchy install

If you already have omarchy installed at `~/.local/share/omarchy/` and want to switch the update system to Ryoku:

```bash
cd ~/.local/share/omarchy
git diff --quiet && git diff --cached --quiet || { echo "dirty tree, commit or stash first"; exit 1; }
git remote set-url origin https://github.com/neur0map/ryoku-arch.git
git fetch origin --tags --prune
git checkout -b main --track origin/main
git branch -D master
```

Subsequent `omarchy-update` runs pull from Ryoku Arch.

## License

MIT. See `LICENSE` for the full text and both the Ryoku and original omarchy copyright notices. See `NOTICE` for upstream attribution.
```

Verify with:
```bash
head -3 /home/omi/prowl/ryoku-arch/README.md
```
Expected first three lines:
```
# Ryoku Arch

力と美のために: For the sake of power and beauty.
```

- [ ] **Step 5.2: Amend `LICENSE`**

The current LICENSE first line is `Copyright (c) David Heinemeier Hansson`. Prepend a new Ryoku copyright line above it so the file reads:

```
Copyright (c) 2026 Carlos Mejia (neur0map)
Copyright (c) David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
...
```

Use:
```bash
cd /home/omi/prowl/ryoku-arch
sed -i '1i Copyright (c) 2026 Carlos Mejia (neur0map)' LICENSE
head -3 LICENSE
```
Expected output:
```
Copyright (c) 2026 Carlos Mejia (neur0map)
Copyright (c) David Heinemeier Hansson

```
(The third line is blank; that is the existing blank line between the copyright block and the permission paragraph.)

- [ ] **Step 5.3: Create `NOTICE`**

Write `/home/omi/prowl/ryoku-arch/NOTICE` with:

```
Ryoku Arch

This project is derived from Omarchy, created by David Heinemeier Hansson
and contributors. The original project is available at:

  https://github.com/basecamp/omarchy

The MIT License and original copyright notice are preserved in the
LICENSE file in this repository. Ryoku Arch additions are also released
under the MIT License.
```

Verify:
```bash
wc -l /home/omi/prowl/ryoku-arch/NOTICE
```
Expected: `10 /home/omi/prowl/ryoku-arch/NOTICE` (or similar, depending on trailing newline handling).

- [ ] **Step 5.4: Create `.gitignore`**

There is no existing `.gitignore` in the tree. Create `/home/omi/prowl/ryoku-arch/.gitignore` with:

```
# Ryoku Arch: developer-local session notes.
# Individual session logs stay out of the repo; only the README and
# TEMPLATE ship.
/logs/*.md
!/logs/README.md
!/logs/TEMPLATE.md
```

Verify:
```bash
cat /home/omi/prowl/ryoku-arch/.gitignore
```
Expected: the content above, exactly.

- [ ] **Step 5.5: Create `docs/README.md`**

Write `/home/omi/prowl/ryoku-arch/docs/README.md`:

```markdown
# Documentation

Developer-facing documentation for Ryoku Arch.

## Contents

- `vision.md`: project goals, audience, and non-goals in long form.
- `rebrand-inventory.md`: catalog of every `omarchy` reference still in the tree, categorized by the kind of change each needs.
- `specs/`: design specs. One file per change, dated `YYYY-MM-DD-*.md`.
- `plans/`: step-by-step implementation plans produced from specs.

Specs precede plans precede code. Every non-trivial change leaves a spec in `specs/` and a plan in `plans/` behind.
```

- [ ] **Step 5.6: Create `docs/vision.md`**

Write `/home/omi/prowl/ryoku-arch/docs/vision.md`:

```markdown
# Ryoku Arch: Vision

## Name

Ryoku (力) means "power" or "strength" in Japanese. Ryoku Arch combines that word with its Linux distribution base to signal the project's two anchors: strength in the form of security tooling, and a considered aesthetic.

## Tagline

力と美のために: For the sake of power and beauty.

## What it is

An opinionated Arch Linux distribution that layers a curated cybersecurity toolset on top of a ricing-focused desktop. Built from omarchy as a starting point so the install framework, theme system, and update mechanism come pre-built.

## Who it is for

People studying or working in cybersecurity who also care about how their machine looks and feels.

## What distinguishes it

- A curated set of security tools (from the BlackArch repository and beyond), opinionated about which are included by default.
- A ricing baseline inherited from omarchy (Hyprland, Waybar, keybindings, themes) with Ryoku-specific defaults layered on top.
- A Japanese minimalism aesthetic for branding and theme work.

## What it is not

- A general-purpose desktop distribution.
- A fork of BlackArch. Ryoku Arch starts from omarchy and pulls security tooling in, rather than starting from a security-focused distribution and adding ricing.
- A drop-in replacement for omarchy. Paths, command names, and install flow match omarchy's during the bootstrap phase; they will diverge over time.

## Roadmap

This document is load-bearing across multiple specs. The initial scaffolding spec (`docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md`) only sets up the repo and the dev loop. Follow-on specs cover, in rough priority order:

1. Command and path rename: `omarchy-*` to `ryoku-*`.
2. Installer migration: `boot.sh` defaults, pacman mirror configuration.
3. Security tooling curation and integration.
4. Brand assets: logo, icons, boot splash, theme defaults.
5. Japanese localization review.
```

- [ ] **Step 5.7: Generate the rebrand inventory raw data**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
rg -n 'omarchy' --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' > /tmp/ryoku-refs.txt
wc -l /tmp/ryoku-refs.txt
head -5 /tmp/ryoku-refs.txt
```
Expected: several thousand lines, with paths like `bin/omarchy-...`, `config/...`, `install/...`, `AGENTS.md`, `README.md`. The docs/specs/ and docs/plans/ paths are excluded because they discuss omarchy by name on purpose (not rename targets).

The raw output stays at `/tmp/ryoku-refs.txt`. The inventory document cites this as the generation source without embedding every line.

- [ ] **Step 5.8: Create `docs/rebrand-inventory.md`**

Write `/home/omi/prowl/ryoku-arch/docs/rebrand-inventory.md`:

```markdown
# Rebrand Inventory

## Purpose

Exhaustive catalog of omarchy references in this repository. Each entry states what the reference is, where it lives, and what the Ryoku-state equivalent should be. This document is consumed by follow-on specs (rename pass, installer migration) to make sure nothing is missed.

## Generation

Raw reference list produced by:

```
rg -n 'omarchy' --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*'
```

Re-run the command above to regenerate the raw list. `docs/specs/` and `docs/plans/` are excluded because they discuss omarchy by name on purpose; those references do not need to change.

## Categories

Every reference falls into one of five categories.

### Category 1: MUST change (functional)

Command names, package names, install paths, user-visible strings. Changing these is the core work of the rename pass.

- `bin/omarchy-*` command names (all ~200 scripts)
- `$OMARCHY_PATH` runtime path references
- `~/.local/share/omarchy/` hardcoded paths in install scripts
- `~/.local/state/omarchy/` state directory references
- User-visible strings in scripts ("Update Omarchy", log messages)

### Category 2: MUST NOT change (legal and attribution)

Attribution that has to remain verbatim for legal or historical reasons.

- `LICENSE`: `Copyright (c) David Heinemeier Hansson` line (preserved; Ryoku copyright is prepended, not replaced).
- `NOTICE`: references to the omarchy project and DHH.
- Upstream commit messages and authorship (immutable git history).

### Category 3: SHOULD change (cosmetic and internal)

Internal identifiers and comments that are not user-visible but should be renamed for brand coherence.

- Environment variables: `$OMARCHY_PATH`, `$OMARCHY_REPO`, `$OMARCHY_REF`, `$OMARCHY_MIRROR`, `$OMARCHY_ONLINE_INSTALL`, `$OMARCHY_USER_NAME`, `$OMARCHY_USER_EMAIL`, `$OMARCHY_CHROOT_INSTALL`, `$OMARCHY_UPDATE_LOGGED`.
- Comments and log strings inside scripts.
- `AGENTS.md`: the entire document is omarchy-voiced; rewrite for Ryoku.

### Category 4: Brand assets (deferred)

Image and text assets that represent the brand. Handled in a dedicated brand-assets spec.

- `logo.svg`, `logo.txt`: upstream omarchy logo in SVG and ASCII form.
- `icon.png`, `icon.txt`: upstream omarchy icon.
- ANSI art banners inside scripts (for example, the banner in `boot.sh`).

### Category 5: Installer defaults and infrastructure (deferred)

Install-time defaults and references to omarchy-operated infrastructure. Handled in a dedicated installer-migration spec. The user's machine is already installed, so these do not block the current dev loop.

- `boot.sh`: `OMARCHY_REPO="${OMARCHY_REPO:-basecamp/omarchy}"` default.
- `boot.sh`: `OMARCHY_REF="${OMARCHY_REF:-master}"` default.
- `boot.sh`: pacman mirror URLs `stable-mirror.omarchy.org`, `mirror.omarchy.org`, `rc-mirror.omarchy.org`.
- `.github/` workflow files (not yet audited; may reference the repo URL or omarchy-specific conventions).

## Raw inventory

Run the `rg` command in the Generation section to produce the raw list. At the time of scaffolding the output contained several thousand lines across bin/, config/, install/, default/, migrations/, themes/, AGENTS.md, and a handful of other locations. The raw list is not embedded here because it changes every time upstream is pulled; regenerate on demand.

For per-directory summaries, the following commands are useful:

```
rg -l 'omarchy' --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' | sort | uniq -c | sort -rn
rg -c 'omarchy' bin/ | sort -t: -k2 -n -r | head -20
```

## Status checklist

- [ ] Raw grep done (initial, at scaffolding)
- [ ] Categorized (categories above are final; line-level categorization happens in the rename pass)
- [ ] Command rename pass executed (Category 1 and 3 commands in `bin/`)
- [ ] Install-path rename pass executed (Category 1 path references)
- [ ] Installer migration pass executed (Category 5)
- [ ] Brand assets pass executed (Category 4)
- [ ] Verified end-to-end install still works post-rename
```

- [ ] **Step 5.9: Create `logs/README.md`**

Write `/home/omi/prowl/ryoku-arch/logs/README.md`:

```markdown
# Session Logs

Per-session handoff notes. One file per working session. Individual session files are gitignored; only `README.md` and `TEMPLATE.md` ship in the repo.

## Why

Ryoku Arch work moves across different sessions, sometimes across different working environments. A structured log per session lets the next session orient itself in under a minute: what was changed, what was verified, what the next step is.

## Naming

`YYYY-MM-DD-session-NN.md`, where `NN` is zero-padded (`01`, `02`, `03`). Local date. If a session crosses midnight, use the date the session started.

## Status vocabulary

- `in-progress`: the session is active. Update the log as you go.
- `handed-off`: the session paused mid-task. The `Next:` field names the concrete next action for the following session.
- `done`: closed, no follow-up needed.

## Reading order

New sessions read the latest log first. Older logs are historical context, not active state.

## Format

Copy `TEMPLATE.md` to a new file when starting a session. The template contains the expected fields and section headings.
```

- [ ] **Step 5.10: Create `logs/TEMPLATE.md`**

Write `/home/omi/prowl/ryoku-arch/logs/TEMPLATE.md`:

```markdown
# YYYY-MM-DD, Session NN
status: in-progress | handed-off | done

**Scope:** one-line description of what this session tried to accomplish

**Changed:**
- path/to/file.ext: one-line what changed

**Summary of changes:**
- *Visual:* what an end user would see or notice on the desktop
- *Code:* what actually changed in files, structure, or behavior

**Verified:**
- command or action run, observed result

**Next:**
- the concrete thing the next session should pick up

**Open issues / decisions pending:**
- item and why it is blocked or undecided

**Notes:** (optional) rationale, surprises, references
```

- [ ] **Step 5.11: (skipped)** A `logs/.gitkeep` file was initially planned but dropped during code review: it is redundant because `logs/README.md` and `logs/TEMPLATE.md` are both tracked and already keep the directory in git.

- [ ] **Step 5.12: Amend the spec's deliverables table to include the plan file**

The spec's deliverables table (in `docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md`) currently lists 11 files. Add one row so it also lists the plan file. Find the row:

```
| `docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md` | new | This document |
```

Insert immediately after it:

```
| `docs/plans/2026-04-22-ryoku-arch-scaffolding-plan.md` | new | Implementation plan produced from this spec |
```

Verify with:
```bash
grep -n 'docs/plans/2026-04-22' /home/omi/prowl/ryoku-arch/docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md
```
Expected: at least one match line showing the new table row.

Also find the spec's `.gitignore` action row (`| `.gitignore` | amend | ...`) and change `amend` to `new`, since there is no pre-existing `.gitignore` in the tree.

Verify:
```bash
grep '`.gitignore`' /home/omi/prowl/ryoku-arch/docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md
```
Expected: one line showing `| `.gitignore` | new | ...`.

- [ ] **Step 5.13: Confirm all scaffolding files exist**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
ls -la README.md LICENSE NOTICE .gitignore \
       docs/README.md docs/vision.md docs/rebrand-inventory.md \
       docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md \
       docs/plans/2026-04-22-ryoku-arch-scaffolding-plan.md \
       logs/README.md logs/TEMPLATE.md
```
Expected: all 11 paths listed with sizes, no errors.

**Rollback note for Task 5:** every file created here is `rm`-able; every file modified here has its pre-modification state available via `git show HEAD:<path>` (the tree has not been committed yet). Run `git checkout -- README.md LICENSE` to revert the two modified files; run `rm` for the new files.

---

## Task 6: Scaffolding commit

**Files:** stages and commits all 11 files from Task 5.

- [ ] **Step 6.1: Stage each file explicitly by name**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git add README.md LICENSE NOTICE .gitignore \
        docs/README.md docs/vision.md docs/rebrand-inventory.md \
        docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md \
        docs/plans/2026-04-22-ryoku-arch-scaffolding-plan.md \
        logs/README.md logs/TEMPLATE.md
git status -s
```
Expected `git status -s` output:
```
M  README.md
M  LICENSE
M  docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md
A  NOTICE
A  .gitignore
A  docs/README.md
A  docs/vision.md
A  docs/rebrand-inventory.md
A  docs/plans/2026-04-22-ryoku-arch-scaffolding-plan.md
A  logs/README.md
A  logs/TEMPLATE.md
```
(Order may vary; the point is exactly those 11 paths, with `M` for modified and `A` for added, and no other files.)

Never use `git add .` or `git add -A`. Staging by name is a safety guarantee.

- [ ] **Step 6.2: Create the scaffolding commit**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git commit -m "scaffold: Ryoku Arch repo structure" -m "Adds README, LICENSE amendment, NOTICE, docs/, logs/, .gitignore rules, and a rebrand inventory. No functional changes: all omarchy-* commands, configs, and install scripts are untouched."
```
Expected: git prints `[main <sha>] scaffold: Ryoku Arch repo structure` and a summary of files changed.

- [ ] **Step 6.3: Verify commit has no `Co-Authored-By` trailer**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git log -1 --format='%B' | grep -iE 'co-authored|claude|anthropic|assistant' || echo "clean: no forbidden trailers"
```
Expected: `clean: no forbidden trailers`. If any of those strings appear, run `git commit --amend` to rewrite the message (still without Co-Authored-By), then re-verify.

- [ ] **Step 6.4: Verify commit author is the user, not an AI attribution**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git log -1 --format='%an <%ae>'
```
Expected: your actual name and email, as configured in `git config user.name` / `user.email`. If the author looks wrong (for example, contains "Claude" or "AI"), stop and fix git config before continuing. Do not proceed with a wrong-author commit at the tip.

**Rollback note for Task 6:** `git reset HEAD~1` uncommits (keeps working tree). `git reset --hard HEAD~1` uncommits and discards changes (destructive, avoid).

---

## Task 7: Push to GitHub

**Files:** none local. Publishes the local state.

- [ ] **Step 7.1: Push `main` to the new origin**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git push -u origin main
```
Expected: progress output showing thousands of objects transferred (all of upstream omarchy history, first time). Last line reads something like `* [new branch] main -> main` and `Branch 'main' set up to track remote branch 'main' from 'origin'.`.

- [ ] **Step 7.2: Push the `upstream-baseline` tag**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git push origin upstream-baseline
```
Expected: last line reads `* [new tag] upstream-baseline -> upstream-baseline`.

- [ ] **Step 7.3: Confirm GitHub sees both `main` and the tag**

Run:
```bash
gh api repos/neur0map/ryoku-arch/commits/main --jq .sha
gh api repos/neur0map/ryoku-arch/git/refs/tags/upstream-baseline --jq .object.sha
```
Expected: first command prints the scaffolding commit SHA. Second command prints the pre-scaffold (upstream-baseline) SHA, which matches Step 1.2's full SHA.

**Rollback note for Task 7:**
- Unpush `main`: `git push origin --delete main` (destructive; only the first push is fully recoverable by re-pushing).
- Unpush tag: `git push origin :refs/tags/upstream-baseline`.

---

## Task 8: Verification

**Files:** none modified. Read-only checks.

- [ ] **Step 8.1: Log and tag state**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git log --oneline -5 origin/main
git show-ref upstream-baseline
```
Expected: top line of the log is the `scaffold: Ryoku Arch repo structure` commit. Subsequent lines are upstream omarchy commits. Tag resolves to the pre-scaffold SHA.

- [ ] **Step 8.2: Upstream remote reachable**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git fetch upstream
git log upstream/dev -1 --oneline
```
Expected: no errors, one line printed identifying the current upstream tip.

- [ ] **Step 8.3: Install-entry scripts parse cleanly**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
bash -n install.sh && echo "install.sh: OK"
bash -n boot.sh && echo "boot.sh: OK"
```
Expected:
```
install.sh: OK
boot.sh: OK
```
Neither command executes the script; `-n` is syntax check only.

- [ ] **Step 8.4: All bash scripts in `bin/` parse cleanly**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
errors=""
for f in bin/omarchy-*; do
  if head -n1 "$f" 2>/dev/null | grep -q '^#!/bin/bash'; then
    if ! bash -n "$f" 2>/dev/null; then
      errors="${errors}${f}\n"
    fi
  fi
done
if [[ -z "$errors" ]]; then
  echo "all bash scripts in bin/ parse cleanly"
else
  echo "FAILURES:"
  printf "$errors"
fi
```
Expected: `all bash scripts in bin/ parse cleanly`. If any failures print, investigate each; these are pre-existing bugs in the files (the scaffolding did not change them) but should be flagged in a session log.

- [ ] **Step 8.5: GitHub-side render check (manual)**

Open in a browser:
- `https://github.com/neur0map/ryoku-arch`: confirm README renders with the bilingual tagline and the pre-alpha notice.
- `https://github.com/neur0map/ryoku-arch/blob/main/LICENSE`: confirm both copyright lines are present.
- `https://github.com/neur0map/ryoku-arch/blob/main/NOTICE`: confirm the file renders.
- `https://github.com/neur0map/ryoku-arch/tags`: confirm `upstream-baseline` is listed.

Record any rendering issues in the session log.

**Rollback note for Task 8:** no state changes; nothing to roll back.

---

## Task 9: Live clone migration (DESTRUCTIVE GATE)

**Files:** modifies state of `~/.local/share/omarchy/` (the live install clone). Does not rename the folder; only changes git remote and branch.

- [ ] **Step 9.1: Verify live clone is clean**

Run:
```bash
cd ~/.local/share/omarchy
git diff --quiet && git diff --cached --quiet && echo "clean" || echo "DIRTY"
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git remote -v
```
Expected:
- `clean`.
- Branch: `master`.
- HEAD SHA: `236a34b2` (or whatever the current master tip is; this is a read, not a check).
- Remote: `origin https://github.com/basecamp/omarchy.git`.

If dirty, stop. The user must commit or stash before migration.

- [ ] **Step 9.2: Prompt user to confirm the branch swap**

Show the user:

> About to switch `~/.local/share/omarchy/` from `basecamp/omarchy master` to `neur0map/ryoku-arch main`. This pulls upstream dev tip plus the Ryoku scaffolding commit onto the live system. Omarchy's migration framework handles the delta; however, the live clone is what your running system reads from, so any regression here is visible immediately. Confirm?

Do not execute Step 9.3 without explicit approval.

- [ ] **Step 9.3: Snapshot first for rollback safety**

If `omarchy-snapshot` is available:
```bash
omarchy-snapshot create
```
If the command is not on PATH (exit code 127), skip silently; the spec's risks section called this out. Record in the session log which case applied.

- [ ] **Step 9.4: Repoint `origin`**

Run:
```bash
cd ~/.local/share/omarchy
git remote set-url origin https://github.com/neur0map/ryoku-arch.git
git remote -v
```
Expected:
```
origin  https://github.com/neur0map/ryoku-arch.git (fetch)
origin  https://github.com/neur0map/ryoku-arch.git (push)
```

- [ ] **Step 9.5: Fetch from the new origin**

Run:
```bash
cd ~/.local/share/omarchy
git fetch origin --tags --prune
```
Expected: progress output showing new objects transferred. Post-fetch, `git branch -r` includes `origin/main`.

Verify:
```bash
git branch -r | grep origin/main
git show-ref upstream-baseline
```
Expected: `origin/main` listed. `upstream-baseline` tag present.

- [ ] **Step 9.6: Switch to `main` tracking origin/main**

Run:
```bash
cd ~/.local/share/omarchy
git checkout -b main --track origin/main
git branch -vv
```
Expected: current branch is `main`, tracking `origin/main`. Local `master` still listed but not current.

This step is the actual source-of-truth swap. The working tree now reflects omarchy-dev-tip plus Ryoku scaffolding, which is different from what was on `master`. Omarchy's migration framework handles file-level reconciliation on next `omarchy-update` (or already, depending on how configs are consumed).

- [ ] **Step 9.7: Delete the now-stale `master` branch**

Run:
```bash
cd ~/.local/share/omarchy
git branch -D master
git branch -vv
```
Expected: only `main` remains, still tracking `origin/main`.

**Rollback note for Task 9:**
- Pre-Step 9.4 state: rerun the `git remote set-url` with the old URL `https://github.com/basecamp/omarchy.git` to point origin back at upstream omarchy.
- Pre-Step 9.6 state: `git checkout master && git branch -D main` returns the live clone to master.
- Pre-Step 9.3 snapshot: use `omarchy-snapshot restore` (or the user's preferred snapshot tool) to restore the system.
- A full rollback returns the live clone to its Step 9.1 verified state.

---

## Task 10: End-to-end update-loop test

**Files:** a single trivial edit to `README.md` that is pushed, pulled, and then reverted.

- [ ] **Step 10.1: Make a trivial edit in the dev folder**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
printf "\n<!-- update-loop probe: %s -->\n" "$(date -u +%Y%m%dT%H%M%SZ)" >> README.md
tail -2 README.md
```
Expected: the trailing HTML comment is visible.

- [ ] **Step 10.2: Commit and push the probe**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git add README.md
git commit -m "test: update-loop probe"
git push origin main
```
Expected: push succeeds; `git log -1 --oneline` shows the probe commit.

- [ ] **Step 10.3: Pull on the live clone**

Run:
```bash
cd ~/.local/share/omarchy
git pull --autostash
tail -2 README.md
```
Expected: the same trailing HTML comment is present.

- [ ] **Step 10.4: Revert the probe in the dev folder and push**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git revert --no-edit HEAD
git log --oneline -3
git push origin main
```
Expected: the most recent commit is `Revert "test: update-loop probe"`. The probe and its revert are both pushed; the revert is the cleaner signal in history than a force-push.

- [ ] **Step 10.5: Pull on the live clone again**

Run:
```bash
cd ~/.local/share/omarchy
git pull --autostash
tail -2 README.md
```
Expected: the probe comment is no longer at the tail of `README.md`. The dev loop is confirmed end to end.

**Rollback note for Task 10:** the probe commit and its revert both remain in history. They are harmless (no functional impact). If cleanup is desired, a future commit can amend README to remove the probe traces entirely.

---

## Task 11: First session log

**Files:**
- Create: `/home/omi/prowl/ryoku-arch/logs/2026-04-22-session-01.md` (gitignored; do not commit).

- [ ] **Step 11.1: Copy the template**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
cp logs/TEMPLATE.md logs/2026-04-22-session-01.md
```

- [ ] **Step 11.2: Populate the log**

Overwrite `/home/omi/prowl/ryoku-arch/logs/2026-04-22-session-01.md` with:

```markdown
# 2026-04-22, Session 01
status: done

**Scope:** Bootstrap the Ryoku Arch repository from the omarchy codebase. Establish the dev loop so edits in `/home/omi/prowl/ryoku-arch/` reach the live system at `~/.local/share/omarchy/` via push + `omarchy-update`.

**Changed:**
- `README.md`: rewrote for Ryoku Arch; added migration instructions for omarchy users.
- `LICENSE`: prepended Ryoku copyright line above DHH's; MIT body preserved.
- `NOTICE`: new; credits omarchy as upstream.
- `.gitignore`: new; ignores session log files while keeping README and TEMPLATE.
- `docs/README.md`, `docs/vision.md`, `docs/rebrand-inventory.md`: new; developer documentation.
- `docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md`, `docs/plans/2026-04-22-ryoku-arch-scaffolding-plan.md`: new; design and plan for this pass.
- `logs/README.md`, `logs/TEMPLATE.md`: new; session log scaffolding.

**Summary of changes:**
- *Visual:* no desktop-facing changes. On GitHub, the repo page now renders the Ryoku Arch README with the bilingual tagline; the LICENSE shows both copyright lines; the NOTICE file is present; the `upstream-baseline` tag is visible on the tags page.
- *Code:* no functional changes. All `omarchy-*` commands, configs, install scripts, and migration scripts are unchanged. The only changes in committed code are documentation and branding.

**Verified:**
- `git log --oneline origin/main` shows the `scaffold:` commit atop upstream omarchy history.
- `git show-ref upstream-baseline` resolves to the pre-scaffold SHA.
- `bash -n install.sh && bash -n boot.sh`: both pass.
- All `bin/omarchy-*` bash scripts parse cleanly.
- Update-loop probe: a trivial README edit pushed from the dev folder appeared on the live clone after `git pull`, then was reverted cleanly.

**Next:**
- Brainstorm the command-rename spec (`omarchy-*` → `ryoku-*`). Inventory is in `docs/rebrand-inventory.md`. Start with Category 1 (functional commands in `bin/`).

**Open issues / decisions pending:**
- Japanese tagline "力と美のために" is a provisional translation. Native-speaker review queued for a later pass (not blocking).
- `boot.sh` defaults still point at `basecamp/omarchy` and `master`. Pacman mirrors still point at `stable-mirror.omarchy.org`. Deferred to the installer-migration spec (Category 5 in the rebrand inventory). Does not block the dev loop because the live install already exists.
- `.github/` workflows are unaudited; may reference `omarchy` or the old repo URL. Flagged for follow-up.

**Notes:** the session was scoped tightly to scaffolding. No functional changes, no tool installs, no theme work. The next session should pick up command rename or installer migration, depending on priority.
```

- [ ] **Step 11.3: Verify the session log is NOT tracked by git**

Run:
```bash
cd /home/omi/prowl/ryoku-arch
git status -s logs/
```
Expected: empty output (the `.gitignore` rule from Step 5.4 excludes all `logs/*.md` except `README.md` and `TEMPLATE.md`).

If the file shows up as untracked in git status, the .gitignore is wrong; debug before continuing.

**Rollback note for Task 11:** `rm /home/omi/prowl/ryoku-arch/logs/2026-04-22-session-01.md` removes the log. No commit or remote state involved.

---

## Done criteria

All of the following are true:

- `neur0map/project-i-a-m` returns 404 on GitHub.
- `neur0map/ryoku-arch` exists with branch `main` containing upstream omarchy history plus one `scaffold:` commit (plus the Task 10 probe and revert commits, which are benign).
- `upstream-baseline` tag is pushed and visible on GitHub.
- `/home/omi/prowl/ryoku-arch/` is the only working clone; `/home/omi/prowl/project-i-a-m/` is gone.
- `git remote -v` in the working folder shows `origin = ryoku-arch` and `upstream = basecamp/omarchy`.
- `~/.local/share/omarchy/` origin points at ryoku-arch, branch is `main` tracking `origin/main`, `master` is deleted.
- `bash -n install.sh && bash -n boot.sh` both return clean.
- Task 10 end-to-end probe succeeded: edit → push → pull on live clone → change visible.
- `logs/2026-04-22-session-01.md` exists locally and is gitignored.
- `docs/rebrand-inventory.md` is committed and populated with the category framework plus generation instructions.

## Out-of-scope reminders

- No `omarchy-*` command was renamed to `ryoku-*` in this plan. That is a separate spec.
- No change to `boot.sh` defaults or pacman mirrors. Separate installer-migration spec.
- No cybersecurity tooling was installed, curated, or integrated. Separate spec.
- No logo, icon, or brand-asset changes. Separate brand-assets spec.
- No `.github/` workflow audit. Flagged in rebrand inventory.
