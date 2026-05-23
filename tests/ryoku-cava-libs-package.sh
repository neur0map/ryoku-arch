#!/bin/bash

set -euo pipefail

# Regression guard for the dashboard music visualiser. The Ryoku quickshell
# plugin's CavaProcessor is gated behind RYOKU_HAS_CAVA, which is only
# defined when pkg_check_modules finds libcava. Stock Arch `cava` does not
# ship a shared library, so without our cava-ryoku PKGBUILD the plugin
# silently builds without cava support, Audio.cava.values stays at zero,
# and the dashboard visualiser bars clamp to ~1e-3 * size (invisible).
#
# This test enforces that:
#   1. distro/arch/cava-ryoku/PKGBUILD exists and provides=(libcava ...).
#   2. The plugin CMake REQUIRES libcava (no QUIET / no Cava_FOUND guard),
#      so a missing libcava breaks the build instead of producing an
#      invisible visualiser at runtime.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pkgbuild="$ROOT_DIR/distro/arch/cava-ryoku/PKGBUILD"
[[ -f $pkgbuild ]] || fail "missing distro/arch/cava-ryoku/PKGBUILD"

grep -qE '^pkgname=cava-ryoku$' "$pkgbuild" || \
  fail "cava-ryoku PKGBUILD must declare pkgname=cava-ryoku"

grep -qE '^_upstream=cava$' "$pkgbuild" || \
  fail "cava-ryoku PKGBUILD must set _upstream=cava so provides/conflicts target the stock package"

grep -qE '^provides=.*libcava=' "$pkgbuild" || \
  fail "cava-ryoku PKGBUILD must declare provides=(... libcava=... ...) so dependents can require libcava"

grep -qE '^conflicts=\("?\$_upstream"?\)' "$pkgbuild" || \
  fail "cava-ryoku PKGBUILD must declare conflicts=(\"\$_upstream\") so it replaces stock cava"

grep -qE 'GIT_CEILING_DIRECTORIES=' "$pkgbuild" || \
  fail "cava-ryoku PKGBUILD must isolate cava's \`git describe\` from parent repos via GIT_CEILING_DIRECTORIES (libtool ABI version leak)"

plugin_cmake="$ROOT_DIR/shell/plugin/src/Ryoku/CMakeLists.txt"
[[ -f $plugin_cmake ]] || fail "missing shell/plugin/src/Ryoku/CMakeLists.txt"

grep -qE 'pkg_check_modules\(Cava[[:space:]]+IMPORTED_TARGET[[:space:]]+libcava[[:space:]]+REQUIRED\)' "$plugin_cmake" || \
  fail "shell/plugin/src/Ryoku/CMakeLists.txt must use pkg_check_modules(Cava IMPORTED_TARGET libcava REQUIRED) so a missing libcava fails the build loudly"

if grep -qE 'pkg_check_modules\(Cava[[:space:]]+IMPORTED_TARGET[[:space:]]+libcava[[:space:]]+QUIET\)' "$plugin_cmake"; then
  fail "shell/plugin/src/Ryoku/CMakeLists.txt must not probe Cava with QUIET (silent fallback hid the dashboard-visualiser bug)"
fi

services_cmake="$ROOT_DIR/shell/plugin/src/Ryoku/Services/CMakeLists.txt"
[[ -f $services_cmake ]] || fail "missing shell/plugin/src/Ryoku/Services/CMakeLists.txt"

if grep -qE 'if\(Cava_FOUND\)' "$services_cmake"; then
  fail "shell/plugin/src/Ryoku/Services/CMakeLists.txt must not guard cava linkage with if(Cava_FOUND) - Cava is required, not optional"
fi

grep -qE 'PkgConfig::Cava' "$services_cmake" || \
  fail "shell/plugin/src/Ryoku/Services/CMakeLists.txt must link PkgConfig::Cava unconditionally"

grep -qE 'RYOKU_HAS_CAVA=1' "$services_cmake" || \
  fail "shell/plugin/src/Ryoku/Services/CMakeLists.txt must define RYOKU_HAS_CAVA=1 unconditionally (otherwise CavaProcessor is compiled out)"

echo "PASS: cava-ryoku PKGBUILD present and plugin CMake requires libcava"
