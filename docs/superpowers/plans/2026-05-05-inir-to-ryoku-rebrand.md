# iNiR to Ryoku Rebrand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Absorb the iNiR shell into Ryoku as a vendored tree, eliminate the snowarch clone dependency at install time, rename `inir`/`iNiR` to `ryoku-shell`/`Ryoku` throughout, convert the bug-fix perl-patches into proper commits in the vendored code, and migrate existing live systems.

**Architecture:** Four sequential phases on the existing `niri-inir-transition` branch. Phase 1 vendors and switches the install source. Phase 2 renames code, paths, services, env vars, and the test surface. Phase 3 converts the 5 surviving perl-patches into normal commits in the vendored tree, shrinking the branding script. Phase 4 ships a one-shot migration so existing iNiR installs transition cleanly to the Ryoku-shell paths.

**Tech Stack:** Bash (install scripts, migrations, branding, tests), QML (Quickshell shell code in `shell/`), KDL (niri config), JSON (config overlays), systemd user units, perl (legacy patches being retired), grep / sed / find for the rename pass.

**Spec:** `docs/superpowers/specs/2026-05-05-inir-to-ryoku-rebrand-design.md`

**Pre-commit hooks:** No em-dash characters (`U+2014`) in committed files. No `Co-Authored-By:` trailers in commit messages.

---

## File Structure

