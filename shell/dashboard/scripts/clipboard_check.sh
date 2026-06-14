#!/usr/bin/env bash
# Check clipboard and insert into database
# Usage: clipboard_check.sh <db_path> <script_path> <data_dir>

set -euo pipefail

DB_PATH="$1"
SCRIPT_PATH="$2"
DATA_DIR="$3"

# Check for files first (text/uri-list)
if FILE_CONTENT=$(wl-paste --type text/uri-list 2>/dev/null); then
	HASH=$(echo -n "$FILE_CONTENT" | tr -d '\r' | md5sum | cut -d' ' -f1)

	# Get file size if it's a local file
	FILE_SIZE=0
	FILE_PATH=$(echo -n "$FILE_CONTENT" | tr -d '\r' | sed 's|^file://||')
	if [ -f "$FILE_PATH" ]; then
		FILE_SIZE=$(stat -c%s "$FILE_PATH" 2>/dev/null || echo 0)
	fi

	echo -n "$FILE_CONTENT" | tr -d '\r' | "$SCRIPT_PATH" "$DB_PATH" "$HASH" "text/uri-list" 0 "" "$FILE_SIZE"
	exit 0
fi

# Check for images
if IMAGE_MIME=$(wl-paste --list-types 2>/dev/null | grep '^image/' | head -1); then
	if [ -n "$IMAGE_MIME" ]; then
		TEMP_IMG=$(mktemp)
		trap 'rm -f "$TEMP_IMG"' EXIT

		if wl-paste --type "$IMAGE_MIME" 2>/dev/null >"$TEMP_IMG"; then
			HASH=$(md5sum "$TEMP_IMG" | cut -d' ' -f1)

			# Determine file extension from MIME type
			case "$IMAGE_MIME" in
			image/png) EXT="png" ;;
			image/jpeg) EXT="jpg" ;;
			image/gif) EXT="gif" ;;
			image/webp) EXT="webp" ;;
			image/bmp) EXT="bmp" ;;
			image/svg+xml) EXT="svg" ;;
			*) EXT="img" ;;
			esac

			TIMESTAMP=$(date +%Y%m%d_%H%M%S)
			FILENAME="clipboard_${TIMESTAMP}.${EXT}"
			BINARY_PATH="$DATA_DIR/$FILENAME"

			mv "$TEMP_IMG" "$BINARY_PATH"
			trap - EXIT

			IMAGE_SIZE=$(stat -c%s "$BINARY_PATH" 2>/dev/null || echo 0)

			echo -n '' | "$SCRIPT_PATH" "$DB_PATH" "$HASH" "$IMAGE_MIME" 1 "$BINARY_PATH" "$IMAGE_SIZE"
			exit 0
		fi
	fi
fi

# Check for plain text - prefer UTF-8 charset to preserve unicode characters
if TEXT_CONTENT=$(wl-paste --type 'text/plain;charset=utf-8' 2>/dev/null); then
	HASH=$(echo -n "$TEXT_CONTENT" | md5sum | cut -d' ' -f1)
	TEXT_SIZE=${#TEXT_CONTENT}
	echo -n "$TEXT_CONTENT" | "$SCRIPT_PATH" "$DB_PATH" "$HASH" "text/plain" 0 "" "$TEXT_SIZE"
	exit 0
elif TEXT_CONTENT=$(wl-paste --type text/plain 2>/dev/null); then
	HASH=$(echo -n "$TEXT_CONTENT" | md5sum | cut -d' ' -f1)
	TEXT_SIZE=${#TEXT_CONTENT}
	echo -n "$TEXT_CONTENT" | "$SCRIPT_PATH" "$DB_PATH" "$HASH" "text/plain" 0 "" "$TEXT_SIZE"
	exit 0
fi
