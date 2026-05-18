ryoku_profile_ids() {
  local dir

  [[ -d $RYOKU_PROFILES_DIR ]] || return 0

  for dir in "$RYOKU_PROFILES_DIR"/*; do
    [[ -d $dir && -f $dir/profile ]] || continue
    (
      PROFILE_ORDER=50
      source "$dir/profile"
      printf '%03d\t%s\n' "$PROFILE_ORDER" "$(basename "$dir")"
    )
  done | sort -n -k1,1 -k2,2 | cut -f2
}

ryoku_profile_load() {
  local profile_id="$1"
  local profile_file

  [[ $profile_id =~ ^[a-z0-9][a-z0-9_-]*$ ]] || return 1

  RYOKU_PROFILE_ID="$profile_id"
  RYOKU_PROFILE_DIR="$RYOKU_PROFILES_DIR/$profile_id"
  profile_file="$RYOKU_PROFILE_DIR/profile"

  [[ -f $profile_file ]] || return 1

  PROFILE_NAME=""
  PROFILE_ICON="extension"
  PROFILE_DESCRIPTION=""
  PROFILE_TAGS=""
  PROFILE_ORDER=50
  PROFILE_REQUIRES_NETWORK=1
  PROFILE_REBOOT_RECOMMENDED=0

  source "$profile_file"
}

ryoku_profile_manifest() {
  local profile_id="$1"
  local manifest="$2"
  local file="$RYOKU_PROFILES_DIR/$profile_id/$manifest"

  [[ -f $file ]] || return 0
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" | awk 'NF { print }'
}

ryoku_profile_packages() {
  local profile_id="$1"

  ryoku_profile_manifest "$profile_id" packages
  ryoku_profile_manifest "$profile_id" aur.packages
  ryoku_profile_manifest "$profile_id" blackarch.packages
}

ryoku_profile_pacman_missing() {
  (( $# > 0 )) || return 0

  if ! command -v pacman >/dev/null 2>&1; then
    printf '%s\n' "$@"
    return 0
  fi

  pacman -T "$@" 2>/dev/null || true
}

ryoku_profile_package_missing() {
  local package="$1"
  local missing

  mapfile -t missing < <(ryoku_profile_pacman_missing "$package")
  (( ${#missing[@]} > 0 ))
}

ryoku_profile_multilib_enabled() {
  [[ -r /etc/pacman.conf ]] || return 1
  awk '
    /^[[:space:]]*\[multilib\][[:space:]]*$/ { in_multi = 1; next }
    /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { in_multi = 0 }
    in_multi && /^[[:space:]]*Include[[:space:]]*=/ { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' /etc/pacman.conf
}

ryoku_profile_enable_multilib() {
  # Uncomment the [multilib] section (and the matching Include line) in
  # /etc/pacman.conf, then refresh the package databases so lib32-* packages
  # become resolvable. Idempotent. Returns 0 on success.
  (( EUID == 0 )) || {
    printf 'Error: ryoku_profile_enable_multilib must run as root.\n' >&2
    return 1
  }

  ryoku_profile_multilib_enabled && { pacman -Sy --noconfirm >/dev/null 2>&1 || true; return 0; }

  [[ -w /etc/pacman.conf ]] || {
    printf 'Error: /etc/pacman.conf is not writable.\n' >&2
    return 1
  }

  cp -a /etc/pacman.conf "/etc/pacman.conf.ryoku-bak.$(date +%Y%m%d-%H%M%S)" || return 1

  # Find the line of #[multilib] and uncomment it plus the next Include line.
  awk '
    BEGIN { uncomment_next_include = 0 }
    /^[[:space:]]*#[[:space:]]*\[multilib\][[:space:]]*$/ {
      sub(/^[[:space:]]*#[[:space:]]*/, "")
      uncomment_next_include = 1
      print
      next
    }
    uncomment_next_include && /^[[:space:]]*#[[:space:]]*Include[[:space:]]*=/ {
      sub(/^[[:space:]]*#[[:space:]]*/, "")
      uncomment_next_include = 0
      print
      next
    }
    /^[[:space:]]*\[[^]]+\][[:space:]]*$/ { uncomment_next_include = 0 }
    { print }
  ' /etc/pacman.conf > /etc/pacman.conf.ryoku-tmp || return 1
  mv /etc/pacman.conf.ryoku-tmp /etc/pacman.conf || return 1

  ryoku_profile_multilib_enabled || {
    printf 'Error: [multilib] still appears disabled after edit.\n' >&2
    return 1
  }

  pacman -Sy --noconfirm || return 1
}

