echo "Converge VPN service setup"

if [[ -x $RYOKU_PATH/install/config/openvpn.sh ]]; then
  bash "$RYOKU_PATH/install/config/openvpn.sh"
fi

if [[ -x $RYOKU_PATH/install/config/tailscale.sh ]]; then
  bash "$RYOKU_PATH/install/config/tailscale.sh"
fi
