# boot.sh Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh `boot.sh` so fresh Arch users get a Ryoku-branded orange banner, hit the correct `main` branch, and legacy Omarchy directories are archived instead of nuked.

**Architecture:** Single-file edit to `boot.sh`. Phase order (`set -eEo pipefail` -> banner -> env -> mirrorlist -> git -> legacy handling -> clone -> install) is preserved; only the banner, env defaults, and legacy-dir handling change. No new runtime dependencies.

**Tech Stack:** bash 5, ANSI truecolor escapes (`\033[38;2;R;G;B;m`), pacman, git, sudo. Target terminals: any 24-bit-color-capable shell (Alacritty, Kitty, Ghostty, WezTerm, foot, Konsole, GNOME Terminal, xterm + `COLORTERM=truecolor`). Acceptable degraded target: Arch installer TTY (`linux` kernel console, 8-color).

**Spec:** [`docs/superpowers/specs/2026-04-24-boot-sh-refresh-design.md`](../specs/2026-04-24-boot-sh-refresh-design.md)

---

## Working trees

All edits are in the dev clone at `/home/omi/prowl/ryoku-arch`. Task 6 mirrors the final `boot.sh` to the installed tree at `~/.local/share/ryoku` and pushes both to `origin/main` on `github.com/neur0map/ryoku-arch`.

## Files

**Modify:**
- `boot.sh` (single file, all five changes land here)

**Mirror:**
- `~/.local/share/ryoku/boot.sh` (end-of-plan sync)

**Snapshot tag:**
- `pre-boot-sh-refresh` at the current dev-clone HEAD before any edit

---

### Task 1: Snapshot tag

**Files:**
- Tag: `pre-boot-sh-refresh`

- [ ] **Step 1.1: Create the snapshot tag at current HEAD**

```bash
cd /home/omi/prowl/ryoku-arch
git tag pre-boot-sh-refresh
git tag -l 'pre-boot-sh-refresh'
```

Expected: the tag name prints once.

- [ ] **Step 1.2: Push the tag to origin**

```bash
git push origin pre-boot-sh-refresh
```

Expected: `[new tag] pre-boot-sh-refresh -> pre-boot-sh-refresh`.

- [ ] **Step 1.3: Verify rollback command works (dry run)**

```bash
git log --oneline pre-boot-sh-refresh -1
```

Expected: prints the same commit as `git log --oneline HEAD -1`. If yes, the rollback point is valid.

(No commit this task. Tags are refs, not commits.)

---

### Task 2: Fail-fast guard

**Files:**
- Modify: `boot.sh` (after shebang, before any logic)

- [ ] **Step 2.1: Insert `set -eEo pipefail` after shebang**

Open `boot.sh`. The current top is:

```bash
#!/bin/bash

# Ryoku Arch online bootstrap. Entry point for curl-to-shell installs.

export RYOKU_ONLINE_INSTALL=true
```

Replace that block with:

```bash
#!/bin/bash

# Ryoku Arch online bootstrap. Entry point for curl-to-shell installs.
#
# Fresh-install only. Upgrades go through ryoku-update, not this script.

set -eEo pipefail

export RYOKU_ONLINE_INSTALL=true
```

- [ ] **Step 2.2: Syntax check**

```bash
bash -n /home/omi/prowl/ryoku-arch/boot.sh
```

Expected: no output, exit 0.

- [ ] **Step 2.3: Commit**

```bash
cd /home/omi/prowl/ryoku-arch
git add boot.sh
git commit -m "boot: set -eEo pipefail so partial failures do not continue"
```

Expected: one-file, one-commit outcome.

---

### Task 3: Fix RYOKU_REF default and remove dead RYOKU_MIRROR block

**Files:**
- Modify: `boot.sh` (env var region)

- [ ] **Step 3.1: Replace the env block**

Find the block in `boot.sh` that currently reads:

```bash
# Channel selection: stable (master), rc (rc branch), dev (dev branch).
# All three currently share the same upstream Arch mirror snapshot; the
# channel concept survives as scaffolding for future differentiation.
RYOKU_REF="${RYOKU_REF:-master}"

case "$RYOKU_REF" in
  dev) export RYOKU_MIRROR=edge ;;
  rc)  export RYOKU_MIRROR=rc ;;
  *)   export RYOKU_MIRROR=stable ;;
esac
```

