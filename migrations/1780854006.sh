echo "Drop /home snapshots and btrfs quotas, keep 5 root snapshots, no timeline"

if ! ryoku-cmd-present snapper btrfs; then
  exit 0
fi

# Disable quotas first: every subvolume delete below would otherwise update
# all qgroups, which is the performance drag we are removing.
sudo btrfs quota disable / 2>/dev/null || true

# Remove the home config and its snapshots, but only when they look auto
# generated. If any snapshot looks hand made (a pre/post pair, or a non
# timeline/number cleanup), leave everything in place. We never run
# interactively, so destroying user snapshots on a guess is not acceptable.
if sudo snapper list-configs 2>/dev/null | grep -q "home"; then
  manual_snaps=$(sudo snapper -c home --csvout list --columns number,type,cleanup 2>/dev/null |
    awk -F, 'NR>1 && $1!="0" && ($2=="pre" || $2=="post" || ($3!="timeline" && $3!="number"))')

  if [[ -n $manual_snaps ]]; then
    echo "  /home has snapshots that look hand made; leaving its snapper config alone."
    echo "  Remove it yourself with: sudo snapper -c home delete-config"
  else
    sudo snapper -c home list --columns number 2>/dev/null |
      awk 'NR>2 && $1 != "0" {print $1}' |
      xargs -r sudo snapper -c home delete 2>/dev/null
    sudo snapper -c home delete-config 2>/dev/null

    home_subvol="/home"
    home_snapshots="$home_subvol/.snapshots"
    if [[ -d $home_snapshots ]]; then
      for snap in "$home_snapshots"/*/snapshot; do
        [[ -d $snap ]] && sudo btrfs subvolume delete "$snap" 2>/dev/null
      done
      sudo rm -rf "${home_snapshots:?}"/* 2>/dev/null
      sudo btrfs subvolume delete "$home_snapshots" 2>/dev/null
    fi
  fi
fi

# Ensure the root config exists and matches our shipped defaults
if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
  sudo snapper -c root create-config /
fi
sudo cp "$RYOKU_PATH/default/snapper/root" /etc/snapper/configs/root

# Drop timeline snapshots: we only keep pre-update (number) snapshots
sudo snapper -c root --csvout list --columns number,cleanup 2>/dev/null |
  awk -F, 'NR>1 && $2 == "timeline" {print $1}' |
  xargs -r sudo snapper -c root delete 2>/dev/null

# Enforce NUMBER_LIMIT on any remaining number snapshots beyond the new cap
sudo snapper -c root cleanup number 2>/dev/null || true
