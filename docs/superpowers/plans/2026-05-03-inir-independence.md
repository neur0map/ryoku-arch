# iNiR Independence Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor the iNiR shell into Ryoku at `apps/ryoku-shell/`, sever every operational dependency on `github.com/snowarch/iNiR`, rename runtime surfaces (service / binary / paths / env vars / CLI verbs / QML IPC) to Ryoku-namespaced equivalents, and migrate existing installs atomically via a snapshot-gated, idempotent migration.

**Architecture:** 8 chunks executed in dependency order. Chunk 1 vendors source (additive, two commits). Chunks 2-6 swap callers, build, packaging. Chunk 7 migrates live systems. Chunk 8 closes the loop with tests + heritage doc. Dual-name fallbacks added in chunks 3-4 keep unmigrated systems bootable across the release window; their removal is deferred to a follow-up release.

**Tech Stack:** bash + perl-based source patching (existing `install/config/ryoku-shell-branding.sh`), systemd user units, niri compositor config (KDL), Quickshell QML, archiso for ISO builds, snapper for migration snapshot gates.

**Spec reference:** `docs/superpowers/specs/2026-05-03-inir-independence-design.md`

**Branch:** Work on `niri-inir-transition` (current branch). All commits are additive, no rewrites, no force-push, no `--no-verify`.

**Implementation-time constants captured at plan-write time:**
- Upstream sha to vendor from: `c1fcbcd50a521a2c2448651adcdefe47ee717326` (verify with `git -C ~/.local/share/inir rev-parse HEAD` at chunk 1 start; if it differs, use the live value and update commit 1a body).
- Migration epoch starting point: ~`1777856910` (use `date +%s` at chunk 7 commit time; must be greater than the latest existing migration `1777852554.sh`).

---

## Chunk 1: Vendor Source

Two atomic commits: raw upstream import, then branding patches + IPC rename + file renames.

### Task 1.1: Raw upstream import as `apps/ryoku-shell/`

**Files:**
- Create: `apps/ryoku-shell/` (entire vendored tree, ~30-50MB)

- [ ] **Step 1: Verify the implementation machine has the iNiR upstream checkout**

```bash
ls -la $HOME/.local/share/inir/.git
git -C $HOME/.local/share/inir rev-parse HEAD
```

Expected: `.git` directory exists; sha printed (recorded as `UPSTREAM_SHA` for the commit body). If `~/.local/share/inir` is missing, clone fresh: `git clone https://github.com/snowarch/iNiR.git /tmp/inir-vendor && cd /tmp/inir-vendor && git rev-parse HEAD` and use `/tmp/inir-vendor` for step 3.

- [ ] **Step 2: Create the vendor target dir**

```bash
mkdir -p $RYOKU_PATH/apps/ryoku-shell
```

- [ ] **Step 3: Extract the upstream tree at HEAD into `apps/ryoku-shell/` (without `.git/`)**

```bash
cd $HOME/.local/share/inir
git archive HEAD | tar -x -C $RYOKU_PATH/apps/ryoku-shell/
```

Expected: no output. Verify with `ls $RYOKU_PATH/apps/ryoku-shell/`, should show `setup`, `shell.qml`, `modules/`, `assets/`, `dots/`, `LICENSE`, `README.md`, etc.

- [ ] **Step 4: Verify file count and key files present**

```bash
find $RYOKU_PATH/apps/ryoku-shell -type f | wc -l
ls $RYOKU_PATH/apps/ryoku-shell/{setup,shell.qml,LICENSE,assets/applications/inir.desktop,assets/systemd/inir.service}
```

Expected: file count > 500 (the upstream is large); all listed paths exist (note: `inir.desktop` and `inir.service` still have legacy names, they get renamed in Task 1.2).

- [ ] **Step 5: Sanity-check the `setup` script doesn't hardcode the dir name `inir`**

```bash
grep -n "inir" $RYOKU_PATH/apps/ryoku-shell/setup | head -20
```

Expected: zero or very few hits, and any hits should be either UI strings or comments, NOT hardcoded paths like `cd ~/.local/share/inir`. If you see hardcoded paths, capture the lines for a small patch in Task 1.2 step 4. Most likely the `setup` script uses `BASH_SOURCE`/`pwd` and is path-agnostic.

- [ ] **Step 6: Stage and commit (commit 1a)**

```bash
cd $RYOKU_PATH
git add apps/ryoku-shell
git commit -m "$(cat <<'EOF'
vendor: import iNiR @ c1fcbcd5 as apps/ryoku-shell/

Imports the iNiR shell source tree from snowarch/iNiR at upstream sha
c1fcbcd50a521a2c2448651adcdefe47ee717326 via `git archive HEAD | tar -x`
(no .git history vendored).

This is the raw upstream import, no Ryoku-specific patches applied yet.
Commit 1b applies all the patches from install/config/ryoku-shell-branding.sh
plus the inir.desktop/inir.service file renames and QML IPC handler renames.

After this pair of commits, install/config/ryoku-shell-branding.sh is no
longer needed at install time, its outputs are baked into apps/ryoku-shell/
directly. Removal lands in chunk 8.

Source: https://github.com/snowarch/iNiR.git
Method: git archive HEAD | tar -x -C apps/ryoku-shell/
EOF
)"
```

Expected: commit succeeds. `git log --oneline -1` shows the new commit.

- [ ] **Step 7: Verify the commit's diff is reviewable as additive-only**

```bash
git show --stat HEAD | head -5
```

Expected: ~3000+ files added under `apps/ryoku-shell/`, no other paths touched, no files modified or deleted.

### Task 1.2: Apply Ryoku branding + IPC rename + file renames

**Files:**
- Modify (rename): `apps/ryoku-shell/assets/systemd/inir.service` → `apps/ryoku-shell/assets/systemd/ryoku-shell.service`
- Modify (rename): `apps/ryoku-shell/assets/applications/inir.desktop` → `apps/ryoku-shell/assets/applications/ryoku-shell.desktop`
- Modify (in-place patches): files under `apps/ryoku-shell/modules/`, `services/`, `welcome.qml`, `dots/sddm/pixel/*` (TSV-driven)
- Modify (in-place IPC rename): every QML file in `apps/ryoku-shell/` that registers an IPC handler with `target: "inir"` or similar

- [ ] **Step 1: Run the existing branding script against the vendored tree**

```bash
cd $RYOKU_PATH
RYOKU_SHELL_PATH="$PWD/apps/ryoku-shell" \
  RYOKU_SHELL_RUNTIME_PATH=/dev/null \
  bash install/config/ryoku-shell-branding.sh
```

Expected: script runs without error; output ends with `Ryoku shell branding: applied`. Files under `apps/ryoku-shell/modules/`, `apps/ryoku-shell/welcome.qml`, `apps/ryoku-shell/dots/sddm/pixel/*`, etc. have been mutated in-place.

Verify with `cd apps/ryoku-shell && git diff --stat`, should show many modified files.

Note on `RYOKU_SHELL_RUNTIME_PATH=/dev/null`: this disables the runtime-side patches (which target `~/.config/quickshell/inir/`); we only want the source-side patches applied to the vendored tree.

- [ ] **Step 2: Rename `inir.service` and `inir.desktop` files in the vendored tree**

```bash
cd $RYOKU_PATH
git mv apps/ryoku-shell/assets/systemd/inir.service apps/ryoku-shell/assets/systemd/ryoku-shell.service
git mv apps/ryoku-shell/assets/applications/inir.desktop apps/ryoku-shell/assets/applications/ryoku-shell.desktop
```

Expected: `git status` shows the two renames.

- [ ] **Step 3: Find and rename QML IPC handler registrations from `inir.*` to `ryoku-shell.*`**

QML files in iNiR commonly register IPC targets with declarations like `IpcHandler { target: "inir" }`. Find them:

```bash
cd $RYOKU_PATH
grep -rln 'target: "inir"' apps/ryoku-shell/
```

For each matching file, replace `target: "inir"` with `target: "ryoku-shell"`:

```bash
cd $RYOKU_PATH
grep -rl 'target: "inir"' apps/ryoku-shell/ | xargs perl -pi -e 's/target: "inir"/target: "ryoku-shell"/g'
```

Then check for any other `inir` IPC references inside the tree's QML/JS that should also flip:

```bash
grep -rn 'IpcHandler\|Quickshell\.IpcHandler\|"inir\."' apps/ryoku-shell/ | head -30
```

Inspect each hit, flip the ones that are namespace registrations or call sites; leave UI strings/comments alone.

- [ ] **Step 4: Apply any required tiny patches to the vendored `setup` script**

If Task 1.1 step 5 found hardcoded `inir` path strings in `apps/ryoku-shell/setup`, patch them now. Common candidates: a hardcoded `INIR_PATH=~/.local/share/inir`, or `INIR_LAUNCHER=~/.local/bin/inir`. Replace with `~/.local/share/ryoku-shell` and `~/.local/bin/ryoku-shell` respectively.

Also: search for the launcher creation logic in `setup`:

```bash
grep -n "local/bin\|launcher\|symlink" apps/ryoku-shell/setup | head -20
```

The launcher creation should produce `~/.local/bin/ryoku-shell`, not `~/.local/bin/inir`. If it produces `inir`, patch it.

- [ ] **Step 5: Bake the `1777776000.sh` resume-recovery tuning directly into the vendored service file**

The existing migration `migrations/1777776000.sh` mutates `inir.service` by removing `PartOf=graphical-session.target` and `Requisite=graphical-session.target` lines and setting `RestartSec=1`. Bake the same final state into the vendored unit so fresh installs land in the post-tuning shape:

```bash
cd $RYOKU_PATH
SERVICE=apps/ryoku-shell/assets/systemd/ryoku-shell.service

# Verify current state of the file:
cat $SERVICE
```

Edit the file to:
1. Remove any `PartOf=graphical-session.target` line
2. Remove any `Requisite=graphical-session.target` line  
3. Ensure `RestartSec=1` is set (replace existing `RestartSec=...` line, or add if absent)

Also ensure the service-name-related strings inside the unit (`Description=`, comments) say "Ryoku shell" not "iNiR", the branding script in step 1 should have done this via the TSV, but verify:

```bash
grep -i "inir" $SERVICE
```

Expected: zero hits, OR only attribution-context hits.

- [ ] **Step 6: Verify the patched tree still parses / setup --help works**

```bash
cd $RYOKU_PATH/apps/ryoku-shell
bash -n setup
./setup --help 2>&1 | head -20
```

