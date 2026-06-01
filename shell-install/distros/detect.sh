#!/bin/bash

# Distro detection. Maps /etc/os-release ID (and ID_LIKE) to a Ryoku shell
# "family", then sources the matching adapter. Family is decoupled from the
# distro ID so every Arch derivative shares one adapter: adding CachyOS or
# another derivative is just an ID in the case below, no new code.

# rsi_os_id -> echo the os-release ID (override-aware), or "unknown".
rsi_os_id() {
  local osr="${RSI_OS_RELEASE:-/etc/os-release}"
  [[ -r $osr ]] || { printf 'unknown'; return; }
  # shellcheck disable=SC1090,SC1091
  ( . "$osr" && printf '%s' "${ID:-unknown}" )
}

# rsi_detect_family -> echoes the family name, or "unsupported".
rsi_detect_family() {
  local id="" id_like=""
  if [[ -r ${RSI_OS_RELEASE:-/etc/os-release} ]]; then
    # shellcheck disable=SC1090,SC1091
    . "${RSI_OS_RELEASE:-/etc/os-release}"
    id="${ID:-}"
    id_like="${ID_LIKE:-}"
  fi

  case "$id" in
    arch | cachyos | endeavouros | manjaro | garuda | arcolinux | artix)
      printf 'arch'
      return 0
      ;;
  esac

  case " $id_like " in
    *" arch "*)
      printf 'arch'
      return 0
      ;;
  esac

  printf 'unsupported'
}

# rsi_load_adapter -> detect the family and source its adapter. Aborts with a
# clear message (and the os-release ID) when the family is unsupported.
rsi_load_adapter() {
  local family adapter
  family="$(rsi_detect_family)"
  RSI_FAMILY="$family"
  export RSI_FAMILY

  if [[ $family == unsupported ]]; then
    rsi_die "unsupported distro '$(rsi_os_id)'. Only the Arch family is supported today. See shell-install/distros/TEMPLATE.sh to add one."
  fi

  adapter="$RSI_DIR/distros/$family.sh"
  [[ -f $adapter ]] || rsi_die "missing distro adapter: $adapter"
  # shellcheck disable=SC1090
  . "$adapter"
}
