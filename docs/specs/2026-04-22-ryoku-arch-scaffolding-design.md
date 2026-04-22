# Ryoku Arch: Repo Scaffolding Design

**Date:** 2026-04-22
**Status:** Draft, pending implementation plan
**Owner:** Carlos Mejia (neur0map)

## Purpose

Bootstrap the Ryoku Arch repository from the upstream omarchy codebase as a clean fork that preserves upstream history. This spec covers repository scaffolding only: rename, relocation, branding surface, documentation structure, session-log conventions, and a minimal migration of the live clone's git remote so the update loop (`omarchy-update`) begins pulling from the Ryoku repo. It does not cover command rebranding, cybersecurity tooling, theme work, install-flow edits, or pacman mirror changes. Those are follow-on specs.

## Context

Ryoku Arch (力, ryoku, "power/strength") is an opinionated Arch Linux distribution derived from omarchy. Its distinguishing focus is the combination of desktop ricing and BlackArch-style cybersecurity tooling, aimed at people studying or working in security who also care about how their machine looks. Tagline: "力と美のために: For the sake of power and beauty" (bilingual, Japanese and English).

The pre-existing `neur0map/project-i-a-m` repository contained an earlier attempt at this idea with divergent design. Its contents are discarded in full, and the clean baseline starts from omarchy.

The user already has omarchy installed on their machine. The live install lives at `~/.local/share/omarchy/`, currently on branch `master` tracking `basecamp/omarchy`. The goal of this spec is to make the dev loop (edit → push → `omarchy-update` → live change) work end to end against the new Ryoku repo.

## Scope

**In scope:**

- Delete the existing `neur0map/project-i-a-m` GitHub repository and create a fresh `neur0map/ryoku-arch` repo in its place.
- Rename the local working clone `/home/omi/prowl/omarchy/` to `/home/omi/prowl/ryoku-arch/` and reconfigure its git remotes (`origin` to Ryoku, `upstream` to basecamp/omarchy).
- Push upstream omarchy history intact as the base of `main`. Tag the upstream tip before our changes so "diff against baseline" is one command. Add one Ryoku-authored scaffolding commit on top.
- Introduce a `docs/` tree (committed) and a `logs/` tree (structure committed, individual session files gitignored).
- Produce a rebrand inventory document cataloging every `omarchy` reference in the tree, for use by follow-on rename and installer specs.
- Amend `LICENSE` to add a Ryoku copyright line while preserving DHH's original MIT notice. Add a `NOTICE` file documenting upstream lineage.
- Migrate the live clone at `~/.local/share/omarchy/` so its `origin` points at `neur0map/ryoku-arch` and it tracks our new `main` branch. After this step, `omarchy-update` on the user's machine pulls Ryoku changes.

**Out of scope (future specs):**

- Renaming any `omarchy-*` command to `ryoku-*`. No file under `bin/`, `config/`, `install/`, `themes/`, `applications/`, `migrations/`, or `default/` is modified.
- Editing `boot.sh`. The install-flow defaults (`OMARCHY_REPO=basecamp/omarchy`, `OMARCHY_REF=master`) and pacman mirror URLs (`stable-mirror.omarchy.org`, etc.) stay untouched. Flagged in the rebrand inventory under "installer defaults" for a later spec. The user's machine is already installed, so this does not block the update loop.
- Installing, curating, or integrating any cybersecurity tooling.
- Replacing logos, icons, or theme assets.
- Changes to install behavior, default app selection, migration framework, or any existing subsystem.

## Deliverables

### Local filesystem

1. Rename `/home/omi/prowl/omarchy/` to `/home/omi/prowl/ryoku-arch/`.
2. Delete the stale sibling `/home/omi/prowl/project-i-a-m/` after confirming its tree is clean and contains no uncommitted work.

### GitHub

3. Delete `neur0map/project-i-a-m` via `gh repo delete`.
4. Create `neur0map/ryoku-arch` via `gh repo create`: public, default branch `main`, description "Opinionated Arch Linux: rice + cybersecurity".

### Git configuration (in renamed folder)

5. `origin` points to `https://github.com/neur0map/ryoku-arch.git`.
6. `upstream` points to `https://github.com/basecamp/omarchy.git`.
7. Local branch renamed from `dev` to `main`.

### Commit history model

Upstream history from `basecamp/omarchy@dev` is preserved verbatim. No squash. Before the Ryoku scaffolding commit, tag the upstream tip locally as `upstream-baseline`. Push the tag alongside `main`. This gives a one-command way to see the delta between upstream and our work (`git diff upstream-baseline..main`), without losing DHH's commit-level authorship.

