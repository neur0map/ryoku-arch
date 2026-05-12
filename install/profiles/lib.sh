ryoku_profile_ids() {
  local dir

  [[ -d $RYOKU_PROFILES_DIR ]] || return 0

  for dir in "$RYOKU_PROFILES_DIR"/*; do
    [[ -d $dir && -f $dir/profile ]] || continue
    basename "$dir"
  done | sort
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

ryoku_profile_install_pacman() {
  local missing

  (( $# > 0 )) || return 0

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

ryoku_profile_install_yay() {
  local target_user
  local target_home

  (( $# > 0 )) || return 0
  command -v yay >/dev/null 2>&1 || return 1

  if (( EUID == 0 )); then
    target_user="$(ryoku_profile_target_user)"
    target_home="$(ryoku_profile_target_home)"
    [[ -n $target_user && -n $target_home && $target_user != "root" ]] || return 1
    ryoku_profile_allow_target_pacman "$target_user"
    sudo -u "$target_user" env HOME="$target_home" yay -S --noconfirm --needed "$@"
  else
    yay -S --noconfirm --needed "$@"
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
  local hardware_packages=()
  local missing=()
  local tags=()
  local package_count

  ryoku_profile_load "$profile_id" || return 1

  mapfile -t official_packages < <(ryoku_profile_manifest "$profile_id" packages)
  mapfile -t aur_packages < <(ryoku_profile_manifest "$profile_id" aur.packages)
  mapfile -t hardware_packages < <(ryoku_profile_manifest "$profile_id" hardware.packages)
  package_count=$(( ${#official_packages[@]} + ${#aur_packages[@]} ))

  mapfile -t missing < <(ryoku_profile_pacman_missing "${official_packages[@]}" "${aur_packages[@]}")

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
