#!/bin/sh
MAGICK_CONFIGURE_PATH="$(dirname "$0")/magick-policy"
export MAGICK_CONFIGURE_PATH

cache="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbs"
mkdir -p "$cache"
chmod 700 "$cache"

tab=$(printf '\t')
snapshot=$(cliphist list)

ids=$(printf '%s\n' "$snapshot" | cut -f1)
for f in "$cache"/*.png; do
    [ -e "$f" ] || continue
    fid=$(basename "$f" .png)
    printf '%s\n' "$ids" | grep -qxF "$fid" || rm -f "$f"
done

printf '%s\n' "$snapshot" | while IFS= read -r line; do
    case "$line" in
        *"${tab}[[ binary data"*png*" ]]"|*"${tab}[[ binary data"*jpg*" ]]"|*"${tab}[[ binary data"*jpeg*" ]]"|*"${tab}[[ binary data"*gif*" ]]"|*"${tab}[[ binary data"*bmp*" ]]"|*"${tab}[[ binary data"*webp*" ]]")
            id=$(printf '%s' "$line" | cut -f1)
            thumb="$cache/$id.png"
            if [ ! -s "$thumb" ]; then
                raw="$cache/.raw.$id"
                printf '%s' "$id" | cliphist decode > "$raw" 2>/dev/null
                magick "${raw}[0]" -resize '256x256>' "png:$thumb.tmp" 2>/dev/null
                if [ -s "$thumb.tmp" ]; then
                    mv "$thumb.tmp" "$thumb"
                else
                    rm -f "$thumb.tmp"
                fi
                rm -f "$raw"
            fi
            ;;
    esac
done