Expected: `bash -n` returns no errors; `./setup --help` prints usage with no Python tracebacks. (If `--help` requires the venv, it may fail with a venv warning, that's OK as long as the bash script itself parses.)

- [ ] **Step 7: Stage and commit (commit 1b)**

```bash
cd $RYOKU_PATH
git add -A apps/ryoku-shell
git commit -m "$(cat <<'EOF'
vendor: apply Ryoku branding + IPC rename to apps/ryoku-shell/

Bakes every patch that install/config/ryoku-shell-branding.sh applied at
install time into the vendored source tree directly. After this commit the
branding script is logically a no-op against apps/ryoku-shell/, its actual
deletion lands in chunk 8 once all consumers stop calling it.

Patches applied (from ryoku-shell-branding.sh):
- apply_replacements_to_tree (TSV substitutions: iNiR Settings → Ryoku
  Settings, Welcome to inir → Welcome to Ryoku, ii-pixel SDDM theme name
  → Ryoku Pixel, etc.)
- apply_lock_security_guard (modules/lock/Lock.qml)
- apply_screen_corners_input_mask_guard (modules/screenCorners/...)
- apply_wallpaper_resolution_patch (services/Wallpapers.qml)
- apply_sidebar_right_keep_mapped_workaround (modules/sidebarRight/...,
  Qt 6.11 UAF mitigation)
- apply_topbar_hug_frame (modules/bar/{Bar,BarContent,Workspaces}.qml,
  weather/WeatherBar.qml)
- apply_weather_bar_dynamic_color (modules/bar/weather/WeatherBar.qml)

File renames:
- assets/systemd/inir.service → assets/systemd/ryoku-shell.service
- assets/applications/inir.desktop → assets/applications/ryoku-shell.desktop

QML IPC handler rename:
- target: "inir" → target: "ryoku-shell" across all IpcHandler registrations

Resume-recovery tuning baked in (was migrations/1777776000.sh):
- Drop PartOf=graphical-session.target
- Drop Requisite=graphical-session.target
- RestartSec=1
EOF
)"
```

Expected: commit succeeds with the diff representing the Ryoku-specific delta over upstream.

- [ ] **Step 8: Final verification, git log shows two commits, no other paths touched**

```bash
cd $RYOKU_PATH
git log --oneline -2
git show --stat HEAD~1 | grep -v "apps/ryoku-shell/" | head
git show --stat HEAD | grep -v "apps/ryoku-shell/" | head
```

Expected: two new commits; the only paths in either commit are under `apps/ryoku-shell/`.

---

## Chunk 2: Re-point install/config

Single commit replacing the upstream-clone install entrypoint with a vendor-copy install entrypoint.

### Task 2.1: Rewrite `install/config/inir.sh` → `install/config/ryoku-shell.sh`

**Files:**
- Delete: `install/config/inir.sh`
- Create: `install/config/ryoku-shell.sh`
- Modify: `install/config/all.sh` (line referencing `config/inir.sh`)
- Modify: `bin/ryoku-update-perform` (line referencing `config/inir.sh`)

- [ ] **Step 1: Read the current `install/config/inir.sh` to capture preserved behaviors**

```bash
cat $RYOKU_PATH/install/config/inir.sh
```

Capture: the `RYOKU_CHROOT_INSTALL` + `UV_*` env handling (preserve verbatim), the `./setup install -y --skip-deps --skip-sysupdate` invocation (preserve verbatim), the post-install `inir service enable niri` + wants-symlink wiring (rename to `ryoku-shell`).

- [ ] **Step 2: Create the new install script**

Create `$RYOKU_PATH/install/config/ryoku-shell.sh` with this content:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

SHELL_VENDOR_PATH="$RYOKU_PATH/apps/ryoku-shell"
SHELL_INSTALL_PATH="${RYOKU_SHELL_PATH:-$HOME/.local/share/ryoku-shell}"

if [[ ! -d $SHELL_VENDOR_PATH ]]; then
  echo "install/config/ryoku-shell.sh: vendored shell tree missing at $SHELL_VENDOR_PATH" >&2
  echo "Did the Ryoku source copy complete? Check $RYOKU_PATH" >&2
  exit 1
fi

setup_env=()
if [[ -n ${RYOKU_CHROOT_INSTALL:-} && -d /var/cache/ryoku/uv ]]; then
  setup_env+=(
    UV_CACHE_DIR=/var/cache/ryoku/uv
    UV_OFFLINE=1
    UV_PYTHON_DOWNLOADS=never
  )
fi

# Sync vendored tree to install path. --delete removes files no longer in
# the vendored tree (e.g., after a Ryoku release that drops a module). The
# --exclude='.git' is defensive, the vendored tree shouldn't have .git but
# guard against accidental future commits including one.
mkdir -p "$(dirname "$SHELL_INSTALL_PATH")"
rsync -a --delete --exclude='.git' "$SHELL_VENDOR_PATH/" "$SHELL_INSTALL_PATH/"

(
  cd "$SHELL_INSTALL_PATH"
  if (( ${#setup_env[@]} > 0 )); then
    env "${setup_env[@]}" ./setup install -y --skip-deps --skip-sysupdate
  else
    ./setup install -y --skip-deps --skip-sysupdate
  fi
)

# Enable the shell under niri (idempotent).
shell_launcher="$HOME/.local/bin/ryoku-shell"
if [[ -x $shell_launcher ]]; then
  "$shell_launcher" service enable niri >/dev/null 2>&1 || true
elif ryoku-cmd-present ryoku-shell; then
  ryoku-shell service enable niri >/dev/null 2>&1 || true
fi

# Wire ryoku-shell.service into niri.service.wants/ for first-login startup.
shell_service="$HOME/.config/systemd/user/ryoku-shell.service"
shell_wants_dir="$HOME/.config/systemd/user/niri.service.wants"
if [[ -f $shell_service ]]; then
  mkdir -p "$shell_wants_dir"
  ln -sf "$shell_service" "$shell_wants_dir/ryoku-shell.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
```

```bash
chmod +x $RYOKU_PATH/install/config/ryoku-shell.sh
```

- [ ] **Step 3: Delete the old install script**

```bash
cd $RYOKU_PATH
git rm install/config/inir.sh
```

- [ ] **Step 4: Update callers, `install/config/all.sh`**

```bash
grep -n "config/inir.sh" $RYOKU_PATH/install/config/all.sh
```

For each hit, replace `config/inir.sh` with `config/ryoku-shell.sh`. Use Edit tool or:

```bash
perl -pi -e 's|config/inir\.sh|config/ryoku-shell.sh|g' $RYOKU_PATH/install/config/all.sh
```

Verify:

```bash
grep -n "config/ryoku-shell.sh\|config/inir.sh" $RYOKU_PATH/install/config/all.sh
```

Expected: only `config/ryoku-shell.sh` references; zero `config/inir.sh`.

- [ ] **Step 5: Update callers, `bin/ryoku-update-perform`**

```bash
grep -n "config/inir.sh" $RYOKU_PATH/bin/ryoku-update-perform
```

For each hit, replace `config/inir.sh` with `config/ryoku-shell.sh`.

```bash
perl -pi -e 's|config/inir\.sh|config/ryoku-shell.sh|g' $RYOKU_PATH/bin/ryoku-update-perform
```

Verify:

```bash
grep -n "config/ryoku-shell.sh\|config/inir.sh" $RYOKU_PATH/bin/ryoku-update-perform
```

Expected: only `config/ryoku-shell.sh`; zero `config/inir.sh`.

- [ ] **Step 6: Syntax-check the new script**

```bash
bash -n $RYOKU_PATH/install/config/ryoku-shell.sh
bash -n $RYOKU_PATH/install/config/all.sh
bash -n $RYOKU_PATH/bin/ryoku-update-perform
```

Expected: no output on any of the three.

- [ ] **Step 7: Dry-run the new install script (do NOT actually install)**

```bash
cd $RYOKU_PATH
bash -x install/config/ryoku-shell.sh 2>&1 | head -30
```

Expected: traces show `rsync -a --delete --exclude=.git apps/ryoku-shell/ ~/.local/share/ryoku-shell/` (and possibly a real install runs further). If the rsync runs against your home dir and you don't want that side effect during dry-run, use a temp `RYOKU_SHELL_PATH`:

```bash
RYOKU_SHELL_PATH=/tmp/ryoku-shell-dryrun bash -x install/config/ryoku-shell.sh 2>&1 | head -50
```

Expected: rsync target is `/tmp/ryoku-shell-dryrun/`; `cd` happens into that dir; `./setup install` may run or fail (depending on Python deps). Cleanup: `rm -rf /tmp/ryoku-shell-dryrun`.

- [ ] **Step 8: Stage and commit**

```bash
cd $RYOKU_PATH
git add install/config/ryoku-shell.sh install/config/all.sh bin/ryoku-update-perform
git commit -m "$(cat <<'EOF'
install: vendor-copy ryoku-shell.sh replaces upstream-clone inir.sh

install/config/ryoku-shell.sh syncs apps/ryoku-shell/ into
~/.local/share/ryoku-shell/ via rsync, then runs the vendored
./setup install. Drops the entire fallback chain (vendor/inir,
/root/inir, /opt/ryoku/inir, git clone), the source is now in
$RYOKU_PATH directly.

Update install/config/all.sh and bin/ryoku-update-perform to call
the new script name.

The old install/config/inir.sh is deleted; no more network clone of
github.com/snowarch/iNiR at install time.
EOF
)"
```

Expected: commit succeeds.

---

## Chunk 3: Rename Runtime Artifacts

Wires the renamed runtime artifacts (already in `apps/ryoku-shell/` from chunk 1b) through the rest of the Ryoku source. Includes env var rename across both consumers with dual-export pattern for the migration window.

### Task 3.1: Rename Ryoku-tree systemd unit file

**Files:**
- Delete: `config/systemd/user/inir.service`
- Create: `config/systemd/user/ryoku-shell.service`

This is the Ryoku-tree copy of the unit (the vendored copy at `apps/ryoku-shell/assets/systemd/ryoku-shell.service` is the install source).

- [ ] **Step 1: Read the current Ryoku-tree unit**

```bash
cat $RYOKU_PATH/config/systemd/user/inir.service
```

- [ ] **Step 2: Rename via git mv and update unit Description**

```bash
cd $RYOKU_PATH
git mv config/systemd/user/inir.service config/systemd/user/ryoku-shell.service
```

Then edit the file to update internal references, `Description=Ryoku shell` (likely already), and the `ExecStart=%h/.local/bin/inir run --session` line should become `ExecStart=%h/.local/bin/ryoku-shell run --session`. Check:

```bash
grep -n "inir\|Description" $RYOKU_PATH/config/systemd/user/ryoku-shell.service
```

Update `ExecStart` line: replace `inir run --session` with `ryoku-shell run --session`. Update any other `inir` references inside the file to `ryoku-shell` (preserve any attribution comments).

Verify:

```bash
grep -n "inir" $RYOKU_PATH/config/systemd/user/ryoku-shell.service
```

Expected: zero hits, OR only attribution-context hits.

- [ ] **Step 3: Stage and commit**

```bash
cd $RYOKU_PATH
git add config/systemd/user/
git commit -m "$(cat <<'EOF'
config: rename systemd user unit inir.service → ryoku-shell.service

Ryoku-tree copy of the unit (the vendored copy at
apps/ryoku-shell/assets/systemd/ryoku-shell.service is the install source).
Update the ExecStart line to call ~/.local/bin/ryoku-shell, matching the
renamed launcher the vendored setup script will create.
EOF
)"
```

### Task 3.2: Rename env vars in `40-environment.kdl` with dual-export

**Files:**
- Modify: `config/niri/config.d/40-environment.kdl`

- [ ] **Step 1: Read the current file**

```bash
cat $RYOKU_PATH/config/niri/config.d/40-environment.kdl
```

Locate the `INIR_VENV` line and its surrounding comment block.

- [ ] **Step 2: Add `RYOKU_SHELL_VENV` alongside `INIR_VENV` (dual-export)**

Edit `config/niri/config.d/40-environment.kdl`. The current line:

```
    INIR_VENV "$HOME/.local/state/quickshell/.venv"
```

becomes (both exports for the migration window):

```
    // RYOKU_SHELL_VENV is the canonical name post-vendor; INIR_VENV is
    // kept as a transitional dual-export so unmigrated user shells still
    // resolve the venv. Both are removed in the dual-name cleanup follow-up
    // release once all hosts have run the chunk-7 migration.
    RYOKU_SHELL_VENV "$HOME/.local/state/quickshell/.venv"
    INIR_VENV "$HOME/.local/state/quickshell/.venv"
```

Also update the surrounding comment block, any line that says "iNiR" in context where it's referring to the runtime (not attribution) should become "Ryoku shell" / "ryoku-shell".

- [ ] **Step 3: Verify**

```bash
grep -n "RYOKU_SHELL_VENV\|INIR_VENV\|iNiR\|ryoku-shell" $RYOKU_PATH/config/niri/config.d/40-environment.kdl
```

Expected: both env var lines present; comment updates applied.

- [ ] **Step 4: Stage and commit**

```bash
cd $RYOKU_PATH
git add config/niri/config.d/40-environment.kdl
git commit -m "$(cat <<'EOF'
config(niri): export RYOKU_SHELL_VENV alongside INIR_VENV (dual-export)

Adds RYOKU_SHELL_VENV (canonical post-vendor) while keeping INIR_VENV as a
transitional dual-export so unmigrated user shells (and the matugen KDE
template until it's updated in the next commit) keep resolving the venv.

Both exports are removed in the dual-name cleanup follow-up release once
all hosts have run the chunk-7 migration.
EOF
)"
```

### Task 3.3: Update matugen KDE template with fallback chain

**Files:**
- Modify: `config/matugen/templates/kde/kde-material-you-colors-wrapper.sh`

- [ ] **Step 1: Read line 46 of the template**

```bash
grep -n "INIR_VENV\|ILLOGICAL_IMPULSE_VIRTUAL_ENV" $RYOKU_PATH/config/matugen/templates/kde/kde-material-you-colors-wrapper.sh
```

Current line 46:

```bash
source "$(eval echo ${INIR_VENV:-$ILLOGICAL_IMPULSE_VIRTUAL_ENV})/bin/activate"
```

- [ ] **Step 2: Replace with fallback chain**

Edit the file. The new line:

```bash
source "$(eval echo ${RYOKU_SHELL_VENV:-${INIR_VENV:-$ILLOGICAL_IMPULSE_VIRTUAL_ENV}})/bin/activate"
```

- [ ] **Step 3: Verify**

```bash
grep -n "RYOKU_SHELL_VENV\|INIR_VENV" $RYOKU_PATH/config/matugen/templates/kde/kde-material-you-colors-wrapper.sh
bash -n $RYOKU_PATH/config/matugen/templates/kde/kde-material-you-colors-wrapper.sh
```

Expected: the new fallback chain is on line 46; bash syntax check passes.

- [ ] **Step 4: Stage and commit**

```bash
cd $RYOKU_PATH
git add config/matugen/templates/kde/kde-material-you-colors-wrapper.sh
git commit -m "$(cat <<'EOF'
matugen: kde-material-you-colors wrapper falls back through both venv envs

Reads ${RYOKU_SHELL_VENV:-${INIR_VENV:-$ILLOGICAL_IMPULSE_VIRTUAL_ENV}}
so freshly-rendered templates work whether the calling shell exported
the new env (post-chunk-3 niri reload) or the legacy one (unmigrated
user session). Falls all the way through to the upstream
ILLOGICAL_IMPULSE_VIRTUAL_ENV name as the last resort.

The legacy INIR_VENV branch drops in the dual-name cleanup follow-up.
EOF
)"
```

### Task 3.4: Verify vendored `setup` launcher creation produces `~/.local/bin/ryoku-shell`

**Files:** none modified in this task, verification only

- [ ] **Step 1: Inspect the vendored setup script for launcher creation logic**

```bash
grep -n "local/bin\|launcher\|symlink\|ln -s" $RYOKU_PATH/apps/ryoku-shell/setup | head -20
```

If the launcher path is hardcoded as `~/.local/bin/inir`, OR it's derived from a variable that resolves to `inir`, edit the setup script to produce `~/.local/bin/ryoku-shell` instead. This is an in-tree edit to the vendored script (now Ryoku-owned).

If the launcher path is derived from the source directory name (e.g., `basename "$SHELL_PATH"`), then it will produce `~/.local/bin/ryoku-shell` automatically once `install/config/ryoku-shell.sh` syncs to `~/.local/share/ryoku-shell`. Verify this by tracing the variable.

- [ ] **Step 2: If a patch was needed, commit**

```bash
cd $RYOKU_PATH
git add apps/ryoku-shell/setup
git commit -m "$(cat <<'EOF'
apps/ryoku-shell: setup creates ~/.local/bin/ryoku-shell launcher

[Brief description of the patch that was needed, line numbers and
the before/after state of the launcher creation block.]
EOF
)"
```

If no patch was needed, skip this step and note in the chunk completion log: "vendored setup script already produces correct launcher path; no patch required."

### Task 3.5: Wire ryoku-shell.service into install/config/ryoku-shell.sh wants-dir (already done in chunk 2)

**Files:** none, verification that chunk 2 task 2.1 step 2's script content already covers this.

- [ ] **Step 1: Verify `install/config/ryoku-shell.sh` writes the wants symlink**

```bash
grep -A3 "shell_wants_dir" $RYOKU_PATH/install/config/ryoku-shell.sh
```

Expected: the script creates `$shell_wants_dir/ryoku-shell.service` symlink. If not present, fix and commit (this would indicate task 2.1 step 2 didn't fully apply).

---

## Chunk 4: Rename CLI Consumers

Renames every Ryoku-side script that calls `inir <verb>` or references `inir.service` / `inir.desktop` / `/quickshell/inir/`. Includes the dual-name fallback in lifecycle helpers.

### Task 4.1: `bin/ryoku-ipc` and lifecycle helpers (with dual-name fallback)

**Files:**
- Modify: `bin/ryoku-ipc`
- Modify: `bin/ryoku-restart-shell`
- Modify: `bin/ryoku-launch-shell`
- Modify: `bin/ryoku-refresh-quickshell`
- Modify: `bin/ryoku-restart-ui`

- [ ] **Step 1: Update `bin/ryoku-ipc`**

In `$RYOKU_PATH/bin/ryoku-ipc`, locate the `exec_inir` function (line ~40-47):

```bash
exec_inir() {
  if ! ryoku-cmd-present inir; then
    echo "ryoku-ipc: inir is not installed or not on PATH" >&2
    return 127
  fi

  exec inir "$@"
}
```

Rename function to `exec_ryoku_shell`, change CLI from `inir` to `ryoku-shell`:

```bash
exec_ryoku_shell() {
  if ! ryoku-cmd-present ryoku-shell; then
    echo "ryoku-ipc: ryoku-shell is not installed or not on PATH" >&2
    return 127
  fi

  exec ryoku-shell "$@"
}
```

Then replace every `exec_inir` call site in the same file with `exec_ryoku_shell`. There are ~10 call sites in dispatch functions (overview_dispatch, clipboard_dispatch, settings_dispatch, lock_dispatch, session_dispatch, launcher_dispatch, region_dispatch).

```bash
perl -pi -e 's/\bexec_inir\b/exec_ryoku_shell/g; s/exec inir "/exec ryoku-shell "/g; s/ryoku-cmd-present inir\b/ryoku-cmd-present ryoku-shell/g; s/ryoku-ipc: inir is not/ryoku-ipc: ryoku-shell is not/g' $RYOKU_PATH/bin/ryoku-ipc
```

Verify:

```bash
grep -n "inir\|ryoku-shell" $RYOKU_PATH/bin/ryoku-ipc
bash -n $RYOKU_PATH/bin/ryoku-ipc
```

Expected: no `inir` hits, multiple `ryoku-shell` hits; bash syntax OK.

- [ ] **Step 2: Update `bin/ryoku-restart-shell` with dual-name fallback**

Current content:

```bash
if ryoku-cmd-present systemctl && systemctl --user status inir.service >/dev/null 2>&1; then
  systemctl --user try-restart inir.service
