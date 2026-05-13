echo "Copy Ryoku logo to ~/.config/ryoku/branding/screensaver.txt so screensaver can be personalized"

mkdir -p ~/.config/ryoku/branding
cp "$RYOKU_PATH"/assets/brand/logo.txt ~/.config/ryoku/branding/screensaver.txt
