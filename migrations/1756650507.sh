echo "Fix JetBrains font setting"

if [[ $(ryoku-font-current) == JetBrains* ]]; then
  ryoku-font-set "JetBrainsMono Nerd Font"
fi
