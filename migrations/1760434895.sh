echo "Change to omarchy-nvim package"
ryoku-pkg-drop omarchy-lazyvim
ryoku-pkg-add omarchy-nvim

# Will trigger to overwrite configs or not to pickup new hot-reload themes
omarchy-nvim-setup
