#!/usr/bin/env bash
# Insert clipboard item into database
# Usage: clipboard_insert.sh <db_path> <hash> <mime_type> <is_image> <binary_path> <size>
# Content is read from stdin

set -euo pipefail

DB_PATH="$1"
HASH="$2"
MIME_TYPE="$3"
IS_IMAGE="$4"
BINARY_PATH="$5"
SIZE="${6:-0}"

# Read content from stdin and strip carriage returns
# Use a temp file to preserve all unicode characters exactly
CONTENT_FILE=$(mktemp)
trap 'rm -f "$CONTENT_FILE"' EXIT
cat | tr -d '\r' >"$CONTENT_FILE"

# Read content back
CONTENT=$(cat "$CONTENT_FILE")

# Don't insert empty content for text items
if [ "$IS_IMAGE" = "0" ] && [ -z "$CONTENT" ]; then
	exit 0
fi

# Create preview
if [ "$IS_IMAGE" = "1" ]; then
	PREVIEW="[Image]"
elif [ ${#CONTENT} -gt 100 ]; then
	PREVIEW="${CONTENT:0:97}..."
else
	PREVIEW="$CONTENT"
fi

# Get timestamp in milliseconds
TIMESTAMP=$(date +%s)000

# Write preview to temp file
PREVIEW_FILE=$(mktemp)
trap 'rm -f "$CONTENT_FILE" "$PREVIEW_FILE"' EXIT
printf '%s' "$PREVIEW" >"$PREVIEW_FILE"

# Use sqlite3 with -cmd to read from files using readfile() function
# This avoids all shell escaping issues
sqlite3 "$DB_PATH" <<EOSQL
.timeout 5000
BEGIN TRANSACTION;
-- Insert or update item (unpinned items always get display_index 0)
INSERT INTO clipboard_items 
(content_hash, mime_type, preview, full_content, is_image, binary_path, size, pinned, display_index, created_at, updated_at) 
VALUES (
    '${HASH}',
    '${MIME_TYPE}',
    readfile('${PREVIEW_FILE}'),
    readfile('${CONTENT_FILE}'),
    ${IS_IMAGE},
    '${BINARY_PATH}',
    ${SIZE},
    0,
    0,
    ${TIMESTAMP},
    ${TIMESTAMP}
)
ON CONFLICT(content_hash) DO UPDATE SET
updated_at = ${TIMESTAMP},
display_index = 0;
-- Reindex unpinned items (new item is at 0, others shift down)
WITH reindexed AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY updated_at DESC, id DESC) - 1 AS new_idx
  FROM clipboard_items WHERE pinned = 0
)
UPDATE clipboard_items SET display_index = (SELECT new_idx FROM reindexed WHERE reindexed.id = clipboard_items.id) WHERE pinned = 0;
COMMIT;
EOSQL
