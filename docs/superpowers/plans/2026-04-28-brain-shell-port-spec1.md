# Brain_Shell Port Spec 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor Brain_Shell into Ryoku under MIT, apply 3 security patches and 4 branding patches, bridge Ryoku's theme palette into Brain_Shell's ColorLoader, and extend the existing `config/quickshell/ryoku/shell.qml` to mount Brain_Shell's TopBar plus Dashboard alongside the existing Frame, with all current Ryoku surfaces (waybar, mako, swayosd, fuzzel/tofi) untouched.

**Architecture:** Single Quickshell process named `ryoku` (already running via the existing autostart line). The extended `shell.qml` mounts the existing decorative Frame plus Brain_Shell's TopBar / PopupDismiss / ConfirmDialog / PopupLayer (with only Dashboard active in PopupLayer per Reading X). Ryoku's theme pipeline writes a JSON file that Brain_Shell's ColorLoader watches for color values. All vendored code lives under `config/quickshell/ryoku/vendor/brain-shell/` with verbatim MIT and patch-list documentation.

**Tech Stack:** Quickshell 0.2.x (already in `install/ryoku-base.packages`), QML/Qt6, bash, Hyprland, JetBrainsMono Nerd Font. No new packages added in this spec.

**Spec reference:** `docs/superpowers/specs/2026-04-28-brain-shell-port-spec1.md` (commit `f43df6e4`). Read it before starting; this plan implements it literally.

**Hook awareness (read before any commit):** The repo's `.githooks/` enforces:
- `commit-msg` rejects messages containing `Co-Authored-By:`, AI-attribution words (`claude`, `anthropic`, `assistant`, `LLM`, `chatgpt`, `gpt-N`), AI-generation phrases ("generated with", "written by claude/ai/an llm", "created using an AI"), or em-dashes (U+2014 `\xe2\x80\x94`).
- `pre-commit` rejects staged `.md`/`.sh`/`.conf`/`.tpl`/`.json`/etc. text files containing em-dashes; runs `bash -n` syntax check on staged shell scripts.

Therefore: every commit message and every text-file change must be em-dash-free. Use `-`, `:`, `,`, or `.` instead. No `Co-Authored-By` trailers. If a hook fails, fix the underlying content; do not bypass with `--no-verify`. **Vendored Brain_Shell QML files may contain em-dashes in their code comments**: this is fine because `.qml` is NOT in the pre-commit hook's text-file regex.

**Dev-vs-installed tree:** Edits land in `/home/omi/prowl/ryoku-arch/`. The runtime config lives at `~/.config/quickshell/ryoku/`. The `bin/ryoku-refresh-quickshell` script mirrors the dev tree to the runtime path. After any QML change, run `ryoku-refresh-quickshell` plus `ryoku-restart-shell` (or just rely on the migration script in Task 18).

---

## File Structure

### New files

```
config/quickshell/ryoku/vendor/brain-shell/
  LICENSE                          Verbatim upstream MIT
  UPSTREAM.md                      Provenance, commit SHA, modification list, cherry-pick procedure
  shell.qml                        Vendored upstream root (kept as reference, not loaded)
  src/
    components/, modules/, popups/, services/, shapes/, state/, theme/, windows/, scripts/
                                   Mirrors upstream src/ tree, all subdirs and qmldirs preserved

default/themed/
  ryoku-shell-colors.json.tpl      Brain_Shell ColorLoader source

migrations/
  <unix-timestamp>.sh              One-time post-update: refresh + restart Quickshell

CREDITS.md                         Repo-root credits

tests/
  brain-shell-spec1.sh             End-to-end smoke test
```

### Modified files

- `default/themed/quickshell-colors.qml.tpl`: extend the existing 7-line stub with 3 additional properties.
- `config/quickshell/ryoku/shell.qml`: extend the existing 16-line file to mount Brain_Shell components alongside Frame.

### Files NOT touched

`bin/ryoku-launch-shell`, `bin/ryoku-restart-shell`, `bin/ryoku-refresh-quickshell`, `bin/ryoku-toggle-frame`, `bin/ryoku-menu`, `default/tofi/**`, `bin/tofi`, `bin/tofi-drun`, `bin/ryoku-launch-drun`, `default/hypr/autostart.conf`, `default/hypr/bindings/**`, `install/ryoku-base.packages`, waybar / mako / swayosd / hyprlock / hypridle config and scripts, `config/quickshell/ryoku/config/Config.qml`, `config/quickshell/ryoku/modules/frame/**`.

---

## Phase A: Snapshot prerequisite (gates everything)

### Task 1: Create rollback snapshots

**Files:** none touched in repo; creates external backup paths and a git tag.

- [ ] **Step 1: Confirm clean working tree (no uncommitted changes)**

```bash
cd /home/omi/prowl/ryoku-arch
git status --short
```

Expected: only the file changes from before this session (the `M`/`??` files listed at session start). NO additions or modifications from this spec yet.

- [ ] **Step 2: Tag the dev clone**

```bash
git tag pre-brainshell-vendor-2026-04-28 HEAD
git tag --list pre-brainshell-vendor-2026-04-28
```

Expected: tag name printed.

- [ ] **Step 3: Backup installed Ryoku tree**

```bash
tstamp=$(date +%Y%m%d-%H%M%S)
echo "$tstamp" > /tmp/ryoku-snapshot-tstamp
cp -aL ~/.local/share/ryoku ~/.local/share/ryoku.pre-brainshell.$tstamp
ls -d ~/.local/share/ryoku.pre-brainshell.$tstamp
```

Expected: backup directory path printed.

- [ ] **Step 4: Backup live Quickshell config (if present)**

```bash
tstamp=$(cat /tmp/ryoku-snapshot-tstamp)
if [[ -d ~/.config/quickshell/ryoku ]]; then
  cp -aL ~/.config/quickshell/ryoku ~/.config/quickshell/ryoku.pre-brainshell.$tstamp
  ls -d ~/.config/quickshell/ryoku.pre-brainshell.$tstamp
else
  echo "no live quickshell config to back up"
fi
```

Expected: either backup path printed, or the no-config message.

- [ ] **Step 5: Optional filesystem snapshot (skip silently if neither tool installed)**

```bash
tstamp=$(cat /tmp/ryoku-snapshot-tstamp)
if command -v timeshift >/dev/null; then
  sudo timeshift --create --comments "pre-brainshell-vendor-$tstamp"
elif command -v snapper >/dev/null; then
  sudo snapper -c root create -d "pre-brainshell-vendor-$tstamp"
else
  echo "no filesystem-snapshot tool available; layers 1-3 are sufficient"
fi
```

Expected: snapshot created or the no-tool message.

- [ ] **Step 6: Print rollback recipe for the user**

```bash
tstamp=$(cat /tmp/ryoku-snapshot-tstamp)
cat <<EOF

ROLLBACK RECIPE (save this):

  pkill -x quickshell
  git -C /home/omi/prowl/ryoku-arch reset --hard pre-brainshell-vendor-2026-04-28
  rsync -a --delete ~/.local/share/ryoku.pre-brainshell.$tstamp/ ~/.local/share/ryoku/
  [ -d ~/.config/quickshell/ryoku.pre-brainshell.$tstamp ] && \\
    rsync -a --delete ~/.config/quickshell/ryoku.pre-brainshell.$tstamp/ ~/.config/quickshell/ryoku/
  # Then log out and log back in.

EOF
```

