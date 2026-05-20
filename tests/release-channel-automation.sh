#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
VERSION_SCRIPT="$ROOT_DIR/bin/ryoku-release-version"
BUMP_SCRIPT="$ROOT_DIR/bin/ryoku-release-bump"
CHANNEL_WORKFLOW="$ROOT_DIR/.github/workflows/release-channel-versions.yml"
STABLE_WORKFLOW="$ROOT_DIR/.github/workflows/stable-release.yml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -x $VERSION_SCRIPT ]] || fail "missing executable ryoku-release-version helper"
[[ -x $BUMP_SCRIPT ]] || fail "missing executable ryoku-release-bump helper"
[[ -f $CHANNEL_WORKFLOW ]] || fail "missing release-channel-versions workflow"
[[ -f $STABLE_WORKFLOW ]] || fail "missing stable-release workflow"

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

repo="$temp_dir/repo"
mkdir -p "$repo/bin"
cp "$VERSION_SCRIPT" "$repo/bin/ryoku-release-version"
cp "$BUMP_SCRIPT" "$repo/bin/ryoku-release-bump"
chmod +x "$repo/bin/ryoku-release-version" "$repo/bin/ryoku-release-bump"

git init "$repo" >/dev/null
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name "Ryoku Test"
printf '%s\n' "0.2.0-alpha.0" >"$repo/VERSION"
git -C "$repo" add VERSION bin/ryoku-release-version bin/ryoku-release-bump
git -C "$repo" commit -m "seed release policy helpers" >/dev/null

stable_version=$(
  RYOKU_RELEASE_CHANNEL=main \
  RYOKU_RELEASE_SHA=abcdef123456 \
  "$repo/bin/ryoku-release-version"
)
[[ $stable_version == "v0.2.0-alpha.0" ]] || \
  fail "stable channel should expose the tracked release version, got '$stable_version'"

dev_version=$(
  RYOKU_RELEASE_CHANNEL=unstable-dev \
  RYOKU_RELEASE_BUILD=17 \
  RYOKU_RELEASE_SHA=abcdef123456 \
  "$repo/bin/ryoku-release-version"
)
[[ $dev_version == "v0.2.0-alpha.0.dev.17+gabcdef1" ]] || \
  fail "unstable-dev should expose target version plus dev build and commit, got '$dev_version'"

printf '%s\n' "0.1.0-alpha-4" >"$repo/VERSION"
normalized_version=$(
  RYOKU_RELEASE_CHANNEL=main \
  RYOKU_RELEASE_SHA=abcdef123456 \
  "$repo/bin/ryoku-release-version"
)
[[ $normalized_version == "v0.1.0-alpha.4" ]] || \
  fail "legacy alpha-N versions should normalize to SemVer prerelease identifiers, got '$normalized_version'"

patch_alpha=$("$repo/bin/ryoku-release-bump" patch alpha)
[[ $patch_alpha == "0.1.1-alpha.0" ]] || \
  fail "patch alpha release should bump only PATCH, got '$patch_alpha'"

minor_alpha=$("$repo/bin/ryoku-release-bump" minor alpha)
[[ $minor_alpha == "0.2.0-alpha.0" ]] || \
  fail "minor alpha release should bump only MINOR, got '$minor_alpha'"

major_stable=$("$repo/bin/ryoku-release-bump" major stable)
[[ $major_stable == "1.0.0" ]] || \
  fail "stable major release should not include a prerelease suffix, got '$major_stable'"

rg -q 'branches:\s*\[main, unstable-dev\]' "$CHANNEL_WORKFLOW" || \
  fail "release channel workflow should validate both main and unstable-dev pushes"

rg -q 'unstable-dev-latest' "$CHANNEL_WORKFLOW" || \
  fail "release channel workflow should move an unstable-dev-latest tag on dev pushes"

rg -q 'ryoku-release-version --channel unstable-dev' "$CHANNEL_WORKFLOW" || \
  fail "release channel workflow should compute unstable versions through ryoku-release-version"

rg -q 'bump_type' "$STABLE_WORKFLOW" || \
  fail "stable release workflow should expose a bump_type dispatch input"

rg -q 'ryoku-release-bump "\$\{\{ inputs\.bump_type \}\}" "\$\{\{ inputs\.release_stage \}\}"' "$STABLE_WORKFLOW" || \
  fail "stable release workflow should compute release versions through ryoku-release-bump"

rg -q 'gh workflow run build-iso\.yml --ref "\$RELEASE_TAG"' "$STABLE_WORKFLOW" || \
  fail "stable release workflow should dispatch the ISO build for the new release tag"

echo "PASS: release channel automation follows Ryoku version policy"
