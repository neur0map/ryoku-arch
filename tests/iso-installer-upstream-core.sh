#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONFIGURATOR="$ROOT_DIR/iso/configs/airootfs/root/configurator"
AUTOMATED_SCRIPT="$ROOT_DIR/iso/configs/airootfs/root/.automated_script.sh"
BUILD_ISO="$ROOT_DIR/iso/builder/build-iso.sh"
GRUB_CFG="$ROOT_DIR/iso/configs/grub/grub.cfg"
FINISHED_SCRIPT="$ROOT_DIR/install/post-install/finished.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$file"; then
    fail "$message"
  fi
}

line_number() {
  local file="$1"
  local pattern="$2"

  grep -nE -- "$pattern" "$file" | head -n1 | cut -d: -f1
}

assert_order() {
  local file="$1"
  local first_pattern="$2"
  local second_pattern="$3"
  local message="$4"
  local first second

  first=$(line_number "$file" "$first_pattern")
  second=$(line_number "$file" "$second_pattern")

  [[ -n $first && -n $second ]] || fail "$message"
  (( first < second )) || fail "$message"
}

run_configurator_dry() {
  local encryption_choice="$1"
  local tmpdir output

  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/bin" "$tmpdir/install/helpers" "$tmpdir/run"

  cat >"$tmpdir/install/helpers/all.sh" <<'EOF'
PADDING_LEFT=0
PADDING_LEFT_SPACES=""
clear_logo() { :; }
EOF

  cat >"$tmpdir/bin/gum" <<'EOF'
#!/bin/bash
subcommand="${1:-}"
shift || true
args="$*"

case $subcommand in
  choose)
    if [[ $args == *"Select keyboard layout"* ]]; then
      echo "English (US)"
    elif [[ $args == *"Timezone"* ]]; then
      echo "UTC"
    elif [[ $args == *"Disk encryption"* ]]; then
      echo "${RYOKU_TEST_ENCRYPTION_CHOICE:-Encrypt the disk (recommended)}"
    elif [[ $args == *"Select install disk"* ]]; then
      echo "/dev/vda (40G) - QEMU HARDDISK"
    else
      exit 2
    fi
    ;;
  input)
    if [[ $args == *"Username"* ]]; then
      echo "ryoku"
    elif [[ $args == *"Password"* ]]; then
      echo "pass1234"
    elif [[ $args == *"Confirm"* ]]; then
      echo "pass1234"
    elif [[ $args == *"Full name"* ]]; then
      echo "Ryoku User"
    elif [[ $args == *"Email address"* ]]; then
      echo "ryoku@example.test"
    elif [[ $args == *"Hostname"* ]]; then
      echo "ryoku-vm"
    else
      exit 2
    fi
    ;;
  confirm)
    exit 0
    ;;
  filter)
    echo "UTC"
    ;;
  table)
    cat
    ;;
  style|spin)
    exit 0
    ;;
  *)
    exit 2
    ;;
esac
EOF

  cat >"$tmpdir/bin/lsblk" <<'EOF'
#!/bin/bash
case "$*" in
  "-dpno NAME,TYPE,RO")
    echo "/dev/vda disk 0"
    ;;
  "-dno SIZE /dev/vda")
    echo "40G"
    ;;
  "-dno VENDOR /dev/vda")
    echo "QEMU"
    ;;
  "-dno MODEL /dev/vda")
    echo "HARDDISK"
    ;;
  "-dno TYPE /dev/vda")
    echo "disk"
    ;;
  "-nro TYPE,NAME,FSTYPE,MOUNTPOINT /dev/vda")
    ;;
  "-bdno SIZE /dev/vda")
    echo "42949672960"
    ;;
  *)
    exit 2
    ;;
esac
EOF

  cat >"$tmpdir/bin/findmnt" <<'EOF'
#!/bin/bash
exit 1
EOF

  cat >"$tmpdir/bin/timedatectl" <<'EOF'
#!/bin/bash
if [[ ${1:-} == "list-timezones" ]]; then
  echo "UTC"
fi
EOF

  for cmd in loadkeys modprobe udevadm; do
    cat >"$tmpdir/bin/$cmd" <<'EOF'