Expected: the recipe is printed; the user is told what to save.

No commit (snapshots are external; the git tag is the only repo-side artifact).

---

## Phase B: Substrate verification

### Task 2: Probe Brain_Shell against installed Quickshell

**Files:** none in repo; throwaway clone at `/tmp/bs-probe`.

- [ ] **Step 1: Clone Brain_Shell to /tmp**

```bash
rm -rf /tmp/bs-probe
git clone --depth 1 https://github.com/Brainitech/Brain_Shell /tmp/bs-probe
git -C /tmp/bs-probe rev-parse HEAD > /tmp/bs-probe-sha
echo "Brain_Shell HEAD SHA: $(cat /tmp/bs-probe-sha)"
```

Expected: clone succeeds, SHA printed (for use in UPSTREAM.md in Task 4).

- [ ] **Step 2: Try running upstream shell directly**

```bash
quickshell -c bs-probe -p /tmp/bs-probe 2>&1 | head -30 &
PROBE_PID=$!
sleep 2
pgrep -f "quickshell.*bs-probe" >/dev/null && echo "OK: probe daemon up" || echo "FAIL: probe daemon did not start"
```

Expected: "OK: probe daemon up". If FAIL, capture stderr from the head output and identify the API mismatch (likely an API renamed in Quickshell 0.2.x). Document as an additional patch in Task 4's UPSTREAM.md.

