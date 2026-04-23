# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run ryoku-restart-xcompose to apply changes

# Include fast emoji access
include "%H/.local/share/ryoku/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$RYOKU_USER_NAME"
<Multi_key> <space> <e> : "$RYOKU_USER_EMAIL"
EOF
