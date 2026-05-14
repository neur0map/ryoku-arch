#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local file="$1"
  [[ -f $ROOT_DIR/$file ]] || fail "$file should exist"
}

assert_executable() {
  local file="$1"
  [[ -x $ROOT_DIR/$file ]] || fail "$file should be executable"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  assert_file "$file"
  grep -qF -- "$needle" "$ROOT_DIR/$file" || fail "$file should contain: $needle"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  assert_file "$file"
  ! grep -qF -- "$needle" "$ROOT_DIR/$file" || fail "$file should not contain: $needle"
}

assert_package_present() {
  local package="$1"
  grep -qxF "$package" "$ROOT_DIR/install/ryoku-base.packages" \
    || fail "install/ryoku-base.packages should include package: $package"
}

assert_package_absent() {
  local package="$1"
  ! grep -qxF "$package" "$ROOT_DIR/install/ryoku-base.packages" \
    || fail "install/ryoku-base.packages should not include package: $package"
}

assert_package_present neovim
assert_package_absent helix

assert_executable "install/packaging/neovim.sh"
assert_contains "install/packaging/neovim.sh" "ryoku-pkg-add neovim"
assert_contains "install/packaging/all.sh" "packaging/neovim.sh"
assert_not_contains "install/packaging/all.sh" "packaging/helix.sh"
assert_executable "install/config/neovim.sh"
assert_contains "install/config/all.sh" "config/neovim.sh"
assert_contains "install/config/neovim.sh" "RYOKU_NVIM_OFFLINE_CACHE"
assert_contains "install/config/neovim.sh" "cp -an"

assert_contains "install/config/mimetypes.sh" "xdg-mime default nvim.desktop text/plain"
assert_not_contains "install/config/mimetypes.sh" "helix.desktop"

assert_contains "bin/ryoku-launch-editor" "EDITOR=nvim"
assert_not_contains "bin/ryoku-launch-editor" "EDITOR=helix"
assert_contains "bin/ryoku-dev-add-migration" 'RYOKU_PATH="$SCRIPT_ROOT"'
assert_contains "bin/ryoku-dev-add-migration" '${EDITOR:-nvim}'
assert_contains "default/bash/aliases" "command nvim ."
assert_contains "default/bash/envs" "export EDITOR="
assert_contains "default/bash/envs" "export VISUAL="

assert_file "config/nvim/init.lua"
assert_file "config/nvim/lua/config/lazy.lua"
assert_contains "config/nvim/lua/config/lazy.lua" "folke/lazy.nvim.git"
assert_contains "config/nvim/lua/config/lazy.lua" '"LazyVim/LazyVim"'
assert_contains "shell/scripts/colors/neovim_themegen.sh" '"yukazakiri/ryoku.nvim"'
assert_contains "config/nvim/lua/plugins/ryoku.lua" 'pcall(vim.cmd.colorscheme, "ryoku-shell")'
assert_contains "config/nvim/lua/plugins/ryoku.lua" 'pcall(vim.cmd.colorscheme, "tokyonight-night")'
assert_contains "config/nvim/lua/plugins/ryoku.lua" 'vim.cmd.colorscheme("habamax")'
assert_not_contains "config/nvim/lua/plugins/ryoku.lua" '"yukazakiri/ryoku.nvim"'
assert_contains "config/nvim/lua/plugins/ryoku-dashboard.lua" "RYOKU"
assert_contains "config/nvim/lua/plugins/ryoku-dashboard.lua" '"folke/snacks.nvim"'

assert_contains "shell/defaults/config.json" '"enableNeovim": true'
assert_contains "shell/modules/common/Config.qml" "property bool enableNeovim: true"

assert_contains "iso/builder/build-iso.sh" "archiso git sudo base-devel jq grub uv neovim"
assert_contains "iso/builder/build-iso.sh" "arch_packages=(git gum jq neovim openssl plymouth)"
assert_contains "iso/builder/build-iso.sh" "var/cache/ryoku/nvim"
assert_contains "iso/builder/build-iso.sh" "Lazy! sync"
assert_contains "iso/builder/build-iso.sh" '"yukazakiri/ryoku.nvim"'
assert_contains "iso/builder/build-iso.sh" "ryoku-base.packages"
assert_contains "iso/builder/build-iso.sh" '--noconfirm -Syw "${official_packages[@]}"'
assert_contains "iso/configs/airootfs/root/.automated_script.sh" "/var/cache/ryoku/nvim"
assert_contains "iso/configs/profiledef.sh" '["/var/cache/ryoku/nvim/"]="0:0:775"'
assert_contains "install/preflight/pacman.sh" "file:///var/cache/ryoku/mirror/offline/"

latest_migration=$(find "$ROOT_DIR/migrations" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | sort -n | tail -n1)
[[ -n $latest_migration ]] || fail "a migration should exist"
assert_contains "migrations/$latest_migration" "Install Neovim and Ryoku LazyVim defaults"
assert_contains "migrations/$latest_migration" "ryoku-pkg-add neovim"
assert_contains "migrations/$latest_migration" "ryoku-refresh-config \"\$relative_path\""
assert_contains "migrations/$latest_migration" "refresh_nvim_file nvim/init.lua"
assert_contains "migrations/$latest_migration" "nvim.ryoku-lazyvim-defaults"
assert_contains "migrations/$latest_migration" "seed_nvim_offline_cache"
assert_not_contains "migrations/$latest_migration" "rm -rf \"$HOME/.config/nvim\""
assert_not_contains "migrations/$latest_migration" "pacman -R"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/ryoku-pkg-add" <<'PKGADD'
#!/bin/bash
printf '%s\n' "$@" >>"$TMPDIR/ryoku-pkg-add.log"
PKGADD
cat >"$tmp_dir/bin/ryoku-snapshot" <<'SNAPSHOT'
#!/bin/bash
exit 0
SNAPSHOT
cat >"$tmp_dir/bin/xdg-mime" <<'XDGMIME'
#!/bin/bash
printf '%s\n' "$*" >>"$TMPDIR/xdg-mime.log"
XDGMIME
chmod +x "$tmp_dir/bin/ryoku-pkg-add" "$tmp_dir/bin/ryoku-snapshot" "$tmp_dir/bin/xdg-mime"

