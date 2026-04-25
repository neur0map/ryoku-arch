#!/bin/bash
# Stages 2-4: gum-driven prompts for disk selection, user info,
# and final type-the-disk-name confirmation.

# --- Stage 2: disk selection -------------------------------------------------

stage_header 2 10 "Disk Selection"

info "Pick the disk to install Ryoku to. The selected disk WILL be erased."

# Build a labeled list: name (size, model)
disk_options=()
for d in $RYOKU_CANDIDATE_DISKS; do
  size=$(lsblk -dn -o SIZE "/dev/$d")
  model=$(lsblk -dn -o MODEL "/dev/$d" | sed 's/[[:space:]]*$//')
  disk_options+=("/dev/$d  ($size, ${model:-unknown model})")
done

selection=$(printf '%s\n' "${disk_options[@]}" \
  | gum choose --cursor.foreground 202 --header "Target disk")
TARGET_DISK="${selection%% *}"     # strip the description after the path

if [[ -z $TARGET_DISK ]]; then
  abort "No disk selected."
fi

success "Target: $TARGET_DISK"
export TARGET_DISK

# --- Stage 3: user config ----------------------------------------------------

stage_header 3 10 "User Configuration"

info "Set up your hostname, user, and disk passphrase."

HOSTNAME=$(gum input --prompt.foreground 202 \
  --prompt "Hostname ❯ " --placeholder "ryoku" --value "ryoku")
[[ -z $HOSTNAME ]] && HOSTNAME="ryoku"
export HOSTNAME

USERNAME=$(gum input --prompt.foreground 202 \
  --prompt "Username ❯ " --placeholder "your-name")
if [[ -z $USERNAME ]] || ! [[ $USERNAME =~ ^[a-z][a-z0-9_-]*$ ]]; then
  abort "Username must start with a lowercase letter and contain only" \
        "lowercase letters, digits, '-', or '_'."
fi
export USERNAME

# User password (twice, must match)
prompt_password() {
  local label="$1" min="$2" pw1 pw2
  while :; do
    pw1=$(gum input --password --prompt.foreground 202 \
            --prompt "${label} ❯ ")
    if (( ${#pw1} < min )); then
      info "Too short (minimum ${min} characters). Try again."
      continue
    fi
    pw2=$(gum input --password --prompt.foreground 202 \
            --prompt "${label} (confirm) ❯ ")
    if [[ $pw1 != "$pw2" ]]; then
      info "Passwords did not match. Try again."
      continue
    fi
    printf '%s' "$pw1"
    return
  done
}

USER_PW=$(prompt_password "User password" 8)
export USER_PW

ROOT_PW=$(prompt_password "Root password" 8)
export ROOT_PW

LUKS_PW=$(prompt_password "Disk encryption passphrase" 12)
export LUKS_PW

success "Configuration captured."

# --- Stage 4: review and confirm --------------------------------------------

stage_header 4 10 "Review and Confirm"

# Show what is currently on the target disk
gum style --foreground 248 \
  "Current contents of $TARGET_DISK:" "" \
  "$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$TARGET_DISK")"
echo

# Plan summary
gum style --border rounded --foreground 202 --padding "1 2" --width 60 \
  "Install plan" "" \
  "  Target disk      : $TARGET_DISK" \
  "  Hostname         : $HOSTNAME" \
  "  Username         : $USERNAME" \
  "  Filesystem       : btrfs (subvols: @ @home @snapshots @log @cache @pkg)" \
  "  Encryption       : LUKS2 (Argon2id, 1 GiB memory cost)" \
  "  Bootloader       : limine (UEFI)" \
  "  Snapshots        : enabled (snapper, configured by boot.sh)"
echo

warning "This WILL erase ALL data on $TARGET_DISK." \
        "" \
        "Type the disk name (e.g. $(basename "$TARGET_DISK")) to confirm:"

attempts=0
while (( attempts < 3 )); do
  echo
  typed=$(gum input --prompt.foreground 196 \
            --prompt "confirm ❯ " \
            --placeholder "$(basename "$TARGET_DISK")")
  if [[ $typed == "$(basename "$TARGET_DISK")" ]]; then
    success "Confirmed."
    return 0 2>/dev/null || true
    break
  fi
  attempts=$((attempts + 1))
  info "Mismatch ($attempts/3). The exact disk name is: $(basename "$TARGET_DISK")"
done

if (( attempts >= 3 )); then
  abort "Confirmation failed three times. Aborting."
fi
