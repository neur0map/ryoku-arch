echo "Move Omarchy Package Repository after Arch core/extra/multilib and remove AUR"

ryoku-refresh-pacman
sudo pacman -Syu --noconfirm