Replace it with:

```bash
# Branch selection. Default to main (the repo's default branch). Users
# can override with RYOKU_REF=<branch> when calling boot.sh. No mirror
# variable: Ryoku does not operate named mirrors; the legacy
# RYOKU_MIRROR block was dead code inherited from Omarchy.
RYOKU_REF="${RYOKU_REF:-main}"
```

- [ ] **Step 3.2: Verify RYOKU_MIRROR is gone**

```bash
grep -n 'RYOKU_MIRROR' /home/omi/prowl/ryoku-arch/boot.sh || echo "clean"
```

Expected: `clean` (no lines found).

- [ ] **Step 3.3: Verify RYOKU_REF default is main**

```bash
grep -n 'RYOKU_REF=' /home/omi/prowl/ryoku-arch/boot.sh
```

Expected: a single line showing `RYOKU_REF="${RYOKU_REF:-main}"`.

- [ ] **Step 3.4: Syntax check**

```bash
bash -n /home/omi/prowl/ryoku-arch/boot.sh
```

Expected: no output, exit 0.

- [ ] **Step 3.5: Commit**

```bash
cd /home/omi/prowl/ryoku-arch
git add boot.sh
git commit -m "boot: default RYOKU_REF to main; drop dead RYOKU_MIRROR block"
```

---

### Task 4: Refresh banner (kanji + wordmark + tagline in Ryoku orange)

**Files:**
- Modify: `boot.sh` (banner region, replacing the current `ansi_art` heredoc and its `printf`)

- [ ] **Step 4.1: Replace the banner block with the three-variable structure**

Find the current banner block in `boot.sh`:

```bash
ansi_art='
            ████
            ██████
  ██████████████████████████████
  ██████████████████████████████
            ████          ██████
          ██████          ██████
          ████            ████
      ██████              ████
  ████████          ██████████
  ████            ██████████

 ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔══██╗╚██╗ ██╔╝██╔═══██╗██║ ██╔╝██║   ██║
 ██████╔╝ ╚████╔╝ ██║   ██║█████╔╝ ██║   ██║
 ██╔══██╗  ╚██╔╝  ██║   ██║██╔═██╗ ██║   ██║
 ██║  ██║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝

            力と美のために  :  For the sake of power and beauty.
'

clear
# Japanese old red #8F1D21 via truecolor ANSI
printf "\033[38;2;143;29;33m%s\033[0m\n" "$ansi_art"
```

Replace the entire block with the three-variable version:

```bash
# Banner art: 力 kanji block rendering adapted from branding/about.txt
# (frame stripped), followed by the RYOKU wordmark in Unicode box-drawing
# and the tagline. All in Ryoku accent orange #F25623 except the tagline,
# which uses the theme's subdued foreground #aeab94.
kanji_art='
                   ████████
                   ████████
                   ████████
                   ████████
     ██████████████████████████████████████████
   ██████████████████████████████████████████████
   ██████████████████████████████████████████████
                   ████████              ████████
                   ██████                ██████
                   ██████                ██████
                 ████████                ██████
                 ████████                ██████
               ████████                  ██████
             ██████████                  ██████
             ████████                  ████████
         ██████████                    ████████
       ██████████                      ██████
   ████████████              ████████████████
   ████████                  ██████████████
     ████                      ████████
'

wordmark='
 ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔══██╗╚██╗ ██╔╝██╔═══██╗██║ ██╔╝██║   ██║
 ██████╔╝ ╚████╔╝ ██║   ██║█████╔╝ ██║   ██║
 ██╔══██╗  ╚██╔╝  ██║   ██║██╔═██╗ ██║   ██║
 ██║  ██║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
'

tagline='            力と美のために  :  For the sake of power and beauty.'

clear
# Orange #F25623 for kanji and wordmark; subdued foreground #aeab94 for
# tagline so the brand mark reads as the focal point.
printf '\033[38;2;242;86;35m%s%s\033[0m\n' "$kanji_art" "$wordmark"
printf '\033[38;2;174;171;148m%s\033[0m\n\n' "$tagline"
```

