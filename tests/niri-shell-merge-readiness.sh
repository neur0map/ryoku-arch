#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

assert_file() {
  local path="$1"

  [[ -f $path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  assert_file "$path"
  [[ -x $path ]] || fail "$path should be executable"
}

assert_package_present() {
  local file="$1"
  local package="$2"

  grep -qxF "$package" "$file" || fail "$file should include package: $package"
}

assert_package_absent() {
  local file="$1"
  local package="$2"

  if grep -qxF "$package" "$file"; then
    fail "$file should not include old default package: $package"
  fi
}

assert_path_absent() {
  local path="$1"

  [[ ! -e $path ]] || fail "$path should not be a default source path after Niri/Ryoku migration"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

assert_order() {
  local file="$1"
  local first_pattern="$2"
  local second_pattern="$3"
  local message="$4"
  local first_line second_line

  first_line=$(grep -nE "$first_pattern" "$file" | head -n1 | cut -d: -f1)
  second_line=$(grep -nE "$second_pattern" "$file" | head -n1 | cut -d: -f1)

  [[ -n $first_line && -n $second_line ]] || fail "$message"
  (( first_line < second_line )) || fail "$message"
}

base_packages="install/ryoku-base.packages"
aur_packages="install/ryoku-aur.packages"

assert_file "$base_packages"
assert_file "$aur_packages"
assert_file "lib/pacman-conflicts.sh"

removed_packages=(
  elephant
  hyprland
  hyprland-guiutils
  hyprsunset
  mako
  swayidle
  swayosd
  tofi
  walker
  waybar
  xdg-desktop-portal-hyprland
)

required_base_packages=(
  adwaita-icon-theme
  awww
  bc
  blueman
  brightnessctl
  breeze-icons
  cliphist
  coreutils
  curl
  ddcutil
  eza
  ffmpeg
  fuzzel
  fish
  fontconfig
  fprintd
  frameworkintegration
  geoclue
  git
  glib2
  gnome-keyring
  grim
  gum
  hicolor-icon-theme
  hypridle
  hyprlock
  hyprpicker
  imagemagick
  inotify-tools
  jq
  jemalloc
  kdialog
  kdecoration
  kconfig
  kirigami
  kitty
  kvantum
  libdbusmenu-gtk3
  libdrm
  libnotify
  libpipewire
  libqalculate
  libxcb
  mesa
  mission-center
  mpv
  mpv-mpris
  nautilus
  networkmanager
  niri
  noto-fonts-emoji
  pacman-contrib
  papirus-icon-theme
  pavucontrol
  pipewire
  pipewire-alsa
  pipewire-pulse
  playerctl
  plasma-integration
  polkit
  polkit-gnome
  python
  qt6-5compat
  qt6-base
  qt6-declarative
  qt6-imageformats
  qt6-multimedia
  qt6-multimedia-ffmpeg
  qt6-positioning
  qt6-quicktimeline
  qt6-sensors
  qt6-svg
  qt6-tools
  qt6-translations
  qt6-virtualkeyboard
  qt6-wayland
  qt5-graphicaleffects
  qt6ct
  quickshell
  ripgrep
  rsync
  sddm
  slurp
  socat
  starship
  swaylock
  swappy
  syntax-highlighting
  tesseract
  tesseract-data-eng
  ttf-dejavu
  ttf-liberation
  ttf-material-symbols-variable
  ttf-roboto
  ttf-roboto-mono
  upower
  uv
  wayland
  wf-recorder
  wget
  wl-clipboard
  wireplumber
  wlsunset
  wtype
  xdg-desktop-portal
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xdg-user-dirs
  xdg-utils
  xwayland-satellite
  ydotool
  yt-dlp
)

required_aur_packages=(
  darkly-bin
  gradia
  limine-mkinitcpio-hook
  limine-snapper-sync
  localsend
  trayscale
)

for package in "${removed_packages[@]}"; do
  assert_package_absent "$base_packages" "$package"
  assert_package_absent "$aur_packages" "$package"
done

assert_package_absent "$base_packages" "limine-mkinitcpio-hook"
assert_package_absent "$base_packages" "limine-snapper-sync"

for package in "${required_base_packages[@]}"; do
  assert_package_present "$base_packages" "$package"
done

for package in "${required_aur_packages[@]}"; do
  assert_package_present "$aur_packages" "$package"
done

old_default_paths=(
  bin/ryoku-hyprland-active-window-transparency-toggle
  bin/ryoku-hyprland-global-opacity-toggle
  bin/ryoku-hyprland-monitor-focused
  bin/ryoku-hyprland-monitor-internal
  bin/ryoku-hyprland-monitor-scaling-cycle
  bin/ryoku-hyprland-monitor-watch
  bin/ryoku-hyprland-monitors-many
  bin/ryoku-hyprland-monitors-none
  bin/ryoku-hyprland-scratchpad-hide
  bin/ryoku-hyprland-scratchpad-toggle
  bin/ryoku-hyprland-scratchpad-window-toggle
  bin/ryoku-hyprland-toggle
  bin/ryoku-hyprland-toggle-disabled
  bin/ryoku-hyprland-toggle-enabled
  bin/ryoku-hyprland-window-close-all
  bin/ryoku-hyprland-window-gaps-toggle
  bin/ryoku-hyprland-window-pop
  bin/ryoku-hyprland-window-single-square-aspect-toggle
  bin/ryoku-hyprland-workspace-layout-toggle
  bin/ryoku-refresh-hypridle
  bin/ryoku-refresh-hyprland
  bin/ryoku-refresh-hyprlock
  bin/ryoku-refresh-hyprsunset
  bin/ryoku-refresh-swayosd
  bin/ryoku-refresh-walker
  bin/ryoku-refresh-waybar
  bin/ryoku-restart-hyprctl
  bin/ryoku-restart-hypridle
  bin/ryoku-restart-hyprsunset
  bin/ryoku-restart-mako
  bin/ryoku-restart-swayosd
  bin/ryoku-restart-walker
  bin/ryoku-restart-waybar
  bin/ryoku-swayosd-brightness
  bin/ryoku-swayosd-client
  bin/ryoku-swayosd-kbd-brightness
  bin/ryoku-toggle-frame
  bin/ryoku-toggle-waybar
  bin/tofi
  bin/tofi-drun
  config/elephant
  config/hyprland-preview-share-picker
  config/quickshell/ryoku
  config/swayosd
  config/uwsm
  config/waybar
  default/hypr
  default/mako
  default/sddm/pixel-rainyroom
  default/themed/tofi.conf.tpl
  default/themed/hyprland-preview-share-picker.css.tpl
  default/themed/hyprland.conf.tpl
  default/themed/hyprlock.conf.tpl
  default/themed/mako.ini.tpl
  default/themed/noctalia-colors.json.tpl
  default/themed/quickshell-colors.qml.tpl
  default/themed/ryoku-shell-colors.json.tpl
  default/themed/swayosd.css.tpl
  default/themed/walker.css.tpl
  default/themed/waybar.css.tpl
  default/tofi
  default/waybar
)

for path in "${old_default_paths[@]}"; do
  assert_path_absent "$path"
done

preserved_screensaver_paths=(
  bin/ryoku-cmd-screensaver
  bin/ryoku-launch-screensaver
  default/alacritty/screensaver.toml
  default/ghostty/screensaver
)

for path in "${preserved_screensaver_paths[@]}"; do
  assert_file "$path"
done

new_backend_paths=(
  config/Kvantum/kvantum.kvconfig
  config/alacritty/colors.toml
  config/btop/themes/ii-auto.theme
  config/foot/foot.ini
  config/fuzzel/fuzzel.ini
  config/fuzzel/fuzzel_theme.ini
  config/gtk-3.0/gtk.css
  config/gtk-3.0/settings.ini
  config/gtk-4.0/gtk.css
  config/gtk-4.0/settings.ini
  config/lazygit/config.yml
  config/matugen/config.toml
  config/matugen/templates.json
  config/niri/config.kdl
  config/niri/config.d/70-binds.kdl
  config/starship/ii-palette.toml
  config/systemd/user/ryoku-shell.service
  config/xdg-desktop-portal/niri-portals.conf
)

for path in "${new_backend_paths[@]}"; do
  assert_file "$path"
done

assert_executable bin/ryoku-restart-ui
assert_executable bin/ryoku-restart-shell
assert_executable bin/ryoku-session-recover
assert_executable bin/ryoku-cmd-profile-list
assert_executable bin/ryoku-cmd-profile-status
assert_executable bin/ryoku-install-profile
assert_executable bin/ryoku-doctor
assert_executable bin/ryoku-update-system-pkgs
assert_executable bin/ryoku-shell-cleanup-orphans
assert_executable bin/ryoku-refresh-limine
assert_executable bin/ryoku-ipc
assert_executable bin/ryoku-lock-screen
assert_executable bin/ryoku-theme-set-shell
assert_executable bin/ryoku-system-logout
assert_executable bin/ryoku-sddm-autologin
assert_executable bin/ryoku-refresh-sddm
assert_executable install/config/shell.sh
assert_executable install/config/session-recover.sh
assert_executable default/systemd/system-sleep/ryoku-session-recover

bash -n bin/ryoku-restart-ui
bash -n bin/ryoku-restart-shell
bash -n bin/ryoku-session-recover
bash -n bin/ryoku-cmd-profile-list
bash -n bin/ryoku-cmd-profile-status
bash -n bin/ryoku-install-profile
bash -n bin/ryoku-doctor
bash -n install/profiles/lib.sh
bash -n bin/ryoku-update-system-pkgs
bash -n bin/ryoku-shell-cleanup-orphans
bash -n bin/ryoku-refresh-limine
bash -n lib/pacman-conflicts.sh
bash -n bin/ryoku-ipc
bash -n bin/ryoku-lock-screen
bash -n bin/ryoku-theme-set-shell
bash -n bin/ryoku-system-logout
bash -n bin/ryoku-sddm-autologin
bash -n bin/ryoku-refresh-sddm
bash -n migrations/1778560467.sh
bash -n install/config/shell.sh
bash -n install/config/session-recover.sh
bash -n default/systemd/system-sleep/ryoku-session-recover

assert_contains install/config/all.sh 'config/shell\.sh' "installer should run the Ryoku shell installer"
assert_contains install/config/all.sh 'config/session-recover\.sh' "installer should install Ryoku session resume recovery"
assert_contains install/packaging/fonts.sh 'config/fonts' "font packaging should install bundled Ryoku-visible fonts for offline installs"
assert_contains bin/ryoku-update-perform 'packaging/base\.sh' "updates should reconcile the default pacman package manifest before running Ryoku"
assert_contains bin/ryoku-update-perform 'packaging/aur-core\.sh' "updates should reconcile the default AUR package manifest before running Ryoku"
assert_contains bin/ryoku-update-perform 'config/shell\.sh' "updates should install or refresh Ryoku shell before running migrations"
assert_contains bin/ryoku-update-perform 'bash "\$RYOKU_INSTALL/packaging/base\.sh"' "updates should run base packaging through bash because install fragments are sourced, not executable"
assert_contains bin/ryoku-update-perform 'bash "\$RYOKU_INSTALL/packaging/aur-core\.sh"' "updates should run AUR packaging through bash because install fragments are sourced, not executable"
assert_order bin/ryoku-update-perform 'ryoku-update-aur-pkgs' 'packaging/aur-core\.sh' "updates should bootstrap/update AUR access before installing default AUR packages"
assert_order bin/ryoku-update-perform 'packaging/aur-core\.sh' 'config/shell\.sh' "updates should install default AUR packages before running Ryoku shell setup"
assert_order bin/ryoku-update-perform 'config/shell\.sh' 'ryoku-migrate' "updates should install or refresh Ryoku shell before migration cleanup"
assert_contains bin/ryoku-update 'ryoku-doctor update' "update failures should tell users to run the doctor"
assert_contains shell/services/ShellUpdates.qml 'ryoku-doctor update' "shell update failures should tell users to run the doctor"
assert_contains migrations/1778560467.sh 'ryoku-update' "migration should expose ryoku-update in the user launcher path"
assert_contains migrations/1778560467.sh 'ryoku-doctor' "migration should expose ryoku-doctor in the user launcher path"
assert_contains bin/ryoku-update-system-pkgs 'ryoku_pacman_repair_conflicts_from_log' "system package updates should clear pacman file conflicts from the latest failed log before pacman -Syu"
assert_contains lib/pacman-conflicts.sh 'exists.*filesystem' "pacman conflict repair should parse generic pacman file conflict lines"
assert_not_contains bin/ryoku-update-system-pkgs 'semver|move_unowned_node_module' "system package conflict repair should not be hardcoded to semver"
assert_contains install/config/shell.sh 'RYOKU_SHELL_PATH' "Ryoku shell installer should support custom install path injection"
assert_contains install/config/shell.sh 'SHELL_VENDOR' "Ryoku shell installer should reference the vendored shell tree"
assert_contains install/config/shell.sh 'niri\.service\.wants' "Ryoku installer should wire ryoku-shell.service into niri.service.wants for first login"
assert_contains iso/bin/ryoku-iso-make '/ryoku:ro' "local-source ISO builds should mount a local Ryoku checkout when available"
assert_contains iso/builder/build-iso.sh 'RYOKU_INSTALLER_REPO|github\.com/neur0map/ryoku-arch' "production ISO builds should bundle Ryoku during the build, not during installed-system setup"
assert_contains iso/builder/build-iso.sh 'sdata/uv/requirements\.txt|UV_CACHE_DIR' "ISO builder should prefetch Ryoku Python wheels for offline setup"
assert_contains iso/builder/build-iso.sh 'root/ryoku/shell' "ISO builder should use the Ryoku shell tree in the live environment"
assert_contains iso/configs/airootfs/root/.automated_script.sh '/var/cache/ryoku/uv' "ISO installer should bind the bundled uv cache into the installed system"
assert_contains shell/settings.qml 'ExtrasConfig\.qml' "Settings should expose the Extras profiles page"
assert_contains shell/modules/settings/SettingsOverlay.qml 'ExtrasConfig\.qml' "Settings overlay should expose the Extras profiles page"
assert_contains shell/modules/settings/ExtrasConfig.qml 'ryoku-install-profile' "Extras should install profiles through the Ryoku profile command"
assert_contains shell/modules/settings/ExtrasConfig.qml '^import qs$' "Extras should import root singletons before using GlobalStates"
assert_file install/profiles/gaming/profile
assert_file install/profiles/gaming/packages
assert_file install/profiles/gaming/aur.packages
assert_not_contains iso/configs/airootfs/root/.automated_script.sh '/root/inir' "ISO installer should not copy legacy shell source paths"
assert_contains bin/ryoku-restart-ui 'ryoku-restart-shell|ryoku-shell\.service' "ryoku-restart-ui should restart Ryoku shell"
assert_not_contains bin/ryoku-restart-ui 'hyprctl reload|restart_always "mako"|swayosd-server|restart_if_running "waybar"|restart_if_running "hypridle"' "ryoku-restart-ui should not restart old Hyprland-era UI services"
assert_contains bin/ryoku-restart-shell 'ryoku-shell\.service|ryoku-shell restart' "ryoku-restart-shell should target Ryoku shell"
assert_not_contains bin/ryoku-restart-shell 'qs -c ryoku|ryoku-launch-shell|pkill -x quickshell' "ryoku-restart-shell should not target the old Ryoku Quickshell shell"
assert_contains bin/ryoku-session-recover 'niri msg action power-on-monitors' "resume recovery should power Niri outputs back on"
assert_contains bin/ryoku-session-recover 'ryoku-restart-ui --quiet' "resume recovery should hard-refresh Ryoku UI"
assert_contains bin/ryoku-shell-cleanup-orphans 'ryoku-shell cleanup-orphans' "Ryoku cleanup should preserve upstream shell runtime cleanup"
assert_contains config/systemd/user/ryoku-shell.service 'ryoku-shell-cleanup-orphans --quiet' "Ryoku shell service should clean stale shell helpers after stop"
assert_contains default/systemd/system-sleep/ryoku-session-recover 'ryoku-session-recover' "system sleep hook should trigger Ryoku session recovery"
assert_contains default/limine/default.conf '^TARGET_OS_NAME="Ryoku"$' "Limine default OS name should be Ryoku"
assert_contains default/limine/default.conf '^CUSTOM_UKI_NAME="ryoku"$' "Limine default UKI name should be ryoku"
assert_contains default/limine/limine.conf '^interface_branding: Ryoku Bootloader$' "Limine boot menu branding should be Ryoku"
assert_contains bin/ryoku-refresh-limine 'limine-mkinitcpio' "Limine refresh should regenerate the Ryoku UKI"
assert_contains bin/ryoku-refresh-limine 'omarchy_linux\.efi' "Limine refresh should remove the legacy Omarchy UKI after Ryoku verification"
assert_contains bin/ryoku-theme-set 'ryoku-theme-set-shell' "theme switching should sync Ryoku colors into the Niri shell"
assert_contains bin/ryoku-lock-screen 'ryoku-shell lock activate' "lock screen should use Ryoku shell lock"
assert_not_contains bin/ryoku-lock-screen 'hyprlock|hyprctl' "lock screen should not use Hyprland lock helpers"
assert_contains bin/ryoku-system-logout 'ryoku-shell session (toggle|open)' "logout command should open the Ryoku session UI"
assert_contains bin/ryoku-sddm-autologin 'Session=niri\.desktop' "SDDM autologin should target niri.desktop"
assert_contains install/login/sddm.sh 'ii-pixel' "fresh installs should validate the Ryoku ii-pixel SDDM theme"
assert_not_contains install/login/sddm.sh 'pixel-rainyroom' "fresh installs should not validate the retired Ryoku pixel-rainyroom theme"
assert_contains bin/ryoku-refresh-sddm 'install-pixel-sddm' "SDDM refresh should update the bundled ii-pixel theme files"
assert_contains bin/ryoku-refresh-sddm 'preserve' "SDDM refresh should preserve selected non-Ryoku themes such as qylock"
assert_not_contains bin/ryoku-refresh-sddm 'RYOKU_SHELL_SDDM_AUTO_APPLY=yes' "SDDM refresh should not force ii-pixel over qylock"
assert_contains config/alacritty/alacritty.toml '~/.config/alacritty/colors\.toml' "Alacritty should import Ryoku generated colors"
assert_not_contains config/alacritty/alacritty.toml '~/.config/ryoku/current/theme/alacritty\.toml' "Alacritty should not import the old Ryoku theme symlink"
assert_contains config/btop/btop.conf 'color_theme = "ii-auto"' "btop should use the Ryoku generated theme"
assert_contains config/gtk-3.0/settings.ini 'gtk-font-name=Rubik 11' "GTK3 defaults should match the live Ryoku font"
assert_contains config/gtk-4.0/settings.ini 'gtk-font-name=Rubik 11' "GTK4 defaults should match the live Ryoku font"
assert_contains config/gtk-3.0/settings.ini 'gtk-cursor-theme-name=Bibata-Modern-Classic' "GTK3 defaults should match the live Ryoku cursor"
assert_contains config/gtk-4.0/settings.ini 'gtk-cursor-theme-name=Bibata-Modern-Classic' "GTK4 defaults should match the live Ryoku cursor"
assert_file config/fonts/Rubik.ttf
assert_file config/fonts/SpaceGrotesk.ttf
assert_file config/fonts/ReadexPro.ttf
assert_not_contains config/niri/config.d/50-startup.kdl 'polkit-gnome-authentication-agent-1|polkit-mate-authentication-agent-1|polkit-kde-authentication-agent-1|lxqt-policykit-agent|lxpolkit' "Niri startup should let Ryoku's layer-shell polkit agent own prompts"
assert_contains migrations/1777751965.sh '-ef' "screensaver preservation should skip self-copies on normal installs"

if rg -n 'hyprctl|hyprsunset|waybar|makoctl|swayosd|tofi|uwsm-app|qs -c ryoku|xdg-desktop-portal-hyprland|pixel-rainyroom' bin install config default lib >/dev/null; then
  fail "runtime/install sources should not keep old Hyprland-era commands or config paths"
fi
if rg -nF 'quickshell/ryoku/' bin install config default lib | grep -qv 'quickshell/ryoku-shell'; then
  fail "runtime/install sources should not keep the old quickshell/ryoku path (use quickshell/ryoku-shell)"
fi

"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc overview toggle' || fail "ryoku-ipc help should document overview toggle"
"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc clipboard toggle' || fail "ryoku-ipc help should document clipboard toggle"
"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc settings open' || fail "ryoku-ipc help should document settings open"
"$PWD/bin/ryoku-ipc" --help | grep -Fq 'ryoku-ipc settings toggle' || fail "ryoku-ipc help should document settings toggle"

pass "Niri/Ryoku merge readiness contract"
