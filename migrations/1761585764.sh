[[ -f $HOME/.local/state/ryoku/independence-cutover.nvim.done ]] && exit 0

echo "Disable Nvim news alerts box"

cp /usr/share/omarchy-nvim/config/lua/plugins/disable-news-alert.lua ~/.config/nvim/lua/plugins/disable-news-alert.lua