| Path | Action | Phase |
|---|---|---|
| `shell/` | Create (vendor of iNiR's tree, ~74 MB excluding `.git/`) | 1 |
| `install/config/inir.sh` | Modify (replace clone path with `cp -a` from `shell/`) | 1 |
| `install/config/inir.sh` | Rename to `install/config/shell.sh`, update path constants | 2 |
| `install/config/all.sh` | Modify (update `inir.sh` reference to `shell.sh`) | 2 |
| `migrations/1778000000.sh` | Modify (source from `shell/` instead of clone) | 1 |
| `iso/builder/build-iso.sh` | Modify (drop `RYOKU_INIR_REPO`, source from `shell/`) | 1 |
| `iso/bin/ryoku-iso-make` | Modify (drop `RYOKU_INIR_REPO`, `RYOKU_INIR_SOURCE`) | 1 |
| `install/config/ryoku-shell-branding.sh` | Modify in Phase 2, shrink in Phase 3 | 2, 3 |
| `default/ryoku-shell/branding-replacements.tsv` | Delete (no upstream to substitute) | 3 |
| `tests/niri-inir-merge-readiness.sh` | Rename to `tests/niri-shell-merge-readiness.sh`, update assertions | 2 |
| `tests/ryoku-shell-branding.sh` | Modify (drop assertions for retired functions) | 3 |
| `tests/ryoku-boot-branding.sh` | Modify (rename references if any iNiR strings) | 2 |
| `tests/install-from-vendor.sh` | Create (asserts no `git clone` in install pipeline) | 1 |
| `config/systemd/user/inir.service` | Rename to `ryoku-shell.service`, update Description | 2 |
| `config/systemd/user/inir.service.d/` | Rename directory to `ryoku-shell.service.d/` | 2 |
| `config/niri/config.d/*.kdl` | Modify (rename inir mentions in 4 files) | 2 |
| `config/alacritty/alacritty.toml` | Modify (rename inir mention) | 2 |
| `config/matugen/templates/*` | Modify (rename inir mentions where present) | 2 |
| `migrations/<new-ts>.sh` | Create (Phase 4 migration) | 4 |

The vendored `shell/` directory will follow iNiR's existing structure unchanged in Phase 1. Phase 2 then renames literal `inir`/`iNiR` strings inside it, including:
- `shell/setup` (the bundled installer; many path constants and identifiers)
- `shell/sdata/lib/uninstall.sh` (the `INIR_ONLY_PATHS` map)
- `shell/scripts/inir` (the launcher binary; rename file too)
- `shell/assets/systemd/inir.service` (rename file + Description)
- `shell/assets/applications/inir.desktop` (rename file + Name + Icon)
- `shell/modules/settings/About.qml` (add Ryoku as primary credit; keep iNiR + illogical-impulse)
- Documentation (`shell/CHANGELOG.md`, `shell/README.md`, `shell/ARCHITECTURE.md`, `shell/docs/*`) is **NOT** modified . historical record is preserved.

---

## Pre-flight: pristine source tree

Before vendoring, the live `~/.local/share/inir/` source must be reset to pristine snowarch HEAD. Our session work has applied bug-fix perl-patches that mutate `Lock.qml`, `Idle.qml`, `ScreenCorners.qml`, etc. We want a clean upstream tree to vendor; the patches will be re-applied as proper commits in Phase 3.

This pre-flight runs once before Task 1.1.

```bash
# Verify the live tree is a snowarch checkout
git -C ~/.local/share/inir remote get-url origin | grep -F 'snowarch/iNiR' || \
  { echo "ERROR: ~/.local/share/inir is not a snowarch clone; aborting" >&2; exit 1; }

# Reset all tracked files to HEAD (discards branding-script perl patches)
git -C ~/.local/share/inir checkout --force -- .

# Drop untracked files (e.g., assets/icons/ryoku.svg from install_visible_assets)
git -C ~/.local/share/inir clean -fd

# Verify clean
git -C ~/.local/share/inir status --short
# Expected: empty output

git -C ~/.local/share/inir log -1 --format='%h %s'
# Expected: c1fcbcd5 Restore live media artwork reloads (or whatever upstream HEAD is at vendor time)
```

If the live tree has untracked critical files (e.g., the user has put work-in-progress there), the engineer should backup before running `clean -fd`. On this machine the only untracked items are Ryoku-installed icons and SDDM assets, which `install/config/ryoku-shell-branding.sh:install_visible_assets` re-creates on next branding run.

---

## PHASE 1: Vendor and switch install source

After Phase 1 lands: snowarch is no longer cloned at install time. Repo grows by ~74 MB. The shell still lives at `~/.local/share/inir/` and is still iNiR-named everywhere; only the source-of-truth changes.

### Task 1.1: Vendor pristine iNiR tree into `shell/`

**Files:**
- Create: `shell/` (copy of `~/.local/share/inir/` excluding `.git/`)

- [ ] **Step 1: Run pre-flight (above) to confirm `~/.local/share/inir/` is pristine**

```bash
git -C ~/.local/share/inir status --short
```
Expected: empty output (no modified or untracked files).

- [ ] **Step 2: Confirm `shell/` does not yet exist in this repo**

```bash
[[ ! -e shell ]] && echo OK || echo "ERROR: shell/ already exists"
```
Expected: `OK`

- [ ] **Step 3: Vendor the tree (excluding `.git/`)**

```bash
cp -a ~/.local/share/inir shell
rm -rf shell/.git
```

- [ ] **Step 4: Verify vendored size and key files**

```bash
du -sh shell
ls shell/shell.qml shell/setup shell/modules shell/services shell/assets
```
Expected: roughly 74 MB total. All listed paths should exist.

- [ ] **Step 5: Add `.gitattributes` entry for binary assets to avoid line-ending churn**

Append to `.gitattributes` at repo root (create file if missing):
```
shell/assets/** binary
shell/dots/** binary
```

- [ ] **Step 6: Stage and commit**

```bash
git add shell .gitattributes
git status --short | head -5  # sanity: many files added
git commit -m "feat(shell): vendor iNiR tree into shell/

Plain copy of pristine snowarch/iNiR HEAD ($(git -C ~/.local/share/inir log -1 --format=%h)),
excluding .git/. ~74 MB tracked source. Eliminates the runtime
clone dependency that subsequent phases will phase out from the
install pipeline. Vendored verbatim; no rename or patch work in
this commit."
```

### Task 1.2: Rewrite `install/config/inir.sh` to copy from `shell/`

**Files:**
- Modify: `install/config/inir.sh`

- [ ] **Step 1: Read the current install script**

```bash
cat install/config/inir.sh
```
Note current logic: clones from `RYOKU_INIR_REPO` (snowarch), with offline fallback chain.

- [ ] **Step 2: Replace clone logic with `cp -a` from `shell/`**

Overwrite `install/config/inir.sh` with:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

INIR_PATH="${RYOKU_INIR_PATH:-$HOME/.local/share/inir}"
SHELL_VENDOR="$RYOKU_PATH/shell"

if [[ ! -d $SHELL_VENDOR ]]; then
  echo "install/config/inir.sh: missing vendored shell tree at $SHELL_VENDOR" >&2
  exit 1
fi

# If the target is a legacy snowarch git checkout, replace it with the vendor.
if [[ -d $INIR_PATH/.git ]]; then
  rm -rf "$INIR_PATH"
fi

# Fresh deploy: copy the vendored tree into place.
if [[ ! -d $INIR_PATH ]]; then
  mkdir -p "$(dirname "$INIR_PATH")"
  cp -a "$SHELL_VENDOR/." "$INIR_PATH/"
fi

(
  cd "$INIR_PATH"
  ./setup install -y --skip-deps --skip-sysupdate
)

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"

inir_launcher="$HOME/.local/bin/inir"
if [[ -x $inir_launcher ]]; then
  "$inir_launcher" service enable niri >/dev/null 2>&1 || true
elif ryoku-cmd-present inir; then
  inir service enable niri >/dev/null 2>&1 || true
fi

inir_service="$HOME/.config/systemd/user/inir.service"
inir_wants_dir="$HOME/.config/systemd/user/niri.service.wants"
if [[ -f $inir_service ]]; then
  mkdir -p "$inir_wants_dir"
  ln -sf "$inir_service" "$inir_wants_dir/inir.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
systemctl --user daemon-reload >/dev/null 2>&1 || true
```

Key changes from the previous version:
- Removed `INIR_REPO`, `INIR_SOURCE`, `INIR_REQUIRE_LOCAL_SOURCE`, the `RYOKU_CHROOT_INSTALL` chroot setup_env, and the `setup_env` UV cache plumbing (no clone, so all of that is moot).
- Removed the entire fallback chain (`vendor/inir`, `/root/inir`, `/opt/ryoku/inir`).
- Replaced the clone-or-pull branch with: if-legacy-checkout-then-rm, if-not-exists-then-cp-from-`shell/`.

- [ ] **Step 3: Static syntax check**

```bash
bash -n install/config/inir.sh && echo OK
```
Expected: `OK`

- [ ] **Step 4: Verify no `git clone` reference remains**

```bash
grep -c 'git clone' install/config/inir.sh
```
Expected: `0`

- [ ] **Step 5: Verify the script references the vendor**

```bash
grep -c 'RYOKU_PATH/shell' install/config/inir.sh
```
Expected: nonzero (at least one reference).

- [ ] **Step 6: Commit**

```bash
git add install/config/inir.sh
git commit -m "feat(install): install iNiR from vendored shell/ tree

install/config/inir.sh now copies from \$RYOKU_PATH/shell/ instead of
cloning snowarch/iNiR. The clone path, offline fallback chain
(vendor/inir, /root/inir, /opt/ryoku/inir), and the chroot UV cache
plumbing are removed; none have meaning without a network source.

Legacy snowarch checkouts at \$INIR_PATH are wiped and replaced with
the vendored copy on the next install run, keeping the migration
seamless for systems already on the niri-inir-transition branch."
```

### Task 1.3: Update `migrations/1778000000.sh` to source from `shell/`

**Files:**
- Modify: `migrations/1778000000.sh`

- [ ] **Step 1: Read current migration**

```bash
cat migrations/1778000000.sh
```

- [ ] **Step 2: Replace the source-resolution block**

Find the section starting at the `# Phase 8: Clone fresh iNiR` comment and ending at the `git clone "$INIR_REPO" "$INIR_PATH"` block. Replace with:

```bash
# Phase 8: Deploy fresh iNiR from the vendored tree in this repo.
SHELL_VENDOR="$RYOKU_PATH/shell"
if [[ ! -d $SHELL_VENDOR ]]; then
  echo "migration: missing vendored shell tree at $SHELL_VENDOR" >&2
  exit 1
fi
cp -a "$SHELL_VENDOR/." "$INIR_PATH/"
```

The full migration after this edit should have phases 1-7 unchanged, phase 8 as above, and phases 9-11 unchanged.

- [ ] **Step 3: Static syntax check**

```bash
bash -n migrations/1778000000.sh && echo OK
```
Expected: `OK`

- [ ] **Step 4: Verify no `git clone` reference**

```bash
grep -c 'git clone' migrations/1778000000.sh
```
Expected: `0`

- [ ] **Step 5: Commit**

```bash
git add migrations/1778000000.sh
git commit -m "feat(migrations): pristine restore deploys from vendored shell/

migrations/1778000000.sh no longer clones snowarch/iNiR; it copies
from \$RYOKU_PATH/shell/ instead. Drops the RYOKU_INIR_REPO and
RYOKU_INIR_SOURCE env-var resolution chain along with the network
clone fallback. The phase comment is updated to match."
```

### Task 1.4: Update ISO builder to source from `shell/`

**Files:**
- Modify: `iso/builder/build-iso.sh`
- Modify: `iso/bin/ryoku-iso-make`

- [ ] **Step 1: Inspect current ISO clone logic**

```bash
grep -n 'RYOKU_INIR_REPO\|inir' iso/builder/build-iso.sh iso/bin/ryoku-iso-make | head -20
```

- [ ] **Step 2: In `iso/builder/build-iso.sh`, replace the clone branch**

Find the block that calls `git clone "$RYOKU_INIR_REPO" "$build_cache_dir/airootfs/root/inir"` (around line 48 in the current file). Replace it with a copy from the vendored tree mounted into the build container:

```bash
# Vendor inir from the Ryoku tree (no network dependency).
if [[ -d /ryoku/shell ]]; then
  cp -a /ryoku/shell "$build_cache_dir/airootfs/root/inir"
elif [[ -d /inir ]]; then
  /bin/bash /builder/sync-local-source.sh /inir "$build_cache_dir/airootfs/root/inir"
else
  echo "build-iso: no Ryoku shell/ tree available at /ryoku/shell" >&2
  exit 1
fi
```

Remove the `RYOKU_INIR_REPO="${RYOKU_INIR_REPO:-https://github.com/snowarch/iNiR.git}"` line at the top.

- [ ] **Step 3: In `iso/bin/ryoku-iso-make`, drop env-var passthrough**

Remove the lines that set or pass through `RYOKU_INIR_REPO` and `RYOKU_INIR_SOURCE` (around lines 54, 64, 78, 83 of the current file). The vendored `shell/` tree under `/ryoku/shell` (mounted from the host) is the only source.

- [ ] **Step 4: Verify**

```bash
bash -n iso/builder/build-iso.sh iso/bin/ryoku-iso-make && echo OK
grep -c 'RYOKU_INIR_REPO\|git clone.*iNiR\|git clone.*inir' iso/builder/build-iso.sh iso/bin/ryoku-iso-make
```
Expected: `OK`, then `0`.

- [ ] **Step 5: Commit**

```bash
git add iso/builder/build-iso.sh iso/bin/ryoku-iso-make
git commit -m "feat(iso): build ISO from vendored shell/ tree

Drops RYOKU_INIR_REPO and RYOKU_INIR_SOURCE from the ISO build
pipeline. The shell tree comes from the Ryoku checkout at
/ryoku/shell mounted into the build container, with /inir as a
backwards-compat fallback for build hosts that still mount the
old path. No network dependency at build time."
```

### Task 1.5: Add a static test asserting independence from snowarch

**Files:**
- Create: `tests/install-from-vendor.sh`

- [ ] **Step 1: Create the test**

```bash
cat > tests/install-from-vendor.sh <<'EOF'
#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_no_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

# install/config/inir.sh must source from the vendored shell/ tree, not clone
assert_no_match install/config/inir.sh 'git clone' \
  "install/config/inir.sh must not clone (vendored shell/ is the source of truth)"
assert_match install/config/inir.sh 'shell"?/?' \
  "install/config/inir.sh must reference the vendored shell/ tree"

# migrations/1778000000.sh must source from the vendored shell/ tree
assert_no_match migrations/1778000000.sh 'git clone' \
  "migrations/1778000000.sh must not clone iNiR"

# ISO builder must not pull from a remote
assert_no_match iso/builder/build-iso.sh 'RYOKU_INIR_REPO' \
  "iso/builder/build-iso.sh must not reference RYOKU_INIR_REPO"

# Vendored tree must exist with key entry points
[[ -f shell/shell.qml ]] || fail "shell/shell.qml must exist"
[[ -f shell/setup ]] || fail "shell/setup must exist"
[[ -d shell/modules ]] || fail "shell/modules must exist"
[[ -d shell/services ]] || fail "shell/services must exist"
[[ ! -d shell/.git ]] || fail "shell/.git must NOT exist (hermetic vendor)"

echo "PASS: install from vendor"
EOF
chmod +x tests/install-from-vendor.sh
```

- [ ] **Step 2: Run the test**

```bash
bash tests/install-from-vendor.sh
```
Expected: `PASS: install from vendor`

- [ ] **Step 3: Commit**

```bash
git add tests/install-from-vendor.sh
git commit -m "test(install): assert vendor-only install pipeline

Locks the contract that install/config/inir.sh, migrations/1778000000.sh,
and iso/builder/build-iso.sh deploy iNiR from the vendored shell/ tree
rather than from a network clone. Also asserts the vendored tree is
hermetic (no .git directory)."
```

---

## PHASE 2: Rename in code

After Phase 2 lands: every literal `inir`/`iNiR` reference in repo code outside the vendored tree's documentation files becomes `ryoku-shell`/`Ryoku`. Runtime paths, service unit names, launcher binary, env vars, and the test file with `inir` in its name all rename. The vendored tree's `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, and `docs/*` are LEFT UNCHANGED: historical record is preserved.

### Task 2.1: Rename install script + path constants

**Files:**
- Rename: `install/config/inir.sh` → `install/config/shell.sh`
- Modify: `install/config/all.sh`
- Modify: `install/config/shell.sh` (path constants and runtime path)

- [ ] **Step 1: Rename the file**

```bash
git mv install/config/inir.sh install/config/shell.sh
```

- [ ] **Step 2: Update path constants inside `install/config/shell.sh`**

Replace these tokens throughout the file:
- `INIR_PATH` → `SHELL_PATH`
- `RYOKU_INIR_PATH` → `RYOKU_SHELL_PATH`
- `$HOME/.local/share/inir` → `$HOME/.local/share/ryoku-shell`
- `$HOME/.config/systemd/user/inir.service` → `$HOME/.config/systemd/user/ryoku-shell.service`
- `$HOME/.config/systemd/user/niri.service.wants/inir.service` → `$HOME/.config/systemd/user/niri.service.wants/ryoku-shell.service`
- `$HOME/.local/bin/inir` → `$HOME/.local/bin/ryoku-shell`
- The `inir service enable niri` calls → `ryoku-shell service enable niri`
- The `ryoku-cmd-present inir` call → `ryoku-cmd-present ryoku-shell`

Use sed for the bulk replacement, then verify by hand:

```bash
sed -i \
  -e 's|INIR_PATH|SHELL_PATH|g' \
  -e 's|RYOKU_SHELL_SHELL_PATH|RYOKU_SHELL_PATH|g' \
  -e 's|/.local/share/inir|/.local/share/ryoku-shell|g' \
  -e 's|systemd/user/inir.service|systemd/user/ryoku-shell.service|g' \
  -e 's|niri.service.wants/inir.service|niri.service.wants/ryoku-shell.service|g' \
  -e 's|/.local/bin/inir|/.local/bin/ryoku-shell|g' \
  -e 's|"inir" service|"ryoku-shell" service|g' \
  -e 's|inir service enable|ryoku-shell service enable|g' \
  -e 's|ryoku-cmd-present inir|ryoku-cmd-present ryoku-shell|g' \
  install/config/shell.sh
```

The `INIR_PATH → SHELL_PATH` rule may double-substitute via `RYOKU_INIR_PATH → RYOKU_SHELL_SHELL_PATH`; the second sed rule corrects this.

- [ ] **Step 3: Update `install/config/all.sh` to call the new path**

```bash
sed -i 's|install/config/inir.sh|install/config/shell.sh|' install/config/all.sh
```

- [ ] **Step 4: Static check**

```bash
bash -n install/config/shell.sh install/config/all.sh && echo OK
grep -n 'inir' install/config/shell.sh install/config/all.sh || echo "no remaining inir refs"
```
Expected: `OK`, then `no remaining inir refs`.

- [ ] **Step 5: Commit**

```bash
git add install/config/shell.sh install/config/all.sh
git status --short
git commit -m "refactor(install): rename inir.sh to shell.sh, ryoku-shell paths

Renames install/config/inir.sh to install/config/shell.sh, all path
constants (INIR_PATH -> SHELL_PATH), the runtime path
(~/.local/share/inir -> ~/.local/share/ryoku-shell), the systemd unit
(inir.service -> ryoku-shell.service), the launcher binary
(~/.local/bin/inir -> ~/.local/bin/ryoku-shell), and the wants
symlink. Updates install/config/all.sh to call the renamed script."
```

### Task 2.2: Rename inside `shell/setup` and `shell/sdata/lib/uninstall.sh`

**Files:**
- Modify: `shell/setup` (path constants throughout; ~50 inir references)
- Modify: `shell/sdata/lib/uninstall.sh` (the `INIR_ONLY_PATHS` map)

- [ ] **Step 1: Inspect current state**

```bash
grep -c 'inir\|iNiR' shell/setup shell/sdata/lib/uninstall.sh
```

- [ ] **Step 2: Bulk-rename `inir` and `iNiR` literal strings**

```bash
sed -i \
  -e 's|/inir|/ryoku-shell|g' \
  -e 's|"inir"|"ryoku-shell"|g' \
  -e "s|'inir'|'ryoku-shell'|g" \
  -e 's|inir.service|ryoku-shell.service|g' \
  -e 's|inir-super-overview|ryoku-shell-super-overview|g' \
  -e 's|inir_super_overview_daemon|ryoku-shell-super-overview-daemon|g' \
  -e 's|INIR_CONFIG_DIR|RYOKU_SHELL_CONFIG_DIR|g' \
  -e 's|INIR_PATH|RYOKU_SHELL_PATH|g' \
  -e 's|inir.desktop|ryoku-shell.desktop|g' \
  -e 's|inir.svg|ryoku-shell.svg|g' \
  -e 's|iNiR|Ryoku|g' \
  shell/setup shell/sdata/lib/uninstall.sh
```

The `iNiR → Ryoku` rule comes last so mixed-case paths (`iNiR-related-thing.qml`) still get substituted.

- [ ] **Step 3: Static check + leftover scan**

```bash
bash -n shell/setup && echo OK
grep -nE 'inir|iNiR' shell/setup shell/sdata/lib/uninstall.sh | head
```
Expected: `OK`. The grep may show a few survivors in comments or string literals. Inspect each manually; rename if it's code, leave if it's a credit/historical mention.

- [ ] **Step 4: Sanity-run shell/setup help**

```bash
bash shell/setup --help 2>&1 | head -5 || true
```
This may fail because the script needs a real environment, but bash parsing should not error.

- [ ] **Step 5: Commit**

```bash
git add shell/setup shell/sdata/lib/uninstall.sh
git commit -m "refactor(shell): rename inir paths inside vendored setup script

Renames \${XDG_CONFIG_HOME}/inir to /ryoku-shell, \${XDG_BIN_HOME}/inir
to /ryoku-shell, the systemd units (inir.service ->
ryoku-shell.service, inir-super-overview.service ->
ryoku-shell-super-overview.service), the helper daemons, the desktop
entry, and the launcher icon throughout shell/setup and
shell/sdata/lib/uninstall.sh (the INIR_ONLY_PATHS map). All path
constants get the matching INIR_ -> RYOKU_SHELL_ rename."
```

### Task 2.3: Rename systemd unit, desktop entry, launcher binary, icon files in `shell/`

**Files:**
- Rename: `shell/assets/systemd/inir.service` → `ryoku-shell.service`
- Rename: `shell/assets/applications/inir.desktop` → `ryoku-shell.desktop`
- Rename: `shell/assets/icons/inir.svg` → `ryoku-shell.svg` (if exists)
- Rename: `shell/scripts/inir` → `shell/scripts/ryoku-shell` (the launcher)
- Modify: contents of each renamed file (Description, Name, Exec, Icon)

- [ ] **Step 1: Locate target files**

```bash
find shell/assets shell/scripts -name '*inir*' -type f
```
Note all matches.

- [ ] **Step 2: Rename systemd unit file and update Description**

```bash
git mv shell/assets/systemd/inir.service shell/assets/systemd/ryoku-shell.service
sed -i \
  -e 's|Description=iNiR shell|Description=Ryoku shell|' \
  -e 's|stop/restart inir|stop/restart Ryoku shell|g' \
  -e 's|inir is a session consumer|Ryoku shell is a session consumer|' \
  -e 's|inir only starts under|Ryoku shell only starts under|' \
  shell/assets/systemd/ryoku-shell.service
```

- [ ] **Step 3: If a `inir-super-overview.service` exists in the same directory, rename it too**

```bash
if [[ -f shell/assets/systemd/inir-super-overview.service ]]; then
  git mv shell/assets/systemd/inir-super-overview.service shell/assets/systemd/ryoku-shell-super-overview.service
  sed -i 's|inir|ryoku-shell|g; s|iNiR|Ryoku|g' shell/assets/systemd/ryoku-shell-super-overview.service
fi
```

- [ ] **Step 4: Rename desktop entry**

```bash
git mv shell/assets/applications/inir.desktop shell/assets/applications/ryoku-shell.desktop
sed -i \
  -e 's|Name=iNiR Settings|Name=Ryoku Settings|' \
  -e 's|Comment=Open iNiR settings|Comment=Open Ryoku settings|' \
  -e 's|Exec=.*/inir settings|Exec=/home/$USER/.local/bin/ryoku-shell settings|' \
  -e 's|Icon=inir|Icon=ryoku-shell|' \
  shell/assets/applications/ryoku-shell.desktop
```
Note: the `Exec=` line will need a runtime-resolved `$HOME`; check what's in the original desktop file. If it uses an absolute hardcoded path, leave the `$USER` substitution; the `apply_replacements_to_file` mechanism in branding handles user-specific substitution (or the install path bakes in `$HOME` directly).

- [ ] **Step 5: Rename launcher icon and any other inir-named assets**

```bash
if [[ -f shell/assets/icons/inir.svg ]]; then
  git mv shell/assets/icons/inir.svg shell/assets/icons/ryoku-shell.svg
fi
# repeat for other matches found in Step 1
```

- [ ] **Step 6: Rename launcher binary**

```bash
if [[ -f shell/scripts/inir ]]; then
  git mv shell/scripts/inir shell/scripts/ryoku-shell
fi
```

- [ ] **Step 7: Verify no stragglers**

```bash
find shell/assets shell/scripts -name '*inir*'
```
Expected: empty.

- [ ] **Step 8: Commit**

```bash
git add shell
git status --short
git commit -m "refactor(shell): rename inir-named asset files to ryoku-shell

Renames the bundled systemd unit, desktop entry, launcher binary, and
icon assets under shell/assets and shell/scripts. Updates each file's
internal Description / Name / Comment / Exec / Icon to Ryoku."
```

### Task 2.4: Rename inside `shell/` modules and services (bulk pass)

**Files:**
- Modify: every QML / shell / Python file under `shell/modules/`, `shell/services/`, `shell/scripts/`, `shell/sdata/` that contains `inir` or `iNiR` literals (excluding documentation files)

- [ ] **Step 1: Inventory remaining `inir` references in code (exclude docs)**

```bash
grep -rln --include='*.qml' --include='*.sh' --include='*.py' --include='*.json' --include='*.toml' \
  --include='*.kdl' --include='*.conf' --include='*.service' --include='*.desktop' \
  -e 'inir' -e 'iNiR' shell/ | sort > /tmp/inir-files.txt
wc -l /tmp/inir-files.txt
```
Expected: significant number (hundreds in the iNiR tree).

- [ ] **Step 2: Bulk rename across that file set**

```bash
xargs -a /tmp/inir-files.txt sed -i \
  -e 's|/.local/share/inir|/.local/share/ryoku-shell|g' \
  -e 's|/.config/quickshell/inir|/.config/quickshell/ryoku-shell|g' \
  -e 's|/.config/inir|/.config/ryoku-shell|g' \
  -e 's|/.cache/quickshell/inir|/.cache/quickshell/ryoku-shell|g' \
  -e 's|/.local/bin/inir\b|/.local/bin/ryoku-shell|g' \
  -e 's|inir.service|ryoku-shell.service|g' \
  -e 's|inir-super-overview|ryoku-shell-super-overview|g' \
  -e 's|inir_super_overview_daemon|ryoku-shell-super-overview-daemon|g' \
  -e 's|inir.desktop|ryoku-shell.desktop|g' \
  -e 's|inir.svg|ryoku-shell.svg|g' \
  -e 's|"inir"|"ryoku-shell"|g' \
  -e "s|'inir'|'ryoku-shell'|g" \
  -e 's|INIR_|RYOKU_SHELL_|g' \
  -e 's|iNiR|Ryoku|g'
```

- [ ] **Step 3: Manually inspect any survivors**

```bash
grep -rln --include='*.qml' --include='*.sh' --include='*.py' --include='*.json' --include='*.toml' \
  --include='*.kdl' --include='*.conf' --include='*.service' --include='*.desktop' \
  -e 'inir' -e 'iNiR' shell/ | head -10
```
Expected: empty, or only documentation files (which we deliberately preserve). If non-doc files appear, inspect and rename remaining cases manually.

- [ ] **Step 4: QML syntax sanity (catch broken imports)**

```bash
# qmllint may not be installed; do a coarse parse check instead
find shell/modules shell/services -name '*.qml' -print0 | xargs -0 -I{} sh -c 'head -c 200 "$1" >/dev/null' _ {} && echo "qml files readable"
```
Expected: `qml files readable`. (Real QML semantic checking happens at runtime via Quickshell hot-reload.)

- [ ] **Step 5: Commit**

```bash
git add shell
git commit -m "refactor(shell): rename inir/iNiR to ryoku-shell/Ryoku in code

Bulk rename across QML, Python, shell, JSON, KDL, and config files
under shell/modules, shell/services, shell/scripts, shell/sdata.
Excludes documentation files (CHANGELOG.md, README.md,
ARCHITECTURE.md, docs/*) which preserve historical iNiR mentions
as upstream credit."
```

### Task 2.5: Update About panel

**Files:**
- Modify: `shell/modules/settings/About.qml`

- [ ] **Step 1: Read current About panel**

```bash
grep -n 'iNiR\|illogical-impulse\|Ryoku\|displayName' shell/modules/settings/About.qml | head -20
```

- [ ] **Step 2: Find the credit list block**

The About panel has a list of project credit entries. Currently entries include `iNiR` and `illogical-impulse`. Find that block (likely a `ListModel` or array literal).

```bash
grep -n -B2 -A8 'illogical-impulse' shell/modules/settings/About.qml
```

- [ ] **Step 3: Add Ryoku as the primary credit entry**

The exact edit depends on the data structure. The new top entry should have: name "Ryoku", URL `https://github.com/neur0map/ryoku-arch`, and an icon (use `palette` or another suitable Material symbol). The existing iNiR entry stays (now as a credited upstream), and illogical-impulse stays (also as a credited upstream).

For example, if the structure is a series of ColumnLayout items:
```qml
ColumnLayout {
    spacing: 4
    StyledText { text: "favorite" }
    StyledText { text: "Ryoku" }
    StyledText { text: "[https://github.com/neur0map/ryoku-arch](https://github.com/neur0map/ryoku-arch)" }
}
// ... existing iNiR entry below ...
// ... existing illogical-impulse entry below ...
```

Insert the new entry as the first credit, immediately above the existing iNiR block.

- [ ] **Step 4: Manually verify the structure**

Open the file and visually confirm: Ryoku at top, iNiR second, illogical-impulse third. The framing text above the credits ("This project is a fork of...") may need a tweak: change to something like "Ryoku is built on iNiR, which is itself a fork of end-4's illogical-impulse."

- [ ] **Step 5: Commit**

```bash
git add shell/modules/settings/About.qml
git commit -m "feat(shell): add Ryoku as primary credit in About panel

Adds Ryoku (https://github.com/neur0map/ryoku-arch) as the lead
project entry. Preserves iNiR and illogical-impulse below it as
historical upstream credits. Updates the framing text to reflect
the new lineage."
```

### Task 2.6: Rename Ryoku-side files referencing iNiR

**Files:**
- Rename: `config/systemd/user/inir.service` → `ryoku-shell.service`
- Rename: `config/systemd/user/inir.service.d/` → `ryoku-shell.service.d/`
- Modify: `config/niri/config.d/40-environment.kdl`, `50-startup.kdl`, `90-user-extra.kdl`, `80-layer-rules.kdl`, `10-input-and-cursor.kdl`, `20-layout-and-overview.kdl`, `60-animations.kdl`, `70-binds.kdl`
- Modify: `config/alacritty/alacritty.toml`
- Modify: `config/matugen/templates/*` (any iNiR mentions)
- Modify: `migrations/1778000000.sh` and `migrations/1777960000.sh` (if they reference inir paths)
- Modify: `bin/ryoku-shell-cleanup-orphans` (the `terminate_exact swayidle` script . if it references inir paths or the inir launcher)

- [ ] **Step 1: Rename systemd unit + drop-in directory**

```bash
git mv config/systemd/user/inir.service config/systemd/user/ryoku-shell.service
git mv config/systemd/user/inir.service.d config/systemd/user/ryoku-shell.service.d

# Update Description and any inir refs inside
sed -i 's|Description=iNiR shell|Description=Ryoku shell|; s|inir|ryoku-shell|g; s|iNiR|Ryoku|g' \
  config/systemd/user/ryoku-shell.service \
  config/systemd/user/ryoku-shell.service.d/*.conf
```

- [ ] **Step 2: Rename inir mentions in config templates**

Build a list and bulk-replace:
```bash
grep -rl --include='*.toml' --include='*.kdl' --include='*.conf' --include='*.json' --include='*.sh' \
  -e 'inir' -e 'iNiR' config/ | sort > /tmp/ryoku-config-files.txt
xargs -a /tmp/ryoku-config-files.txt sed -i \
  -e 's|/.local/share/inir|/.local/share/ryoku-shell|g' \
  -e 's|/.config/quickshell/inir|/.config/quickshell/ryoku-shell|g' \
  -e 's|/.config/inir|/.config/ryoku-shell|g' \
  -e 's|/.local/bin/inir\b|/.local/bin/ryoku-shell|g' \
  -e 's|inir.service|ryoku-shell.service|g' \
  -e 's|"inir"|"ryoku-shell"|g' \
  -e 's|iNiR|Ryoku|g'
```

- [ ] **Step 3: Verify no stragglers in config**

```bash
grep -rln --include='*.toml' --include='*.kdl' --include='*.conf' --include='*.json' --include='*.sh' \
  -e 'inir' -e 'iNiR' config/ | head
```
Expected: empty (or, if any remain, manually inspect, they may be in comments referring to historical iNiR).

- [ ] **Step 4: Update migrations that touch inir paths**

```bash
sed -i \
  -e 's|/.local/share/inir|/.local/share/ryoku-shell|g' \
  -e 's|/.config/quickshell/inir|/.config/quickshell/ryoku-shell|g' \
  -e 's|/.config/inir|/.config/ryoku-shell|g' \
  -e 's|/.local/bin/inir\b|/.local/bin/ryoku-shell|g' \
  -e 's|inir.service|ryoku-shell.service|g' \
  -e 's|inir-super-overview.service|ryoku-shell-super-overview.service|g' \
  migrations/*.sh
```

The pristine restore migration `1778000000.sh` and the lock-fix migration `1777960000.sh` are the most likely to need this. The Phase 4 migration (added later) will use the new paths from inception.

- [ ] **Step 5: Update bin/ scripts that hardcode inir paths**

```bash
grep -ln 'inir\|iNiR' bin/ | xargs -I {} sed -i \
  -e 's|/.local/share/inir|/.local/share/ryoku-shell|g' \
  -e 's|/.config/quickshell/inir|/.config/quickshell/ryoku-shell|g' \
  -e 's|/.local/bin/inir\b|/.local/bin/ryoku-shell|g' \
  -e 's|inir.service|ryoku-shell.service|g' \
  -e 's|inir cleanup-orphans|ryoku-shell cleanup-orphans|g' \
  -e 's|"inir"|"ryoku-shell"|g' \
  -e 's|iNiR|Ryoku|g' {}
```

- [ ] **Step 6: Sanity check**

```bash
bash -n config/systemd/user/ryoku-shell.service.d/*.conf 2>&1 || true  # ini files, no syntax check
grep -rln --include='*.sh' -e 'inir' -e 'iNiR' bin/ | head
grep -rln --include='*.sh' -e 'inir' -e 'iNiR' migrations/ | head
```
Expected: no matches in bin/ or migrations/.

- [ ] **Step 7: Commit**

```bash
git add config/ migrations/ bin/
git status --short | head
git commit -m "refactor(ryoku): rename inir paths and identifiers throughout

Renames the systemd unit (inir.service -> ryoku-shell.service) and
drop-in directory, all config template references in config/
(niri/, alacritty/, matugen/), the migrations that touch the runtime
paths (1778000000, 1777960000), and bin/ scripts that hardcode the
old paths. Both internal env vars and visible labels are updated."
```

### Task 2.7: Rename `tests/niri-inir-merge-readiness.sh`

**Files:**
- Rename: `tests/niri-inir-merge-readiness.sh` → `tests/niri-shell-merge-readiness.sh`
- Modify: contents (path/identifier renames in the assertions)

- [ ] **Step 1: Rename**

```bash
git mv tests/niri-inir-merge-readiness.sh tests/niri-shell-merge-readiness.sh
```

- [ ] **Step 2: Bulk-rename references inside**

```bash
sed -i \
  -e 's|/.local/share/inir|/.local/share/ryoku-shell|g' \
  -e 's|/.config/quickshell/inir|/.config/quickshell/ryoku-shell|g' \
  -e 's|inir.service|ryoku-shell.service|g' \
  -e 's|install/config/inir.sh|install/config/shell.sh|g' \
  -e 's|"iNiR|"Ryoku|g' \
  -e 's|"inir"|"ryoku-shell"|g' \
  -e 's|iNiR|Ryoku|g' \
  tests/niri-shell-merge-readiness.sh
```

The pass-message `pass "Niri/iNiR merge readiness contract"` becomes `pass "Niri/Ryoku merge readiness contract"`.

- [ ] **Step 3: Run the test**

```bash
bash tests/niri-shell-merge-readiness.sh
```
Expected: `OK: Niri/Ryoku merge readiness contract`. If a path assertion fails, the rename in the previous tasks missed something; fix and re-run.

- [ ] **Step 4: Commit**

```bash
git add tests/niri-shell-merge-readiness.sh
git commit -m "test(merge-readiness): rename file + assertions to Ryoku-shell

Renames tests/niri-inir-merge-readiness.sh to
tests/niri-shell-merge-readiness.sh and updates all path/identifier
assertions inside to the new Ryoku-shell namespace."
```

### Task 2.8: Phase 2 verification + rest-of-repo sweep

**Files:**
- Modify: any leftover files containing `inir` outside `shell/CHANGELOG.md`, `shell/README.md`, `shell/ARCHITECTURE.md`, `shell/docs/`

- [ ] **Step 1: Search the entire repo for survivors (outside vendored docs)**

```bash
grep -rln \
  --exclude-dir='.git' \
  --exclude-dir='shell/docs' \
  --exclude='shell/CHANGELOG.md' \
  --exclude='shell/README.md' \
  --exclude='shell/ARCHITECTURE.md' \
  --exclude='shell/CONTRIBUTING.md' \
  --exclude='shell/CODE_OF_CONDUCT.md' \
  --exclude='shell/SECURITY.md' \
  --exclude='shell/welcome.qml' \
  --exclude='shell/translations/*' \
  -e 'inir' -e 'iNiR' \
  | grep -v '^docs/superpowers/specs/' \
  | grep -v '^docs/superpowers/plans/' \
  | head -30
```

The survivors fall into three categories:
- **Code that should be renamed**: rename it.
- **Vendored documentation that we kept**: leave it.
- **Spec/plan files in docs/superpowers/**: leave them (historical record of the rebrand process itself).

- [ ] **Step 2: Inspect each survivor and decide**

For each file in the grep output, run:
```bash
grep -n 'inir\|iNiR' <file>
```
Decide: rename, or document why it stays (probably as a credit/historical mention).

- [ ] **Step 3: Rename the survivors that should be renamed**

Apply the same sed pattern as in Task 2.4 / 2.6.

- [ ] **Step 4: Run all tests**

```bash
for t in tests/*.sh; do
  out=$(bash "$t" 2>&1) || printf 'FAIL %s\n%s\n' "$(basename $t)" "$(echo "$out" | tail -3)"
done
```
Expected: no FAIL lines.

- [ ] **Step 5: Commit**

```bash
git add -A
git status --short | head
git commit -m "refactor(repo): Phase 2 cleanup pass for stragglers

Final sweep of inir/iNiR references outside vendored documentation.
Confirms the rest-of-repo rename contract: every code reference is
ryoku-shell/Ryoku, while shell/docs/, shell/{CHANGELOG,README,
ARCHITECTURE,CONTRIBUTING,CODE_OF_CONDUCT,SECURITY}.md, and
shell/translations/ keep their original iNiR mentions as credit."
```

---

## PHASE 3: Convert patches to commits

After Phase 3 lands: the 5 bug-fix perl-patches that previously lived in `install/config/ryoku-shell-branding.sh` have been applied directly to `shell/` as normal QML edits. The branding script shrinks to ~50-100 lines (asset copies, JSON merge, possibly the service-cleanup hook).

### Task 3.1: Apply lock security guard to `shell/modules/lock/Lock.qml`

**Files:**
- Modify: `shell/modules/lock/Lock.qml`

- [ ] **Step 1: Find the anchor lines in Lock.qml**

```bash
grep -n 'GlobalStates.screenLocked && !lockSurfaceLoader.item' shell/modules/lock/Lock.qml
grep -n '\[Lock\] Lock surface failed to load, using swaylock fallback' shell/modules/lock/Lock.qml
```

- [ ] **Step 2: Apply the secure-state guard**

Edit `shell/modules/lock/Lock.qml`:

Replace:
```qml
running: GlobalStates.screenLocked && !lockSurfaceLoader.item
```
With:
```qml
running: GlobalStates.screenLocked && (!lock.secure || !lockSurfaceLoader.item)
```

Replace:
```qml
console.warn("[Lock] Lock surface failed to load, using swaylock fallback")
```
With:
```qml
console.warn(lock.secure ? "[Lock] Lock surface failed to load, using swaylock fallback" : "[Lock] Lock session did not become secure, using swaylock fallback")
```

- [ ] **Step 3: Verify**

```bash
grep -c 'Lock session did not become secure' shell/modules/lock/Lock.qml
grep -c '!lock.secure || !lockSurfaceLoader.item' shell/modules/lock/Lock.qml
```
Both expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add shell/modules/lock/Lock.qml
git commit -m "fix(shell/lock): guard against lock session not becoming secure

Without this guard, when niri's ext_session_lock_v1 secure-surface
timeout (~1s) elapses before the Quickshell lock surface loads,
the QML running condition triggers the swaylock fallback even
though the lock session was about to be secured properly. Add
\`!lock.secure ||\` to the running condition so the fallback only
fires once we know the session has become secure but the surface
failed to load. Differentiate the warning message accordingly."
```

### Task 3.2: Apply idle-disable-swayidle to `shell/services/Idle.qml`

**Files:**
- Modify: `shell/services/Idle.qml`

- [ ] **Step 1: Find the function signature**

```bash
grep -n 'function _startSwayidle' shell/services/Idle.qml
```

- [ ] **Step 2: Insert an early-return at the top of `_startSwayidle()`**

In the function body, immediately before the existing `if (inhibit) return`, insert:

```qml
        // RYOKU: swayidle replaced by hypridle (managed via systemd user unit
        // hypridle.service). hypridle has `inhibit_sleep = 3` which blocks
        // suspend until the lock surface is secure on the compositor.
        // This is the race-protection swayidle lacks.
        // See ~/.config/hypr/hypridle.conf.
        return

```

- [ ] **Step 3: Verify**

```bash
grep -c 'RYOKU: swayidle replaced by hypridle' shell/services/Idle.qml
```
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add shell/services/Idle.qml
git commit -m "fix(shell/idle): suppress swayidle spawn (hypridle owns lid-close)

Replaces iNiR's swayidle launch with an early-return guarded by a
RYOKU sentinel. hypridle (managed via systemd user unit
hypridle.service, with inhibit_sleep = 3) is the race-immune
replacement: it blocks suspend until the lock surface is secure on
the compositor, which swayidle cannot do. See
config/hypr/hypridle.conf."
```

### Task 3.3: Apply screen-corners input-mask guard

**Files:**
- Modify: `shell/modules/screenCorners/ScreenCorners.qml`

- [ ] **Step 1: Find the anchor**

```bash
grep -n 'item: sidebarCornerOpenInteractionLoader.active' shell/modules/screenCorners/ScreenCorners.qml
```

- [ ] **Step 2: Replace the mask region**

Find:
```qml
        exclusionMode: ExclusionMode.Ignore
        mask: Region {
            item: sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : null
        }
```

Replace with:
```qml
        exclusionMode: ExclusionMode.Ignore
        Item { id: emptyMask; width: 0; height: 0 }
        mask: Region {
            item: sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : emptyMask
        }
```

- [ ] **Step 3: Verify**

```bash
grep -c 'id: emptyMask' shell/modules/screenCorners/ScreenCorners.qml
```
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add shell/modules/screenCorners/ScreenCorners.qml
git commit -m "fix(shell/screenCorners): guard input mask against null

When sidebarCornerOpenInteractionLoader is inactive, the previous
\`item: null\` made the input mask cover the entire screen,
intermittently swallowing clicks meant for windows below. Substitute
a zero-sized Item so the mask reduces to nothing instead of
covering everything."
```

### Task 3.4: Apply wallpaper-resolution simplification

**Files:**
- Modify: `shell/services/Wallpapers.qml`

- [ ] **Step 1: Find the anchor**

```bash
grep -n 'readonly property string _resolvedMainWallpaperPath' shell/services/Wallpapers.qml
```

- [ ] **Step 2: Replace the multi-line resolution block**

Find the multi-line block that starts with `readonly property string _resolvedMainWallpaperPath: {` and ends with the corresponding closing brace.

Replace it with the single-line form:
```qml
    readonly property string _resolvedMainWallpaperPath: Config.options?.background?.wallpaperPath ?? ""
```

- [ ] **Step 3: Verify**

```bash
grep -c '_resolvedMainWallpaperPath: Config.options?.background?.wallpaperPath' shell/services/Wallpapers.qml
```
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add shell/services/Wallpapers.qml
git commit -m "fix(shell/wallpapers): simplify wallpaper path resolution

Drops the multi-monitor focused-output lookup that did not return a
useful path in any code path Ryoku exercises. The single-line form
falls through to Config.options.background.wallpaperPath, which is
what the rest of the shell already reads."
```

### Task 3.5: Apply sidebar-right keep-mapped workaround

**Files:**
- Modify: `shell/modules/sidebarRight/SidebarRight.qml`

- [ ] **Step 1: Find the anchor**

The original perl-regex in the branding script targeted a specific section. Locate the relevant area:
```bash
grep -n 'visible:\|keepMapped\|empty.*mask\|emptyMask' shell/modules/sidebarRight/SidebarRight.qml | head -10
```

- [ ] **Step 2: Apply the keep-mapped workaround**

Refer to `install/config/ryoku-shell-branding.sh:apply_sidebar_right_keep_mapped_workaround` (still present at this point) for the exact original perl substitution. Translate the substitution into a hand-edit. The general shape: introduce an `id: _emptyMask` zero-sized Item and reroute a Region's mask to it.

- [ ] **Step 3: Verify the patch marker is present**

```bash
grep -c 'id: _emptyMask' shell/modules/sidebarRight/SidebarRight.qml
```
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add shell/modules/sidebarRight/SidebarRight.qml
git commit -m "fix(shell/sidebarRight): keep-mapped workaround for qt6 dpr glitch

Translates the perl-regex workaround formerly applied at install
time by ryoku-shell-branding.sh:apply_sidebar_right_keep_mapped_workaround
into a normal QML edit in the vendored tree. The fix introduces a
zero-sized _emptyMask item and routes the Region mask through it
to avoid the qt6 device-pixel-ratio rendering glitch."
```

### Task 3.6: Shrink `install/config/ryoku-shell-branding.sh`

**Files:**
- Modify: `install/config/ryoku-shell-branding.sh` (remove the 5 retired functions + their callers + `apply_replacements_to_tree`)
- Delete: `default/ryoku-shell/branding-replacements.tsv`
- Modify: `tests/ryoku-shell-branding.sh` (drop assertions for retired functions)
- Modify: `bin/ryoku-dev-check-drift` (drop drift entries for the 5 patches now committed)

- [ ] **Step 1: Identify the function bodies to remove**

```bash
grep -nE '^(apply_lock_security_guard|apply_idle_disable_swayidle|apply_screen_corners_input_mask_guard|apply_wallpaper_resolution_patch|apply_sidebar_right_keep_mapped_workaround|apply_replacements_to_tree)' install/config/ryoku-shell-branding.sh
```

- [ ] **Step 2: Remove function bodies + main() calls**

Use sed line-range deletes for each function body (compute line ranges from Step 1's output). Then remove the `main()` invocations:

```bash
sed -i '/^  apply_lock_security_guard$/d' install/config/ryoku-shell-branding.sh
sed -i '/^  apply_idle_disable_swayidle$/d' install/config/ryoku-shell-branding.sh
sed -i '/^  apply_screen_corners_input_mask_guard$/d' install/config/ryoku-shell-branding.sh
sed -i '/^  apply_wallpaper_resolution_patch$/d' install/config/ryoku-shell-branding.sh
sed -i '/^  apply_sidebar_right_keep_mapped_workaround$/d' install/config/ryoku-shell-branding.sh
sed -i '/^  apply_replacements_to_tree "\$SHELL_PATH"$/d' install/config/ryoku-shell-branding.sh
sed -i '/^  apply_replacements_to_tree "\$RUNTIME_SHELL_PATH"$/d' install/config/ryoku-shell-branding.sh
```

For the function body deletions, use the line ranges from Step 1's grep:
```bash
# Example (replace LINE_START,LINE_END with actual values):
# sed -i 'LINE_START,LINE_END d' install/config/ryoku-shell-branding.sh
```

Each function ends with a `}` at column 1 followed by a blank line. After deleting, verify no orphan `apply_*` references remain:
```bash
grep -nE 'apply_lock_security_guard|apply_idle_disable_swayidle|apply_screen_corners_input_mask_guard|apply_wallpaper_resolution_patch|apply_sidebar_right_keep_mapped_workaround|apply_replacements_to_tree' install/config/ryoku-shell-branding.sh
```
Expected: empty.

- [ ] **Step 3: Delete the now-orphaned TSV**

```bash
git rm default/ryoku-shell/branding-replacements.tsv
```

- [ ] **Step 4: Drop drift-checker entries for the now-shipped patches**

```bash
grep -n 'lock security\|idle disable\|screen-corners input mask\|wallpaper resolution\|sidebar-right keep-mapped' bin/ryoku-dev-check-drift
```

For each drift entry corresponding to a Phase 3 patch, remove it from the script. The drift checker should now only check for the surviving installed-time mutations (asset copies, branding labels).

- [ ] **Step 5: Drop the corresponding test assertions**

```bash
grep -n 'apply_lock_security_guard\|apply_idle_disable_swayidle\|apply_screen_corners_input_mask_guard\|apply_wallpaper_resolution_patch\|apply_sidebar_right_keep_mapped_workaround\|apply_replacements_to_tree\|branding-replacements.tsv' tests/ryoku-shell-branding.sh
```

Remove each matching `assert_*` line from the test file.

- [ ] **Step 6: Run tests**

```bash
bash -n install/config/ryoku-shell-branding.sh && echo OK
bash tests/ryoku-shell-branding.sh
```
Expected: `OK`, then `PASS: ryoku shell branding`.

- [ ] **Step 7: Commit**

```bash
git add install/config/ryoku-shell-branding.sh \
        default/ryoku-shell/branding-replacements.tsv \
        tests/ryoku-shell-branding.sh \
        bin/ryoku-dev-check-drift
git status --short
git commit -m "refactor(branding): retire perl-patches now committed in shell/

The 5 bug-fix patches (apply_lock_security_guard,
apply_idle_disable_swayidle, apply_screen_corners_input_mask_guard,
apply_wallpaper_resolution_patch,
apply_sidebar_right_keep_mapped_workaround) are now normal commits
in shell/ rather than perl-regex applied at install time. Remove the
function bodies and their main() invocations. Also retire
apply_replacements_to_tree and the branding-replacements.tsv: the
strings are already Ryoku-named in the vendored tree.

Drops the corresponding drift-checker entries and test assertions.
The branding script now contains only asset copies, label edits for
the desktop entry and systemd unit, the service-cleanup hook, and
the JSON config overlay merge."
```

---

## PHASE 4: Migrate existing systems

After Phase 4 lands: a one-shot migration script transitions live iNiR installs to Ryoku-shell paths.

### Task 4.1: Write the migration script

**Files:**
- Create: `migrations/<unix-ts>.sh` (pick a timestamp greater than `1778000000`)

- [ ] **Step 1: Pick a timestamp**

```bash
ls migrations/ | sort | tail -1
# choose the next round number greater than the latest, e.g., 1778100000
```

For this plan, use `1778100000` unless that already exists; in that case, increment to `1778200000`.

- [ ] **Step 2: Create the migration**

Create `migrations/1778100000.sh`:

```bash
#!/bin/bash
# Migrate from iNiR paths to Ryoku-shell paths. Uninstall iNiR via its
# own setup uninstall (which knows every iNiR-managed path via
# installed_listfile) and then install fresh from the vendored
# shell/ tree. See spec at
# docs/superpowers/specs/2026-05-05-inir-to-ryoku-rebrand-design.md.

set -euo pipefail
trap 'echo "Migration failed. Re-run with: bin/ryoku-migrate" >&2' ERR

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

INIR_PATH="$HOME/.local/share/inir"
INIR_USER_CONFIG="$HOME/.config/inir/config.json"

# Phase 1: Banner
printf '\n'
printf '\033[1;33mMigrating iNiR to Ryoku-shell.\033[0m\n'
printf 'Desktop chrome (bar, sidebars, lock UI) will be unavailable for ~1-3 min.\n'
printf 'Existing windows persist (niri keeps running). Do NOT lock the screen.\n'
printf '\n'

# Phase 2: Pre-flight. Skip cleanly on systems with no iNiR installed.
if [[ ! -x $INIR_PATH/setup ]]; then
  echo "iNiR setup script missing at $INIR_PATH/setup; nothing to migrate."
  exit 0
fi

# Phase 3: Backup user config to a path outside the wipe scope.
ts=$(date +%s)
backup_dir="$RYOKU_STATE_PATH/inir-to-ryoku-shell-backup"
mkdir -p "$backup_dir"
if [[ -f $INIR_USER_CONFIG ]]; then
  cp "$INIR_USER_CONFIG" "$backup_dir/config.json.$ts"
  echo "Backed up iNiR user config to $backup_dir/config.json.$ts"
fi

# Phase 4: Stop iNiR services so the unit files can be safely removed.
systemctl --user stop inir.service inir-super-overview.service 2>/dev/null || true

# Phase 5: Run iNiR's own uninstall to remove every iNiR-tracked file.
"$INIR_PATH/setup" uninstall -y

# Phase 6: Wipe the iNiR source tree (uninstall does not remove its own repo).
rm -rf "$INIR_PATH"

# Phase 7: Run the new shell install pipeline. Deploys to ryoku-shell paths.
"$RYOKU_PATH/install/config/shell.sh"

# Phase 8: Re-link the niri.service.wants symlink to the new unit.
WANTS_DIR="$HOME/.config/systemd/user/niri.service.wants"
SERVICE_UNIT="$HOME/.config/systemd/user/ryoku-shell.service"
mkdir -p "$WANTS_DIR"
ln -sf "$SERVICE_UNIT" "$WANTS_DIR/ryoku-shell.service"

# Remove the old niri-wants symlink for inir.service if it still exists.
rm -f "$WANTS_DIR/inir.service"

# Phase 9: Reload user units and start ryoku-shell.
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user start ryoku-shell.service

echo
echo "Migration to Ryoku-shell complete."
if [[ -f $backup_dir/config.json.$ts ]]; then
  echo "Backup of prior iNiR config: $backup_dir/config.json.$ts"
fi
```

- [ ] **Step 3: Static checks**

```bash
bash -n migrations/1778100000.sh && echo OK
grep -c 'set -euo pipefail' migrations/1778100000.sh
grep -c 'setup uninstall -y' migrations/1778100000.sh
grep -c 'install/config/shell.sh' migrations/1778100000.sh
grep -c 'ryoku-shell.service' migrations/1778100000.sh
```
Expected: `OK`, then four counts of `1` or higher.

- [ ] **Step 4: Confirm no em-dashes (pre-commit hook)**

```bash
grep -cP '\x{2014}' migrations/1778100000.sh
```
Expected: `0`.

- [ ] **Step 5: Commit**

```bash
git add migrations/1778100000.sh
git commit -m "feat(migrations): transition iNiR install to Ryoku-shell

One-shot migration that runs iNiR's own setup uninstall -y to clean
every iNiR-managed path (15 entries in INIR_ONLY_PATHS), wipes the
~/.local/share/inir source tree, then runs install/config/shell.sh
to deploy fresh from the vendored shell/ tree to the Ryoku-shell
paths. Backs up the user's iNiR config.json to
\$RYOKU_STATE_PATH/inir-to-ryoku-shell-backup/ first."
```

### Task 4.2: Add a static test for the migration

**Files:**
- Modify: `tests/install-from-vendor.sh` (extend with migration assertions)

- [ ] **Step 1: Extend the test**

Append to `tests/install-from-vendor.sh`:

```bash
# Phase 4 migration must use the uninstall+reinstall pattern
migration_file=$(ls migrations/177810*.sh migrations/177820*.sh 2>/dev/null | sort | head -1)
if [[ -z $migration_file ]]; then
  fail "Phase 4 migration not found in migrations/"
fi
assert_match "$migration_file" 'setup uninstall -y' \
  "Phase 4 migration must run iNiR's own uninstall to clean tracked paths"
assert_match "$migration_file" 'install/config/shell.sh' \
  "Phase 4 migration must run the new shell install pipeline"
assert_match "$migration_file" 'ryoku-shell.service' \
  "Phase 4 migration must start the new ryoku-shell.service"
```

- [ ] **Step 2: Run the test**

```bash
bash tests/install-from-vendor.sh
```
Expected: `PASS: install from vendor`.

- [ ] **Step 3: Commit**

```bash
git add tests/install-from-vendor.sh
git commit -m "test(install): assert Phase 4 migration shape

Extends the vendor-only install test to also verify that the iNiR
to Ryoku-shell migration uses the proven uninstall+reinstall pattern
and starts the new ryoku-shell.service."
```

### Task 4.3: Final integration verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

```bash
for t in tests/*.sh; do
  out=$(bash "$t" 2>&1) || printf 'FAIL %s\n' "$(basename $t)"
done
echo "---"
echo "If no FAIL above, all tests passed."
```
Expected: no `FAIL` lines.

- [ ] **Step 2: Verify no `inir`/`iNiR` literals remain in code (excluding allowed paths)**

```bash
grep -rln \
  --exclude-dir='.git' \
  --exclude-dir='shell/docs' \
  --exclude-dir='shell/translations' \
  --exclude-dir='docs/superpowers/specs' \
  --exclude-dir='docs/superpowers/plans' \
  --exclude='shell/CHANGELOG.md' \
  --exclude='shell/README.md' \
  --exclude='shell/ARCHITECTURE.md' \
  --exclude='shell/CONTRIBUTING.md' \
  --exclude='shell/CODE_OF_CONDUCT.md' \
  --exclude='shell/SECURITY.md' \
  --exclude='shell/welcome.qml' \
  -e 'inir' -e 'iNiR' . | head -20
```
Expected: empty (or only allowed paths from the exclude list).

- [ ] **Step 3: Verify the install pipeline is hermetic**

```bash
grep -rn 'snowarch\|RYOKU_INIR_REPO\|RYOKU_INIR_SOURCE\|RYOKU_INIR_UPDATE' install/ migrations/ iso/ bin/ lib/ | head
```
Expected: empty.

- [ ] **Step 4: Print final commit graph**

```bash
git log --oneline origin/niri-inir-transition..HEAD
```
Expected: a list of commits matching the phases.

The plan ends here. The user will run `bin/ryoku-migrate` on their live system to execute the Phase 4 migration when ready.

---

## Spec coverage check (self-review)

| Spec section | Plan coverage |
|---|---|
| Goals: eliminate snowarch clone | Tasks 1.2, 1.3, 1.4. Test 1.5 locks the contract. |
| Goals: eliminate perl-regex patch dance | Tasks 3.1-3.6. |
| Goals: rename inir/iNiR to ryoku-shell/Ryoku | Tasks 2.1-2.8. |
| Goals: one-shot migration for existing systems | Task 4.1. Test 4.2. |
| Goals: preserve historical attribution | Task 2.5 (About panel). Tasks 2.4 + 2.8 explicitly exclude shell/CHANGELOG, shell/README, etc. |
| Non-Goals: no git subtree/submodule | Task 1.1 explicitly drops shell/.git. |
| Non-Goals: no "pull from snowarch" | Task 1.2 removes RYOKU_INIR_REPO entirely. |
| Non-Goals: no `ii` namespace rename | Plan never touches `qs.modules.ii.*`. |
| Non-Goals: no doc rewrite | Tasks 2.4 and 2.8 explicitly exclude documentation files. |
| Architecture: Phase 1 single commit | Tasks 1.1-1.5 produce 5 commits within Phase 1; the spec called for "single commit" but reviewability favors multiple. Acceptable as long as all 5 land before Phase 2 begins. |
| Phase 2 sub-items: paths, services, env vars, About, test rename | Tasks 2.1-2.7 cover each. Task 2.8 is the cleanup pass. |
| Phase 3 sub-items: 5 patches converted, branding script shrunk | Tasks 3.1-3.6. |
| Phase 4 sub-items: uninstall+reinstall pattern, backup | Task 4.1 step 2 implements both. |
| Pre-commit hooks (em-dash, no Co-Authored-By) | Plan header documents both; Task 4.1 step 4 explicitly verifies em-dash. |

No gaps found. Phase 1's "single commit" wording in the spec is the only divergence; the plan splits it for reviewability, which is consistent with the spec's spirit (each phase is "landable independently").