elif ryoku-cmd-present inir; then
  inir restart
else
  echo "ryoku-restart-shell: inir is not installed or not on PATH" >&2
  exit 127
fi
```

Replace with dual-name fallback (try ryoku-shell first, fall back to inir):

```bash
if ryoku-cmd-present systemctl; then
  if systemctl --user status ryoku-shell.service >/dev/null 2>&1; then
    systemctl --user try-restart ryoku-shell.service
    exit 0
  fi
  # Dual-name fallback for unmigrated systems (chunk-7 migration not yet run).
  # Removed in the dual-name cleanup follow-up release.
  if systemctl --user status inir.service >/dev/null 2>&1; then
    systemctl --user try-restart inir.service
    exit 0
  fi
fi

if ryoku-cmd-present ryoku-shell; then
  ryoku-shell restart
elif ryoku-cmd-present inir; then
  # Dual-name fallback for unmigrated systems.
  inir restart
else
  echo "ryoku-restart-shell: ryoku-shell is not installed or not on PATH" >&2
  exit 127
fi
```

Verify:

```bash
bash -n $RYOKU_PATH/bin/ryoku-restart-shell
```

- [ ] **Step 3: Update `bin/ryoku-launch-shell` with dual-name fallback**

Current content:

```bash
# Compatibility launcher for the shell managed by iNiR.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"
exec inir run "$@"
```

Replace with:

```bash
# Compatibility launcher for the Ryoku shell.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

if ryoku-cmd-present ryoku-shell; then
  exec ryoku-shell run "$@"
elif ryoku-cmd-present inir; then
  # Dual-name fallback for unmigrated systems (chunk-7 migration not yet run).
  # Removed in the dual-name cleanup follow-up release.
  exec inir run "$@"
else
  echo "ryoku-launch-shell: ryoku-shell is not installed or not on PATH" >&2
  exit 127
fi
```

Verify:

```bash
bash -n $RYOKU_PATH/bin/ryoku-launch-shell
```

- [ ] **Step 4: Update `bin/ryoku-refresh-quickshell` with dual-name fallback**

Current content:

```bash
exec inir repair
```

Replace the trailing exec with:

```bash
if ryoku-cmd-present ryoku-shell; then
  exec ryoku-shell repair
elif ryoku-cmd-present inir; then
  # Dual-name fallback for unmigrated systems.
  exec inir repair
else
  echo "ryoku-refresh-quickshell: ryoku-shell is not installed or not on PATH" >&2
  exit 127
fi
```

Verify:

```bash
bash -n $RYOKU_PATH/bin/ryoku-refresh-quickshell
```

- [ ] **Step 5: Update `bin/ryoku-restart-ui`**

```bash
grep -n "inir" $RYOKU_PATH/bin/ryoku-restart-ui
```

The script likely calls `bin/ryoku-restart-shell` (which now has its own dual-name fallback). If `bin/ryoku-restart-ui` contains direct `inir.service` or `inir restart` references, update them with the dual-name fallback pattern. Otherwise (if it just calls `ryoku-restart-shell`), no change beyond what's already in step 2.

If updates are needed, edit and verify with `bash -n`.

- [ ] **Step 6: Stage and commit**

```bash
cd $RYOKU_PATH
git add bin/ryoku-ipc bin/ryoku-restart-shell bin/ryoku-launch-shell bin/ryoku-refresh-quickshell bin/ryoku-restart-ui
git commit -m "$(cat <<'EOF'
bin: rename inir → ryoku-shell in ipc + lifecycle helpers

ryoku-ipc: exec_inir → exec_ryoku_shell helper, all CLI calls flip
to ryoku-shell.

