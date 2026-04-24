# Set identification from install inputs
if [[ -n ${RYOKU_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$RYOKU_USER_NAME"
fi

if [[ -n ${RYOKU_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$RYOKU_USER_EMAIL"
fi
