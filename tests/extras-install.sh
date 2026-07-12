#!/usr/bin/env bash
# hermetic test for ryoku-extras-install: the tsv parser carries tier+interactive,
# nautilus-pack items install/detect, optional-tier items are skipped in a
# whole-bundle install, and a sidebarLeft plugin is auto-enabled on install.
# The actuator prepends $HOME/.local/bin to PATH, so the fakes live there and
# HOME is a temp dir; no network, no pacman, no real shell.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/.."
act="$repo/system/extras/ryoku-extras-install"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

bin="$tmp/.local/bin"
mkdir -p "$bin" "$tmp/cache/bundles/demo" "$tmp/data" "$tmp/run"

cat >"$tmp/cache/bundles/registry.json" <<'EOF'
{ "bundles": [ { "id": "demo" } ] }
EOF
cat >"$tmp/cache/bundles/demo/bundle.json" <<'EOF'
{ "id": "demo", "requires": ["gpu-lib32"], "items": [
  { "type": "package", "name": "corepkg", "tier": "core" },
  { "type": "package", "name": "optpkg", "tier": "optional" },
  { "type": "nautilus-pack", "name": "video-reformat" },
  { "type": "plugin", "name": "creator-deck" } ] }
EOF

# fake ryoku-hub: cache dir, nautilus install/remove (writes/deletes the tracking
# manifest the actuator detects), plugin install (drops a sidebarLeft manifest).
cat >"$bin/ryoku-hub" <<EOF
#!/usr/bin/env bash
if [ "\$1 \$2" = "extras cache" ]; then echo "$tmp/cache"; exit 0; fi
if [ "\$1 \$2" = "extras nautilus" ]; then
  d="$tmp/data/ryoku/nautilus/\$3"; mkdir -p "\$d"; echo '{"subdir":"Ryoku Creator"}' >"\$d/manifest.json"; exit 0
fi
if [ "\$1 \$2" = "extras nautilusremove" ]; then
  rm -rf "$tmp/data/ryoku/nautilus/\$3"; exit 0
fi
if [ "\$1 \$2" = "extras plugin" ]; then
  d="$tmp/data/ryoku/plugins/\$3"; mkdir -p "\$d"; echo '{"defaults":{"host":"sidebarLeft"}}' >"\$d/manifest.json"; exit 0
fi
exit 0
EOF

# fake pacman: nothing installed, nothing official -> packages route to the AUR.
cat >"$bin/pacman" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

# fake ryoku-plugins-place: log every call so we can assert the auto-enable.
cat >"$bin/ryoku-plugins-place" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$tmp/place.log"
exit 0
EOF

chmod +x "$bin"/*
export HOME="$tmp" XDG_DATA_HOME="$tmp/data" XDG_RUNTIME_DIR="$tmp/run" PATH="$bin:$PATH"

# --- status parses the new item types without corrupting fields ---------------
out="$(bash "$act" status bundle demo)"
grep -q '"type": *"nautilus-pack"' <<<"$out" || fail "nautilus-pack missing from status"
grep -q '"type": *"plugin"' <<<"$out" || fail "plugin missing from status"

# --- whole-bundle DRYRUN install: core planned, optional skipped --------------
out="$(RYOKU_EXTRAS_DRYRUN=1 bash "$act" install bundle demo 2>&1)"
grep -q 'corepkg' <<<"$out" || fail "core package not planned"
grep -q 'optpkg' <<<"$out" && fail "optional package planned in whole-bundle install"
grep -qi 'nautilus pack video-reformat' <<<"$out" || fail "nautilus pack not planned"
grep -qi 'plugin creator-deck' <<<"$out" || fail "plugin not planned"
grep -q 'DRYRUN: ensure the 32-bit' <<<"$out" || fail "gpu-lib32 requirement not ensured before install"

# --- optional installs when named as a single item ----------------------------
out="$(RYOKU_EXTRAS_DRYRUN=1 bash "$act" install item demo optpkg 2>&1)"
grep -q 'optpkg' <<<"$out" || fail "optional package not installed at item scope"

# --- real (non-dryrun) plugin install auto-enables a sidebarLeft guest ---------
: >"$tmp/place.log"
bash "$act" install item demo creator-deck >/dev/null 2>&1 || true
grep -q 'creator-deck enabled true' "$tmp/place.log" || fail "sidebarLeft guest not auto-enabled"

# --- nautilus pack install + removal round-trips ------------------------------
bash "$act" install item demo video-reformat >/dev/null 2>&1 || true
[ -f "$tmp/data/ryoku/nautilus/video-reformat/manifest.json" ] || fail "nautilus pack not installed"
bash "$act" remove item demo video-reformat >/dev/null 2>&1 || true
[ -f "$tmp/data/ryoku/nautilus/video-reformat/manifest.json" ] && fail "nautilus pack not removed"

echo "extras-install: all checks passed"
