#!/usr/bin/env bash
# shellcheck shell=bash
# optional LUKS2 on the root partition. RYOKU_ENCRYPT=1 = format root as a
# LUKS2 container and open it as /dev/mapper/root, so the filesystem lives
# on the mapper. always sets ROOT_DEV; sets LUKS_PART when encrypting
# (consumed by crypttab + the kernel cmdline).

ryoku_luks() {
  if [[ ${RYOKU_ENCRYPT:-} != 1 ]]; then
    ROOT_DEV=$ROOT_PART
    log "encryption: off (root on $ROOT_DEV)"
    return 0
  fi
  [[ -n ${RYOKU_LUKS_PASSPHRASE:-} ]] || die "RYOKU_ENCRYPT=1 but RYOKU_LUKS_PASSPHRASE is unset"

  # hard safety: LUKS only ever formats ROOT_PART. if ROOT_PART is unset, is
  # the whole disk, or matches the reused ESP, the partition step set
  # something dangerous, so refuse. better to abort than to luksFormat a
  # Windows partition or the ESP.
  [[ -n ${ROOT_PART:-} ]] || die "LUKS: ROOT_PART is unset; refusing to format."
  [[ $ROOT_PART != "${RYOKU_DISK:-}" ]] || die "LUKS: refusing to format whole disk ($ROOT_PART); ROOT_PART must be a partition."
  [[ $ROOT_PART != "${ESP_DEV:-}" ]] || die "LUKS: refusing to format ESP ($ROOT_PART); ROOT_PART must be the new root partition."

  LUKS_PART=$ROOT_PART
  log "encryption: LUKS2 on $LUKS_PART -> /dev/mapper/root"

  # a /dev/mapper/root left open by a previous failed run (or a retry in the
  # same live session) makes `cryptsetup open ... root` abort with "Device root
  # already exists" before any keyslot is checked. free the name first so the
  # open is idempotent; harmless when nothing holds it. (ryoku_release_disk does
  # the same before the wipe; this guards the open even when release ran on a
  # different disk or the name was orphaned after.)
  ryoku_free_mapper root

  # passphrase stays on stdin, never on the command line, never in a log.
  printf '%s' "$RYOKU_LUKS_PASSPHRASE" | run_secret \
    "cryptsetup luksFormat --type luks2 --batch-mode $LUKS_PART (passphrase via stdin)" \
    cryptsetup luksFormat --type luks2 --batch-mode "$LUKS_PART"
  printf '%s' "$RYOKU_LUKS_PASSPHRASE" | run_secret \
    "cryptsetup open $LUKS_PART root (passphrase via stdin)" \
    cryptsetup open "$LUKS_PART" root

  ROOT_DEV=/dev/mapper/root
}
