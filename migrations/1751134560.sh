echo "Add UWSM env"

export RYOKU_PATH="$HOME/.local/share/ryoku"
export PATH="$RYOKU_PATH/bin:$PATH"

mkdir -p "$HOME/.config/uwsm/"
cat <<EOF | tee "$HOME/.config/uwsm/env"
export RYOKU_PATH=$HOME/.local/share/ryoku
export PATH=$RYOKU_PATH/bin/:$PATH
EOF

# Ensure we have the latest repos and are ready to pull
ryoku-update-keyring
ryoku-refresh-pacman
sudo systemctl restart systemd-timesyncd
sudo pacman -Sy # Normally not advisable, but we'll do a full -Syu before finishing

mkdir -p ~/.local/state/ryoku/migrations
touch ~/.local/state/ryoku/migrations/1751134560.sh

# Remove old AUR packages to prevent a super lengthy build on old Ryoku installs
ryoku-pkg-drop zoom qt5-remoteobjects wf-recorder wl-screenrec

# Get rid of old AUR packages
bash $RYOKU_PATH/migrations/1756060611.sh
touch ~/.local/state/ryoku/migrations/1756060611.sh

bash ryoku-update-perform
