# Run before limine-snapper.sh so the resume hook and cmdline drop-ins are in
# place when the install performs its single Limine/UKI rebuild. The
# --no-rebuild flag tells the helper to skip its own rebuild.
ryoku-hibernation-setup --force --no-rebuild
