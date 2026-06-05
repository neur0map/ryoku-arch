#!/usr/bin/env bash

# Check dependencies
for dep in grim slurp tesseract wl-copy notify-send; do
    if ! command -v $dep &> /dev/null; then
        notify-send "OCR Error" "Missing dependency: $dep" -u critical
        exit 1
    fi
done

# Select region
REGION=$(slurp)
if [ -z "$REGION" ]; then
    exit 0 # User cancelled
fi

# Capture and OCR
# Languages based on installed tesseract packages:
# eng (English), spa (Spanish), lat (Latin), jpn (Japanese), 
# chi_sim (Simplified Chinese), chi_tra (Traditional Chinese), kor (Korean)
if [ -n "$1" ]; then
    LANGS="$1"
else
    # Default fallback if no argument provided
    LANGS="eng+spa"
fi

# Pipe grim output to tesseract stdin (-) and output to stdout (-)
# stderr is redirected to /dev/null to avoid noise in notification if tesseract warns
TEXT=$(grim -g "$REGION" - | tesseract - - -l "$LANGS" 2>/dev/null)

# Trim whitespace
TEXT=$(echo "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -n "$TEXT" ]; then
    echo "$TEXT" | wl-copy
    notify-send "OCR Result" "Text copied to clipboard" -i edit-paste
else
    notify-send "OCR Result" "No text detected" -u low -i dialogue-error
fi