Lifecycle helpers (restart-shell, launch-shell, refresh-quickshell,
restart-ui) try ryoku-shell.service / ryoku-shell binary first, fall
back to inir.service / inir for unmigrated systems within the release
window. The fallback branches are removed in the dual-name cleanup
follow-up release once all hosts have run the chunk-7 migration.
EOF
)"
```

### Task 4.2: `bin/ryoku-shell-cleanup-orphans` (CLI call + runtime path patterns)

**Files:**
- Modify: `bin/ryoku-shell-cleanup-orphans`

- [ ] **Step 1: Read current content**

```bash
cat $RYOKU_PATH/bin/ryoku-shell-cleanup-orphans
```

Lines to update:
- Line 72-74: `if command_present inir; then inir cleanup-orphans ...`
- Line 78: `terminate_pattern '/quickshell/inir/scripts/daemon/keyboard_lock_state_daemon\.py' "keyboard indicator daemon"`
- Line 80: `terminate_pattern '/quickshell/inir/scripts/colors/switchwall\.sh' "wallpaper color worker"`

- [ ] **Step 2: Update CLI call (lines 72-74) with dual-name fallback**

Replace:

```bash
if command_present inir; then
  inir cleanup-orphans >/dev/null 2>&1 || true
fi
```

With:

```bash
if command_present ryoku-shell; then
  ryoku-shell cleanup-orphans >/dev/null 2>&1 || true
elif command_present inir; then
  # Dual-name fallback for unmigrated systems (chunk-7 migration not yet run).
  # Removed in the dual-name cleanup follow-up release.
  inir cleanup-orphans >/dev/null 2>&1 || true
fi
```

- [ ] **Step 3: Update runtime path patterns (lines 78, 80)**

Replace `/quickshell/inir/scripts/...` with `/quickshell/ryoku-shell/scripts/...` in both `terminate_pattern` calls. The leaf script names (`keyboard_lock_state_daemon.py`, `switchwall.sh`) stay the same.

For the dual-name window, processes spawned from unmigrated systems are still under `/quickshell/inir/`. To handle both, use a regex alternation:

```bash
terminate_pattern '/quickshell/(ryoku-shell|inir)/scripts/daemon/keyboard_lock_state_daemon\.py' "keyboard indicator daemon"
```

```bash
terminate_pattern '/quickshell/(ryoku-shell|inir)/scripts/colors/switchwall\.sh' "wallpaper color worker"
```

The legacy `inir` branch in the regex drops in the dual-name cleanup follow-up release.

- [ ] **Step 4: Verify**

```bash
grep -n "inir\|ryoku-shell" $RYOKU_PATH/bin/ryoku-shell-cleanup-orphans
bash -n $RYOKU_PATH/bin/ryoku-shell-cleanup-orphans
```

Expected: only ryoku-shell references plus the dual-name fallback branches; bash syntax OK.

- [ ] **Step 5: Stage and commit**

```bash
cd $RYOKU_PATH
git add bin/ryoku-shell-cleanup-orphans
git commit -m "$(cat <<'EOF'
bin: ryoku-shell-cleanup-orphans calls ryoku-shell + matches new path

Two changes (tightly coupled because both tie to the runtime dir rename):

1. CLI call: prefer 'ryoku-shell cleanup-orphans', fall back to
   'inir cleanup-orphans' for unmigrated systems.

2. pkill -f patterns for the keyboard indicator daemon and wallpaper
   color worker now match either /quickshell/ryoku-shell/scripts/...
   (post-migration) OR /quickshell/inir/scripts/... (pre-migration),
   via regex alternation. The leaf script names stay the same.

Both inir-side branches drop in the dual-name cleanup follow-up release.
EOF
)"
```

### Task 4.3: `bin/ryoku-cmd-*` wrappers

**Files:** every `bin/ryoku-cmd-*` script that calls `inir <verb>`

- [ ] **Step 1: Identify the affected scripts**

```bash
grep -l "\binir\b" $RYOKU_PATH/bin/ryoku-cmd-* 2>/dev/null
```

Expected list (from earlier audit): `ryoku-cmd-mic-mute`, `ryoku-cmd-audio-switch`, `ryoku-cmd-ocr`, `ryoku-cmd-screenrecord`, `ryoku-cmd-colorpicker`.

- [ ] **Step 2: For each script, replace `inir <verb>` with `ryoku-shell <verb>`**

For each file in the list, inspect:

```bash
grep -n "\binir\b" $RYOKU_PATH/bin/ryoku-cmd-mic-mute
```

Then update via Edit tool or perl. These scripts are typically one-liners calling `inir <subcommand>`. Example pattern:

```bash
for f in ryoku-cmd-mic-mute ryoku-cmd-audio-switch ryoku-cmd-ocr ryoku-cmd-colorpicker; do
  perl -pi -e 's/\binir\b/ryoku-shell/g' "$RYOKU_PATH/bin/$f"
done
```

For `ryoku-cmd-screenrecord` (which has both `inir` and `iNiR` per earlier grep), be careful: the `iNiR` mention may be a comment/attribution. Inspect first:

```bash
grep -n "inir\|iNiR" $RYOKU_PATH/bin/ryoku-cmd-screenrecord
```

Update only the runtime CLI call (`inir <verb>` → `ryoku-shell <verb>`); leave `iNiR` in attribution comments alone.

- [ ] **Step 3: Verify each script syntax-checks**

```bash
for f in ryoku-cmd-mic-mute ryoku-cmd-audio-switch ryoku-cmd-ocr ryoku-cmd-screenrecord ryoku-cmd-colorpicker; do
  bash -n "$RYOKU_PATH/bin/$f"
done
```

Expected: no output.

- [ ] **Step 4: Stage and commit**

```bash
cd $RYOKU_PATH
git add bin/ryoku-cmd-mic-mute bin/ryoku-cmd-audio-switch bin/ryoku-cmd-ocr bin/ryoku-cmd-screenrecord bin/ryoku-cmd-colorpicker
git commit -m "bin(cmd-*): rename inir CLI calls to ryoku-shell"
```

### Task 4.4: `bin/ryoku-launch-*` wrappers

**Files:** every `bin/ryoku-launch-*` script that calls `inir <verb>` (excluding `ryoku-launch-shell` which is in Task 4.1)

- [ ] **Step 1: Identify**

```bash
grep -l "\binir\b" $RYOKU_PATH/bin/ryoku-launch-* | grep -v ryoku-launch-shell
```

Expected: `ryoku-launch-clipboard`, `ryoku-launch-drun`.

- [ ] **Step 2: Replace `inir <verb>` with `ryoku-shell <verb>` in each**

```bash
for f in ryoku-launch-clipboard ryoku-launch-drun; do
  perl -pi -e 's/\binir\b/ryoku-shell/g' "$RYOKU_PATH/bin/$f"
  bash -n "$RYOKU_PATH/bin/$f"
done
```

- [ ] **Step 3: Stage and commit**

```bash
cd $RYOKU_PATH
git add bin/ryoku-launch-clipboard bin/ryoku-launch-drun
git commit -m "bin(launch-*): rename inir CLI calls to ryoku-shell"
```

### Task 4.5: Other `bin/ryoku-*` consumers

**Files:** every remaining `bin/ryoku-*` script with `inir` references, `ryoku-brightness-display`, `ryoku-dev-check-drift`, `ryoku-dev-verify-category1`, `ryoku-dev-verify-display`, `ryoku-lock-screen`, `ryoku-menu`, `ryoku-menu-keybindings`, `ryoku-notification-dismiss`, `ryoku-refresh-sddm`, `ryoku-shell-cleanup-orphans` (already done), `ryoku-system-logout`, `ryoku-theme-bg-next`, `ryoku-theme-bg-set`, `ryoku-theme-set-shell`, `ryoku-toggle-notification-silencing`, `ryoku-update-perform` (already partially done in chunk 2), `ryoku-volume`.

- [ ] **Step 1: Re-grep to get the current consumer set**

```bash
grep -lE "\binir\b|inir\.service|inir\.desktop|RYOKU_INIR|INIR_PATH" $RYOKU_PATH/bin/ryoku-* 2>/dev/null | grep -vE "ryoku-(ipc|restart-shell|launch-shell|refresh-quickshell|restart-ui|shell-cleanup-orphans|cmd-mic-mute|cmd-audio-switch|cmd-ocr|cmd-screenrecord|cmd-colorpicker|launch-clipboard|launch-drun|update-perform)$"
```

- [ ] **Step 2: For each script, classify each `inir` hit before replacing**

Each consumer needs careful inspection because some references are:
- CLI calls: `inir <verb>` → `ryoku-shell <verb>`
- Service file references: `inir.service` → `ryoku-shell.service`
- Path references: `~/.local/share/inir` → `~/.local/share/ryoku-shell`
- Env var references: `RYOKU_INIR_PATH` → `RYOKU_SHELL_PATH`, `INIR_PATH` → `RYOKU_SHELL_PATH`
- Attribution comments: leave alone

For each file, run `grep -n "inir\|iNiR\|INIR" <file>` and apply context-appropriate replacements one at a time. Use the Edit tool for precision rather than blanket perl substitution to avoid touching attribution.

Special cases to verify:
- `ryoku-refresh-sddm` (had `INIR_PATH`, `INIR_SDDM_AUTO_APPLY`, `RYOKU_INIR_PATH`, references to `iNiR`): the env vars rename to `RYOKU_SHELL_*` consistently; inspect carefully.
- `ryoku-update-perform`: chunk 2 already updated `config/inir.sh` → `config/ryoku-shell.sh`. Verify no other `inir` hits remain.
- `ryoku-dev-verify-display`, `ryoku-dev-verify-category1`, `ryoku-dev-check-drift`: dev tools that grep / verify the install state. They reference `inir.service`, `~/.local/share/inir`, `~/.config/quickshell/inir/`, `inir.service.d`. Update each to the new names. These tools may also need a dual-name fallback; for v1, just rename to the new names, these are dev tools and the user can re-run after migration.

- [ ] **Step 3: Verify with grep + syntax-check**

```bash
grep -lE "\binir\b|inir\.service|inir\.desktop|RYOKU_INIR|INIR_PATH" $RYOKU_PATH/bin/ryoku-* 2>/dev/null
```

Expected: empty (or only matches that are explicit dual-name fallback branches you intentionally added).

```bash
for f in $(git diff --name-only --cached -- bin/); do bash -n "$f"; done
```

Expected: no errors.

- [ ] **Step 4: Stage and commit**

```bash
cd $RYOKU_PATH
git add -u bin/
git commit -m "$(cat <<'EOF'
bin: rename inir → ryoku-shell across remaining helpers

Updates the remaining bin/ryoku-* scripts that referenced inir CLI,
inir.service, ~/.local/share/inir, ~/.config/quickshell/inir/, the
INIR_PATH env, or RYOKU_INIR_* envs:

[paste the file list from `git diff --name-only --cached -- bin/`]

