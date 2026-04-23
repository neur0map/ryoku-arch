RYOKU_MIGRATIONS_STATE_PATH="$RYOKU_STATE_PATH/migrations"
mkdir -p "$RYOKU_MIGRATIONS_STATE_PATH"

for file in "$RYOKU_PATH"/migrations/*.sh; do
  touch "$RYOKU_MIGRATIONS_STATE_PATH/$(basename "$file")"
done
