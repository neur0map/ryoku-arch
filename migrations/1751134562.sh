echo "Ensure all indexes and packages are up to date"

ryoku-update-keyring
ryoku-refresh-pacman
sudo pacman -Syu --noconfirm
