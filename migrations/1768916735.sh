echo "Fix microphone gain and audio mixing on Asus ROG laptops"

source "$RYOKU_PATH/install/config/hardware/asus/fix-mic.sh"
source "$RYOKU_PATH/install/config/hardware/asus/fix-audio-mixer.sh"

if ryoku-hw-asus-rog; then
  ryoku-restart-pipewire
fi