#!/bin/bash
exit 0
EOF
  done

  chmod 755 "$tmpdir"/bin/*

  if ! output=$(
    cd "$tmpdir/run"
    RYOKU_INSTALL="$tmpdir/install" \
      RYOKU_TEST_ENCRYPTION_CHOICE="$encryption_choice" \
      PATH="$tmpdir/bin:$PATH" \
      bash "$CONFIGURATOR" dry
  ); then
    rm -rf "$tmpdir"
    fail "configurator dry run failed for encryption choice: $encryption_choice"
  fi

  rm -rf "$tmpdir"
  printf '%s\n' "$output"
}

assert_contains "$CONFIGURATOR" 'English \(US, Colemak\)\|colemak' \
  "installer should offer the upstream Colemak keymap option"
assert_contains "$CONFIGURATOR" 'Letters, digits, and dashes' \
  "installer should describe valid hostnames accurately"
assert_contains "$CONFIGURATOR" '\^\[A-Za-z0-9\]\(\[A-Za-z0-9-\]\{0,61\}\[A-Za-z0-9\]\)\?\$' \
  "installer hostname validation should reject underscores and leading/trailing dashes"

assert_contains "$CONFIGURATOR" 'encryption_form\(\)' \
  "installer should expose an explicit disk encryption choice"
assert_contains "$CONFIGURATOR" 'Encrypt the disk \(recommended\)' \
  "installer should keep encryption as the default visible option"
assert_contains "$CONFIGURATOR" 'Install without disk encryption' \
  "installer should expose the no-encryption option by name"
assert_contains "$CONFIGURATOR" 'Protects data if the machine or drive is lost' \
  "encrypted option should explain its main benefit"
assert_contains "$CONFIGURATOR" 'VMs, test machines, and guarded desktops' \
  "unencrypted option should explain valid use cases"
assert_contains "$CONFIGURATOR" 'Anyone with the disk can read the installed data' \
  "unencrypted option should disclose the data-at-rest tradeoff"
assert_contains "$CONFIGURATOR" 'encrypt_installation=true' \
  "installer should default to encrypted installs"
assert_contains "$CONFIGURATOR" 'user_encrypt_installation\.txt' \
  "installer should persist the selected encryption mode for later install stages"
assert_contains "$CONFIGURATOR" 'credentials_encryption_line' \
  "installer should conditionally include archinstall credential encryption"
assert_contains "$CONFIGURATOR" 'disk_encryption_config' \
  "installer should conditionally include disk_encryption in archinstall config"
assert_contains "$CONFIGURATOR" '"snapper"' \
  "archinstall package list should include snapper for snapshot config parity"

encrypted_output=$(run_configurator_dry "Encrypt the disk (recommended)")
printf '%s\n' "$encrypted_output" | grep -q '"disk_encryption"' || \
  fail "encrypted dry run should include disk_encryption config"
printf '%s\n' "$encrypted_output" | grep -q '"encryption_password"' || \
  fail "encrypted dry run should include encryption credentials"
printf '%s\n' "$encrypted_output" | grep -q '^true$' || \
  fail "encrypted dry run should persist true encryption mode"

unencrypted_output=$(run_configurator_dry "Install without disk encryption")
if printf '%s\n' "$unencrypted_output" | grep -q '"disk_encryption"'; then
  fail "unencrypted dry run should omit disk_encryption config"
fi
if printf '%s\n' "$unencrypted_output" | grep -q '"encryption_password"'; then
  fail "unencrypted dry run should omit encryption credentials"
fi
printf '%s\n' "$unencrypted_output" | grep -q '^false$' || \
  fail "unencrypted dry run should persist false encryption mode"

assert_contains "$AUTOMATED_SCRIPT" 'install_disk\(\)' \
  "ISO automated install should derive the selected install disk"
assert_contains "$AUTOMATED_SCRIPT" 'cleanup_install_disk\(\)' \
  "ISO automated install should clean holders from the selected disk"
assert_contains "$AUTOMATED_SCRIPT" 'vgchange -an' \
  "disk cleanup should deactivate LVM volume groups on the install disk"
assert_contains "$AUTOMATED_SCRIPT" 'cryptsetup close' \
  "disk cleanup should close LUKS mappings on the install disk"
assert_contains "$AUTOMATED_SCRIPT" 'partprobe "\$disk"' \
  "disk cleanup should ask the kernel to re-read the selected disk"
assert_contains "$AUTOMATED_SCRIPT" 'cleanup_install_disk "\$\(install_disk\)"' \
  "archinstall should run only after selected disk cleanup"
assert_order "$AUTOMATED_SCRIPT" 'cleanup_install_disk "\$\(install_disk\)"' 'archinstall[[:space:]]*\\' \
  "disk cleanup should happen before archinstall starts"
assert_contains "$AUTOMATED_SCRIPT" 'install_status=\$\?' \
  "live ISO wrapper should capture the chrooted installer exit status"
assert_contains "$AUTOMATED_SCRIPT" 'install_status == 42' \
  "live ISO wrapper should treat exit 42 as a reboot request"
assert_order "$AUTOMATED_SCRIPT" 'install_status=\$\?' 'install_status == 42' \
  "live ISO wrapper should capture install status before testing reboot request"

assert_contains "$FINISHED_SCRIPT" 'exit 42' \
  "chrooted finish script should signal reboot with an exit status"
assert_order "$FINISHED_SCRIPT" 'trap - ERR INT TERM EXIT' 'exit 42' \
  "chrooted finish script should disable installer error traps before signaling reboot"
assert_not_contains "$FINISHED_SCRIPT" '/var/tmp/ryoku-install-completed' \
  "chrooted finish script should not write reboot marker files"

assert_contains "$BUILD_ISO" 'arch_packages=\([^)]*lvm2[^)]*cryptsetup[^)]*parted[^)]*\)' \
  "live ISO should include lvm2, cryptsetup, and parted for disk cleanup"
assert_not_contains "$GRUB_CFG" '^play 600 ' \
  "ISO GRUB menu should not beep on boot"

echo "PASS: ISO installer upstream core parity"
