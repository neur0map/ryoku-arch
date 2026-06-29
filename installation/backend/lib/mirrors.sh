#!/usr/bin/env bash
# shellcheck shell=bash
# Rank the package mirrors before pacstrap. The ISO ships a small static
# mirrorlist (installation/iso/airootfs/etc/pacman.d/mirrorlist) led by a CDN
# mirror, but a user far from every shipped origin still stalls: pacstrap aborts
# with "failed retrieving file ... Operation too slow. Less than 1 bytes/sec"
# and the whole install dies at "failed to install packages to new root".
#
# The shipped list has been geo-routed and then CDN-led; both still stranded
# users far from every origin (e.g. South America). So rank adaptively instead:
# prefer mirrors in the user's own country (resolved by IP geolocation, the same
# way chroot.sh resolves the timezone), and fall back to the globally fastest
# recent mirrors when the country has none. reflector measures the real download
# rate, so the user pulls from a mirror that is actually fast for them.
#
# best-effort and never worse than the shipped list: an offline box, a missing
# reflector, a failed geolocation, or a reflector that returns nothing all keep
# the shipped mirrorlist; on success the shipped mirrors are still appended as
# last-resort fallbacks. ranks the live list in place, so the deploy step copies
# the improved list into the target and the target's first updates benefit too.
#
# runs under the orchestrator's `set -euo pipefail`, so every step that may fail
# (geolocation, mktemp, reflector, the rewrite) is guarded: ranking is an
# optimization and must NEVER abort the install. RYOKU_MIRRORLIST overrides the
# path (defaults to the live one); only the tests set it.

ryoku_rank_mirrors() {
  local list=${RYOKU_MIRRORLIST:-/etc/pacman.d/mirrorlist}

  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "mirrors: would rank $list with reflector (own country first, else fastest 20 by rate); shipped list kept as fallback"
    return 0
  fi

  [[ ${RYOKU_ONLINE:-1} == 1 ]] || { log "mirrors: offline install, keeping the shipped mirrorlist"; return 0; }
  command -v reflector >/dev/null 2>&1 || { log "mirrors: reflector unavailable, keeping the shipped mirrorlist"; return 0; }

  local ranked country count
  ranked=$(mktemp) || { log "mirrors: no scratch space, keeping the shipped mirrorlist"; return 0; }
  country=$(ryoku_geoip_country) || country=""

  if [[ -n $country ]] \
     && timeout 60 reflector --country "$country" --protocol https --sort rate \
          --connection-timeout 5 --download-timeout 5 --save "$ranked" 2>/dev/null \
     && grep -q '^Server' "$ranked"; then
    log "mirrors: ranking by download rate within $country"
  elif timeout 180 reflector --protocol https --age 12 --latest 20 --sort rate \
          --connection-timeout 5 --download-timeout 5 --save "$ranked" 2>/dev/null \
     && grep -q '^Server' "$ranked"; then
    log "mirrors: ranking the fastest recent mirrors worldwide${country:+ ($country had none)}"
  else
    log "mirrors: reflector returned nothing, keeping the shipped mirrorlist"
    rm -f -- "$ranked"
    return 0
  fi

  # ranked mirrors first, then the shipped curated mirrors, so the result can
  # only add faster servers, never drop the known-good ones.
  count=$(grep -c '^Server' "$ranked" 2>/dev/null) || count=0
  if { cat -- "$ranked"; printf '\n# shipped fallbacks\n'; grep '^Server' "$list" 2>/dev/null || true; } >"$list.ranked"; then
    if mv -- "$list.ranked" "$list"; then
      log "mirrors: using $count ranked mirror(s), shipped list appended as fallback"
    else
      rm -f -- "$list.ranked"
      log "mirrors: could not replace the mirrorlist, keeping the shipped one"
    fi
  else
    rm -f -- "$list.ranked"
    log "mirrors: could not assemble the ranked list, keeping the shipped one"
  fi
  rm -f -- "$ranked"
}

# ryoku_geoip_country: two-letter country code from IP geolocation, or empty.
# mirrors ryoku_cfg_timezone's provider approach (chroot.sh) but reads the
# country field; first valid hit wins. only scopes the mirror ranking, so a miss
# is harmless (the caller falls back to a worldwide ranking). guarded for the
# orchestrator's `set -euo pipefail`: a failed curl must not abort the install.
ryoku_geoip_country() {
  local url cc
  for url in "https://ipinfo.io/country" "http://ip-api.com/line?fields=countryCode"; do
    cc=$(curl -fsSL --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]') || cc=""
    if [[ $cc =~ ^[A-Za-z][A-Za-z]$ ]]; then
      printf '%s' "${cc^^}"
      return 0
    fi
  done
  return 0
}