Attribution comments are preserved. Dev tools (ryoku-dev-*) are
renamed to the new path/unit names; their callers (the user) re-run
after migration.
EOF
)"
```

### Task 4.6: niri keybinds (`70-binds.kdl`) spawn calls + comments

**Files:**
- Modify: `config/niri/config.d/70-binds.kdl`

- [ ] **Step 1: Read current spawn calls**

```bash
grep -n 'spawn "inir"' $RYOKU_PATH/config/niri/config.d/70-binds.kdl
```

Expected: ~20 hits.

- [ ] **Step 2: Replace all `spawn "inir"` with `spawn "ryoku-shell"`**

```bash
perl -pi -e 's/spawn "inir"/spawn "ryoku-shell"/g' $RYOKU_PATH/config/niri/config.d/70-binds.kdl
```

- [ ] **Step 3: Update comment lines that mention iNiR/inir as the runtime**

Re-grep:

```bash
grep -n "inir\|iNiR" $RYOKU_PATH/config/niri/config.d/70-binds.kdl
```

For each comment line referring to "iNiR's launcher" / "iNiR's overview" / "iNiR shell overlays" etc., replace "iNiR" with "Ryoku shell" (or "ryoku-shell" where the lowercase command name reads better). Leave attribution-context references alone (there shouldn't be any in keybind config; double-check).

- [ ] **Step 4: Verify**

```bash
grep -n "inir\|iNiR\|ryoku-shell" $RYOKU_PATH/config/niri/config.d/70-binds.kdl | head -40
```

Expected: zero `inir` / `iNiR` hits, ~20 `ryoku-shell` spawn lines, comments updated.

- [ ] **Step 5: Stage and commit**

```bash
cd $RYOKU_PATH
git add config/niri/config.d/70-binds.kdl
git commit -m "config(niri): keybinds spawn ryoku-shell, not inir"
```

### Task 4.7: niri startup (`50-startup.kdl`) comments

**Files:**
- Modify: `config/niri/config.d/50-startup.kdl`

- [ ] **Step 1: Update the comment block referring to "iNiR shell"**

```bash
grep -n "inir\|iNiR" $RYOKU_PATH/config/niri/config.d/50-startup.kdl
```

The file has a comment block:

```
// ── iNiR shell ──────────────────────────────────────────────────────────────
// iNiR is managed by the user systemd service (inir.service).
// Do not add a compositor startup entry here or you'll get two shells.
```

Update to:

```
// ── Ryoku shell ─────────────────────────────────────────────────────────────
// Ryoku shell is managed by the user systemd service (ryoku-shell.service).
// Do not add a compositor startup entry here or you'll get two shells.
```

Also check the cliphist-related comment line ("Access via iNiR's clipboard overlay (Mod+V)") and the polkit comment line ("iNiR's setup auto-detects ..."). Update both to "Ryoku shell" framing.

- [ ] **Step 2: Verify**

```bash
grep -n "inir\|iNiR\|Ryoku shell" $RYOKU_PATH/config/niri/config.d/50-startup.kdl
```

Expected: zero `inir`/`iNiR` hits; multiple `Ryoku shell` comment lines.

- [ ] **Step 3: Stage and commit**

```bash
cd $RYOKU_PATH
git add config/niri/config.d/50-startup.kdl
git commit -m "config(niri): startup comments say Ryoku shell, not iNiR"
```

---

## Chunk 5: ISO Build

Drops `RYOKU_INIR_REPO`, the `/inir` mount, the upstream-clone fallback, and the `/root/inir` copy step. The vendored tree at `apps/ryoku-shell/` is included automatically via the existing Ryoku source bundling.

### Task 5.1: `iso/builder/build-iso.sh`

**Files:**
- Modify: `iso/builder/build-iso.sh`

- [ ] **Step 1: Remove `RYOKU_INIR_REPO` declaration and the `/inir` mount handling**

In `$RYOKU_PATH/iso/builder/build-iso.sh`, delete:

- Line 36: `RYOKU_INIR_REPO="${RYOKU_INIR_REPO:-https://github.com/snowarch/iNiR.git}"`
- Lines 45-49 (the entire `/inir` mount handling block):
  ```bash
  if [[ -d /inir ]]; then
    /bin/bash /builder/sync-local-source.sh /inir "$build_cache_dir/airootfs/root/inir"
  else
    git clone "$RYOKU_INIR_REPO" "$build_cache_dir/airootfs/root/inir"
  fi
  ```

- [ ] **Step 2: Re-point the uv prefetch to the vendored tree**

Lines 51-59 currently read `inir_requirements="$build_cache_dir/airootfs/root/inir/sdata/uv/requirements.txt"`. After step 1, `airootfs/root/inir` doesn't exist anymore. The vendored tree is bundled inside the Ryoku source at `airootfs/root/ryoku/apps/ryoku-shell/`. Update:

Replace lines 51-59 with:

```bash
shell_requirements="$build_cache_dir/airootfs/root/ryoku/apps/ryoku-shell/sdata/uv/requirements.txt"
shell_uv_cache="$build_cache_dir/airootfs/var/cache/ryoku/uv"
if [[ -f $shell_requirements ]]; then
  mkdir -p "$shell_uv_cache"
  shell_uv_venv=$(mktemp -d)
  UV_CACHE_DIR="$shell_uv_cache" uv venv --prompt ryoku-shell-cache "$shell_uv_venv"
  VIRTUAL_ENV="$shell_uv_venv" UV_CACHE_DIR="$shell_uv_cache" uv pip install -r "$shell_requirements"
  rm -rf "$shell_uv_venv"
fi
```

(Renamed variable prefix `inir_*` → `shell_*` and `inir-cache` prompt → `ryoku-shell-cache` for clarity.)

- [ ] **Step 3: Verify**

```bash
grep -n "inir\|iNiR\|RYOKU_INIR" $RYOKU_PATH/iso/builder/build-iso.sh
bash -n $RYOKU_PATH/iso/builder/build-iso.sh
```

Expected: zero `inir`/`iNiR`/`RYOKU_INIR` hits; bash syntax OK.

- [ ] **Step 4: Stage and commit**

```bash
cd $RYOKU_PATH
git add iso/builder/build-iso.sh
git commit -m "$(cat <<'EOF'
iso(build): drop snowarch/iNiR clone; uv prefetch reads from vendored tree

Removes RYOKU_INIR_REPO, the /inir bind-mount handling, and the upstream
git-clone fallback for the iNiR source. The vendored apps/ryoku-shell/
tree is bundled into the ISO via the existing Ryoku source copy at
airootfs/root/ryoku/, so no separate copy step is needed.

The Python uv prefetch now reads requirements.txt from the bundled
apps/ryoku-shell/sdata/uv/ path instead of the previously-cloned
airootfs/root/inir/sdata/uv/ path. Same offline-cache behavior, same
target dir (airootfs/var/cache/ryoku/uv).
EOF
)"
```

### Task 5.2: `iso/bin/ryoku-iso-make`

**Files:**
- Modify: `iso/bin/ryoku-iso-make`

- [ ] **Step 1: Remove `RYOKU_INIR_REPO` and `/inir` mount handling**

```bash
grep -n "INIR\|inir\|iNiR" $RYOKU_PATH/iso/bin/ryoku-iso-make
```

Expected hits at lines ~54, 64, 78-83. Delete:

- Line 54: `RYOKU_INIR_REPO="${RYOKU_INIR_REPO:-https://github.com/snowarch/iNiR.git}"`
- Line 64: `-e "RYOKU_INIR_REPO=$RYOKU_INIR_REPO"` (in the docker args block)
- Lines 78-83 (the entire INIR_SOURCE block):
  ```bash
  INIR_SOURCE="${RYOKU_INIR_SOURCE:-$HOME/.local/share/inir}"
  if [[ -d $INIR_SOURCE/.git ]]; then
    DOCKER_ARGS+=(-v "$INIR_SOURCE:/inir:ro")
  else
    echo "[error] no INIR source available; build will need network."
    echo "Set RYOKU_INIR_SOURCE or install iNiR at ~/.local/share/inir." >&2
    [...rest of error message...]
  fi
  ```

- [ ] **Step 2: Verify**

```bash
grep -n "inir\|iNiR\|INIR" $RYOKU_PATH/iso/bin/ryoku-iso-make
bash -n $RYOKU_PATH/iso/bin/ryoku-iso-make
```

Expected: zero hits; bash syntax OK.

- [ ] **Step 3: Stage and commit**

```bash
cd $RYOKU_PATH
git add iso/bin/ryoku-iso-make
git commit -m "$(cat <<'EOF'
iso(make): drop RYOKU_INIR_* env handling and /inir bind mount

The vendored apps/ryoku-shell/ tree ships inside the Ryoku source bundle
that ryoku-iso-make already mounts. No separate iNiR checkout, no docker
env passthrough.
EOF
)"
```

### Task 5.3: `iso/configs/airootfs/root/.automated_script.sh`

**Files:**
- Modify: `iso/configs/airootfs/root/.automated_script.sh`

- [ ] **Step 1: Remove the `/root/inir` copy step**

```bash
grep -n "inir" $RYOKU_PATH/iso/configs/airootfs/root/.automated_script.sh
```

Expected hits at lines ~161-162:

```bash
if [[ -d /root/inir ]]; then
  cp -r /root/inir /mnt/home/$RYOKU_USER/.local/share/
fi
```

Delete the entire `if` block. The vendored tree ships inside the Ryoku source copy that the installer already lays down, and `install/config/ryoku-shell.sh` syncs from there to `~/.local/share/ryoku-shell/`.

- [ ] **Step 2: Verify**

```bash
grep -n "inir" $RYOKU_PATH/iso/configs/airootfs/root/.automated_script.sh
bash -n $RYOKU_PATH/iso/configs/airootfs/root/.automated_script.sh
```

Expected: zero hits; bash syntax OK.

- [ ] **Step 3: Stage and commit**

```bash
cd $RYOKU_PATH
git add iso/configs/airootfs/root/.automated_script.sh
git commit -m "$(cat <<'EOF'
iso(installer): drop /root/inir → ~/.local/share/inir copy

apps/ryoku-shell/ ships inside the Ryoku source copy. The new
install/config/ryoku-shell.sh syncs from $RYOKU_PATH/apps/ryoku-shell/
to ~/.local/share/ryoku-shell/ on first install, so no per-installer
copy step is needed.
EOF
)"
```

---

## Chunk 6: Distro / PKGBUILD

Updates the two distro packages that reference iNiR, `quickshell-ryoku` (description framing) and `qt6-qiooperation-patch` (systemd drop-in path).

### Task 6.1: `quickshell-ryoku` PKGBUILD

**Files:**
- Modify: `distro/arch/quickshell-ryoku/PKGBUILD`

- [ ] **Step 1: Update description and DISTRIBUTOR strings**

```bash
grep -n "inir\|iNiR" $RYOKU_PATH/distro/arch/quickshell-ryoku/PKGBUILD
```

Apply these edits to `$RYOKU_PATH/distro/arch/quickshell-ryoku/PKGBUILD`:

- Header comment block (lines ~3-22): the references to "iNiR project" and "iNiR's panel-family system" can be reworked to talk about "Ryoku shell" + the Quickshell IpcHandlerRegistry context. The patch itself is a Quickshell upstream patch (no iNiR semantics); the comment just needs to remove the iNiR-as-external-project framing. Edit to:
  - Replace "the iNiR project's `fix-extension-uaf.patch`" with "Ryoku's `fix-extension-uaf.patch`"
  - Replace "iNiR's panel-family system + 50+ IpcHandlers" with "the Ryoku shell's panel-family system + 50+ IpcHandlers"

- Line 27 (pkgdesc): replace `'(iNiR fix-extension-uaf patch applied)'` with `'(ryoku-shell fix-extension-uaf patch applied)'`

- Line 69 (DISTRIBUTOR): replace `'Ryoku Arch (iNiR-patched)'` with `'Ryoku Arch (ryoku-shell-patched)'`

The `fix-extension-uaf.patch` filename stays, it's a Quickshell patch, not iNiR-specific.

- [ ] **Step 2: Verify**

```bash
grep -n "inir\|iNiR" $RYOKU_PATH/distro/arch/quickshell-ryoku/PKGBUILD
```

Expected: zero hits.

- [ ] **Step 3: Stage and commit**

```bash
cd $RYOKU_PATH
git add distro/arch/quickshell-ryoku/PKGBUILD
git commit -m "$(cat <<'EOF'
distro(quickshell-ryoku): drop iNiR-as-external-project framing