(The `kanji_art` block above is `config/fastfetch/about.txt` with the `██`-border frame and empty padding rows stripped; verify this against `cat ~/.config/ryoku/branding/about.txt` if you want to double-check the glyph.)

- [ ] **Step 4.2: Syntax check**

```bash
bash -n /home/omi/prowl/ryoku-arch/boot.sh
```

Expected: no output, exit 0.

- [ ] **Step 4.3: Extract and render just the banner in a scratch shell**

Create a temporary script that only runs the banner portion, to verify visual output without triggering the rest of the installer:

```bash
cd /home/omi/prowl/ryoku-arch
# Extract lines between the start of kanji_art and the second printf.
# We run this in a subshell so any 'set -e' behavior from boot.sh does
# not leak out if something downstream fails later.
bash -c '
  set -eEo pipefail
  # shellcheck disable=SC1091
  source <(sed -n "/^kanji_art=/,/^printf .*tagline/p" boot.sh)
'
```

Expected: the orange kanji, orange wordmark, and subdued tagline print to the terminal. Visually confirm:
- 力 kanji glyph is legible (not a blocky mess).
- Orange color is distinct and matches your current frame accent.
- Wordmark reads RYOKU.
- Tagline is readable in subdued gray.
- No raw `\033[` escape sequences visible (if you see those, printf quoting is wrong).

If the render is broken, STOP and report BLOCKED with the observed output.

- [ ] **Step 4.4: Commit**

```bash
cd /home/omi/prowl/ryoku-arch
git add boot.sh
git commit -m "boot: refresh banner (kanji block art + wordmark + tagline in Ryoku orange)"
```

---

### Task 5: Omarchy legacy migration + fresh-install guard comment

**Files:**
- Modify: `boot.sh` (around the `rm -rf "$HOME/.local/share/omarchy"` and `rm -rf "$HOME/.local/share/ryoku"` lines)

- [ ] **Step 5.1: Replace the unconditional omarchy rm with a migration block**

Find the current lines in `boot.sh`:

```bash
echo -e "\nCloning Ryoku Arch from: https://github.com/${RYOKU_REPO}.git"
rm -rf "$HOME/.local/share/ryoku"
# If the legacy path exists from a pre-rename checkout, take it out of
# the way so git clone does not fight a stale tree. Upgrades from an
# existing install go through migrations, not this script.
rm -rf "$HOME/.local/share/omarchy"
git clone "https://github.com/${RYOKU_REPO}.git" "$HOME/.local/share/ryoku" >/dev/null
```

Replace with:

```bash
echo -e "\nCloning Ryoku Arch from: https://github.com/${RYOKU_REPO}.git"

# If the pre-rename ~/.local/share/omarchy is a real directory (legacy
# Omarchy install), archive it by renaming so the user keeps their git
# history and local commits. If it is a symlink (the post-rename
# compat shim) or absent, leave it alone.
OMARCHY_DIR="$HOME/.local/share/omarchy"
if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]]; then
  MIGRATED_DIR="$HOME/.local/share/ryoku.migrated-$(date +%s)"
  mv "$OMARCHY_DIR" "$MIGRATED_DIR"
  echo "Archived legacy ~/.local/share/omarchy to $MIGRATED_DIR"
fi

# boot.sh is a fresh-install entrypoint. For upgrades, use ryoku-update,
# which preserves the local clone and applies migrations. Re-running
# boot.sh on an installed system will destroy the local clone.
rm -rf "$HOME/.local/share/ryoku"
git clone "https://github.com/${RYOKU_REPO}.git" "$HOME/.local/share/ryoku" >/dev/null
```

- [ ] **Step 5.2: Syntax check**

```bash
bash -n /home/omi/prowl/ryoku-arch/boot.sh
```

Expected: no output, exit 0.

- [ ] **Step 5.3: Functional test for the migration path**

The migration block is the most important new logic. Verify it handles all three cases correctly by extracting and running just that block with mocked `$HOME`:

