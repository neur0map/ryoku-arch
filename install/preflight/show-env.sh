# Show installation environment variables
gum log --level info "Installation Environment:"

env | grep -E "^(RYOKU_CHROOT_INSTALL|RYOKU_ONLINE_INSTALL|RYOKU_USER_NAME|RYOKU_USER_EMAIL|USER|HOME|RYOKU_REPO|RYOKU_REF|RYOKU_PATH)=" | sort | while IFS= read -r var; do
  gum log --level info "  $var"
done
