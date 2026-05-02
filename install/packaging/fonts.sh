# Ryoku and iNiR-visible user fonts
mkdir -p ~/.local/share/fonts
cp "$RYOKU_PATH/config/ryoku.ttf" ~/.local/share/fonts/

if [[ -d $RYOKU_PATH/config/fonts ]]; then
  for font in "$RYOKU_PATH"/config/fonts/*.{otf,ttf}; do
    [[ -f $font ]] || continue
    cp "$font" ~/.local/share/fonts/
  done
fi

fc-cache