ryoku_profile_ensure_multilib_for_packages() {
  # Inspect the given package list; if any package is lib32-* (and a few
  # known-multilib packages like steam, umu-launcher), make sure [multilib]
  # is on. Under pkexec/SUDO_UID the user has already authenticated for
  # this install, so we treat that as consent. On an interactive TTY we
  # prompt y/N first.
  local pkg
  local needs_multilib=0

  for pkg in "$@"; do
    case "$pkg" in
      lib32-*|steam|steam-devices|umu-launcher) needs_multilib=1; break ;;
    esac
  done

  (( needs_multilib == 1 )) || return 0
  ryoku_profile_multilib_enabled && return 0

  if (( EUID != 0 )); then
    printf 'Multilib is required but cannot be enabled without root.\n' >&2
    return 1
  fi

  local consent=0
  if [[ -n ${PKEXEC_UID:-} || -n ${SUDO_UID:-} ]]; then
    # Came in through pkexec/sudo for this profile; the unlock dialog already
    # served as the consent step.
    consent=1
    printf '[ryoku-profile] Enabling [multilib] in /etc/pacman.conf for lib32 packages.\n'
  elif [[ -t 0 && -t 1 ]]; then
    printf 'This profile needs the [multilib] repo for 32-bit libraries.\n'
    printf 'Enable [multilib] in /etc/pacman.conf now? [y/N] '
    local reply
    read -r reply
    case "$reply" in
      [yY]|[yY][eE][sS]) consent=1 ;;
    esac
  else
    printf 'Error: [multilib] needed but no consent path available (non-TTY, non-pkexec). Pass RYOKU_PROFILE_ENABLE_MULTILIB=1 to opt in.\n' >&2
  fi

  if (( consent == 0 )) && [[ ${RYOKU_PROFILE_ENABLE_MULTILIB:-0} == 1 ]]; then
    consent=1
  fi

  (( consent == 1 )) || {
    printf 'Error: [multilib] is required to install: %s\n' "$*" >&2
    return 1
  }

  ryoku_profile_enable_multilib
}