```bash
# Case A: omarchy is a real directory (legacy install). Must migrate.
TMP_HOME="$(mktemp -d)"
mkdir -p "$TMP_HOME/.local/share/omarchy"
echo "legacy-marker" > "$TMP_HOME/.local/share/omarchy/README"

HOME="$TMP_HOME" bash -c '
  set -eEo pipefail
  OMARCHY_DIR="$HOME/.local/share/omarchy"
  if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]]; then
    MIGRATED_DIR="$HOME/.local/share/ryoku.migrated-$(date +%s)"
    mv "$OMARCHY_DIR" "$MIGRATED_DIR"
    echo "Archived legacy ~/.local/share/omarchy to $MIGRATED_DIR"
  fi
'

# Verify: omarchy is gone, ryoku.migrated-* exists with the marker
ls "$TMP_HOME/.local/share/" | grep -c 'ryoku.migrated-'
ls "$TMP_HOME/.local/share/omarchy" 2>&1 | head -1
cat "$TMP_HOME/.local/share/ryoku.migrated-"*/README
rm -rf "$TMP_HOME"
```

Expected:
- `grep -c` prints `1` (one migrated dir created).
- `ls omarchy` prints an error (dir gone).
- `cat README` prints `legacy-marker`.

```bash
# Case B: omarchy is a symlink (post-rename compat). Must leave alone.
TMP_HOME="$(mktemp -d)"
mkdir -p "$TMP_HOME/.local/share/ryoku"
ln -s "$TMP_HOME/.local/share/ryoku" "$TMP_HOME/.local/share/omarchy"

HOME="$TMP_HOME" bash -c '
  set -eEo pipefail
  OMARCHY_DIR="$HOME/.local/share/omarchy"
  if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]]; then
    MIGRATED_DIR="$HOME/.local/share/ryoku.migrated-$(date +%s)"
    mv "$OMARCHY_DIR" "$MIGRATED_DIR"
    echo "Archived legacy ~/.local/share/omarchy to $MIGRATED_DIR"
  fi
'

# Verify: symlink still exists, no migrated dir created
ls -la "$TMP_HOME/.local/share/omarchy"
ls "$TMP_HOME/.local/share/" | grep 'migrated' || echo "no migrated dir, correct"
rm -rf "$TMP_HOME"
```

Expected:
- `ls -la omarchy` shows it is still a symlink (first char `l`).
- `grep 'migrated'` prints nothing, final `echo` prints `no migrated dir, correct`.

```bash
# Case C: omarchy is absent (fresh install). Must be a no-op.
TMP_HOME="$(mktemp -d)"

HOME="$TMP_HOME" bash -c '
  set -eEo pipefail
  OMARCHY_DIR="$HOME/.local/share/omarchy"
  if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]]; then
    MIGRATED_DIR="$HOME/.local/share/ryoku.migrated-$(date +%s)"
    mv "$OMARCHY_DIR" "$MIGRATED_DIR"
    echo "Archived legacy ~/.local/share/omarchy to $MIGRATED_DIR"
  fi
'

# Verify: nothing created, no migrated dir
ls "$TMP_HOME/.local/share/" 2>/dev/null | wc -l
rm -rf "$TMP_HOME"
```

Expected: `0` (no files in .local/share).

- [ ] **Step 5.4: Commit**

```bash
cd /home/omi/prowl/ryoku-arch
git add boot.sh
git commit -m "boot: migrate legacy ~/.local/share/omarchy; document fresh-install intent"
```

---

### Task 6: Final verification, sync to installed tree, push

**Files:**
- Mirror: `~/.local/share/ryoku/boot.sh`
- Tags / commits pushed to `origin/main`

- [ ] **Step 6.1: Full static analysis on the final boot.sh**

```bash
cd /home/omi/prowl/ryoku-arch
bash -n boot.sh
shellcheck boot.sh 2>&1 | head -40
```

Expected:
- `bash -n` exits 0 with no output.
- `shellcheck` reports nothing or only informational notes (SC2034 for unused variables, SC2155 for declare-and-assign). If it reports any `warning:` or `error:`, fix before continuing.

- [ ] **Step 6.2: Run the banner end-to-end**

Run boot.sh up through the banner printf, then interrupt. The quickest way is to wrap it in a subshell that exits just after the banner:

```bash
cd /home/omi/prowl/ryoku-arch
bash -c '
  set -eEo pipefail
  source <(sed -n "/^#!/,/^clear$/p" boot.sh)
  source <(sed -n "/^clear$/,/^printf .*tagline/p" boot.sh | tail -n +2)
'
```

