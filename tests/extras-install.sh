#!/usr/bin/env bash
# hermetic test for ryoku-extras-install: the tsv parser carries tier+interactive,
# nautilus-pack and plugin items install/detect through Ryostore's internal guest
# commands, optional-tier items are skipped in a whole-bundle install, and a
# plugin install places the plugin without enabling it (install never activates).
# The actuator prepends $HOME/.local/bin to PATH, so the fakes live there and
# HOME is a temp dir; no network, no pacman, no real shell, no real ryostore.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/.."
act="$repo/system/extras/ryoku-extras-install"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

bin="$tmp/.local/bin"
mkdir -p "$bin" "$tmp/cache/bundles/default" "$tmp/cache/collections/demo" "$tmp/data" "$tmp/run"

cat >"$tmp/cache/bundles/registry.json" <<'EOF'
{ "bundles": [
  { "id": "demo", "path": "collections/demo", "components": [
    { "type": "package", "name": "corepkg", "detect": "corepkg", "tier": "core", "interactive": false, "summary": "" },
    { "type": "package", "name": "optpkg", "detect": "optpkg", "tier": "optional", "interactive": false, "summary": "" },
    { "type": "nautilus-pack", "name": "video-reformat", "detect": "video-reformat", "tier": "core", "interactive": false, "summary": "" },
    { "type": "plugin", "name": "creator-deck", "detect": "creator-deck", "tier": "core", "interactive": false, "summary": "" } ] },
  { "id": "default", "path": "", "components": [
    { "type": "package", "name": "defaultpkg", "detect": "defaultpkg", "tier": "core", "interactive": false, "summary": "" } ] } ] }
EOF
cat >"$tmp/cache/collections/demo/bundle.json" <<'EOF'
{ "id": "demo", "requires": ["gpu-lib32"], "items": [
  { "type": "package", "name": "corepkg", "tier": "core" },
  { "type": "package", "name": "optpkg", "tier": "optional" },
  { "type": "nautilus-pack", "name": "video-reformat" },
  { "type": "plugin", "name": "creator-deck" } ] }
EOF
cat >"$tmp/cache/bundles/default/bundle.json" <<'EOF'
{ "id": "default", "items": [
  { "type": "package", "name": "defaultpkg", "tier": "core" } ] }
EOF

# fake ryostore: the cache dir, and the internal guest primitives the actuator
# calls. install-guest drops the tracking/plugin manifest the actuator detects;
# remove-guest deletes it. Nothing here enables a plugin: install only places.
cat >"$bin/ryostore" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "internal cache") echo "$tmp/cache"; exit 0 ;;
  "internal bundle")
    case "\$3" in
      demo)    echo "$tmp/cache/collections/demo/bundle.json"; exit 0 ;;
      default) echo "$tmp/cache/bundles/default/bundle.json"; exit 0 ;;
    esac ;;
  "internal installer") echo "$tmp/cache/installers/\$3.sh"; exit 0 ;;
  "internal install-guest")
    case "\$3" in
      plugins)  d="$tmp/data/ryoku/plugins/\$4";  mkdir -p "\$d"; echo '{"defaults":{"host":"sidebarLeft"}}' >"\$d/manifest.json"; exit 0 ;;
      nautilus) d="$tmp/data/ryoku/nautilus/\$4"; mkdir -p "\$d"; echo '{"subdir":"Ryoku Creator"}'         >"\$d/manifest.json"; exit 0 ;;
    esac ;;
  "internal remove-guest")
    case "\$3" in
      plugins)  rm -rf "$tmp/data/ryoku/plugins/\$4";  exit 0 ;;
      nautilus) rm -rf "$tmp/data/ryoku/nautilus/\$4"; exit 0 ;;
    esac ;;
esac
exit 0
EOF

# fake pacman: nothing installed, nothing official -> packages route to the AUR.
cat >"$bin/pacman" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

chmod +x "$bin"/*
export HOME="$tmp" XDG_DATA_HOME="$tmp/data" XDG_RUNTIME_DIR="$tmp/run" PATH="$bin:$PATH"

# --- status parses the new item types without corrupting fields ---------------
out="$(bash "$act" status bundle demo)"
grep -q '"type": *"nautilus-pack"' <<<"$out" || fail "nautilus-pack missing from status"
grep -q '"type": *"plugin"' <<<"$out" || fail "plugin missing from status"
out="$(bash "$act" status bundle default)"
grep -q '"name": *"defaultpkg"' <<<"$out" || fail "empty registry path did not use canonical bundle path"

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

# --- real (non-dryrun) plugin install places the plugin, install-only ---------
bash "$act" install item demo creator-deck >/dev/null 2>&1 || true
[ -f "$tmp/data/ryoku/plugins/creator-deck/manifest.json" ] || fail "plugin not placed on install"

# --- plugin install + removal round-trips through the internal guest commands --
bash "$act" remove item demo creator-deck >/dev/null 2>&1 || true
[ -f "$tmp/data/ryoku/plugins/creator-deck/manifest.json" ] && fail "plugin not removed"

# --- nautilus pack install + removal round-trips ------------------------------
bash "$act" install item demo video-reformat >/dev/null 2>&1 || true
[ -f "$tmp/data/ryoku/nautilus/video-reformat/manifest.json" ] || fail "nautilus pack not installed"
bash "$act" remove item demo video-reformat >/dev/null 2>&1 || true
[ -f "$tmp/data/ryoku/nautilus/video-reformat/manifest.json" ] && fail "nautilus pack not removed"

echo "extras-install: all checks passed"
