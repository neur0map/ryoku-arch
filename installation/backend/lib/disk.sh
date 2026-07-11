#!/usr/bin/env bash
# Partition the target disk. two strategies, both set ESP_DEV + ROOT_PART:
#
#   whole     wipe the disk, fresh GPT: ESP + a root that takes the rest.
#             destroys everything on the disk.
#   alongside keep every existing partition (e.g. Windows on the same drive):
#             create a DEDICATED Ryoku ESP + root in the largest free region.
#             the Windows ESP is never reused or mounted. nothing existing gets
#             wiped or moved, so the user makes room first by shrinking Windows.

# largest free region 'alongside' needs = a dedicated Ryoku ESP (RYOKU_ESP_GIB)
# plus the root, whose floor is the base system closure + the swapfile (which
# lives inside root, @swap subvolume). base raised 15->20 after measuring the
# base+dev+desktop closure at ~13-15 GiB plus AUR build/snapshot headroom.
ryoku_min_root_gib() { echo $(( 20 + ${RYOKU_SWAP_GIB:-0} )); }

# ryoku_release_previous_attempt: the failure EXIT trap deliberately LEAVES /mnt
# mounted so a failed install's partial tree + log can be inspected. but the TUI
# "retry" re-runs this backend in the SAME live session, so /mnt (and the
# swapfile the mount stage swapped on) is still held from the prior attempt. a
# held /mnt pins ROOT_DEV, so the partition/wipe below dies "Device or resource
# busy" and ryoku_reclaim_leftovers skips its still-mounted partitions -- the
# retry wedges. tear our own prior attempt down first: swapoff the installer's
# swapfile (a swapfile pins its fs, blocking the umount), then recursively
# unmount /mnt. best-effort + idempotent; a fresh run (nothing at /mnt) no-ops.
ryoku_release_previous_attempt() {
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: if /mnt is a leftover mount from a prior attempt, would swapoff /mnt/swap/swapfile then umount -R /mnt"
    return 0
  fi
  mountpoint -q /mnt || return 0
  log "releasing /mnt left mounted by a previous install attempt (swapoff + umount -R)"
  swapoff /mnt/swap/swapfile 2>/dev/null || true
  umount -R /mnt 2>/dev/null || umount -l /mnt 2>/dev/null || true
  udevadm settle 2>/dev/null || true
}

ryoku_partition() {
  # a TUI retry re-runs this backend with /mnt still mounted from the failed
  # attempt; free it before touching the disk (see ryoku_release_previous_attempt).
  ryoku_release_previous_attempt
  case ${RYOKU_DISK_STRATEGY:-} in
    whole)     ryoku_partition_whole ;;
    alongside) ryoku_partition_alongside ;;
    '')        die "RYOKU_DISK_STRATEGY is required (use 'whole' or 'alongside'); refusing to wipe disk on empty strategy." ;;
    *)         die "disk strategy '$RYOKU_DISK_STRATEGY' not supported (use 'whole' or 'alongside')" ;;
  esac
}

# ryoku_free_mapper closes a device-mapper node by name. ryoku_release_disk only
# reaches mappers lsblk ties to the disk; one an earlier run orphaned still owns
# the name and fails the later `cryptsetup open ... root` with "Device root
# already exists". no such node is a no-op.
ryoku_free_mapper() {
  local name=$1 node="/dev/mapper/$1" mp
  [[ -n $name ]] || return 0
  dmsetup info -- "$name" >/dev/null 2>&1 || return 0
  log "freeing stale mapper /dev/mapper/$name held by a previous run"
  # unmount and swapoff first (a swapfile inside the fs pins the mapper), then close.
  while IFS= read -r mp; do
    [[ -n $mp ]] || continue
    run_sh "umount -R -- '$mp' 2>/dev/null || umount -l -- '$mp' 2>/dev/null || true"
  done < <(lsblk -nrpo MOUNTPOINT "$node" 2>/dev/null | awk 'NF' | sort -r)
  run_sh 'swapoff -a 2>/dev/null || true'
  run_sh "cryptsetup close -- '$name' 2>/dev/null || dmsetup remove --force -- '$name' 2>/dev/null || true"
  run_sh 'udevadm settle 2>/dev/null || true'
}