mkdir -p "$tmp_dir/offline-nvim/lazy/lazy.nvim"
printf 'offline lazy cache\n' >"$tmp_dir/offline-nvim/lazy/lazy.nvim/README.md"

mkdir -p "$tmp_dir/home-empty/.config/ryoku-shell"
printf '{}\n' >"$tmp_dir/home-empty/.config/ryoku-shell/config.json"

empty_output=$(
  HOME="$tmp_dir/home-empty" \
  TMPDIR="$tmp_dir" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_NVIM_OFFLINE_CACHE="$tmp_dir/offline-nvim" \
  PATH="$tmp_dir/bin:$ROOT_DIR/bin:$PATH" \
    bash "$ROOT_DIR/migrations/$latest_migration"
)
[[ $empty_output == *"Neovim LazyVim defaults installed"* ]] \
  || fail "migration should report installed defaults"

[[ -f $tmp_dir/home-empty/.config/nvim/.ryoku-lazyvim ]] || fail "migration should install Ryoku nvim marker"
[[ -f $tmp_dir/home-empty/.config/nvim/init.lua ]] || fail "migration should install Ryoku nvim init"
[[ -f $tmp_dir/home-empty/.config/nvim/lua/plugins/ryoku-dashboard.lua ]] || fail "migration should install Ryoku dashboard"
[[ -f $tmp_dir/home-empty/.local/share/nvim/lazy/lazy.nvim/README.md ]] \
  || fail "migration should seed offline Neovim plugin cache"
grep -q '^export EDITOR=nvim$' "$tmp_dir/home-empty/.config/uwsm/default" || fail "migration should set EDITOR=nvim"
grep -q '^export VISUAL=nvim$' "$tmp_dir/home-empty/.config/uwsm/default" || fail "migration should set VISUAL=nvim"
grep -q '^export SUDO_EDITOR=nvim$' "$tmp_dir/home-empty/.config/uwsm/default" || fail "migration should set SUDO_EDITOR=nvim"
jq -e '.appearance.wallpaperTheming.enableNeovim == true' "$tmp_dir/home-empty/.config/ryoku-shell/config.json" >/dev/null \
  || fail "migration should enable Neovim shell theming"

mkdir -p "$tmp_dir/home-custom/.config/nvim" "$tmp_dir/home-custom/.config/ryoku-shell"
printf 'return { "user plugin" }\n' >"$tmp_dir/home-custom/.config/nvim/init.lua"
printf '{}\n' >"$tmp_dir/home-custom/.config/ryoku-shell/config.json"
rm -f "$tmp_dir/ryoku-pkg-add.log"

custom_output=$(
  HOME="$tmp_dir/home-custom" \
  TMPDIR="$tmp_dir" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_NVIM_OFFLINE_CACHE="$tmp_dir/offline-nvim" \
  PATH="$tmp_dir/bin:$ROOT_DIR/bin:$PATH" \
    bash "$ROOT_DIR/migrations/$latest_migration"
)
[[ $custom_output == *"existing ~/.config/nvim preserved"* ]] \
  || fail "migration should report preserved custom Neovim config"

grep -q 'user plugin' "$tmp_dir/home-custom/.config/nvim/init.lua" \
  || fail "migration should preserve existing custom Neovim config"
default_count=$(find "$tmp_dir/home-custom/.config" -maxdepth 1 -type d -name 'nvim.ryoku-lazyvim-defaults.*' | wc -l)
(( default_count == 1 )) || fail "migration should stage Ryoku defaults beside an existing custom Neovim config"
staged_default=$(find "$tmp_dir/home-custom/.config" -maxdepth 1 -type d -name 'nvim.ryoku-lazyvim-defaults.*' -print -quit)
[[ -f $staged_default/.ryoku-lazyvim ]] || fail "staged defaults should include Ryoku nvim marker"
[[ -f $staged_default/lua/plugins/ryoku-dashboard.lua ]] || fail "staged defaults should include Ryoku dashboard"
[[ -f $tmp_dir/home-custom/.local/share/nvim/lazy/lazy.nvim/README.md ]] \
  || fail "migration should seed offline Neovim cache with custom configs"

grep -qxF neovim "$tmp_dir/ryoku-pkg-add.log" || fail "migration should install neovim package"
jq -e '.appearance.wallpaperTheming.enableNeovim == true' "$tmp_dir/home-custom/.config/ryoku-shell/config.json" >/dev/null \
  || fail "migration should enable Neovim shell theming with custom configs"

mkdir -p "$tmp_dir/home-install"
RYOKU_NVIM_OFFLINE_CACHE="$tmp_dir/offline-nvim" \
HOME="$tmp_dir/home-install" \
  bash "$ROOT_DIR/install/config/neovim.sh"
[[ -f $tmp_dir/home-install/.local/share/nvim/lazy/lazy.nvim/README.md ]] \
  || fail "fresh install config should seed offline Neovim plugin cache"
