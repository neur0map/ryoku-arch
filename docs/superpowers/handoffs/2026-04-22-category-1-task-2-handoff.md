# Category 1 Rename Handoff

Date: `2026-04-22`

## Stop Point

- Worktree: `/home/omi/prowl/ryoku-arch/.worktrees/category1-rename`
- Branch: `category1-rename`
- Current HEAD: `788075f238108262c2b240f2bad8579dee729e01`
- Status: stop after Task 2
- Push status: nothing pushed

Category 1 execution is intentionally paused here.

- Task 1 is complete and review-clean in the current branch state.
- Task 2 is implemented but not accepted.
- Tasks 3-11 have not started.

Do not start Task 3 until Task 2 is patched and passes review.

## Read First

Open these files first when resuming:

- `docs/superpowers/specs/2026-04-22-category-1-rename-design.md`
- `docs/superpowers/plans/2026-04-22-category-1-rename-plan.md`
- `docs/superpowers/handoffs/2026-04-22-category-1-task-2-handoff.md`

Important plan-fix commits already applied on this branch:

- `9815384f` `docs: fix task 2 runtime contract dependency`
- `fc970e98` `docs: fix task 2 install compatibility bridge`

Task 2 must be judged against the patched plan, not the original text from `9bc1488d`.

## Task 2 Scope

Only these files need to be patched to finish Task 2:

- `lib/runtime-env.sh`
- `install.sh`
- `default/bash/envs`
- `config/uwsm/env`
- `bin/ryoku-version`

Current Task 2 commit:

- `788075f2` `refactor: add ryoku runtime path contract`

Spec review already passed for these five files.
Code-quality review did not pass.

## Open Findings

### 1. High: runtime helper resolves the installed tree instead of the current checkout

Files:

- `lib/runtime-env.sh:9`
- `install.sh:7`
- `bin/ryoku-version:6`

Problem:

- `lib/runtime-env.sh` prefers `~/.local/share/ryoku` whenever it exists.
- That ignores a caller-provided `RYOKU_PATH` in the common case where the installed path exists.
- `install.sh` can therefore source `helpers/all.sh` and the rest from the installed tree instead of the checked-out repo.
- `bin/ryoku-version` can report the installed repo HEAD instead of the repo containing the script.

Repro:

```bash
tmp=$(mktemp -d)
mkdir -p "$tmp/.local/share/ryoku"
HOME="$tmp" RYOKU_PATH=/home/omi/prowl/ryoku-arch/.worktrees/category1-rename \
  bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/lib/runtime-env.sh; printf "RYOKU_PATH=%s\n" "$RYOKU_PATH"'
rm -rf "$tmp"
```

Current output:

```text
RYOKU_PATH=/tmp/.../.local/share/ryoku
```

Patch direction:

- `lib/runtime-env.sh` should respect a pre-exported `RYOKU_PATH` before falling back to installed paths.
- `install.sh` should compute its repo root and export `RYOKU_PATH` to that repo root before sourcing `lib/runtime-env.sh`.
- `bin/ryoku-version` should do the same so it reports the checkout containing the script.

### 2. Medium: shell/session entrypoints can emit missing-file noise on fresh or partial installs

Files:

- `default/bash/envs:6`
- `config/uwsm/env:4`

Problem:

- Both files unconditionally source absolute installed helper paths.
- The first `source` suppresses stderr, but the fallback `source` does not.
- In a fresh or partially migrated environment, startup prints `No such file or directory`.

Repro:

```bash
tmp=$(mktemp -d)
HOME="$tmp" bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/default/bash/envs' 2>&1
rm -rf "$tmp"
```

Current output:

```text
/home/omi/prowl/ryoku-arch/.worktrees/category1-rename/default/bash/envs: line 6: /tmp/.../.local/share/omarchy/lib/runtime-env.sh: No such file or directory
```

Also:

```bash
tmp=$(mktemp -d)
HOME="$tmp" bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/config/uwsm/env' 2>&1
rm -rf "$tmp"
```

Patch direction:

- Guard helper loading with `[[ -r ... ]]` checks and only source an existing file.
- Keep `$HOME/.local/bin` on `PATH`.
- Keep `omarchy-cmd-present mise && eval "$(mise activate bash --shims)"` unchanged for now.
- Be careful not to expand scope into later command-family renames.

Note:

- The `config/uwsm/env` repro also errors on `source ~/.config/uwsm/default` when that file does not exist.
- That file is not part of the code-review finding, but if you touch that area, keep behavior intentional and avoid making startup noisier.