Expected: the orange banner prints cleanly, then the subshell exits before any pacman or git call. Confirms the banner block is valid in isolation.

- [ ] **Step 6.3: Mirror to installed tree**

```bash
cp /home/omi/prowl/ryoku-arch/boot.sh ~/.local/share/ryoku/boot.sh
diff /home/omi/prowl/ryoku-arch/boot.sh ~/.local/share/ryoku/boot.sh
```

Expected: empty diff output.

- [ ] **Step 6.4: Commit in the installed tree**

```bash
cd ~/.local/share/ryoku
git status --short
USER_EMAIL="$(git -C /home/omi/prowl/ryoku-arch config user.email)"
USER_NAME="$(git -C /home/omi/prowl/ryoku-arch config user.name)"
git add boot.sh
git -c user.email="$USER_EMAIL" -c user.name="$USER_NAME" \
    commit -m "boot: sync refreshed boot.sh from dev clone"
```

Expected: single-file commit. `git status --short` on the installed tree after should print nothing.

- [ ] **Step 6.5: Push dev clone to origin**

```bash
cd /home/omi/prowl/ryoku-arch
git push origin main
```

Expected: four commits pushed (one per Task 2..5), HEAD now matches dev-clone HEAD.

- [ ] **Step 6.6: Verify installed tree matches origin**

```bash
git -C ~/.local/share/ryoku fetch origin
git -C ~/.local/share/ryoku diff --shortstat origin/main HEAD
```

Expected: no output (no diff). If there is a diff, it means the installed tree's local commit has different content than the push; reset with `git -C ~/.local/share/ryoku reset --hard origin/main`.

- [ ] **Step 6.7: Final sanity: origin fetch, tag verification**

```bash
git -C /home/omi/prowl/ryoku-arch fetch origin
git -C /home/omi/prowl/ryoku-arch rev-parse origin/main
git -C /home/omi/prowl/ryoku-arch rev-parse HEAD
git -C /home/omi/prowl/ryoku-arch rev-parse pre-boot-sh-refresh
```

Expected:
- `origin/main` and `HEAD` print the same SHA.
- `pre-boot-sh-refresh` prints a DIFFERENT SHA (the pre-refresh snapshot).

---

## Rollback

Single-file change means rollback is trivial:

```bash
cd /home/omi/prowl/ryoku-arch
git reset --hard pre-boot-sh-refresh
# If the refresh had been pushed:
git push --force-with-lease origin main

cd ~/.local/share/ryoku
git fetch origin
git reset --hard origin/main
```

---

## Self-review

**Spec coverage.** Every item in the spec is covered:

| Spec item | Task |
|---|---|
| `set -eEo pipefail` as phase 0 | Task 2 |
| RYOKU_REF default -> main | Task 3 |
| Drop RYOKU_MIRROR block | Task 3 |
| Banner kanji from stripped about.txt | Task 4 |
| Banner orange `#F25623` color | Task 4 |
| Subdued tagline `#aeab94` color | Task 4 |
| Omarchy legacy dir migration | Task 5 |
| Fresh-install guard comment | Task 5 |
| Snapshot tag + rollback | Task 1, Task 6 |
| Static analysis (`bash -n`, shellcheck) | Task 6 |
| Banner isolated render test | Task 4, Task 6 |
| Migration tests for all three omarchy cases | Task 5 |
| Installed-tree mirror | Task 6 |
| Push to origin | Task 6 |

**Placeholder scan.** Searched for `TBD`, `TODO`, `XXX`, `FIXME`, `implement later`, `add appropriate`. None found in this plan.

**Type consistency.** Only bash variables are involved. The variable names `kanji_art`, `wordmark`, `tagline`, `OMARCHY_DIR`, `MIGRATED_DIR`, `RYOKU_REF`, `RYOKU_REPO`, `USER_EMAIL`, `USER_NAME` are used consistently across tasks.

**Explicit non-coverage.** Fresh-install VM test and ISO-readiness smoke test are called out as follow-up work, not part of this plan (consistent with the spec's `Test plan > Fresh-install VM test (blocking for marking ready-to-ship)` note).
