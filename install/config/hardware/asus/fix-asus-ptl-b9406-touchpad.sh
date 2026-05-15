# Touchpad quirk for ASUS ExpertBook B9406 (Pixart 093A:4F05 on i2c-hid).
#
# The pad reports near-zero pressure, causing libinput jump detection to drop
# all motion while button events still work. Mask pressure axes for this model.

if ryoku-hw-asus-expertbook-b9406; then
  sudo mkdir -p /etc/libinput
  sudo tee /etc/libinput/ryoku-asus-expertbook-b9406.quirks >/dev/null <<EOF
[ASUS ExpertBook B9406 Touchpad]
MatchBus=i2c
MatchUdevType=touchpad
MatchVendor=0x093A
MatchProduct=0x4F05
MatchDMIModalias=dmi:*svnASUS*:pn*B9406*
AttrEventCode=-ABS_MT_PRESSURE;-ABS_PRESSURE;
EOF
fi
