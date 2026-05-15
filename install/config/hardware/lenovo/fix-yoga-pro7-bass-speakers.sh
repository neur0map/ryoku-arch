# Fix bass speakers on Lenovo Yoga Pro 7 14IAH10.

if ryoku-hw-match "Yoga Pro 7 14IAH10"; then
  sudo tee /etc/modprobe.d/lenovo-yoga-pro7-bass.conf >/dev/null <<'EOF'
options snd-sof-intel-hda-generic hda_model=alc287-yoga9-bass-spk-pin
EOF
fi