PKGBUILD pkgdesc and DISTRIBUTOR strings now say "ryoku-shell" instead
of "iNiR" since the shell is vendored. fix-extension-uaf.patch filename
stays, it's a Quickshell upstream patch.
EOF
)"
```

### Task 6.2: `qt6-qiooperation-patch` (apply.sh, verify.sh, README.md)

**Files:**
- Modify: `distro/arch/qt6-qiooperation-patch/apply.sh`
- Modify: `distro/arch/qt6-qiooperation-patch/verify.sh`
- Modify: `distro/arch/qt6-qiooperation-patch/README.md`

- [ ] **Step 1: Update `apply.sh`, rename systemd drop-in dir paths**

```bash
grep -n "inir\.service" $RYOKU_PATH/distro/arch/qt6-qiooperation-patch/apply.sh
```

Apply edits to `$RYOKU_PATH/distro/arch/qt6-qiooperation-patch/apply.sh`:
- Line 29: `readonly DROPIN_DIR="$HOME/.config/systemd/user/inir.service.d"` → `readonly DROPIN_DIR="$HOME/.config/systemd/user/ryoku-shell.service.d"`
- Line 91 (heredoc comment): `# Wires inir.service to the patched libQt6Core ...` → `# Wires ryoku-shell.service to the patched libQt6Core ...`
- Lines 105-108: `systemctl --user reset-failed inir.service` → `systemctl --user reset-failed ryoku-shell.service`; `is-active --quiet inir.service` → `is-active --quiet ryoku-shell.service`; `restart inir.service` → `restart ryoku-shell.service`

The header comment block (lines 1-23) references "iNiR / Ryoku" as the original debugging context, that's attribution; leave the iNiR mention alone.

- [ ] **Step 2: Update `verify.sh` similarly**

```bash
grep -n "inir\.service\|inir" $RYOKU_PATH/distro/arch/qt6-qiooperation-patch/verify.sh
```

Apply matching path renames: `inir.service.d/` → `ryoku-shell.service.d/`, `inir.service` → `ryoku-shell.service`.

- [ ] **Step 3: Update `README.md`**

```bash
grep -n "inir\.service\|inir" $RYOKU_PATH/distro/arch/qt6-qiooperation-patch/README.md
```

Apply matching renames for any path/service references inside install instructions. iNiR-as-debugging-context attribution (e.g., "this bug was found while running iNiR ...") stays.

- [ ] **Step 4: Verify all three files**

```bash
grep -n "inir\.service\|/inir\.service\.d/" $RYOKU_PATH/distro/arch/qt6-qiooperation-patch/{apply.sh,verify.sh,README.md}
bash -n $RYOKU_PATH/distro/arch/qt6-qiooperation-patch/{apply.sh,verify.sh}
```

Expected: zero `inir.service`/`inir.service.d/` hits; bash syntax OK on apply.sh and verify.sh.

- [ ] **Step 5: Stage and commit**

```bash
cd $RYOKU_PATH
git add distro/arch/qt6-qiooperation-patch/
git commit -m "$(cat <<'EOF'
distro(qt6-qiooperation-patch): write to ryoku-shell.service.d/

apply.sh / verify.sh / README.md update the systemd drop-in dir from
~/.config/systemd/user/inir.service.d/ to ryoku-shell.service.d/, and
the systemctl invocations target ryoku-shell.service.

The header attribution comments referencing the iNiR debugging context
where this bug was found are preserved (historical attribution).
EOF
)"
```

---

## Chunk 7: Live-System Migration

One commit. The migration script must land atomically, partial migration scripts leave ambiguous state.

### Task 7.1: Write the migration script

**Files:**
- Create: `migrations/<epoch>.sh` (epoch = `date +%s` at commit time, must be > `1777852554`)

- [ ] **Step 1: Capture current epoch as the migration filename**

```bash
date +%s
```

Use this value as the migration filename. Example: if the value is `1777860000`, the file is `migrations/1777860000.sh`. (Document the value used in the commit body.)

- [ ] **Step 2: Read `migrations/1777776000.sh` to understand the migration runner contract**

```bash
cat $RYOKU_PATH/migrations/1777776000.sh
```

Note the conventions: no shebang, no `set -e`, uses `$RYOKU_PATH` env (sourced by the runner), uses `echo` for status, `exit 0` would be unusual (migrations typically run to completion or use early-return via `if`).

Important: the migration runner sources the script in a sub-shell, so `exit 0` / `exit 1` are acceptable but consider whether they affect the parent runner. Inspect `bin/ryoku-migrate` to confirm behavior. Use `return` in functions and explicit success/failure logging in the body.

- [ ] **Step 3: Create the migration script**

Create `$RYOKU_PATH/migrations/<epoch>.sh` (replace `<epoch>` with the captured value):

```bash
echo "Migrate iNiR shell to vendored ryoku-shell"

# Detect state. -e covers both real dirs and symlinks for the legacy path.
if [[ ! -e $HOME/.local/share/inir && -d $HOME/.local/share/ryoku-shell ]]; then
  echo "  already migrated"
  return 0 2>/dev/null || exit 0
fi

if [[ ! -e $HOME/.local/share/inir && ! -d $HOME/.local/share/ryoku-shell ]]; then
  echo "  no shell installed; install/config/ryoku-shell.sh handles next update"
  return 0 2>/dev/null || exit 0
fi

# Refuse to auto-migrate a custom dev checkout (symlink).
if [[ -L $HOME/.local/share/inir ]]; then
  echo "  ~/.local/share/inir is a symlink to $(readlink -f $HOME/.local/share/inir)" >&2
  echo "  abort: refuse to auto-migrate a custom dev checkout" >&2
  echo "  remove the symlink and re-run: rm $HOME/.local/share/inir" >&2
  return 1 2>/dev/null || exit 1
fi

# Snapshot gate (best-effort).
if command -v ryoku-snapshot >/dev/null 2>&1; then
  ryoku-snapshot create "pre-ryoku-shell-rename" 2>&1 || \
    echo "  warning: snapshot create failed, proceeding"
else
  echo "  warning: ryoku-snapshot unavailable, proceeding"
fi

# Stop legacy service. Don't delete the wants symlink yet, that's the
# rollback signal in case the new service fails.
systemctl --user stop inir.service 2>/dev/null || true

# Carry over user state BEFORE touching anything else.
mkdir -p $HOME/.config/ryoku-shell
if [[ -f $HOME/.config/inir/config.json && ! -f $HOME/.config/ryoku-shell/config.json ]]; then
  cp -a $HOME/.config/inir/config.json $HOME/.config/ryoku-shell/config.json
fi

# Invalidate Python venv. May contain shebangs / .pth files / pip-recorded
# paths referencing ~/.local/share/inir/. The new setup regenerates it.
rm -rf $HOME/.local/state/quickshell/.venv

# Run the new install (lays down vendored tree, writes ryoku-shell.service,
# creates ~/.local/bin/ryoku-shell, writes the new wants symlink).
if ! bash $RYOKU_PATH/install/config/ryoku-shell.sh; then
  echo "  install/config/ryoku-shell.sh failed; legacy paths preserved" >&2
  return 1 2>/dev/null || exit 1
fi

# Migrate the niri.service.wants symlink.
rm -f $HOME/.config/systemd/user/niri.service.wants/inir.service

# Migrate the Qt6 patch drop-in (only if previously applied).
if [[ -d $HOME/.config/systemd/user/inir.service.d ]]; then
  mkdir -p $HOME/.config/systemd/user/ryoku-shell.service.d
  for f in $HOME/.config/systemd/user/inir.service.d/*; do
    [[ -f $f ]] || continue
    target=$HOME/.config/systemd/user/ryoku-shell.service.d/$(basename "$f")
    [[ -f $target ]] && continue
    cp -a "$f" "$target"
  done
fi

# Daemon-reload + start new service.
systemctl --user daemon-reload
systemctl --user start ryoku-shell.service

# Verification gate, wait up to 10s for new service to become active.
for i in 1 2 3 4 5 6 7 8 9 10; do
  systemctl --user is-active --quiet ryoku-shell.service && break
  sleep 1
done
if ! systemctl --user is-active --quiet ryoku-shell.service; then
  echo "  ryoku-shell.service failed to start; legacy paths preserved" >&2
  echo "  rollback: 'systemctl --user start inir.service' to restore old shell" >&2
  return 1 2>/dev/null || exit 1
fi

# Cleanup legacy paths. Only reached after the verification gate passed.
# Step 1 already verified ~/.local/share/inir is not a symlink, so rm -rf
# is safe.
rm -rf $HOME/.local/share/inir
rm -rf $HOME/.config/quickshell/inir
rm -rf $HOME/.config/inir
rm -rf $HOME/.config/systemd/user/inir.service.d
rm -f  $HOME/.config/systemd/user/inir.service
rm -f  $HOME/.local/bin/inir
rm -f  $HOME/.local/share/applications/inir.desktop
rm -f  $HOME/.local/share/icons/hicolor/scalable/apps/inir.svg

# Final daemon-reload to clear any stale unit references.
systemctl --user daemon-reload

echo "  migrated to ryoku-shell.service"
```

- [ ] **Step 4: Syntax-check**

```bash
bash -n $RYOKU_PATH/migrations/<epoch>.sh
```

Expected: no output.

- [ ] **Step 5: DRY-RUN, verify on a snapshot before live run**

DO NOT run the migration directly on the dev machine before chunks 1-6 are landed and tested. The dry-run is for verification of the script's logic flow.

If a snapshot is available:

```bash
ryoku-snapshot create "pre-migration-dryrun"
# Run the migration in a controlled way. The migration is designed to be
# safe (snapshot gate + verification before cleanup). If anything goes
# wrong, snapper rollback restores the pre-migration state.
RYOKU_PATH=$RYOKU_PATH bash $RYOKU_PATH/migrations/<epoch>.sh
```

If the migration fails, the user has the snapper snapshot. If it succeeds, the live system is now on `ryoku-shell.service`. Verify with `systemctl --user is-active ryoku-shell.service` and `~/.local/bin/ryoku-shell --help`.

If you don't want to run live yet (preferred order: land all chunks first, then run live migration via `ryoku-update`), skip this step.

- [ ] **Step 6: Stage and commit**

```bash
cd $RYOKU_PATH
git add migrations/<epoch>.sh
git commit -m "$(cat <<'EOF'
migrations(<epoch>): cut over inir → ryoku-shell on installed systems

Atomic, snapshot-gated, idempotent migration that:
1. Refuses to touch ~/.local/share/inir if it's a symlink (dev checkout).
2. Stops inir.service.
3. Carries over ~/.config/inir/config.json → ~/.config/ryoku-shell/.
4. Invalidates ~/.local/state/quickshell/.venv (paths may be stale).
5. Runs install/config/ryoku-shell.sh to lay down the vendored tree.
6. Re-points the niri.service.wants symlink.
7. Migrates the Qt6 patch drop-in (if applied).
8. Starts ryoku-shell.service.
9. Verification gate: waits up to 10s for active state.
10. Only after the gate passes: removes ~/.local/share/inir,
    ~/.config/quickshell/inir, ~/.config/inir, the legacy systemd unit,
    drop-in dir, launcher, desktop file, and icon.

If the new service fails to activate, legacy paths are preserved and
'systemctl --user start inir.service' restores the old shell.

The existing migrations/1777776000.sh (resume-recovery tuning of
inir.service) is unchanged: its own [[ -f $tmp_service ]] guard makes
it a no-op on post-cutover hosts. The same final-state tuning is baked
into apps/ryoku-shell/assets/systemd/ryoku-shell.service in chunk 1b.
EOF
)"
```

