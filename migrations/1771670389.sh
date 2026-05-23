echo "Add Logout option to system menu"

true # ryoku-refresh-sddm retired post-rebirth (install-pixel-sddm.sh removed)

if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  sudo sed -i 's/^Current=.*/Current=omarchy/' /etc/sddm.conf.d/autologin.conf
fi