**Tag:** `upstream-baseline`, annotated, message `"omarchy <short-sha> at Ryoku Arch fork point"`.

**Ryoku scaffolding commit (single commit on top of upstream-baseline):**

Adds or modifies exactly the following files:

| Path | Action | Notes |
|---|---|---|
| `README.md` | rewrite | Ryoku Arch title, bilingual tagline ("力と美のために: For the sake of power and beauty"), one-paragraph vision (arch rice + cybersecurity), pre-alpha status notice, credit to the omarchy project by DHH |
| `LICENSE` | amend | Prepend a new line `Copyright (c) 2026 Carlos Mejia (neur0map)` above the existing `Copyright (c) ... DHH ...` line. Do not modify MIT body text. Both copyright lines live in the same file. |
| `NOTICE` | new | One-paragraph attribution: this project is derived from omarchy by DHH, MIT license preserved in LICENSE |
| `.gitignore` | new | Ignore session log files but keep `logs/README.md` and `logs/TEMPLATE.md` |
| `docs/README.md` | new | Index of the docs/ tree |
| `docs/vision.md` | new | Long-form Ryoku vision (cybersec + ricing, audience, non-goals) |
| `docs/rebrand-inventory.md` | new | Categorized catalog of every `omarchy` reference |
| `docs/specs/2026-04-22-ryoku-arch-scaffolding-design.md` | new | This document |
| `docs/plans/2026-04-22-ryoku-arch-scaffolding-plan.md` | new | Implementation plan produced from this spec |
| `logs/README.md` | new | Explains session-log format, naming, status vocabulary |
| `logs/TEMPLATE.md` | new | Copy-to-start-a-session template |

Commit message (title + body):

```
scaffold: Ryoku Arch repo structure

Adds README, LICENSE amendment, NOTICE, docs/, logs/, .gitignore rules,
and a rebrand inventory. No functional changes: all omarchy-* commands,
configs, and install scripts are untouched.
```

Commit uses plain `git commit` with title and body as two `-m` flags. No trailer block, no `Co-Authored-By`.

### Explicitly unchanged

No file under `bin/`, `config/`, `install/`, `themes/`, `applications/`, `migrations/`, `default/`, or `.github/` is modified. `AGENTS.md`, `boot.sh`, `install.sh`, `version`, `icon.png`, `icon.txt`, `logo.svg`, `logo.txt`, and `.editorconfig` are preserved verbatim.

## Directory structure (post-scaffolding)

```
ryoku-arch/
├── .editorconfig
├── .github/
├── .gitignore                       (amended)
├── AGENTS.md
├── LICENSE                          (amended)
├── NOTICE                           (new)
├── README.md                        (rewritten)
├── applications/
├── bin/
├── boot.sh
├── config/
├── default/
├── docs/                            (new)
│   ├── README.md
│   ├── vision.md
│   ├── rebrand-inventory.md
│   └── specs/
│       └── 2026-04-22-ryoku-arch-scaffolding-design.md
├── icon.png
├── icon.txt
├── install.sh
├── install/
├── logo.svg
├── logo.txt
├── logs/                            (new)
│   ├── README.md
│   └── TEMPLATE.md
├── migrations/
├── themes/
└── version
```

## Rebrand inventory document structure

File: `docs/rebrand-inventory.md`. Sections:

1. **Purpose.** One paragraph on why this document exists and how it is consumed.
2. **Categories.**
   - Category 1, MUST change (functional): command names, package names, install paths, user-visible strings.
   - Category 2, MUST NOT change (legal/attribution): DHH's copyright line in `LICENSE`, verbatim attribution in `NOTICE`, upstream commit messages.
   - Category 3, SHOULD change (cosmetic/internal): environment variables such as `$OMARCHY_PATH`, internal comments, log strings.
   - Category 4, Brand assets (deferred): `logo.svg`, `logo.txt`, `icon.png`, `icon.txt`.
   - Category 5, Installer defaults and infrastructure (deferred): `boot.sh` defaults `OMARCHY_REPO` and `OMARCHY_REF`, pacman mirror URLs `stable-mirror.omarchy.org` / `mirror.omarchy.org` / `rc-mirror.omarchy.org`, `.github/` workflow references.
3. **Category lists.** Bulleted lists of reference patterns per category. The raw line-level list is not embedded (regenerate on demand via the command in the Generation section); the document is a categorization plan, not a snapshot of the grep output.
4. **Generation method.** `rg -n 'omarchy' --hidden --glob '!.git/*'` plus manual categorization.
5. **Status checklist.** Raw grep done / categorized / rename pass executed / installer pass executed / verified.

