echo "Add emoji font fallback to fontconfig"
cp $RYOKU_PATH/config/fontconfig/fonts.conf ~/.config/fontconfig/fonts.conf
fc-cache -f