ryoku_profile_install_pacman() {
  local missing

  (( $# > 0 )) || return 0

  # Ensure [multilib] is on before asking pacman for lib32 packages,
  # otherwise pacman -T reports them missing AND -S fails with "target
  # not found" and the whole bundle aborts.
  ryoku_profile_ensure_multilib_for_packages "$@" || return 1

  mapfile -t missing < <(ryoku_profile_pacman_missing "$@")
  (( ${#missing[@]} > 0 )) || return 0

  if (( EUID == 0 )); then
    pacman -S --noconfirm --needed "${missing[@]}"
  else
    sudo pacman -S --noconfirm --needed "${missing[@]}"
  fi
}

ryoku_profile_target_uid() {
  if [[ -n ${RYOKU_PROFILE_TARGET_UID:-} ]]; then
    printf '%s\n' "$RYOKU_PROFILE_TARGET_UID"
  elif [[ -n ${SUDO_UID:-} && $SUDO_UID != "0" ]]; then
    printf '%s\n' "$SUDO_UID"
  elif [[ -n ${PKEXEC_UID:-} && $PKEXEC_UID != "0" ]]; then
    printf '%s\n' "$PKEXEC_UID"
  else
    id -u
  fi
}

ryoku_profile_target_user() {
  local uid

  uid="$(ryoku_profile_target_uid)"
  getent passwd "$uid" | cut -d: -f1
}

ryoku_profile_target_home() {
  local uid

  uid="$(ryoku_profile_target_uid)"
  getent passwd "$uid" | cut -d: -f6
}

ryoku_profile_cleanup_temp_sudoers() {
  local file

  for file in "${RYOKU_PROFILE_TEMP_SUDOERS[@]:-}"; do
    [[ -n $file && -f $file ]] || continue
    rm -f "$file"
  done
}

ryoku_profile_allow_target_pacman() {
  local target_user="$1"
  local target_uid
  local sudoers_file

  (( EUID == 0 )) || return 0
  [[ -n $target_user && $target_user != "root" ]] || return 0

  target_uid="$(id -u "$target_user")"
  sudoers_file="/etc/sudoers.d/90-ryoku-profile-install-$target_uid"

  # I only open this pacman sudo path while yay is running under pkexec.
  printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$target_user" >"$sudoers_file"
  chmod 440 "$sudoers_file"

  RYOKU_PROFILE_TEMP_SUDOERS+=("$sudoers_file")
  trap ryoku_profile_cleanup_temp_sudoers EXIT
}

ryoku_profile_bootstrap_yay() {
  # Bootstrap yay if it isn't on PATH. Returns 0 if yay is available
  # afterwards. Mirrors the path used by install/preflight/yay-bootstrap.sh
  # when present; otherwise falls back to a direct git/makepkg build under
  # the target user.
  command -v yay >/dev/null 2>&1 && return 0

  local bootstrap_script="${RYOKU_PATH:-}/install/preflight/yay-bootstrap.sh"
  if [[ -x $bootstrap_script ]]; then
    "$bootstrap_script" || return 1
  else
    # Minimal inline bootstrap: clone, makepkg, install as target user.
    local target_user target_home
    target_user="$(ryoku_profile_target_user)"
    target_home="$(ryoku_profile_target_home)"
    [[ -n $target_user && $target_user != "root" ]] || return 1

    ryoku_profile_install_pacman base-devel git || return 1
    ryoku_profile_allow_target_pacman "$target_user"

    local build_dir
    build_dir="$(sudo -u "$target_user" mktemp -d)" || return 1
    (
      cd "$build_dir" || exit 1
      sudo -u "$target_user" git clone --depth 1 https://aur.archlinux.org/yay-bin.git . >/dev/null 2>&1 || exit 1
      sudo -u "$target_user" env HOME="$target_home" makepkg -si --noconfirm >/dev/null 2>&1 || exit 1
    ) || { rm -rf "$build_dir"; return 1; }
    rm -rf "$build_dir"
  fi

  command -v yay >/dev/null 2>&1
}

ryoku_profile_install_yay() {
  local target_user
  local target_home
  local yay_bin

  (( $# > 0 )) || return 0

  if ! command -v yay >/dev/null 2>&1; then
    ryoku_profile_bootstrap_yay || {
      printf 'Error: yay is required for AUR packages but is not installed and could not be bootstrapped.\n' >&2
      return 1
    }
  fi

  # Resolve absolute path once so sudo -u (which resets PATH to the
  # target user's secure_path) can still find yay even when it lives
  # at /usr/local/bin via the GitHub-fallback install path.
  yay_bin="$(command -v yay)"

  if (( EUID == 0 )); then
    target_user="$(ryoku_profile_target_user)"
    target_home="$(ryoku_profile_target_home)"
    [[ -n $target_user && -n $target_home && $target_user != "root" ]] || return 1
    ryoku_profile_allow_target_pacman "$target_user"
    sudo -u "$target_user" env HOME="$target_home" PATH="/usr/local/bin:/usr/bin:/bin" "$yay_bin" -S --noconfirm --needed --answerclean All --answerdiff None "$@"
  else
    "$yay_bin" -S --noconfirm --needed --answerclean All --answerdiff None "$@"
  fi
}

ryoku_profile_install_aur() {
  local package
  local aur_missing=()
  local still_missing=()

  for package in "$@"; do
    ryoku_profile_package_missing "$package" || continue

    if ryoku_profile_install_pacman "$package" >/dev/null 2>&1; then
      continue
    fi

    aur_missing+=("$package")
  done

  (( ${#aur_missing[@]} > 0 )) || return 0

  ryoku_profile_install_yay "${aur_missing[@]}" || return 1
  mapfile -t still_missing < <(ryoku_profile_pacman_missing "${aur_missing[@]}")

  if (( ${#still_missing[@]} > 0 )); then
    printf 'Error: AUR packages did not install: %s\n' "${still_missing[*]}" >&2
    return 1
  fi
}

ryoku_profile_blackarch_available() {
  pacman -Sl blackarch >/dev/null 2>&1
}

ryoku_profile_bootstrap_blackarch() {
  local strap_dir
  local strap_file
  local strap_sha1="${RYOKU_BLACKARCH_STRAP_SHA1:-00688950aaf5e5804d2abebb8d3d3ea1d28525ed}"

  ryoku_profile_blackarch_available && return 0

  strap_dir="$(mktemp -d)"
  strap_file="$strap_dir/strap.sh"

  curl -fsSL https://blackarch.org/strap.sh -o "$strap_file" || {
    rm -rf "$strap_dir"
    return 1
  }
  printf '%s  %s\n' "$strap_sha1" "$strap_file" | sha1sum -c - >/dev/null || {
    rm -rf "$strap_dir"
    return 1
  }
  chmod 755 "$strap_file"

  if (( EUID == 0 )); then
    "$strap_file" || {
      rm -rf "$strap_dir"
      return 1
    }
    pacman -Sy --noconfirm || {
      rm -rf "$strap_dir"
      return 1
    }
  else
    sudo "$strap_file" || {
      rm -rf "$strap_dir"
      return 1
    }
    sudo pacman -Sy --noconfirm || {
      rm -rf "$strap_dir"
      return 1
    }
  fi

  rm -rf "$strap_dir"
  ryoku_profile_blackarch_available
}

ryoku_profile_install_blackarch() {
  local missing=()

  (( $# > 0 )) || return 0

  mapfile -t missing < <(ryoku_profile_pacman_missing "$@")
  (( ${#missing[@]} > 0 )) || return 0

  ryoku_profile_bootstrap_blackarch || return 1
  ryoku_profile_install_pacman "${missing[@]}"
}

ryoku_profile_state_file_for_read() {
  local profile_id="$1"
  local user_state="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/profiles/$profile_id.state"
  local system_state="/var/lib/ryoku/profiles/$profile_id.state"

  if [[ -n ${RYOKU_PROFILE_STATE_DIR:-} ]]; then
    printf '%s/%s.state\n' "$RYOKU_PROFILE_STATE_DIR" "$profile_id"
  elif [[ -f $system_state ]]; then
    printf '%s\n' "$system_state"
  else
    printf '%s\n' "$user_state"
  fi
}

ryoku_profile_state_file_for_write() {
  local profile_id="$1"

  if [[ -n ${RYOKU_PROFILE_STATE_DIR:-} ]]; then
    printf '%s/%s.state\n' "$RYOKU_PROFILE_STATE_DIR" "$profile_id"
  elif (( EUID == 0 )); then
    printf '/var/lib/ryoku/profiles/%s.state\n' "$profile_id"
  else
    printf '%s/ryoku/profiles/%s.state\n' "${XDG_STATE_HOME:-$HOME/.local/state}" "$profile_id"
  fi
}

ryoku_profile_state_value() {
  local profile_id="$1"
  local key="$2"
  local file

  file="$(ryoku_profile_state_file_for_read "$profile_id")"
  [[ -f $file ]] || return 1

  awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }' "$file"
}

ryoku_profile_write_state() {
  local profile_id="$1"
  local state="$2"
  local exit_code="${3:-0}"
  local file

  file="$(ryoku_profile_state_file_for_write "$profile_id")"
  mkdir -p "$(dirname "$file")"

  {
    printf 'id=%s\n' "$profile_id"
    printf 'state=%s\n' "$state"
    printf 'exit_code=%s\n' "$exit_code"
    printf 'updated_at=%s\n' "$(date -Iseconds)"
  } >"$file"
}

ryoku_profile_json_escape() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"

  printf '%s' "$value"
}

ryoku_profile_json_string() {
  printf '"%s"' "$(ryoku_profile_json_escape "$1")"
}

ryoku_profile_json_array() {
  local item
  local first=1

  printf '['
  for item in "$@"; do
    (( first == 1 )) || printf ','
    first=0
    ryoku_profile_json_string "$item"
  done
  printf ']'
}

ryoku_profile_status_json() {
  local profile_id="$1"
  local state
  local recorded_state
  local installed=false
  local requires_network=false
  local reboot_recommended=false
  local official_packages=()
  local aur_packages=()
  local blackarch_packages=()
  local hardware_packages=()
  local missing=()
  local tags=()
  local package_count

  ryoku_profile_load "$profile_id" || return 1

  mapfile -t official_packages < <(ryoku_profile_manifest "$profile_id" packages)
  mapfile -t aur_packages < <(ryoku_profile_manifest "$profile_id" aur.packages)
  mapfile -t blackarch_packages < <(ryoku_profile_manifest "$profile_id" blackarch.packages)
  mapfile -t hardware_packages < <(ryoku_profile_manifest "$profile_id" hardware.packages)
  package_count=$(( ${#official_packages[@]} + ${#aur_packages[@]} + ${#blackarch_packages[@]} ))

  mapfile -t missing < <(ryoku_profile_pacman_missing "${official_packages[@]}" "${aur_packages[@]}" "${blackarch_packages[@]}")

  if (( ${#missing[@]} == 0 )); then
    state="installed"
    installed=true
  else
    recorded_state="$(ryoku_profile_state_value "$profile_id" state 2>/dev/null || true)"
    if [[ $recorded_state == "failed" ]]; then
      state="failed"
    else
      state="not-installed"
    fi
  fi

  [[ ${PROFILE_REQUIRES_NETWORK:-0} == "1" ]] && requires_network=true
  [[ ${PROFILE_REBOOT_RECOMMENDED:-0} == "1" ]] && reboot_recommended=true
  IFS='|' read -r -a tags <<< "${PROFILE_TAGS:-}"

  printf '{'
  printf '"id":'; ryoku_profile_json_string "$profile_id"; printf ','
  printf '"name":'; ryoku_profile_json_string "${PROFILE_NAME:-$profile_id}"; printf ','
  printf '"icon":'; ryoku_profile_json_string "${PROFILE_ICON:-extension}"; printf ','
  printf '"description":'; ryoku_profile_json_string "${PROFILE_DESCRIPTION:-}"; printf ','
  printf '"tags":'; ryoku_profile_json_array "${tags[@]}"; printf ','
  printf '"packages":'; ryoku_profile_json_array "${official_packages[@]}"; printf ','
  printf '"aurPackages":'; ryoku_profile_json_array "${aur_packages[@]}"; printf ','
  printf '"blackarchPackages":'; ryoku_profile_json_array "${blackarch_packages[@]}"; printf ','
  printf '"hardwarePackages":'; ryoku_profile_json_array "${hardware_packages[@]}"; printf ','
  printf '"packageCount":%d,' "$package_count"
  printf '"state":'; ryoku_profile_json_string "$state"; printf ','
  printf '"installed":%s,' "$installed"
  printf '"requiresNetwork":%s,' "$requires_network"
  printf '"rebootRecommended":%s,' "$reboot_recommended"
  printf '"missingCount":%d,' "${#missing[@]}"
  printf '"missing":'; ryoku_profile_json_array "${missing[@]}"
  printf '}'
}