---

## Chunk 8: Tests + Heritage Doc + Final Sweep

In-place rewrite of the test contract; auxiliary test updates; heritage doc; README credits update; deletion of the no-longer-used branding script and TSV.

### Task 8.1: In-place rewrite of `tests/niri-inir-merge-readiness.sh`

**Files:**
- Modify: `tests/niri-inir-merge-readiness.sh` (file kept; not renamed)

- [ ] **Step 1: Read the current test file**

```bash
cat $RYOKU_PATH/tests/niri-inir-merge-readiness.sh | head -100
```

The test has ~75 assertions organized into sections:
- Removed-package list (Hyprland-era), KEEP unchanged
- Required-base-package list, KEEP, but verify `quickshell` etc. still required
- Old-default-paths-absent, KEEP, but check if `apps/ryoku-shell` should NOT be in this list (it should exist, not be absent)
- Preserved-screensaver-paths, KEEP unchanged
- New-backend-paths, UPDATE: `config/systemd/user/inir.service` → `config/systemd/user/ryoku-shell.service`
- Per-script assertions (lines ~349-430+), UPDATE many

- [ ] **Step 2: Update path references in the file**

Apply these substitutions:

a) `config/systemd/user/inir.service` → `config/systemd/user/ryoku-shell.service` (in the new_backend_paths array around line 336):

```bash
perl -pi -e 's|config/systemd/user/inir\.service|config/systemd/user/ryoku-shell.service|g' $RYOKU_PATH/tests/niri-inir-merge-readiness.sh
```

b) `install/config/inir.sh` → `install/config/ryoku-shell.sh` in `assert_executable` and `bash -n` lines (around line 355, 370):

```bash
perl -pi -e 's|install/config/inir\.sh|install/config/ryoku-shell.sh|g' $RYOKU_PATH/tests/niri-inir-merge-readiness.sh
```

- [ ] **Step 3: Flip the `assert_contains install/config/...sh` block**

Around lines 374, 383-388, the test asserts that `install/config/inir.sh` contains the upstream-clone behaviors (RYOKU_INIR_SOURCE, INIR_PATH, fallback chain, network clone). After chunk 2, the new `install/config/ryoku-shell.sh` does NOT have these. Replace the block:

```
assert_contains install/config/all.sh 'config/inir\.sh' "..."
assert_contains install/config/inir.sh 'RYOKU_INIR_SOURCE' "..."
assert_contains install/config/inir.sh 'INIR_PATH' "..."
assert_contains install/config/inir.sh 'RYOKU_CHROOT_INSTALL|RYOKU_INIR_REQUIRE_LOCAL_SOURCE' "..."
assert_contains install/config/inir.sh '/root/inir|/opt/ryoku/inir|vendor/inir' "..."
assert_contains install/config/inir.sh 'niri\.service\.wants' "..."
assert_contains install/config/inir.sh 'UV_CACHE_DIR|UV_OFFLINE' "..."
```

Replace with:

```
assert_contains install/config/all.sh 'config/ryoku-shell\.sh' "installer should run the Ryoku shell vendor-copy installer"
assert_contains install/config/ryoku-shell.sh 'apps/ryoku-shell' "installer should rsync from the vendored shell tree"
assert_not_contains install/config/ryoku-shell.sh 'github\.com/snowarch/iNiR' "installer must not clone from upstream"
assert_not_contains install/config/ryoku-shell.sh 'RYOKU_INIR_REPO|/root/inir|/opt/ryoku/inir|vendor/inir' "installer must not have an upstream-clone fallback chain"
assert_contains install/config/ryoku-shell.sh 'niri\.service\.wants' "installer should wire ryoku-shell.service into niri.service.wants for first login"
assert_contains install/config/ryoku-shell.sh 'UV_CACHE_DIR|UV_OFFLINE' "installer should use the ISO-bundled uv cache in chroot installs"
```

- [ ] **Step 4: Flip the ISO-build assertions (lines ~389-393)**

Original (asserts upstream-clone behavior in build-iso.sh and ryoku-iso-make):

```
assert_contains iso/bin/ryoku-iso-make '/inir:ro' "..."
assert_contains iso/builder/build-iso.sh 'RYOKU_INIR_REPO|github\.com/snowarch/iNiR' "..."
assert_contains iso/builder/build-iso.sh 'sdata/uv/requirements\.txt|UV_CACHE_DIR' "..."
assert_contains iso/builder/build-iso.sh 'root/inir' "..."
assert_contains iso/configs/airootfs/root/.automated_script.sh '/var/cache/ryoku/uv' "..."
assert_contains iso/configs/airootfs/root/.automated_script.sh '/root/inir' "..."
```

Replace with:

```
assert_not_contains iso/bin/ryoku-iso-make '/inir:ro|RYOKU_INIR' "ryoku-iso-make must not mount a separate iNiR checkout"
assert_not_contains iso/builder/build-iso.sh 'RYOKU_INIR_REPO|github\.com/snowarch/iNiR' "build-iso must not clone the upstream iNiR repo"
assert_contains iso/builder/build-iso.sh 'apps/ryoku-shell/sdata/uv/requirements\.txt|UV_CACHE_DIR' "build-iso should prefetch shell Python deps from the vendored tree"
assert_contains iso/configs/airootfs/root/.automated_script.sh '/var/cache/ryoku/uv' "ISO installer should bind the bundled uv cache into the installed system"
assert_not_contains iso/configs/airootfs/root/.automated_script.sh '/root/inir' "ISO installer must not copy a separate /root/inir into the user home"
```

- [ ] **Step 5: Flip the per-script assertions (lines ~395-417)**

Update each `assert_contains` / `assert_not_contains` line that names `inir.service` / `inir restart` / `inir lock activate` / `inir session toggle` / `inir cleanup-orphans` / `INIR_PATH`. The post-cutover assertions should reference `ryoku-shell.service` / `ryoku-shell <verb>` etc., and (importantly) should ALLOW the dual-name fallback to be present. Use `assert_contains` with a regex alternation:

Examples:

```
assert_contains bin/ryoku-restart-shell 'ryoku-shell\.service|ryoku-shell restart' "ryoku-restart-shell should target the Ryoku shell"
assert_contains bin/ryoku-shell-cleanup-orphans 'ryoku-shell cleanup-orphans' "Ryoku cleanup should preserve upstream shell runtime cleanup"
assert_contains bin/ryoku-lock-screen 'ryoku-shell lock activate' "lock screen should use the Ryoku shell lock"
assert_contains bin/ryoku-system-logout 'ryoku-shell session (toggle|open)' "logout command should open the Ryoku shell session UI"
assert_contains bin/ryoku-refresh-sddm 'ii-pixel|install-pixel-sddm|ryoku-shell' "SDDM refresh should apply the ii-pixel theme via the Ryoku shell"
```

