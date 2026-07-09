#!/usr/bin/env bash
# shellcheck shell=bash
# Carry the live session's network setup into the installed system so wifi
# survives first boot. two parts, both required:
#
#   1) pin NetworkManager's wifi backend to iwd in the target. base set ships
#      iwd (not wpa_supplicant), and the live ISO already runs NM over iwd
#      (installation/iso/airootfs/etc/NetworkManager/conf.d/wifi-backend.conf).
#      that drop-in lives only on the ISO. without an equivalent in the target,
#      NM falls back to wpa_supplicant, finds nothing, wifi can't associate.
#
#   2) copy the saved connection profiles NM wrote while the user joined a
#      network during install (/etc/NetworkManager/system-connections/
#      *.nmconnection) into the target, preserving the 600 root:root perms NM
#      requires. otherwise the credentials evaporate on reboot.
#
# ryoku_network runs in the "configure" stage; ryoku_ensure_dns runs at
# preflight, before the disk is touched. everything routes through the dry-run
# wrappers.

ryoku_network() {
  log "persisting NetworkManager configuration into the target"
  ryoku_network_backend
  ryoku_network_connections
}

# ryoku_network_backend writes the iwd backend pin into the target, mirroring
# the live ISO's drop-in.
ryoku_network_backend() {
  log "pinning NetworkManager Wi-Fi backend to iwd"
  run mkdir -p /mnt/etc/NetworkManager/conf.d
  write_file /mnt/etc/NetworkManager/conf.d/wifi-backend.conf <<'EOF'
# Ryoku ships iwd, not wpa_supplicant; point NM at iwd. NM dbus-activates iwd
# on demand. mirrors the live ISO drop-in
# installation/iso/airootfs/etc/NetworkManager/conf.d/wifi-backend.conf.
[device]
wifi.backend=iwd
EOF
}

# ryoku_network_connections: copy the saved .nmconnection keyfiles from the
# live session into the target with the ownership/perms NM demands.
ryoku_network_connections() {
  local srcdir=/etc/NetworkManager/system-connections
  local dst=/mnt/etc/NetworkManager/system-connections
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    printf 'DRYRUN: copy saved network profiles %s/*.nmconnection -> %s/ (chmod 600, chown root:root)\n' \
      "$srcdir" "$dst"
    return 0
  fi
  [[ -d $srcdir ]] || { log "skip: $srcdir not present"; return 0; }
  local files=()
  shopt -s nullglob
  files=("$srcdir"/*.nmconnection)
  shopt -u nullglob
  (( ${#files[@]} )) || { log "no saved network profiles to carry over"; return 0; }
  mkdir -p "$dst"
  cp "${files[@]}" "$dst"/
  # NM refuses keyfiles that are group/world readable or not root-owned, so
  # normalize both regardless of where they came from.
  chmod 600 "$dst"/*.nmconnection
  chown root:root "$dst"/*.nmconnection
  log "carried over ${#files[@]} saved network profile(s)"
}

# ryoku_ensure_dns: pacstrap and the desktop set resolve mirror hostnames, but a
# live box can have a route (so the TUI's reachability check passes) and still no
# working resolver -- NetworkManager over iwd may not populate /etc/resolv.conf,
# and the install then dies at pacstrap with "Could not resolve host" AFTER the
# disk is wiped. Verify name resolution; if it is broken, drop in public
# resolvers and re-test; on a genuinely offline box abort HERE, before the disk
# is touched, instead of stranding a wiped disk. Runs at preflight, before
# partitioning. RYOKU_RESOLV_CONF overrides the resolver file (tests only).
ryoku_ensure_dns() {
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "dns: would verify name resolution and write fallback resolvers (1.1.1.1, 9.9.9.9, 8.8.8.8) if it fails"
    return 0
  fi
  [[ ${RYOKU_ONLINE:-1} == 1 ]] || { log "dns: offline install, skipping the resolver check"; return 0; }

  if ryoku_dns_works; then
    log "dns: name resolution works"
    return 0
  fi

  local resolv=${RYOKU_RESOLV_CONF:-/etc/resolv.conf}
  log "dns: cannot resolve mirror hostnames; writing fallback resolvers to $resolv"
  rm -f -- "$resolv" 2>/dev/null || true
  printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\nnameserver 8.8.8.8\n' >"$resolv"

  if ryoku_dns_works; then
    log "dns: name resolution restored with the fallback resolvers"
    return 0
  fi
  die "no working DNS: cannot resolve package mirrors even with public resolvers. Connect to a working network (the Wi-Fi step, or plug in Ethernet) and retry. The disk has not been touched yet."
}

# ryoku_dns_works: can the system resolver turn a hostname into an address? uses
# the same nsswitch path pacman and curl take, so it reflects what pacstrap will
# see. tries more than one host so a single dead domain does not read as a dead
# resolver. RYOKU_DNS_PROBE_HOSTS overrides the probe set (tests only).
ryoku_dns_works() {
  local host
  for host in ${RYOKU_DNS_PROBE_HOSTS:-archlinux.org geo.mirror.pkgbuild.com}; do
    getent hosts "$host" >/dev/null 2>&1 && return 0
  done
  return 1
}

# ryoku_ensure_mirrors: DNS can work while HTTP does not (captive portal, half-up
# wifi, blocked egress). A flaky link then fails DEEP in pacstrap: a partial db
# sync resolves core but not extra and pacman reports "target not found: go"
# (the first dev package) on an already-wiped disk. Probe the actual bytes the
# install needs, both Arch's geo mirror and the [ryoku] repo, before any disk
# write. RYOKU_MIRROR_PROBE_URLS overrides the probe set (tests only).
ryoku_ensure_mirrors() {
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "mirrors: would verify HTTP reach of the Arch geo mirror and repo.ryoku.dev before touching the disk"
    return 0
  fi
  [[ ${RYOKU_ONLINE:-1} == 1 ]] || { log "mirrors: offline install, skipping the reachability check"; return 0; }

  local url
  for url in ${RYOKU_MIRROR_PROBE_URLS:-\
https://geo.mirror.pkgbuild.com/core/os/x86_64/core.db \
https://repo.ryoku.dev/stable/x86_64/ryoku.db}; do
    if ! curl -fsSI --retry 2 --max-time 20 -o /dev/null "$url"; then
      die "cannot reach $url over HTTP. The install downloads everything (base system, desktop, toolchains), so it needs a solid connection: reconnect Wi-Fi or plug in Ethernet, then retry. The disk has not been touched yet."
    fi
  done
  log "mirrors: Arch geo mirror and repo.ryoku.dev reachable"
}