### 3. Medium: compatibility bridge handles `OMARCHY_PATH` inconsistently

File:

- `lib/runtime-env.sh:19`

Problem:

- `OMARCHY_PATH` is force-set to `"$RYOKU_PATH"`.
- `OMARCHY_INSTALL` and `OMARCHY_INSTALL_LOG_FILE` preserve caller overrides.
- That inconsistency can break legacy or staging callers that still export `OMARCHY_PATH`.

Repro:

```bash
OMARCHY_PATH=/tmp/legacy-target \
  bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/lib/runtime-env.sh; printf "OMARCHY_PATH=%s\nRYOKU_PATH=%s\n" "$OMARCHY_PATH" "$RYOKU_PATH"'
```

Current output:

```text
OMARCHY_PATH=/home/omi/.local/share/omarchy
RYOKU_PATH=/home/omi/.local/share/omarchy
```

Patch direction:

- Make `OMARCHY_PATH` follow the same compatibility rule as the other bridge variables.
- The smallest likely fix is `export OMARCHY_PATH="${OMARCHY_PATH:-$RYOKU_PATH}"`, unless a stronger reason appears during patching.

## Constraints To Preserve

- Do not push anything.
- Do not start Task 3 yet.
- Do not rename `omarchy-cmd-present` yet. Task 2 must keep it in `config/uwsm/env`.
- Preserve `$HOME/.local/bin` on `PATH` in `default/bash/envs` and `config/uwsm/env`.
- Keep the work inside this execution worktree, not the main checkout.
- Follow hooks rules and do not create co-authored commits.
- Avoid touching Hyprland, Waybar, or other display-critical files in this patch.

## Recommended Patch Order

1. Fix `lib/runtime-env.sh` path precedence and compatibility alias behavior.
2. Fix `install.sh` bootstrap so it uses the current checkout as its runtime root.
3. Fix `bin/ryoku-version` bootstrap so it reports the current checkout.
4. Guard helper sourcing in `default/bash/envs`.
5. Guard helper sourcing in `config/uwsm/env` without changing the `omarchy-cmd-present` call.

Keep the patch inside the existing Task 2 file set.

## Verification After Patch

Run these before asking for review:

```bash
cd /home/omi/prowl/ryoku-arch/.worktrees/category1-rename
bash -n lib/runtime-env.sh install.sh default/bash/envs config/uwsm/env bin/ryoku-version
bin/ryoku-dev-verify-category1 foundation
bin/ryoku-version
```

Re-run the failure-mode checks too:

```bash
tmp=$(mktemp -d)
mkdir -p "$tmp/.local/share/ryoku"
HOME="$tmp" RYOKU_PATH=/home/omi/prowl/ryoku-arch/.worktrees/category1-rename \
  bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/lib/runtime-env.sh; printf "RYOKU_PATH=%s\n" "$RYOKU_PATH"'
rm -rf "$tmp"

tmp=$(mktemp -d)
HOME="$tmp" bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/default/bash/envs' 2>&1
rm -rf "$tmp"

tmp=$(mktemp -d)
HOME="$tmp" bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/config/uwsm/env' 2>&1
rm -rf "$tmp"

OMARCHY_PATH=/tmp/legacy-target \
  bash -lc 'source /home/omi/prowl/ryoku-arch/.worktrees/category1-rename/lib/runtime-env.sh; printf "OMARCHY_PATH=%s\nRYOKU_PATH=%s\n" "$OMARCHY_PATH" "$RYOKU_PATH"'
```

Expected after patch:

- caller-provided `RYOKU_PATH` is preserved
- `default/bash/envs` does not emit missing runtime-helper errors
- `config/uwsm/env` does not emit missing runtime-helper errors
- `OMARCHY_PATH` bridge behavior is consistent with the chosen compatibility policy

## Review Gate After Patch

After patching:

1. Run a spec-compliance review on the same five Task 2 files against the patched plan.
2. Run a code-quality review on the same five files.
3. Only mark Task 2 complete if both reviews are clean.
4. Then continue to Task 3.

## Useful Branch History

Recent commits in order:

- `788075f2` `refactor: add ryoku runtime path contract`
- `fc970e98` `docs: fix task 2 install compatibility bridge`
- `9815384f` `docs: fix task 2 runtime contract dependency`
- `e43d3e39` `fix: resolve verifier repo root physically`
- `83a4d694` `chore: add category 1 verification helpers`
- `3df39d6b` `chore: ignore local worktrees`

Task 1 is already in a good state. The next session should resume by fixing Task 2 in place, not by reopening Task 1 or advancing the plan.