The dual-name fallback branches are silently allowed by these assertions (they require the new name to be present, but don't fail if the legacy name is also present in fallback branches).

- [ ] **Step 6: Add new vendoring assertions**

Append to the test file (before the final `pass` line) a block that asserts the vendored tree exists and the branding script is gone:

```bash
# Ryoku shell vendoring assertions
assert_file apps/ryoku-shell/setup
assert_executable apps/ryoku-shell/setup
assert_file apps/ryoku-shell/assets/systemd/ryoku-shell.service
assert_file apps/ryoku-shell/assets/applications/ryoku-shell.desktop
assert_file apps/ryoku-shell/LICENSE

# The branding patch script and its TSV are deleted in chunk 8.
[[ ! -f install/config/ryoku-shell-branding.sh ]] || fail "install/config/ryoku-shell-branding.sh should be deleted post-vendor"
[[ ! -f default/ryoku-shell/branding-replacements.tsv ]] || fail "default/ryoku-shell/branding-replacements.tsv should be deleted post-vendor"

# No active source code should reference the upstream URL outside the vendored tree, docs, NOTICE/LICENSE/CREDITS/README.
if grep -rE 'github\.com/snowarch/iNiR|snowarch/iNiR' \
     --include='*.sh' --include='*.kdl' --include='*.qml' \
     --include='*.toml' --include='*.json' --include='*.css' \
     --include='*.conf' --include='*.service' --include='*.desktop' \
     --include='*.packages' \
     bin/ config/ default/ install/ iso/ tests/ migrations/ distro/ lib/ >/dev/null; then
  fail "active source must not reference upstream snowarch/iNiR repo"
fi
```

- [ ] **Step 7: Update the final `pass` message**

Last line of the test reads `pass "Niri/iNiR merge readiness contract"`. Update to:

```
pass "Ryoku shell vendoring + Niri config baseline contract"
```

- [ ] **Step 8: Run the test**

```bash
cd $RYOKU_PATH
bash tests/niri-inir-merge-readiness.sh
```

Expected: `OK: ...` lines, ending with `OK: Ryoku shell vendoring + Niri config baseline contract`. Any FAIL means an earlier chunk didn't apply correctly; trace and fix.

- [ ] **Step 9: Stage and commit**

```bash
cd $RYOKU_PATH
git add tests/niri-inir-merge-readiness.sh
git commit -m "$(cat <<'EOF'
tests(merge-readiness): flip iNiR-vendoring assertions, add new ones

In-place rewrite. Niri config baseline assertions stay unchanged. The
iNiR-vendoring section flips from "must clone snowarch/iNiR" to "must
NOT clone" and adds new assertions:

- apps/ryoku-shell/setup is executable
- apps/ryoku-shell/assets/systemd/ryoku-shell.service exists
- install/config/ryoku-shell-branding.sh is deleted
- default/ryoku-shell/branding-replacements.tsv is deleted
- no github.com/snowarch/iNiR string in active source

Per-script assertions updated to require the new ryoku-shell.service /
ryoku-shell <verb> names. Dual-name fallback branches in lifecycle
helpers are silently allowed (the assertions require the new name to
be present, but don't fail if the legacy name is also present).
EOF
)"
```

### Task 8.2: Update `tests/ryoku-session-recovery.sh` and other auxiliary tests

**Files:**
- Modify: `tests/ryoku-session-recovery.sh`
- Modify: any other `tests/*.sh` that assert iNiR-specific behavior

- [ ] **Step 1: Update `tests/ryoku-session-recovery.sh:70`**

```bash
grep -n "inir cleanup-orphans" $RYOKU_PATH/tests/ryoku-session-recovery.sh
```

Replace the asserted string `'inir cleanup-orphans'` with `'ryoku-shell cleanup-orphans'`.

```bash
perl -pi -e "s/'inir cleanup-orphans'/'ryoku-shell cleanup-orphans'/g" $RYOKU_PATH/tests/ryoku-session-recovery.sh
```

- [ ] **Step 2: Audit other tests for iNiR references**

```bash
grep -lE "\binir\b|inir\.service|inir\.desktop|RYOKU_INIR|/quickshell/inir/" $RYOKU_PATH/tests/*.sh
```

For each file in the list (excluding `niri-inir-merge-readiness.sh` already done), inspect each hit and apply context-appropriate replacements.

- [ ] **Step 3: Run the affected tests**

```bash
cd $RYOKU_PATH
for f in $(git diff --name-only --cached -- tests/); do
  echo "=== $f ==="
  bash "$f" || echo "FAILED: $f"
done
```

Expected: all tests pass.

- [ ] **Step 4: Stage and commit**

```bash
cd $RYOKU_PATH
git add tests/
git commit -m "tests: update auxiliary tests to assert ryoku-shell names"
```

### Task 8.3: Heritage doc + README credits

**Files:**
- Create: `docs/inir-heritage.md`
- Modify: `README.md` (Credits section)

- [ ] **Step 1: Create `docs/inir-heritage.md`**

Mirror the structure of `docs/omarchy-heritage.md`. Read the existing one for tone:

```bash
cat $RYOKU_PATH/docs/omarchy-heritage.md
```

Create `$RYOKU_PATH/docs/inir-heritage.md` with this content:

```markdown
# iNiR Heritage

Ryoku began with iNiR as an external upstream, the shell layer cloned at
install time from `snowarch/iNiR`, then patched in place. As of
[YYYY-MM-DD, fill in the chunk-8 commit date], the iNiR source tree is
vendored into Ryoku at `apps/ryoku-shell/` and Ryoku no longer has any
external runtime, install, or update dependency on the iNiR repository.

This document explains what remains so users and contributors can tell the
difference between active Ryoku behavior and intentional historical or
attribution references.

## What Still Remains

| Surface | Why It Remains |
| --- | --- |
| `LICENSE`, `NOTICE` upstream attribution | Required by upstream iNiR's MIT license. |
| `CREDITS.md`, `README.md` Credits section | Attribution to `snowarch/iNiR` for the original shell project. |
| `apps/ryoku-shell/{CHANGELOG,CONTRIBUTING,README,SECURITY}.md` and `docs/` | Preserved from upstream, historical context for the vendored tree. |
| `apps/ryoku-shell/Ii*` QML internals (`ShellIiPanels.qml`, `iiScreenFrame`, `iiPersist`, ...) | Internal QML identifiers; never user-visible; renamed only when changed for other reasons. |
| `dots/sddm/pixel/` directory name and `/usr/share/sddm/themes/ii-pixel` | External SDDM theme identifier; preserved to keep theme lookup stable. |
| Migrations under `migrations/` that touch `~/.local/share/inir`, `~/.config/inir`, `inir.service` | Cleanup-only, these remove legacy state from pre-cutover systems. |
| `distro/arch/qt6-qiooperation-patch/` comments mentioning iNiR | Historical context for the Quickshell crash chain that led to the patch. |
| Historical plan/spec documents under `docs/superpowers/` | Records of past work sessions. |
| Dual-name fallback branches in `bin/ryoku-restart-shell`, `bin/ryoku-restart-ui`, `bin/ryoku-launch-shell`, `bin/ryoku-refresh-quickshell`, `bin/ryoku-shell-cleanup-orphans` | Transitional, kept until the dual-name cleanup follow-up release. |
| Dual-export `INIR_VENV` line in `config/niri/config.d/40-environment.kdl` and the `${INIR_VENV:-...}` fallback in `config/matugen/templates/kde/kde-material-you-colors-wrapper.sh` | Transitional, kept until the dual-name cleanup follow-up release. |

## Current User-Facing Surfaces

| Ryoku Surface | Current Meaning |
| --- | --- |
| `~/.local/share/ryoku-shell/` | Installed shell source tree. |
| `~/.config/quickshell/ryoku-shell/` | Quickshell runtime. |
| `~/.config/ryoku-shell/config.json` | User shell config. |
| `ryoku-shell.service` | systemd user unit. |
| `~/.local/bin/ryoku-shell` | Shell CLI entrypoint. |
| `ryoku-shell <verb>` | Shell IPC and command surface. |
| `apps/ryoku-shell/` | Vendored source tree, Ryoku-owned. |

## How To Review A New Reference

When a new iNiR reference appears, classify it before changing it:

1. **Attribution:** keep it if it preserves copyright, license, or upstream credit.
2. **External identifier:** keep it if the string is a theme, package, or path that exists under that name.
3. **Cleanup:** keep it if it only removes or migrates old installed state.
4. **Historical doc:** keep it if the file is a dated plan/spec record.
5. **Active runtime:** rename or remove it. Active runtime should use `ryoku-shell` surfaces.
```

After saving, fill in the date placeholder with today's date.

- [ ] **Step 2: Update `README.md` Credits section**

```bash
grep -n "iNiR" $RYOKU_PATH/README.md
```

Find the Credits bullet for iNiR (around line 71):

```markdown
- [**iNiR**](https://github.com/snowarch/iNiR): the current shell layer and session UI Ryoku installs on top of Niri.
```

Replace with:

```markdown
- [**iNiR**](https://github.com/snowarch/iNiR): the original shell project Ryoku's vendored shell at `apps/ryoku-shell/` is forked from. See [`docs/inir-heritage.md`](docs/inir-heritage.md).
```

- [ ] **Step 3: Stage and commit**

```bash
cd $RYOKU_PATH
git add docs/inir-heritage.md README.md
git commit -m "$(cat <<'EOF'
docs: add iNiR heritage doc; update README credits

docs/inir-heritage.md mirrors omarchy-heritage.md shape: documents what
iNiR references stay (attribution, external identifiers, cleanup-only
migrations, dual-name transitional branches) and what the canonical
ryoku-shell surfaces are.

README.md Credits bullet for iNiR updated to clarify the project is
now vendored as Ryoku source.
EOF
)"
```

### Task 8.4: Delete branding script + TSV

**Files:**
- Delete: `install/config/ryoku-shell-branding.sh`
- Delete: `default/ryoku-shell/branding-replacements.tsv`

- [ ] **Step 1: Verify nothing references the script anymore**

```bash
cd $RYOKU_PATH
grep -rln "ryoku-shell-branding.sh" --include='*.sh' bin/ install/ tests/ migrations/ iso/ 2>/dev/null
```

Expected: zero hits. If any callers remain, audit them, the only legitimate caller would have been `install/config/inir.sh` (deleted in chunk 2). If something else calls it, that's a bug from earlier chunks.

- [ ] **Step 2: Delete both files**

```bash
cd $RYOKU_PATH
git rm install/config/ryoku-shell-branding.sh default/ryoku-shell/branding-replacements.tsv
```

If `default/ryoku-shell/` becomes empty, also remove the dir (`git rm` doesn't track empty dirs):

```bash
ls $RYOKU_PATH/default/ryoku-shell/ 2>/dev/null
```

If output shows other files (e.g., `config-overrides.json`), leave the dir.

- [ ] **Step 3: Run the merge-readiness test (asserts these are gone)**

```bash
cd $RYOKU_PATH
bash tests/niri-inir-merge-readiness.sh
```

Expected: passes; the new assertions added in Task 8.1 step 6 (`[[ ! -f install/config/ryoku-shell-branding.sh ]]`) are now satisfied.

- [ ] **Step 4: Final grep audit**

```bash
cd $RYOKU_PATH
grep -rE 'inir|iNiR|INIR' \
  --include='*.sh' --include='*.kdl' --include='*.qml' \
  --include='*.toml' --include='*.json' --include='*.css' \
  --include='*.conf' --include='*.service' --include='*.desktop' \
  --include='*.packages' \
  bin/ config/ default/ install/ iso/ tests/ migrations/ distro/ lib/ 2>/dev/null
```

Inspect every hit. Expected categories of allowed hits (per `docs/inir-heritage.md`):
- Dual-name fallback branches in `bin/ryoku-restart-shell`, `bin/ryoku-launch-shell`, etc.
- Dual-export `INIR_VENV` line in `config/niri/config.d/40-environment.kdl`
- `${INIR_VENV:-...}` fallback in `config/matugen/templates/kde/kde-material-you-colors-wrapper.sh`
- Cleanup references in migrations (`migrations/<chunk-7-epoch>.sh` and the no-op-on-cutover `migrations/1777776000.sh`)
- Comment attribution in `distro/arch/qt6-qiooperation-patch/apply.sh` header

Anything else is a missed rename, go back to the appropriate chunk and fix.

- [ ] **Step 5: Stage and commit**

```bash
cd $RYOKU_PATH
git add -A install/config/ default/ryoku-shell/
git commit -m "$(cat <<'EOF'
install: delete ryoku-shell-branding.sh and branding-replacements.tsv

Both retired. The branding patches they applied at install time are now
baked into apps/ryoku-shell/ directly (chunk 1b). Nothing in the active
code path calls either file as of this commit.
EOF
)"
```

---

## Final Verification

After all 8 chunks land:

- [ ] **Step 1: Full test sweep**

```bash
cd $RYOKU_PATH
for f in tests/*.sh; do
  echo "=== $f ==="
  bash "$f" 2>&1 | tail -5
done
```

Expected: every test ends with `OK:` or `pass`.

- [ ] **Step 2: Repo cleanliness**

```bash
cd $RYOKU_PATH
git status --short
```

Expected: clean working tree.

- [ ] **Step 3: Live verification (after migration runs)**

If you've run `ryoku-update` (which triggers chunk 7's migration), verify:

```bash
systemctl --user is-active ryoku-shell.service && echo "OK: service active"
~/.local/bin/ryoku-shell --help 2>&1 | head -3 && echo "OK: launcher works"
ryoku-ipc --help | grep -F "ryoku-ipc overview toggle" && echo "OK: ipc dispatch wired"
```

Expected: three `OK:` lines.

- [ ] **Step 4: ISO build sanity (optional)**

If a fresh ISO build is feasible, run:

```bash
cd $RYOKU_PATH
unset RYOKU_INIR_REPO RYOKU_INIR_SOURCE
bash iso/bin/ryoku-iso-make
```

Expected: build completes; resulting ISO contains `apps/ryoku-shell/` inside the bundled Ryoku source.

---

## Self-Review Notes (plan author)

Spec coverage check:
- Chunk 1 (vendor source) → Tasks 1.1, 1.2 ✓
- Chunk 2 (re-point install/config) → Task 2.1 ✓
- Chunk 3 (rename runtime artifacts) → Tasks 3.1-3.5 ✓
- Chunk 4 (rename CLI consumers) → Tasks 4.1-4.7 ✓
- Chunk 5 (ISO build) → Tasks 5.1-5.3 ✓
- Chunk 6 (distro/PKGBUILD) → Tasks 6.1-6.2 ✓
- Chunk 7 (live-system migration) → Task 7.1 ✓
- Chunk 8 (tests + heritage + sweep) → Tasks 8.1-8.4 ✓
- Dual-name fallback cleanup deferred to follow-up release (per spec), explicitly noted in tasks 4.1, 4.2, 4.5, and the heritage doc

Placeholder scan: no TBD/TODO patterns; all code blocks contain actual code; all bash commands are exact.

Type/name consistency: `ryoku-shell.service`, `~/.local/bin/ryoku-shell`, `~/.local/share/ryoku-shell`, `~/.config/quickshell/ryoku-shell`, `~/.config/ryoku-shell/config.json`, `RYOKU_SHELL_VENV`, `RYOKU_SHELL_PATH` used consistently throughout. CLI verb form is `ryoku-shell <verb>` (matching iNiR's `inir <verb>` pattern). QML IPC namespace is `ryoku-shell` (with the dot, `ryoku-shell.target`).