# ryoku_tree_mountpoints <mounts-file> <dev>...: every mountpoint in <mounts-file>
# (/proc/mounts format) whose source device is one of <dev>..., deepest path
# first. reads /proc/mounts, NOT lsblk MOUNTPOINT (which prints only ONE
# mountpoint per device), so all of a partition's subvol mounts come back;
# decodes the octal escapes /proc/mounts uses (\040 space, \011 tab, \134 \).
ryoku_tree_mountpoints() {
  local mounts=$1; shift
  [[ -r $mounts ]] || return 0
  (( $# )) || return 0
  local devset
  printf -v devset '%s\n' "$@"
  awk -v devs="$devset" '
    BEGIN { n = split(devs, a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") want[a[i]] = 1 }
    ($1 in want) {
      mp = $2
      gsub(/\\040/, " ", mp); gsub(/\\011/, "\t", mp); gsub(/\\134/, "\\", mp)
      print mp
    }
  ' "$mounts" | sort -ru
}

# ryoku_disk_swapfiles <swaps-file> <mountpoint>...: paths of file-type swap
# entries in <swaps-file> (/proc/swaps format) that sit under one of the given
# mountpoints -- so the installer's own /mnt/swap/swapfile (a FILE on @swap, not
# a swap-typed block device) is freed on a retry. block-device swaps are handled
# by the partition swapoff loop; this covers only the swapFILE case.
ryoku_disk_swapfiles() {
  local swaps=$1; shift
  [[ -r $swaps ]] || return 0
  (( $# )) || return 0
  local mpset
  printf -v mpset '%s\n' "$@"
  awk -v mps="$mpset" '
    BEGIN { cnt = split(mps, mp, "\n") }
    NR == 1 { next }
    $2 == "file" {
      f = $1
      gsub(/\\040/, " ", f); gsub(/\\011/, "\t", f); gsub(/\\134/, "\\", f)
      for (i = 1; i <= cnt; i++) {
        if (mp[i] == "") continue
        if (f == mp[i] || index(f, mp[i] "/") == 1) { print f; break }
      }
    }
  ' "$swaps"
}

# ryoku_release_disk = free the target so the wipe doesn't die "Device or
# resource busy". on the live medium something we didn't put there often holds
# the disk: udisks-automount, a stale /mnt, an open LUKS/dm mapper from a
# previous failed run, auto-enabled swap. kernel refuses to re-read or wipe a
# disk while ANY child is held, so tear it down leaves-first: swapoff, unmount,
# close dm/LUKS, vgchange -an, mdadm --stop, settle. scoped to the disk's own
# tree (lsblk "$disk"), never touches the live medium. best-effort + idempotent.
ryoku_release_disk() {
  local disk=$1
  [[ -b $disk || -n ${RYOKU_DRYRUN:-} ]] || return 0
  log "releasing $disk before wipe (swapoff, unmount, close holders)"

  local mounts_src=${RYOKU_PROC_MOUNTS:-/proc/mounts}
  local swaps_src=${RYOKU_PROC_SWAPS:-/proc/swaps}

  # every device in the disk's own tree (the disk, its partitions, any dm/LUKS
  # child). the exact set matched against /proc/mounts + /proc/swaps below, so a
  # sibling disk is never touched. lsblk -p names a mapper child the same way
  # /proc/mounts does (/dev/mapper/<name>), so the string match is direct.
  local name
  local -a tree_devs=()
  while IFS= read -r name; do
    [[ -n $name ]] && tree_devs+=("$name")
  done < <(lsblk -nrpo NAME "$disk" 2>/dev/null)

  # this disk's mountpoints, deepest first (see ryoku_tree_mountpoints for why
  # /proc/mounts and not lsblk).
  local -a mps=()
  local mp
  while IFS= read -r mp; do
    [[ -n $mp ]] && mps+=("$mp")
  done < <(ryoku_tree_mountpoints "$mounts_src" "${tree_devs[@]}")

  # swapoff any swapFILE on one of those mountpoints BEFORE the umount below: a
  # live swapfile pins its fs and fails the unmount. this is the installer's own
  # /mnt/swap/swapfile on a retry -- it is a file, so it never appears in the
  # partition swapoff loop further down.
  local sf
  while IFS= read -r sf; do
    [[ -n $sf ]] || continue
    run_sh "swapoff -- '$sf' 2>/dev/null || true"
  done < <(ryoku_disk_swapfiles "$swaps_src" "${mps[@]}")

  # unmount every mountpoint on the disk, deepest first (a nested mount pins its
  # parent). lazy-unmount fallback so a busy mount still releases the device.
  for mp in "${mps[@]}"; do
    run_sh "umount -R -- '$mp' 2>/dev/null || umount -l -- '$mp' 2>/dev/null || true"
  done

  # swapoff any swap PARTITION on the disk (a swap-typed child device).
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    run_sh "swapoff -- '$name' 2>/dev/null || true"
  done < <(lsblk -nrpo NAME,FSTYPE "$disk" 2>/dev/null | awk '$2=="swap"{print $1}')

  # close dm holders on the disk (LUKS/crypt, LVM, plain dm), leaves first so a
  # stacked setup unwinds. cryptsetup for crypt, dmsetup for the rest.
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    run_sh "cryptsetup close -- '$name' 2>/dev/null || dmsetup remove --force -- '$name' 2>/dev/null || true"
  done < <(lsblk -nrpo NAME,TYPE "$disk" 2>/dev/null | awk '$2=="crypt"||$2=="lvm"||$2=="dm"{print $1}' | tac)

  # deactivate any LVM VG with a PV on the disk or one of its partitions. feed
  # pvs the exact tree devices, NEVER a "${disk}*" glob: /dev/sda* would also
  # match /dev/sdaa on a many-disk box and could kill a VG on another disk.
  if command -v pvs >/dev/null 2>&1 && (( ${#tree_devs[@]} > 0 )); then
    while IFS= read -r name; do
      [[ -n $name ]] || continue
      run_sh "vgchange -an -- '$name' 2>/dev/null || true"
    done < <(pvs --noheadings -o vg_name "${tree_devs[@]}" 2>/dev/null | awk 'NF' | sort -u)
  fi

  # stop any md RAID array with a member on the disk.
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    run_sh "mdadm --stop -- '$name' 2>/dev/null || true"
  done < <(lsblk -nrpo NAME,TYPE "$disk" 2>/dev/null | awk '$2 ~ /raid/{print $1}' | tac)

  # a "root" mapper orphaned off the disk tree escapes the loops above; free it too.
  ryoku_free_mapper root

  run_sh 'udevadm settle 2>/dev/null || true'
}

# ryoku_wipe_signatures clears signatures off a device, retried: right after
# sgdisk zaps the GPT the kernel can briefly report the device busy while it
# drops the stale table, even with no holders left. settle + retry; the final
# attempt routes through run() so a real failure still aborts loudly (and is
# printed, not executed, under dry-run).
ryoku_wipe_signatures() {
  local target=$1
  if [[ -z ${RYOKU_DRYRUN:-} ]]; then
    for _ in 1 2; do
      wipefs --all "$target" 2>/dev/null && return 0
      udevadm settle 2>/dev/null || true
      sleep 1
    done
  fi
  run wipefs --all "$target"
}

ryoku_partition_whole() {
  local disk=$RYOKU_DISK
  local esp_end=$(( 1 + RYOKU_ESP_GIB * 1024 ))   # MiB: 1 MiB align gap + the ESP

  # destructive-wipe guard: refuse to zap a disk that already holds partitions
  # (e.g. a Windows install) unless the caller has explicitly acked. the TUI
  # only sets RYOKU_WIPE_CONFIRMED=1 after the typed "ERASE" ack on the Review
  # screen. a truly blank disk goes through without the token so a fresh install
  # is not gated on a second confirmation.
  # under dry-run the disk may be absent and ryoku_disk_populated fails closed,
  # so narrate the guard instead of probing; the real check stands in real mode.
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    log "DRYRUN: would refuse to wipe $disk if it holds partitions and RYOKU_WIPE_CONFIRMED != 1"
  elif [[ ${RYOKU_WIPE_CONFIRMED:-} != 1 ]] && ryoku_disk_populated "$disk"; then
    die "refusing to wipe $disk: it already holds partitions and RYOKU_WIPE_CONFIRMED is not set. Pick 'alongside' to keep them, or set RYOKU_WIPE_CONFIRMED=1 to wipe explicitly."
  fi

  log "partitioning $disk (whole disk, GPT: ${RYOKU_ESP_GIB}GiB ESP + root)"

  # free the disk before touching it: on the live medium the target may be held
  # by an auto-mounted partition (udisks), leftover state from a previous run,
  # or active swap. while a child holds the disk, sgdisk/wipefs fail "Device or
  # resource busy".
  ryoku_release_disk "$disk"

  # nuke the partition table, then re-read so the kernel drops the now-stale
  # partitions before wipefs probes the bare disk.
  run sgdisk --zap-all "$disk"
  run partprobe "$disk"
  run_sh 'udevadm settle 2>/dev/null || true'
  ryoku_wipe_signatures "$disk"

  # fresh GPT: partition 1 = ESP (EF00 == GPT 'esp' flag), partition 2 = root.
  run parted --script "$disk" mklabel gpt
  run parted --script "$disk" mkpart ESP fat32 1MiB "${esp_end}MiB"
  run parted --script "$disk" set 1 esp on
  run parted --script "$disk" mkpart root "${esp_end}MiB" 100%

  # let the kernel re-read the new table before touching the partitions.
  run partprobe "$disk"
  run_sh 'udevadm settle || true'

  ESP_DEV=$(part_dev "$disk" 1)
  ROOT_PART=$(part_dev "$disk" 2)

  # a fresh GPT can lay these partitions over an older layout, so a stale sig
  # (old LUKS2 header, previous btrfs) can still sit at the start of each. the
  # whole-disk wipefs above doesn't reach into partition space, so clear the new
  # partitions directly. otherwise blkid reports the old type (e.g. crypto_LUKS)
  # and the later mount fails with "unknown filesystem type".
  run wipefs --all "$ESP_DEV"
  run wipefs --all "$ROOT_PART"
  log "ESP=$ESP_DEV root partition=$ROOT_PART"
}

ryoku_partition_alongside() {
  local disk=$RYOKU_DISK
  log "partitioning $disk (alongside existing OS: dedicated Ryoku ESP + root in free space, nothing wiped)"

  # under dry-run the disk may not exist; narrate what we'd do and pick
  # plausible device names so the rest of the flow can be exercised.
  if [[ -n ${RYOKU_DRYRUN:-} ]]; then
    local d_min d_need d_max
    d_min=$(ryoku_min_root_gib)
    d_need=$(( d_min + RYOKU_ESP_GIB ))
    log "DRYRUN: would require a GPT disk and >= ${d_need}GiB contiguous free (${d_min}GiB root + ${RYOKU_ESP_GIB}GiB ESP); the Windows ESP is never touched"
    log "DRYRUN: with RYOKU_RECLAIM_LEFTOVERS=1 would reclaim UNMOUNTED leftover partitions labeled exactly ryoku/ryokuboot from a prior failed run; without the ack, existing such partitions abort the install"
    d_max=$(ryoku_max_partnum "$disk" 2>/dev/null || true)
    { [[ $d_max =~ ^[0-9]+$ ]] && (( d_max > 0 )); } || d_max=3   # disk absent on dev box: assume ESP+MSR+C:
    ESP_DEV=$(part_dev "$disk" "$(( d_max + 1 ))")
    ROOT_PART=$(part_dev "$disk" "$(( d_max + 2 ))")
    log "DRYRUN: new Ryoku ESP=$ESP_DEV (${RYOKU_ESP_GIB}GiB, label ryokuboot) root=$ROOT_PART (label ryoku)"
    return 0
  fi

  # UEFI dual-boot needs a GPT label. refuse MBR rather than guess at a remap.
  local pttype
  pttype=$(blkid -o value -s PTTYPE "$disk" 2>/dev/null || true)
  [[ $pttype == gpt ]] || die "alongside needs a GPT disk; $disk has '${pttype:-no}' partition table. Use whole-disk, or convert to GPT."

  # reclaim leftovers of a previous failed run BEFORE measuring free space, so
  # the region they hold is available again and retries don't stack partitions.
  # gated on RYOKU_RECLAIM_LEFTOVERS=1 (the TUI's typed-ERASE ack): without it,
  # existing ryoku/ryokuboot partitions are fatal, not silently deleted.
  ryoku_reclaim_leftovers "$disk"

  # need a contiguous free region big enough for a DEDICATED Ryoku ESP + root.
  # we never reuse the Windows ESP: a 100-260 MiB OEM ESP cannot hold our kernel
  # + initramfs + UKIs (ENOSPC mid-pacstrap or at mkinitcpio), and writing our
  # fallback loader onto it clobbers Windows'. user makes room by shrinking
  # Windows first (safest from Windows Disk Management).
  local free_mib min_root need_gib
  free_mib=$(ryoku_largest_free_mib "$disk")
  min_root=$(ryoku_min_root_gib)
  need_gib=$(( min_root + RYOKU_ESP_GIB ))
  (( free_mib >= need_gib * 1024 )) || die "not enough free space on $disk: $(( free_mib / 1024 ))GiB contiguous free, need >= ${need_gib}GiB (${min_root}GiB root + ${RYOKU_ESP_GIB}GiB ESP). Shrink the Windows partition first, then retry."
  log "largest free region: $(( free_mib / 1024 ))GiB (need >= ${need_gib}GiB for root + ESP)"

  # snapshot the pre-existing partition set so we can prove (after sgdisk) that
  # BOTH new partitions landed in free space without overwriting an existing one.
  local -a pre_parts=()
  local p
  while IFS= read -r p; do
    [[ -n $p ]] && pre_parts+=("$p")
  done < <(ryoku_partitions "$disk")

  # create the dedicated Ryoku ESP (EF00, label ryokuboot) then the root (8300,
  # label ryoku), each in the largest aligned free region sgdisk sees at that
  # step. 0:0 places the ESP in the current largest free block; the root's 0:0:0
  # then takes the largest free block AFTER the ESP -- usually the remainder of
  # the same region, but if that remainder is now smaller than another free
  # block the root lands in that OTHER region instead. either way only free
  # space is used and no existing partition is touched (the post-sgdisk checks
  # below prove exactly two NEW partitions appeared), and the >= root+ESP
  # single-region requirement measured above guarantees a home for both. one
  # invocation = one atomic table write.
  run sgdisk \
    -n "0:0:+${RYOKU_ESP_GIB}G" -t 0:ef00 -c 0:ryokuboot \
    -n 0:0:0 -t 0:8300 -c 0:ryoku \
    "$disk"
  run partprobe "$disk"
  run_sh 'udevadm settle || true'

  # the new partitions = current set minus the pre-existing set; must be exactly
  # two (the ESP + the root).
  local -a new_parts=()
  local seen q
  while IFS= read -r p; do
    [[ -n $p ]] || continue
    seen=0
    for q in "${pre_parts[@]}"; do [[ $q == "$p" ]] && { seen=1; break; }; done
    (( seen )) || new_parts+=("$p")
  done < <(ryoku_partitions "$disk")
  (( ${#new_parts[@]} == 2 )) || die "alongside expected to create 2 new partitions (ESP + root) but sees ${#new_parts[@]} (${new_parts[*]:-none}); refusing to continue."

  # map the two new partitions to ESP/root by our exact GPT partlabels.
  ESP_DEV=""; ROOT_PART=""
  local lbl
  for p in "${new_parts[@]}"; do
    lbl=$(lsblk -dno PARTLABEL "$p" 2>/dev/null || true)
    case $lbl in
      ryokuboot) ESP_DEV=$p ;;
      ryoku)     ROOT_PART=$p ;;
    esac
  done
  [[ -n $ESP_DEV ]]   || die "alongside could not find the new Ryoku ESP (partlabel ryokuboot) after sgdisk; refusing to continue."
  [[ -n $ROOT_PART ]] || die "alongside could not find the new Ryoku root (partlabel ryoku) after sgdisk; refusing to continue."
  [[ $ESP_DEV != "$ROOT_PART" ]] || die "alongside ESP and root resolved to the same device $ESP_DEV; refusing to continue."

  # hard safety, applied to BOTH new partitions: each must be a real NEW block
  # device, must not be the disk itself, must not have existed before sgdisk, and
  # its parent must be the target disk. any failure = we're about to touch an
  # existing OS partition, so abort before any wipefs/mkfs.
  local dev parent disk_base=${disk##*/}
  for dev in "$ESP_DEV" "$ROOT_PART"; do
    [[ $dev != "$disk" ]] || die "alongside partition resolves to disk $disk; refusing to format."
    [[ -b $dev ]] || die "alongside created a partition but $dev is not a block device."
    for p in "${pre_parts[@]}"; do
      [[ $p != "$dev" ]] || die "alongside partition $dev existed before sgdisk; refusing to format an existing partition."
    done
    parent=$(lsblk -no PKNAME "$dev" 2>/dev/null | head -n1)
    [[ $parent == "$disk_base" ]] || die "alongside partition $dev parent='$parent' does not match disk '$disk_base'; refusing to format."
  done

  # clear any stale sig in the two NEW partitions only (never the disk or any
  # existing partition), so a leftover LUKS/btrfs header at these offsets can't
  # fail the later mkfs/mount.
  run wipefs --all "$ESP_DEV"
  run wipefs --all "$ROOT_PART"
  log "ESP=$ESP_DEV (new Ryoku ESP) root partition=$ROOT_PART"
}

# ryoku_reclaim_leftovers deletes partitions whose GPT partlabel is EXACTLY
# 'ryoku' or 'ryokuboot' and that are not mounted: leftovers of a previous
# failed alongside run that would otherwise eat the free region and stack up on
# every retry. GATED: reclaim (a destructive delete) runs ONLY when
# RYOKU_RECLAIM_LEFTOVERS=1 -- the TUI sets it after the typed ERASE ack on the
# Review screen. without the ack, finding such partitions is fatal (they might
# be a healthy COMPLETED Ryoku install, not a leftover): die listing them and
# the two ways forward rather than delete anything. only our own exact labels,
# only when unmounted; any other partition (and a still-mounted one) is untouched.
ryoku_reclaim_leftovers() {
  local disk=$1 p lbl mnt num info list
  local -a dnums=() dinfo=()
  # first pass: identify leftovers while the table is still stable (nothing
  # deleted yet). collect their numbers; do NOT delete mid-scan -- sgdisk
  # re-reads the table after each -d, which races the kernel's view of the
  # sibling partitions we still have to inspect.
  while IFS= read -r p; do
    [[ -n $p ]] || continue
    lbl=$(lsblk -dno PARTLABEL "$p" 2>/dev/null || true)
    [[ $lbl == ryoku || $lbl == ryokuboot ]] || continue
    mnt=$(lsblk -nrpo MOUNTPOINT "$p" 2>/dev/null | awk 'NF' | head -n1)
    if [[ -n $mnt ]]; then
      log "leaving $p alone: labeled '$lbl' but mounted at $mnt (not a leftover)"
      continue
    fi
    num=$(part_num "$p")
    [[ $num =~ ^[0-9]+$ ]] || continue
    dnums+=("$num")
    dinfo+=("$p (GPT label '$lbl', partition $num)")
  done < <(ryoku_partitions "$disk")

  (( ${#dnums[@]} )) || return 0

  # safety gate: without the explicit ack these might be a healthy completed
  # Ryoku install, not a failed-run leftover. refuse to delete; list them and
  # the two ways forward.
  if [[ ${RYOKU_RECLAIM_LEFTOVERS:-} != 1 ]]; then
    list=""
    for info in "${dinfo[@]}"; do list+="  $info"$'\n'; done
    die "existing Ryoku-labeled partition(s) on $disk (a previous Ryoku install or a failed run):
${list}alongside will NOT delete these automatically -- they may be a working Ryoku install. To proceed, either:
  1) confirm reclaim in the TUI Review screen (the typed ERASE ack, which sets RYOKU_RECLAIM_LEFTOVERS=1) so they are deleted, or
  2) delete or keep them yourself with another tool, then retry."
  fi

  for info in "${dinfo[@]}"; do
    log "reclaiming leftover $info from a previous failed run"
  done
  # delete them all in ONE sgdisk call: a single table re-read at the end, so
  # removing one partition can't disturb the kernel's node for another.
  local -a delargs=()
  for num in "${dnums[@]}"; do delargs+=(-d "$num"); done
  run sgdisk "${delargs[@]}" "$disk"
  run partprobe "$disk"
  run_sh 'udevadm settle || true'
}

# ryoku_partitions: partition device paths on a disk, in table order.
ryoku_partitions() {
  lsblk -lnpo NAME,TYPE "$1" 2>/dev/null | awk '$2=="part"{print $1}'
}

# ryoku_disk_populated: 0 (true) when $1 has at least one visible partition, 1
# only when the disk IS visible AND has zero partitions. if the disk can't be
# read (missing device, broken GPT, no lsblk) we return 0 so the wipe guard
# fails closed: better to abort than wipe a disk we didn't fully introspect.
ryoku_disk_populated() {
  local disk=$1
  lsblk -dno NAME "$disk" >/dev/null 2>&1 || return 0
  local n
  n=$(lsblk -lnpo NAME,TYPE "$disk" 2>/dev/null | awk '$2=="part"' | wc -l)
  (( n > 0 ))
}

# ryoku_max_partnum: highest partition number on the disk (0 if none).
ryoku_max_partnum() {
  sgdisk -p "$1" 2>/dev/null | awk '/^[[:space:]]+[0-9]+[[:space:]]/{n=$1} END{print n+0}'
}

# ryoku_largest_free_mib: size (MiB) of the largest contiguous free region on
# the disk. parses parted's machine-readable free listing in whole BYTES (no
# float truncation), floors to MiB, then subtracts a 1 MiB alignment margin so
# the partition can still start on an aligned boundary inside the region.
ryoku_largest_free_mib() {
  parted -ms "$1" unit B print free 2>/dev/null | awk -F: '
    $0 ~ /free;[[:space:]]*$/ { s = $4; sub(/B$/, "", s); if (s + 0 > m) m = s + 0 }
    END { mib = int(m / 1048576); if (mib > 0) mib -= 1; printf "%d\n", mib }
  '
}