At scaffolding time the raw grep output populates the tables. Categorization and target names are finalized in the later rename pass, not here.

## Session log template

File: `logs/TEMPLATE.md` (committed). New sessions copy to `logs/YYYY-MM-DD-session-NN.md` (gitignored).

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

`logs/README.md` documents:

- Naming pattern `YYYY-MM-DD-session-NN.md` with zero-padded `NN` (e.g., `01`, `02`). Local date.
- Status vocabulary: `in-progress` (actively being worked), `handed-off` (paused mid-task for continuation), `done` (closed, no follow-up).
- Why session files are gitignored: they are working memory, not release artifacts.
- Golden rule: a new session reads the latest log first; older logs are historical context.

## Update system migration (live clone)

Independent of the repo scaffolding, the user's installed copy at `~/.local/share/omarchy/` must be repointed so `omarchy-update` pulls from the Ryoku repo.

**Current state (verified):** origin = `basecamp/omarchy`, branch = `master`, SHA `236a34b2`, clean tree.

**Target state:** origin = `neur0map/ryoku-arch`, branch = `main` tracking `origin/main`.

**Migration steps (to run on the user's machine, after the Ryoku repo has been pushed):**

```bash
cd ~/.local/share/omarchy

# Safety: bail out if there are local modifications.
git diff --quiet && git diff --cached --quiet || { echo "dirty tree, abort"; exit 1; }

# Repoint origin.
git remote set-url origin https://github.com/neur0map/ryoku-arch.git

# Fetch new history.
git fetch origin --tags --prune

# Switch from master to main. This pulls down whatever delta exists between
# omarchy master and Ryoku main (upstream dev-tip + scaffolding commit).
git checkout -b main --track origin/main

# Optional: remove the now-stale master branch.
git branch -D master
```

**First update on the live clone:** because ryoku-arch's `main` is based on omarchy's `dev` tip plus one scaffold commit, the first `omarchy-update` (or the `git checkout -b main` above) brings the live system from omarchy-master to omarchy-dev plus Ryoku scaffolding. The existing omarchy migration framework (`omarchy-migrate` + `migrations/*.sh`) is designed to handle this kind of jump safely; user configs in `~/.config/` are not clobbered.

After migration, the dev loop works as follows:
- Edit in `/home/omi/prowl/ryoku-arch/`.
- Commit and push to `origin/main`.
- On the live system, run `omarchy-update` (or `git -C ~/.local/share/omarchy pull`) to apply.

The live clone retains all omarchy path names, environment variables (`$OMARCHY_PATH`), and command names (`omarchy-*`). Those stay until the dedicated rename spec runs.

## Execution sequence

**Phase 1, pre-flight.**

1. In `/home/omi/prowl/omarchy/`, confirm no uncommitted modifications to tracked files: `git diff --quiet && git diff --cached --quiet`. Untracked files under `docs/specs/` (this spec) are expected and allowed.
2. Record the local HEAD SHA: `git rev-parse HEAD`. Do **not** run `git fetch upstream` to refresh; baseline on the currently-cloned SHA to keep the reset deterministic. Save the short SHA for use in the tag message.
3. `gh auth status` confirms authenticated as user `neur0map` with repo + `delete_repo` scopes.
4. Confirm the repo slated for deletion is exactly `neur0map/project-i-a-m`.
5. In `/home/omi/prowl/project-i-a-m/`, confirm clean tree before deletion: `git status -s` returns empty. Abort and prompt the user if not.

**Phase 2, GitHub destruction and recreation.** Requires explicit user confirmation at execution.

6. `gh repo delete neur0map/project-i-a-m --yes`.
7. `gh repo create neur0map/ryoku-arch --public --description "Opinionated Arch Linux: rice + cybersecurity"`.
8. `gh repo view neur0map/ryoku-arch` confirms existence.

**Phase 3, local folder reshape.**

9. Rename `/home/omi/prowl/omarchy/` to `/home/omi/prowl/ryoku-arch/`.
10. `git remote rename origin upstream`, then `git remote add origin https://github.com/neur0map/ryoku-arch.git`.
11. `git branch -m dev main`.
12. `rm -rf /home/omi/prowl/project-i-a-m/`. Requires explicit user confirmation at execution.

**Phase 4, baseline tag.**

13. `git tag -a upstream-baseline -m "omarchy <short-sha> at Ryoku Arch fork point"` on current HEAD.

**Phase 5, Ryoku scaffolding commit.**

14. Write all new and modified files per the deliverables table.
15. Generate raw rebrand inventory: `rg -n 'omarchy' --hidden --glob '!.git/*' > /tmp/ryoku-refs.txt`, transform into `docs/rebrand-inventory.md` tables.
16. `git add` each file by name; do not use `git add .` or `git add -A`.
17. `git commit -m "scaffold: Ryoku Arch repo structure" -m "<body>"` using the body from the commit history model section above. No trailer block, no `Co-Authored-By`.

**Phase 6, push to GitHub.**

18. `git push -u origin main`.
19. `git push origin upstream-baseline` (push the tag).

**Phase 7, verification.**

20. `git log --oneline origin/main | head -5` shows the scaffolding commit as tip, on top of omarchy history.
21. `git show-ref upstream-baseline` exists and matches the pre-scaffolding SHA.
22. `git fetch upstream && git log upstream/dev -1` confirms upstream remote reachable.
23. Install-entry syntax check (safe, non-executing): `bash -n install.sh && bash -n boot.sh`.
24. Bash-script syntax check, scoped to bash-shebang files: `for f in bin/omarchy-*; do head -n1 "$f" 2>/dev/null | grep -q '^#!/bin/bash' && bash -n "$f" || true; done`. No error output.
25. On GitHub: the repo page renders README, LICENSE shows MIT with both copyright lines, NOTICE is present, `upstream-baseline` tag is visible.

**Phase 8, live clone migration.** Runs on the user's machine, not the dev folder.

26. Apply the migration steps from the "Update system migration" section above.
27. Validate: `git -C ~/.local/share/omarchy remote -v` shows ryoku-arch. `git -C ~/.local/share/omarchy log -1` shows the Ryoku scaffolding commit as HEAD.

**Phase 9, first session log.**

28. Create `logs/2026-04-22-session-01.md` locally (gitignored) using the template, marking this session `done` with a summary of the scaffolding work. Seeds the log workflow.

## Destructive-action gates

These operations require explicit user confirmation at implementation time, separate from design approval:

- Phase 2 step 6: `gh repo delete` (irreversible on GitHub).
- Phase 3 step 12: `rm -rf` on the stale local clone.
- Phase 8 step 26: the `git checkout -b main` step on the live clone (big delta from master to main on a running system).

Every other step is either reversible or confined to the local working tree.

## Verification criteria for "done"

- `neur0map/project-i-a-m` no longer exists on GitHub.
- `neur0map/ryoku-arch` exists and has upstream omarchy history plus one `scaffold:` commit on `main`, plus an `upstream-baseline` tag.
- `/home/omi/prowl/ryoku-arch/` is the only working clone; `/home/omi/prowl/project-i-a-m/` is gone.
- `git remote -v` in the working folder shows `origin` = ryoku-arch, `upstream` = basecamp/omarchy.
- `bash -n install.sh && bash -n boot.sh` both return cleanly.
- README on GitHub renders the Ryoku Arch description with bilingual tagline.
- LICENSE contains both the Ryoku copyright line and DHH's original MIT notice.
- `docs/rebrand-inventory.md` contains a populated raw inventory ready for follow-on passes.
- `~/.local/share/omarchy/` (the live clone) has origin pointing at ryoku-arch and HEAD matching the Ryoku scaffolding commit.
- A trivial test edit (for example, appending a blank line to `README.md`) pushed from the dev folder appears on the live clone after `omarchy-update` or `git pull`.

## Risks and open items

- **Live-clone migration delta.** The live system jumps from omarchy-master to omarchy-dev plus scaffolding in one `git checkout -b main`. Omarchy's migration framework (`migrations/*.sh`, `omarchy-migrate`) is intended to handle such jumps, but the size of the delta is larger than a normal update. Mitigation: run `omarchy-snapshot create` (if available) before migration so the user can roll back. Call this out in the Phase 8 step.
- **Japanese tagline.** "力と美のために" is a provisional translation of "For the sake of power and beauty." A native speaker review is not blocking for scaffolding but is listed as an open item in the first session log for a later pass.
- **Installer and pacman mirrors still point at omarchy.** `boot.sh` defaults and the mirror override are untouched. This is acceptable because the install flow is not part of this spec, and the user's machine is already installed. Documented in rebrand inventory Category 5.
- **`.github/` workflows** may reference `omarchy` or the old repo URL. They stay untouched in this pass but are flagged in the rebrand inventory.
- **Orphaned forks of `project-i-a-m`.** If anyone had forked the old repo, `gh repo delete` orphans those forks. Unlikely in practice given the repo's pre-existing scope; noted for completeness.

## Next steps

After this spec is approved, transition to the `writing-plans` skill to produce a concrete implementation plan with ordered, independently-verifiable steps.