- [ ] **Step 3: If the probe started, do not interact (avoid touching the user's session); kill it**

```bash
pkill -f "quickshell.*bs-probe" 2>/dev/null
sleep 0.5
pgrep -f "quickshell.*bs-probe" >/dev/null && \
  pkill -9 -f "quickshell.*bs-probe"
```

Expected: probe daemon is gone (`pgrep` returns nothing).

- [ ] **Step 4: If probe FAILED with QML errors, STOP and resolve**

If the probe daemon failed to start with QML parse errors or missing-API errors, do NOT proceed with the plan. Identify which Quickshell API names have changed, document the substitution in UPSTREAM.md, and adjust Tasks 6-15 accordingly. The cost of fixing API drift up front is bounded; the cost of vendoring 15k lines and discovering it doesn't compile is days.

If the probe started cleanly, `/tmp/bs-probe-sha` holds the SHA we vendor at. Continue.

No commit.

---

## Phase C: Vendor + attribution skeleton

### Task 3: Create vendor directory and copy LICENSE

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/LICENSE`

- [ ] **Step 1: Confirm vendor dir does not yet exist**

```bash
[[ ! -d config/quickshell/ryoku/vendor/brain-shell ]] && echo "OK: not yet created"
```

Expected: "OK: not yet created".

- [ ] **Step 2: Create the directory and copy LICENSE**

```bash
mkdir -p config/quickshell/ryoku/vendor/brain-shell
cp /tmp/bs-probe/LICENSE config/quickshell/ryoku/vendor/brain-shell/LICENSE
```

- [ ] **Step 3: Verify LICENSE content**

```bash
head -3 config/quickshell/ryoku/vendor/brain-shell/LICENSE
```

Expected: starts with `MIT License`, includes `Copyright (c) 2026 Brainiac (Brainitech)`.

- [ ] **Step 4: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/LICENSE
git commit -m "vendor: add Brain_Shell LICENSE (MIT, Brainiac/Brainitech)"
```

Expected: commit succeeds with hooks passing.

---

### Task 4: Write UPSTREAM.md (skeleton; modifications list filled by later tasks)

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md`

- [ ] **Step 1: Write the UPSTREAM.md scaffold**

```bash
SHA=$(cat /tmp/bs-probe-sha)
cat > config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md <<EOF
# Vendored Brain_Shell

Source:        https://github.com/Brainitech/Brain_Shell
Author:        Brainiac (Brainitech)
License:       MIT (see LICENSE)
Vendored at:   $SHA
Vendored by:   Ryoku Project, with explicit permission from upstream.

This directory is the Ryoku Quickshell visual layer, derived from
Brain_Shell. Modifications below preserve the MIT license and the
upstream copyright. Future cherry-picks from upstream re-apply each
modification listed here.

## Modifications

1. Security: AppLauncher.qml line 71. Parse Exec field per freedesktop
   spec instead of shell-interpolating the raw string. Prevents command
   injection from malicious or buggy .desktop entries.
2. Security: CpuFreqService.qml line 116. Validate gov against an
   allowlist (\`performance\`, \`powersave\`, \`ondemand\`, \`conservative\`,
   \`schedutil\`, \`userspace\`) before shell interpolation.
3. Security: WallpaperService.qml line 62. Replace \`bash -c "cat
   '<path>'"\` with direct \`["cat", path]\` Process command. Removes
   single-quote-escape injection in path strings.
4. Branding: ColorLoader.qml line 39. Read colors from
   \`\$HOME/.config/ryoku/current/theme/ryoku-shell-colors.json\`,
   written by Ryoku's theme pipeline.
5. Branding: CavaService.qml. Cava temp config path moved from
   \`/tmp/brain_shell/\` to \`/tmp/ryoku-shell/\`.
6. Branding: ScreenRecService.qml. Cava recording temp config path
   moved from \`/tmp/brain_shell/\` to \`/tmp/ryoku-shell/\`.
7. Activation: PopupLayer.qml. Only Dashboard is instantiated in
   Ryoku Spec 1; other popups are commented out and re-enabled in
   follow-up specs. Border anchor properties softened from
   \`required property var\` to \`property var ... : null\`.

## Cherry-pick procedure

When pulling a fresh upstream snapshot:

1. \`git clone https://github.com/Brainitech/Brain_Shell /tmp/brainshell-fresh\`
2. Note new commit SHA.
3. \`cp -r /tmp/brainshell-fresh/src/* config/quickshell/ryoku/vendor/brain-shell/src/\`
4. \`cp /tmp/brainshell-fresh/shell.qml config/quickshell/ryoku/vendor/brain-shell/shell.qml\`
5. Re-apply each modification listed above. Diffs of prior patches
   live in git history; \`git log --follow config/quickshell/ryoku/vendor/brain-shell/src/<file>\`.
6. Update commit SHA at the top of this file.
7. Run the smoke test (\`tests/brain-shell-spec1.sh\`).

## Upstream qmldir notes

Upstream \`src/services/qmldir\` contains a typo on the line
\`TempService ./system/empService.qml\` (should be \`TempService.qml\`).
This is an upstream bug. If \`TempService\` is referenced anywhere in
the active component graph, QML will fail to resolve it. Spec 1
activates only Dashboard; if Dashboard's transitive imports do NOT
touch TempService, the typo is dormant and we leave it untouched
(preserving verbatim upstream). If Dashboard does touch TempService,
patch the qmldir to the correct filename and add Patch 8 to this file.
EOF
```

- [ ] **Step 2: Verify content**

```bash
grep -c "Modifications" config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md
grep -c $'\xe2\x80\x94' config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md
```

Expected: first command prints 1 or more; second command prints 0 (no em-dashes; pre-commit hook would reject otherwise).

- [ ] **Step 3: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md
git commit -m "vendor: add UPSTREAM.md with provenance and cherry-pick procedure"
```

Expected: commit succeeds.

---

### Task 5: Vendor src/ tree and shell.qml verbatim

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/` (entire upstream src/)
- Create: `config/quickshell/ryoku/vendor/brain-shell/shell.qml`

- [ ] **Step 1: Confirm probe clone is still present**

```bash
[[ -d /tmp/bs-probe/src ]] && echo "OK: src/ present in probe clone"
```

Expected: "OK: src/ present in probe clone". If absent, re-clone:
```bash
rm -rf /tmp/bs-probe
git clone --depth 1 https://github.com/Brainitech/Brain_Shell /tmp/bs-probe
git -C /tmp/bs-probe rev-parse HEAD > /tmp/bs-probe-sha
```

- [ ] **Step 2: Copy src/ tree and shell.qml**

```bash
cp -r /tmp/bs-probe/src config/quickshell/ryoku/vendor/brain-shell/src
cp /tmp/bs-probe/shell.qml config/quickshell/ryoku/vendor/brain-shell/shell.qml
```

- [ ] **Step 3: Verify file count and presence**

```bash
find config/quickshell/ryoku/vendor/brain-shell/src -type f | wc -l
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml ]] && echo "OK: PopupLayer present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml ]] && echo "OK: TopBar present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml ]] && echo "OK: ColorLoader present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml ]] && echo "OK: AppLauncher present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml ]] && echo "OK: CpuFreqService present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml ]] && echo "OK: CavaService present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml ]] && echo "OK: ScreenRecService present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml ]] && echo "OK: WallpaperService present"
[[ -f config/quickshell/ryoku/vendor/brain-shell/shell.qml ]] && echo "OK: shell.qml present"
```

Expected: count is around 60-70 files; all 9 named files print "OK".

- [ ] **Step 4: Confirm no upstream README.md was vendored (would fail pre-commit em-dash hook)**

```bash
[[ ! -f config/quickshell/ryoku/vendor/brain-shell/README.md ]] && echo "OK: upstream README excluded"
```

Expected: "OK: upstream README excluded". If README.md was somehow vendored, delete it:
```bash
rm -f config/quickshell/ryoku/vendor/brain-shell/README.md
```

- [ ] **Step 5: Commit (large diff; ~60 new files)**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src config/quickshell/ryoku/vendor/brain-shell/shell.qml
git commit -m "vendor: add Brain_Shell src/ and shell.qml verbatim under MIT"
```

Expected: commit succeeds. The pre-commit hook scans .md/.sh/.conf/.tpl/.json files for em-dashes; it does NOT scan .qml so vendored QML with em-dashes in comments is fine.

---

## Phase D: Security patches

### Task 6: Patch 1 - AppLauncher Exec injection

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml`

- [ ] **Step 1: Confirm current vulnerable code is present**

```bash
grep -n 'launcher.command = \["bash", "-c", "setsid " + exec' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml
```

Expected: line 71 (or near) printed. If absent, the upstream changed; check the file and adapt.

- [ ] **Step 2: Read the file to find exact context for the Edit tool**

```bash
sed -n '65,80p' config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml
```

Note the exact lines around the launch function so the Edit tool can match unambiguously.

- [ ] **Step 3: Apply the patch using your Edit tool**

Replace the line:
```javascript
        launcher.command = ["bash", "-c", "setsid " + exec + " &>/dev/null &"]
```

With:
```javascript
        // Ryoku: parse Exec per freedesktop spec (whitespace-split respecting
        // quoted args, strip %f/%u/%i/%c/%k field codes), then exec via Process
        // command array directly. Avoids shell injection from malicious or
        // buggy .desktop Exec= fields.
        function parseExec(raw) {
            var stripped = raw.replace(/%[a-zA-Z]/g, "").trim()
            var args = []
            var cur = ""
            var inQuote = null
            for (var i = 0; i < stripped.length; ++i) {
                var c = stripped[i]
                if (inQuote) {
                    if (c === inQuote) { inQuote = null } else { cur += c }
                } else if (c === '"' || c === "'") {
                    inQuote = c
                } else if (c === ' ' || c === '\t') {
                    if (cur) { args.push(cur); cur = "" }
                } else { cur += c }
            }
            if (cur) args.push(cur)
            return args
        }
        launcher.command = ["setsid"].concat(parseExec(exec))
```

Match exact indentation (8 spaces, inside the surrounding function).

- [ ] **Step 4: Verify the patch landed**

```bash
grep -q "Ryoku: parse Exec per freedesktop spec" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml \
  && echo "OK: patch comment present"
grep -q '\["setsid"\]\.concat(parseExec(exec))' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml \
  && echo "OK: patched command form present"
! grep -q '\["bash", "-c", "setsid " + exec' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml \
  && echo "OK: vulnerable form gone"
```

Expected: all three "OK" lines.

- [ ] **Step 5: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml
git commit -m "vendor: patch AppLauncher Exec field shell injection (HIGH)"
```

---

### Task 7: Patch 2 - CpuFreqService governor allowlist

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml`

- [ ] **Step 1: Confirm current vulnerable code is present**

```bash
grep -n '"echo " + gov + " | tee /sys/devices' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml
```

Expected: line 116 (or near) printed.

- [ ] **Step 2: Inspect surrounding context**

```bash
sed -n '110,125p' config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml
```

The patch adds a guard ABOVE the existing line, not replacing it.

- [ ] **Step 3: Apply the patch using your Edit tool**

Find the line:
```javascript
            "echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
```

Replace it (PRESERVING the line itself) by inserting the allowlist guard ABOVE it. Use Edit to change:
```javascript
            "echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
```

To:
```javascript
            // Ryoku: validate gov against allowlist before shell interpolation.
            // Linux kernel governors are a fixed set; reject anything else.
            (function() {
                var allowed = ["performance", "powersave", "ondemand", "conservative", "schedutil", "userspace"]
                if (allowed.indexOf(gov) === -1) {
                    console.warn("[ryoku-shell] rejected unknown CPU governor:", gov)
                    return ""
                }
                return ""
            })(),
            "echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
```

NOTE: the IIFE returns an empty string that becomes a no-op shell argument; if the surrounding context is a JS expression list (Process command array), this preserves type-safety. If the surrounding context is a single string (e.g. `"echo ..." + something`), the patch shape changes to:

```javascript
            (function() {
                var allowed = ["performance", "powersave", "ondemand", "conservative", "schedutil", "userspace"]
                return allowed.indexOf(gov) === -1 ? "true" : "echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
            })()
```

Inspect line 110-125 (Step 2 output) to determine which form fits. If unsure, use the second (string-returning) form which works in both contexts.

- [ ] **Step 4: Verify the patch landed**

```bash
grep -q "Ryoku: validate gov against allowlist" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml \
  && echo "OK: patch comment present"
grep -q '"performance", "powersave", "ondemand", "conservative", "schedutil", "userspace"' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml \
  && echo "OK: allowlist present"
```

Expected: both "OK" lines.

- [ ] **Step 5: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml
git commit -m "vendor: patch CpuFreqService governor injection with allowlist (MEDIUM)"
```

---

### Task 8: Patch 3 - WallpaperService configPath shell wrapper

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml`

- [ ] **Step 1: Confirm current vulnerable code is present**

```bash
grep -n 'command: \["bash", "-c", "cat .. + root.configPath' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml
```

Expected: line 62 (or near) printed. If grep pattern fails to match, inspect the file:
```bash
grep -n 'cat.*configPath' config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml
```

- [ ] **Step 2: Apply the patch using your Edit tool**

Replace:
```javascript
        command: ["bash", "-c", "cat '" + root.configPath + "' 2>/dev/null"]
```

With:
```javascript
        // Ryoku: drop the shell wrapper; pass path as a Process arg directly.
        // Eliminates single-quote-escape injection in path strings.
        command: ["cat", root.configPath]
```

- [ ] **Step 3: Verify the patch landed**

```bash
grep -q "Ryoku: drop the shell wrapper" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml \
  && echo "OK: patch comment present"
grep -q 'command: \["cat", root.configPath\]' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml \
  && echo "OK: patched command present"
! grep -q '"cat .. + root.configPath' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml \
  && echo "OK: vulnerable form gone"
```

Expected: all three "OK" lines.

- [ ] **Step 4: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml
git commit -m "vendor: patch WallpaperService configPath shell-quote injection (LOW)"
```

---

## Phase E: Path rebrands

### Task 9: Patch 4 - ColorLoader rebrand to Ryoku theme path

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml`

- [ ] **Step 1: Confirm current path is present**

```bash
grep -n '/.cache/brain-shell/colors.json' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml
```

Expected: at least one line printed.

- [ ] **Step 2: Inspect the lines around the path (line 5 comment + line 39 path)**

```bash
sed -n '1,10p;35,45p' config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml
```

- [ ] **Step 3: Apply the patch using your Edit tool**

Change the header comment block. The upstream block (lines 4-9 of the file) starts with `// ColorLoader` followed by an em-dash separator and the text `watches ~/.cache/brain-shell/colors.json and exposes parsed color properties` over two lines. Replace the entire upstream comment block with the new comment below (do not reproduce the em-dash; the plan file itself avoids em-dashes for the pre-commit hook):
```
// Ryoku: ColorLoader watches the Ryoku theme pipeline output at
// $HOME/.config/ryoku/current/theme/ryoku-shell-colors.json (rendered
// by ryoku-theme-set-templates from default/themed/ryoku-shell-colors.json.tpl).
// Original upstream comment removed because it referenced the
// brain-shell cache path that no longer applies.
```

Then change the assignment in `_homeProc.stdout.SplitParser.onRead`:
Replace:
```javascript
                    colorsFile.path = h + "/.cache/brain-shell/colors.json"
```

With:
```javascript
                    colorsFile.path = h + "/.config/ryoku/current/theme/ryoku-shell-colors.json"
```

- [ ] **Step 4: Verify the patch landed**

```bash
! grep -q '/.cache/brain-shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml \
  && echo "OK: brain-shell cache path gone"
grep -q '/.config/ryoku/current/theme/ryoku-shell-colors.json' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml \
  && echo "OK: ryoku theme path present"
grep -q "Ryoku: ColorLoader watches" \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml \
  && echo "OK: header comment updated"
```

Expected: all three "OK" lines.

- [ ] **Step 5: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml
git commit -m "vendor: rebrand ColorLoader path to Ryoku theme pipeline output"
```

---

### Task 10: Patch 5 - CavaService /tmp path rebrand

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml`

- [ ] **Step 1: Confirm current paths are present**

```bash
grep -n '/tmp/brain_shell' config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml
```

Expected: 2 or more lines printed (mkdir + cava -p invocation).

- [ ] **Step 2: Apply the patch using sed (multiple occurrences in same file)**

```bash
sed -i 's|/tmp/brain_shell|/tmp/ryoku-shell|g' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml
```

Then add a Ryoku marker comment near the first occurrence so future cherry-picks see it. Use Edit to find:
```javascript
            "mkdir -p /tmp/ryoku-shell && " +
```

And replace with:
```javascript
            // Ryoku: /tmp/brain_shell -> /tmp/ryoku-shell rebrand.
            "mkdir -p /tmp/ryoku-shell && " +
```

- [ ] **Step 3: Verify the patch landed**

```bash
! grep -q '/tmp/brain_shell' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml \
  && echo "OK: brain_shell tmp path gone"
grep -c '/tmp/ryoku-shell' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml
grep -q "Ryoku: /tmp/brain_shell -> /tmp/ryoku-shell rebrand" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml \
  && echo "OK: marker comment present"
```

Expected: "OK: brain_shell tmp path gone"; count is 2 or more; "OK: marker comment present".

- [ ] **Step 4: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml
git commit -m "vendor: rebrand CavaService tmp config path to /tmp/ryoku-shell"
```

---

### Task 11: Patch 6 - ScreenRecService /tmp path rebrand

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml`

- [ ] **Step 1: Confirm current paths are present**

```bash
grep -n '/tmp/brain_shell' config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml
```

Expected: 2 or more lines printed.

- [ ] **Step 2: Apply the patch using sed**

```bash
sed -i 's|/tmp/brain_shell|/tmp/ryoku-shell|g' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml
```

Then add the Ryoku marker. Use Edit to find:
```javascript
            "mkdir -p /tmp/ryoku-shell && printf '%s\\n' '" +
```

And replace with:
```javascript
            // Ryoku: /tmp/brain_shell -> /tmp/ryoku-shell rebrand.
            "mkdir -p /tmp/ryoku-shell && printf '%s\\n' '" +
```

- [ ] **Step 3: Verify the patch landed**

```bash
! grep -q '/tmp/brain_shell' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml \
  && echo "OK: brain_shell tmp path gone"
grep -c '/tmp/ryoku-shell' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml
grep -q "Ryoku: /tmp/brain_shell -> /tmp/ryoku-shell rebrand" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml \
  && echo "OK: marker comment present"
```

Expected: "OK: brain_shell tmp path gone"; count 2 or more; "OK: marker comment present".

- [ ] **Step 4: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml
git commit -m "vendor: rebrand ScreenRecService tmp config path to /tmp/ryoku-shell"
```

---

## Phase F: Theme bridge

### Task 12: Extend default/themed/quickshell-colors.qml.tpl

**Files:**
- Modify: `default/themed/quickshell-colors.qml.tpl`

- [ ] **Step 1: Confirm current 7-line stub**

```bash
cat default/themed/quickshell-colors.qml.tpl
```

Expected:
```
pragma Singleton
import QtQuick

QtObject {
    readonly property color frame: "{{ background }}"
}
```

- [ ] **Step 2: Replace with the extended template**

Use Write (overwriting):

```qml
pragma Singleton
import QtQuick

QtObject {
    // Existing property used by the decorative Frame (Config.qml reads this).
    readonly property color frame: "{{ background }}"

    // Properties added in Spec 1 for Brain_Shell components that prefer
    // QML import over JSON file watching. Currently unused; reserved for
    // future Ryoku-authored components that import Theme directly.
    readonly property color background:  "{{ background }}"
    readonly property color foreground:  "{{ foreground }}"
    readonly property color accent:      "{{ accent }}"
}
```

- [ ] **Step 3: Verify**

```bash
grep -c 'readonly property color' default/themed/quickshell-colors.qml.tpl
```

Expected: 4.

- [ ] **Step 4: Commit**

```bash
git add default/themed/quickshell-colors.qml.tpl
git commit -m "themed: extend quickshell-colors template with background, foreground, accent"
```

---

### Task 13: Add default/themed/ryoku-shell-colors.json.tpl

**Files:**
- Create: `default/themed/ryoku-shell-colors.json.tpl`

- [ ] **Step 1: Confirm file does not exist**

```bash
[[ ! -f default/themed/ryoku-shell-colors.json.tpl ]] && echo "OK: file does not exist yet"
```

- [ ] **Step 2: Create the file**

Use Write to create with this content:

```json
{
  "background": "{{ background }}",
  "active":     "{{ accent }}",
  "text":       "{{ foreground }}",
  "subtext":    "{{ color7 }}",
  "icon":       "{{ foreground }}",
  "border":     "{{ accent }}",
  "iconFont":   "{{ color6 }}"
}
```

- [ ] **Step 3: Verify**

```bash
python3 -c "import json; json.load(open('default/themed/ryoku-shell-colors.json.tpl'.replace('.tpl', '.tpl')))" 2>&1 | head -3 || echo "(template has placeholders so JSON parse expected to fail; that is normal)"
grep -c '{{' default/themed/ryoku-shell-colors.json.tpl
```

Expected: count is 7 (one placeholder per JSON value).

- [ ] **Step 4: Commit**

```bash
git add default/themed/ryoku-shell-colors.json.tpl
git commit -m "themed: add ryoku-shell-colors JSON template for Brain_Shell ColorLoader"
```

---

### Task 14: Verify theme rendering produces valid JSON

**Files:** none modified; runs the existing renderer.

- [ ] **Step 1: Mirror the dev tree to the installed tree (so the renderer sees the new template)**

```bash
ryoku-refresh-config 2>/dev/null || rsync -a --delete \
  /home/omi/prowl/ryoku-arch/default/themed/ ~/.local/share/ryoku/default/themed/
```

- [ ] **Step 2: Run the existing template renderer**

```bash
ryoku-theme-set-templates
```

Expected: no error output.

- [ ] **Step 3: Check the rendered JSON file exists and is valid**

```bash
RENDERED=""
for p in "$HOME/.config/ryoku/current/theme/ryoku-shell-colors.json" \
         "$HOME/.config/ryoku/current/next-theme/ryoku-shell-colors.json"; do
  [[ -f $p ]] && RENDERED="$p" && break
done

if [[ -z $RENDERED ]]; then
  echo "FAIL: rendered file not found at either expected path"
  exit 1
fi

echo "Rendered: $RENDERED"
cat "$RENDERED"
echo "---"
! grep -q '{{' "$RENDERED" && echo "OK: no unsubstituted placeholders"
python3 -c "import json,sys; d=json.load(open('$RENDERED')); print('OK: valid JSON, keys:', sorted(d.keys()))"
```

Expected:
- "Rendered: ..." with the path.
- 7 hex color values printed (no `{{` placeholders).
- "OK: no unsubstituted placeholders".
- "OK: valid JSON, keys: ['active', 'background', 'border', 'icon', 'iconFont', 'subtext', 'text']".

- [ ] **Step 4: Audit themes/ for missing color keys (color6, color7)**

```bash
for theme in themes/*/colors.toml; do
  for key in color6 color7; do
    grep -q "^$key " "$theme" || echo "MISSING: $key in $theme"
  done
done
```

Expected: NO "MISSING" lines. If any theme is missing `color6` or `color7`, add a sensible value matching the theme palette to that theme's `colors.toml`. Re-run Step 4 until clean.

If you had to add keys, commit:
```bash
git add themes/
git commit -m "themes: ensure color6 and color7 are defined for theme bridge"
```

If no themes needed updates, no commit.

---

## Phase G: PopupLayer activation patch (Reading X)

### Task 15: Patch 7 - Comment out 8 popups, soften border-anchor properties

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml`

- [ ] **Step 1: Confirm current state (all popups instantiated)**

```bash
cat config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml
```

Confirm the file has all of: ArchMenu, WallpaperPopup, AudioPopup, QuickControl, Dashboard, NotificationsPopup, NotificationToast, ScreenRecOptionsPopup, NetworkPopup as instantiations.

- [ ] **Step 2: Replace the file with the Reading-X version**

Use Write to overwrite:

```qml
import QtQuick
import Quickshell
import "../"

// ============================================================
// PopupLayer - the only file that instantiates popup windows.
//
// shell.qml creates the anchor windows and passes them in.
//
// Ryoku Spec 1 activation: only Dashboard is instantiated.
// Other popups are vendored as code but commented out; each is
// re-enabled in a follow-up spec when its replacement for the
// existing Ryoku surface (mako, swayosd, fuzzel, etc.) is
// validated. Border-anchor properties softened from
// `required property var` to `property var ... : null` so
// callers can pass null when no Border is mounted.
// ============================================================

Item {
    id: root

    // Anchor windows (set by shell.qml). Border anchors default to null
    // because Brain_Shell's Border is dormant in Spec 1 (Ryoku Frame
    // provides the border surface).
    required property var topBar
    property var leftBorder:   null
    property var rightBorder:  null
    property var bottomBorder: null

    // Active in Spec 1
    Dashboard { anchorWindow: root.topBar }

    // Dormant in Spec 1; re-enable in follow-up specs.
    // ArchMenu              { anchorWindow: root.leftBorder }
    // WallpaperPopup        {}
    // AudioPopup            { anchorWindow: root.rightBorder }
    // QuickControl          { anchorWindow: root.topBar }
    // NotificationsPopup    { anchorWindow: root.topBar }
    // NotificationToast     { anchorWindow: root.rightBorder }
    // ScreenRecOptionsPopup { anchorWindow: root.topBar }
    // NetworkPopup          {}
}
```

- [ ] **Step 3: Verify the activation count**

```bash
ACTIVE=$(grep -cE '^\s*Dashboard\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
DORMANT=$(grep -cE '^\s*//\s*(ArchMenu|WallpaperPopup|AudioPopup|QuickControl|NotificationsPopup|NotificationToast|ScreenRecOptionsPopup|NetworkPopup)\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
echo "Active: $ACTIVE (expected 1)"
echo "Dormant (commented): $DORMANT (expected 8)"
[[ $ACTIVE -eq 1 && $DORMANT -eq 8 ]] && echo "OK: Reading X activation"
```

Expected: "Active: 1", "Dormant (commented): 8", "OK: Reading X activation".

- [ ] **Step 4: Commit**

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml
git commit -m "vendor: PopupLayer Reading X activation (Dashboard only, others dormant)"
```

---

## Phase H: shell.qml extension

### Task 16: Extend config/quickshell/ryoku/shell.qml with Brain_Shell mounts

**Files:**
- Modify: `config/quickshell/ryoku/shell.qml`

- [ ] **Step 1: Confirm current shell.qml is the 16-line version**

```bash
cat config/quickshell/ryoku/shell.qml
```

Expected:
```qml
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Frame {}
    }

    Variants {
        model: Quickshell.screens
        ExclusionZones {}
    }
}
```

- [ ] **Step 2: Replace with the extended version**

Use Write to overwrite:

```qml
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell

// Brain_Shell vendored components (MIT, Brainiac/Brainitech).
// See config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md.
import "vendor/brain-shell/src/windows" as BSW
import "vendor/brain-shell/src/popups" as BSP

ShellRoot {
    // Existing decorative Frame, untouched.
    Variants {
        model: Quickshell.screens
        Frame {}
    }

    // Existing exclusion zones, untouched.
    Variants {
        model: Quickshell.screens
        ExclusionZones {}
    }

    // Brain_Shell additions (Spec 1: TopBar plus PopupDismiss plus
    // ConfirmDialog plus PopupLayer with Dashboard active).
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                required property var modelData

                BSW.TopBar         { id: bsTopBar; screen: modelData }
                BSW.PopupDismiss   { screen: modelData }
                BSW.ConfirmDialog  { screen: modelData }

                BSP.PopupLayer {
                    topBar: bsTopBar
                    // Border anchors stay null in Spec 1 (Frame is the
                    // border system). PopupLayer Patch 7 softens these
                    // from required to property defaults.
                }
            }
        }
    }

    Component.onCompleted: console.log("[ryoku-shell] up with brain-shell components")
}
```

- [ ] **Step 3: Verify**

```bash
grep -q 'BSW.TopBar' config/quickshell/ryoku/shell.qml && echo "OK: TopBar mounted"
grep -q 'BSP.PopupLayer' config/quickshell/ryoku/shell.qml && echo "OK: PopupLayer mounted"
grep -q 'Frame {}' config/quickshell/ryoku/shell.qml && echo "OK: Frame still mounted"
grep -q 'ExclusionZones {}' config/quickshell/ryoku/shell.qml && echo "OK: ExclusionZones still mounted"
```

Expected: all four "OK" lines.

- [ ] **Step 4: Commit**

```bash
git add config/quickshell/ryoku/shell.qml
git commit -m "quickshell: extend shell.qml with Brain_Shell TopBar plus Dashboard mounts"
```

---

## Phase I: Credits and migration

### Task 17: Add CREDITS.md at repo root

**Files:**
- Create: `CREDITS.md`

- [ ] **Step 1: Confirm CREDITS.md does not exist**

```bash
[[ ! -f CREDITS.md ]] && echo "OK: not present"
```

- [ ] **Step 2: Create the file**

Use Write to create with this content:

```markdown
# Credits

Ryoku is built on the work of others. The most significant external
contributions are below.

## Brain_Shell

The Ryoku Quickshell visual layer is derived from Brain_Shell by
Brainiac (Brainitech), MIT licensed and used with explicit permission.

- Upstream: https://github.com/Brainitech/Brain_Shell
- Vendored under: config/quickshell/ryoku/vendor/brain-shell/
- License: MIT (see config/quickshell/ryoku/vendor/brain-shell/LICENSE)
- Modifications recorded in config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md

## Omarchy

Ryoku's tooling backbone (the ryoku-* script ecosystem, theme
pipeline shape, menu architecture) descends from Omarchy. Reference
is preserved in script structure and patterns rather than file
headers.
```

- [ ] **Step 3: Verify no em-dashes (pre-commit hook would reject)**

```bash
grep -c $'\xe2\x80\x94' CREDITS.md
```

Expected: 0.

- [ ] **Step 4: Commit**

```bash
git add CREDITS.md
git commit -m "docs: add CREDITS attributing Brain_Shell upstream and Omarchy heritage"
```

---

### Task 18: Add migration script

**Files:**
- Create: `migrations/<timestamp>.sh`

- [ ] **Step 1: Pick a timestamp greater than the highest existing migration**

```bash
LAST=$(ls migrations/*.sh 2>/dev/null | sed -E 's|migrations/([0-9]+)\.sh|\1|' | sort -n | tail -1)
NOW=$(date +%s)
NEW=$(( NOW > LAST ? NOW : LAST + 1 ))
echo "$NEW" > /tmp/ryoku-migration-stamp
echo "Migration timestamp: $NEW"
echo "Migration path: migrations/${NEW}.sh"
```

- [ ] **Step 2: Create the migration**

```bash
NEW=$(cat /tmp/ryoku-migration-stamp)
cat > "migrations/${NEW}.sh" <<'EOF'
#!/bin/bash
# Spec 1 migration: the Quickshell process is already running at update
# time with the OLD shell.qml that mounts only Frame and ExclusionZones.
# After update, restart it so it picks up the NEW shell.qml that ALSO
# mounts Brain_Shell components. Without this, users wait until next
# session login to see the new shell.

set -e
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

# Skip if no graphical session.
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  exit 0
fi

# Skip if user has explicitly disabled the shell (frame-off toggle).
if ryoku-toggle-enabled frame-off; then
  exit 0
fi

# Mirror the dev tree to the user's installed config (gets the new
# shell.qml + vendor/brain-shell/ tree into ~/.config/quickshell/ryoku/).
ryoku-refresh-quickshell

# Restart the running Quickshell process so it loads the new shell.qml.
# Uses the existing helper which does pkill + setsid-respawn.
ryoku-restart-shell

# Brief grace period, then notify if the new shell came up.
sleep 0.5
if pgrep -x quickshell >/dev/null 2>&1; then
  notify-send -u low \
    "Ryoku Shell updated" \
    "Brain_Shell components are now visible alongside the existing frame and waybar. Click the center of the top to open the Dashboard. To disable everything (frame plus new components), run: ryoku-toggle-frame"
fi
EOF
chmod +x "migrations/${NEW}.sh"
```

- [ ] **Step 3: Syntax-check**

```bash
NEW=$(cat /tmp/ryoku-migration-stamp)
bash -n "migrations/${NEW}.sh" && echo "OK: bash syntax"
grep -c $'\xe2\x80\x94' "migrations/${NEW}.sh"
```

Expected: "OK: bash syntax"; em-dash count is 0.

- [ ] **Step 4: Commit**

```bash
NEW=$(cat /tmp/ryoku-migration-stamp)
git add "migrations/${NEW}.sh"
git commit -m "migration: post-update restart of Quickshell to pick up Brain_Shell shell.qml"
```

---

## Phase J: Smoke test

### Task 19: Create tests/brain-shell-spec1.sh

**Files:**
- Create: `tests/brain-shell-spec1.sh`

- [ ] **Step 1: Confirm file does not exist**

```bash
[[ ! -f tests/brain-shell-spec1.sh ]] && echo "OK: not present"
```

- [ ] **Step 2: Create the test**

Use Write:

```bash
#!/bin/bash
# Brain_Shell Spec 1 smoke test.
# Static checks against the dev tree. Run from repo root.

set -e
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "OK: $1"; }

# --- Snapshot evidence ------------------------------------------------
git rev-parse pre-brainshell-vendor-2026-04-28 >/dev/null 2>&1 \
  || fail "git tag pre-brainshell-vendor-2026-04-28 not found"
ls ~/.local/share/ryoku.pre-brainshell.* >/dev/null 2>&1 \
  || fail "installed-tree backup not found"
pass "snapshots present"

# --- File structure ---------------------------------------------------
[[ -f config/quickshell/ryoku/vendor/brain-shell/LICENSE ]]    || fail "vendored LICENSE missing"
[[ -f config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md ]] || fail "UPSTREAM.md missing"
[[ -d config/quickshell/ryoku/vendor/brain-shell/src/popups ]]  || fail "vendored src/popups missing"
[[ -d config/quickshell/ryoku/vendor/brain-shell/src/windows ]] || fail "vendored src/windows missing"
[[ -f config/quickshell/ryoku/shell.qml ]]                       || fail "shell.qml missing"
[[ -f default/themed/ryoku-shell-colors.json.tpl ]]              || fail "JSON theme template missing"
[[ -f default/themed/quickshell-colors.qml.tpl ]]                || fail "QML theme template missing"
[[ -f CREDITS.md ]]                                              || fail "CREDITS.md missing"
ls migrations/[0-9]*.sh 2>/dev/null | grep -q . \
  || fail "no migration script found in migrations/"
pass "file structure"

# --- shell.qml extends, does not replace ------------------------------
grep -q '^\s*Frame\s*{}' config/quickshell/ryoku/shell.qml \
  || fail "Frame removed from shell.qml (Spec 1 requires it stay)"
grep -q '^\s*ExclusionZones\s*{}' config/quickshell/ryoku/shell.qml \
  || fail "ExclusionZones removed from shell.qml (Spec 1 requires it stay)"
grep -q 'BSW.TopBar' config/quickshell/ryoku/shell.qml \
  || fail "Brain_Shell TopBar not mounted in shell.qml"
grep -q 'BSP.PopupLayer' config/quickshell/ryoku/shell.qml \
  || fail "Brain_Shell PopupLayer not mounted in shell.qml"
pass "shell.qml extension"

# --- Security patches applied -----------------------------------------
grep -q "Ryoku: parse Exec per freedesktop spec" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml \
  || fail "AppLauncher security patch missing"
grep -q "Ryoku: validate gov against allowlist" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml \
  || fail "CpuFreqService security patch missing"
grep -q '"cat", root.configPath' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml \
  || fail "WallpaperService security patch missing"
pass "security patches"

# --- Path rebrands ----------------------------------------------------
! grep -q '/.cache/brain-shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml \
  || fail "ColorLoader still references brain-shell cache path"
! grep -q '/tmp/brain_shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml \
  || fail "CavaService still references brain_shell tmp path"
! grep -q '/tmp/brain_shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml \
  || fail "ScreenRecService still references brain_shell tmp path"
pass "path rebrands"

# --- Theme bridge: rendered JSON is valid and substituted -------------
ryoku-theme-set-templates 2>/dev/null || true
RENDERED=""
for p in "$HOME/.config/ryoku/current/theme/ryoku-shell-colors.json" \
         "$HOME/.config/ryoku/current/next-theme/ryoku-shell-colors.json"; do
  [[ -f $p ]] && RENDERED="$p" && break
done
if [[ -n $RENDERED ]]; then
  ! grep -q '{{' "$RENDERED" || fail "rendered JSON has unsubstituted placeholders at $RENDERED"
  python3 -c "import json,sys; json.load(open('$RENDERED'))" \
    || fail "rendered JSON malformed at $RENDERED"
  pass "theme bridge"
else
  echo "SKIP: rendered theme colors not found at expected paths"
fi

# --- PopupLayer activation matches Reading X --------------------------
ACTIVE=$(grep -cE '^\s*Dashboard\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
DORMANT=$(grep -cE '^\s*//\s*(ArchMenu|WallpaperPopup|AudioPopup|QuickControl|NotificationsPopup|NotificationToast|ScreenRecOptionsPopup|NetworkPopup)\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
[[ $ACTIVE -eq 1 ]]  || fail "expected 1 active popup (Dashboard), got $ACTIVE"
[[ $DORMANT -eq 8 ]] || fail "expected 8 dormant popups, got $DORMANT"
pass "PopupLayer activation matches Reading X"

# --- Existing stack untouched -----------------------------------------
grep -q "uwsm-app -- waybar" default/hypr/autostart.conf \
  || fail "waybar exec-once was removed (Spec 1 requires it stay)"
grep -q "uwsm-app -- mako" default/hypr/autostart.conf \
  || fail "mako exec-once was removed (Spec 1 requires it stay)"
grep -q "uwsm-app -- swayosd-server" default/hypr/autostart.conf \
  || fail "swayosd exec-once was removed (Spec 1 requires it stay)"
[[ -x bin/tofi && -x bin/tofi-drun ]] \
  || fail "tofi shims were removed (Spec 1 requires they stay)"
[[ -x bin/ryoku-launch-shell ]]  || fail "ryoku-launch-shell removed"
[[ -x bin/ryoku-restart-shell ]] || fail "ryoku-restart-shell removed"
[[ -x bin/ryoku-refresh-quickshell ]] || fail "ryoku-refresh-quickshell removed"
[[ -x bin/ryoku-toggle-frame ]]  || fail "ryoku-toggle-frame removed"
pass "existing stack untouched"

echo ""
echo "Static checks passed. Run the manual checklist next:"
echo "  1. ryoku-refresh-quickshell  (mirror dev tree to ~/.config)"
echo "  2. ryoku-restart-shell       (or run the migration script)"
echo "  3. Visually verify TopBar appears alongside waybar"
echo "  4. Click center notch -> Dashboard opens with launcher tab"
echo "  5. Launch a real app from launcher tab -> window appears"
echo "  6. ryoku-theme-set <other-theme> -> colors update across Frame plus TopBar plus Dashboard"
echo "  7. ryoku-toggle-frame -> everything (Frame plus Brain_Shell) disappears"
echo "  8. ryoku-toggle-frame again -> everything comes back"
```

- [ ] **Step 3: Make executable and syntax-check**

```bash
chmod +x tests/brain-shell-spec1.sh
bash -n tests/brain-shell-spec1.sh && echo "OK: bash syntax"
grep -c $'\xe2\x80\x94' tests/brain-shell-spec1.sh
```

Expected: "OK: bash syntax"; em-dash count 0.

- [ ] **Step 4: Run the test (should pass at this point if Tasks 1-18 all completed)**

```bash
./tests/brain-shell-spec1.sh
```

Expected: every section prints "OK"; final lines print the manual checklist.

If any FAIL, identify which task left work undone and fix.

- [ ] **Step 5: Commit**

```bash
git add tests/brain-shell-spec1.sh
git commit -m "tests: add Brain_Shell Spec 1 static smoke test"
```

---

## Phase K: Mirror, restart, and full runtime verification

### Task 20: End-to-end runtime verification

**Files:** none modified; runs scripts and verifies visible behavior.

This task is the final acceptance gate. Per repo memory, picker-opens / process-up is not proof. Every visible-window claim must be verified.

- [ ] **Step 1: Mirror dev tree to live config**

```bash
ryoku-refresh-quickshell
ryoku-refresh-config 2>/dev/null || true
```

Expected: mirror succeeds; existing `~/.config/quickshell/ryoku.bak.<ts>` may have been created by `ryoku-refresh-quickshell`.

- [ ] **Step 2: Run the new migration script**

```bash
NEW=$(cat /tmp/ryoku-migration-stamp 2>/dev/null \
  || ls migrations/[0-9]*.sh | tail -1 | sed -E 's|migrations/([0-9]+)\.sh|\1|')
./migrations/${NEW}.sh
```

Expected: a notify-send notification appears in the user's session ("Ryoku Shell updated"); Quickshell process restarts.

- [ ] **Step 3: Confirm daemon started cleanly**

```bash
sleep 1
pgrep -x quickshell && echo "OK: daemon up"
journalctl --user -n 50 --no-pager 2>/dev/null | grep -i 'ryoku-shell' | tail -10
```

Expected: PID printed; the line `[ryoku-shell] up with brain-shell components` appears in the journal (or in the current Hyprland output).

- [ ] **Step 4: Verify existing Frame intact (visual)**

Look at the screen. The decorative Ryoku border around the screen edges should be unchanged from before this spec. Width and color match the active theme.

If the Frame is gone or visibly different, abort and inspect: `shell.qml` may have removed the Frame Variants block.

- [ ] **Step 5: Verify TopBar visible (visual)**

Look at the top of the focused monitor. A 3-notch Brain_Shell TopBar should appear, IN ADDITION TO the existing waybar. Two bars at top is expected for Spec 1.

If only one bar (waybar) is visible, the Brain_Shell TopBar is not rendering. Likely causes: import path wrong in shell.qml, QML parse error in TopBar or its dependencies. Inspect Quickshell stderr.

- [ ] **Step 6: Verify Dashboard opens (visual)**

Click the center notch of the Brain_Shell TopBar. The notch should expand into the Dashboard panel (approximately 900x520). Tabs visible: home, stats, kanban, launcher, config.

If the notch does not respond, the click handler in `CenterContent.qml:854` is not wired or the panel state is not propagating. Inspect.

- [ ] **Step 7: Verify launcher tab launches a real app (the critical visible-window check)**

Navigate to the launcher tab in the Dashboard. Real installed applications appear with real icons (resolved from system icon theme).

Pick a harmless app (e.g. a calculator or text editor) and launch it. **Verify the actual app window appears on screen.** Per repo memory: "picker opening is not proof the launcher works; run a real Super+Space pick app window-appears before calling launcher changes done."

If the click does not produce a window, the AppLauncher security patch (Task 6) may have a bug in `parseExec`. Inspect the parsed Exec args and the resulting Process command.

- [ ] **Step 8: Verify theme switch propagates**

```bash
CURRENT=$(cat ~/.config/ryoku/current/theme.name 2>/dev/null || echo unknown)
echo "Current theme: $CURRENT"

# Switch to a different theme.
TARGET=$(ls themes/ | grep -v "^$CURRENT$" | head -1)
echo "Switching to: $TARGET"
ryoku-theme-set "$TARGET"

sleep 1
pgrep -x quickshell && echo "OK: daemon survived theme switch (it restarts as part of ryoku-theme-set)"
```

Visually confirm: Frame, TopBar, and Dashboard all show the new theme's colors. Switch back to the original to confirm round-trip:
```bash
ryoku-theme-set "$CURRENT"
```

- [ ] **Step 9: Verify existing Ryoku surfaces still work**

- Press whatever keybind currently launches fuzzel. Fuzzel appears as before.
- Trigger a notification (e.g. `notify-send "test"`); mako popup appears as before.
- Change volume; swayosd appears as before.
- Run `ryoku-menu` (or `Super Alt+Space`); the existing tofi tree opens as before.

If any of these are broken, the existing stack was inadvertently disabled. Inspect changes to `default/hypr/autostart.conf` (which we did NOT touch in this spec; if it changed, something went wrong).

- [ ] **Step 10: Verify easy soft rollback**

```bash
ryoku-toggle-frame
sleep 1
pgrep -x quickshell && echo "FAIL: shell still running after ryoku-toggle-frame"
pgrep -x quickshell || echo "OK: shell killed"
```

Visually confirm: the Frame, TopBar, Dashboard all disappear. Only waybar (and other existing surfaces) remain.

- [ ] **Step 11: Re-enable**

```bash
ryoku-toggle-frame
sleep 1
pgrep -x quickshell && echo "OK: shell back up"
```

Visually confirm: Frame and TopBar reappear.

- [ ] **Step 12: (Optional, only if everything above failed) Hard rollback**

If runtime checks fail in unrecoverable ways, use the snapshots from Task 1:

```bash
pkill -x quickshell
git -C /home/omi/prowl/ryoku-arch reset --hard pre-brainshell-vendor-2026-04-28
tstamp=$(cat /tmp/ryoku-snapshot-tstamp)
rsync -a --delete ~/.local/share/ryoku.pre-brainshell.${tstamp}/ ~/.local/share/ryoku/
[[ -d ~/.config/quickshell/ryoku.pre-brainshell.${tstamp} ]] && \
  rsync -a --delete ~/.config/quickshell/ryoku.pre-brainshell.${tstamp}/ ~/.config/quickshell/ryoku/
# Log out and back in.
```

Diagnose the failure, restart with the lessons learned.

- [ ] **Step 13: Sign-off commit (only if any fixes were needed during runtime verification)**

If Steps 4-11 surfaced any bugs and you fixed them in Tasks 6-19, commit those fixes. Otherwise no commit; the work from Tasks 1-19 is the final state.

```bash
# Only if you fixed something:
git add -p
git commit -m "spec1: <fix description> from runtime verification"
```

If nothing needed fixing, sign off here. The user can now use Brain_Shell's TopBar and Dashboard alongside the existing waybar/mako/swayosd/fuzzel stack, with `ryoku-toggle-frame` as the one-command off-switch.

---

## Self-review

After writing the plan above, checking against the spec:

**Spec coverage:** Section 2 (in-scope items) maps to:
- Vendor src/ + shell.qml: Tasks 3 + 5
- Three security patches: Tasks 6, 7, 8
- Three path rebrands: Tasks 9, 10, 11
- Extend quickshell-colors.qml.tpl: Task 12
- Add ryoku-shell-colors.json.tpl: Task 13
- Modify shell.qml: Task 16
- Add CREDITS.md: Task 17
- Migration script: Task 18
- Smoke test: Task 19
- Snapshot prerequisite: Task 1
- Substrate verification: Task 2

Section 9 PopupLayer activation patch: Task 15. Section 10 snapshot details: Task 1. Section 13 acceptance criteria: covered by Tasks 19 (static) and 20 (runtime).

**Placeholder scan:** searched the plan for TBD / TODO / "implement later" / "fill in details" / "Add appropriate" / "Similar to Task N". None found in plan content; the only TODO-like is the conditional CpuFreqService patch shape selection in Task 7 Step 3, which gives the implementer a deterministic if-then between two complete code blocks (not a "fill in"). Acceptable.

**Type/name consistency:** `Theme` properties from the extended template (`background`, `foreground`, `accent`, `frame`) match between Tasks 12 and the shell.qml import expectations. JSON keys (`background`, `active`, `text`, `subtext`, `icon`, `border`, `iconFont`) match Brain_Shell's `ColorLoader._parse` from the spec's Section 5. PopupLayer `topBar` / `leftBorder` / etc. property names match between Task 15 and Task 16.

**Hook hygiene:** every commit message uses simple area:action format with no em-dashes, AI words, or Co-Authored-By. Every text-file content block (CREDITS.md, UPSTREAM.md, migration script, smoke test) is em-dash-free. Vendored .qml files may contain em-dashes in code comments which is fine (the pre-commit hook does not scan .qml).

Plan saved to `docs/superpowers/plans/2026-04-28-brain-shell-port-spec1.md`.
