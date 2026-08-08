#!/bin/sh
# Wallpaper index for the switcher overlay. One thumbnail and one dominant-colour
# reading per wallpaper, for images (~/Pictures/Wallpapers) and videos
# (~/Pictures/livewalls) alike, printed as TSV for the Walls singleton:
#
#   type<TAB>mtime<TAB>path<TAB>thumb<TAB>hue<TAB>sat<TAB>preview
#
# Thumb and hue are cached beside each other and only rebuilt when the source is
# newer, so a warm run returns at once. Only the untrusted original -> thumbnail
# decode runs through the shared magick cage; the hue reading is taken from the
# thumbnail we just made, and video posters come from ffmpeg's first frame.
#
# `preview` is a small muted loop the switcher plays on a hovered live tile,
# instead of decoding the full-res original (a 4K clip through QtMultimedia
# hitches the UI and takes seconds). It is built by a detached background pass
# this script kicks at the end, never on the hot path, so the grid never waits on
# a transcode; the switcher picks each preview up on its next open once it exists.
wpdir="$HOME/Pictures/Wallpapers"
livedir="$HOME/Pictures/livewalls"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/ryoku-wp-thumbs"
policy="$HOME/.config/hypr/scripts/magick-policy"
mkdir -p "$cache"

# one small preview loop from a clip: ~480p, muted, capped length, fast encode.
mkprev() {
    ffmpeg -y -loglevel error -t 12 -i "$1" -an \
        -vf "scale=480:-2:flags=bicubic,fps=24" \
        -c:v libx264 -preset veryfast -crf 30 -pix_fmt yuv420p -movflags +faststart \
        "$2.tmp.mp4" 2>/dev/null
    if [ -s "$2.tmp.mp4" ]; then mv "$2.tmp.mp4" "$2"; else rm -f "$2.tmp.mp4"; fi
}

# --previews: the detached background pass. Build a preview for every live clip
# missing one (or older than its source), flock'd so two switcher opens never
# double up, a few at a time so it drains fast without pinning every core.
if [ "$1" = "--previews" ]; then
    exec 9>"$cache/.preview.lock"
    flock -n 9 || exit 0
    n=0
    for src in "$livedir"/*; do
        case "$src" in *.mp4 | *.webm | *.mkv | *.MP4 | *.WEBM | *.MKV) ;; *) continue ;; esac
        [ -e "$src" ] || continue
        prev="$cache/$(basename "$src").preview.mp4"
        { [ -s "$prev" ] && [ ! "$src" -nt "$prev" ]; } && continue
        mkprev "$src" "$prev" &
        n=$((n + 1))
        [ "$((n % 4))" -eq 0 ] && wait
    done
    wait
    exit 0
fi

# decode an untrusted image through the cage when the policy is present.
caged() {
    if [ -d "$policy" ]; then MAGICK_CONFIGURE_PATH="$policy" magick "$@"; else magick "$@"; fi
}

# drop cached thumbs + hues + previews whose source is gone.
for f in "$cache"/*.png; do
    [ -e "$f" ] || continue
    b=$(basename "$f" .png)
    [ -e "$wpdir/$b" ] || [ -e "$livedir/$b" ] || rm -f "$f" "$cache/$b.hue" "$cache/$b.preview.mp4"
done

emit() {
    kind=$1 src=$2
    [ -e "$src" ] || return
    name=$(basename "$src")
    thumb="$cache/$name.png"
    huef="$cache/$name.hue"
    if [ ! -s "$thumb" ] || [ "$src" -nt "$thumb" ]; then
        if [ "$kind" = live ]; then
            ffmpeg -y -loglevel error -ss 1 -i "$src" -frames:v 1 -vf "scale=512:-2" "$thumb.tmp.png" 2>/dev/null
            [ -s "$thumb.tmp.png" ] || ffmpeg -y -loglevel error -i "$src" -frames:v 1 -vf "scale=512:-2" "$thumb.tmp.png" 2>/dev/null
        else
            caged "${src}[0]" -strip -resize 512x "$thumb.tmp.png" 2>/dev/null
        fi
        if [ -s "$thumb.tmp.png" ]; then mv "$thumb.tmp.png" "$thumb"; rm -f "$huef"; else rm -f "$thumb.tmp.png"; fi
    fi
    [ -s "$thumb" ] || return
    if [ ! -s "$huef" ]; then
        magick "$thumb" -resize 1x1! -colorspace HSL -format '%[fx:u.r*360] %[fx:u.g*100]' info: >"$huef" 2>/dev/null || echo "0 0" >"$huef"
    fi
    read -r hue sat <"$huef"
    prev=""
    if [ "$kind" = live ]; then
        p="$cache/$name.preview.mp4"
        [ -s "$p" ] && prev="$p"
    fi
    mtime=$(stat -c %Y "$src" 2>/dev/null || echo 0)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$mtime" "$src" "$thumb" "${hue:-0}" "${sat:-0}" "$prev"
}

for src in "$wpdir"/*; do
    case "$src" in
    *.jpg | *.jpeg | *.png | *.webp | *.JPG | *.JPEG | *.PNG | *.WEBP) emit image "$src" ;;
    esac
done
for src in "$livedir"/*; do
    case "$src" in
    *.mp4 | *.webm | *.mkv | *.MP4 | *.WEBM | *.MKV) emit live "$src" ;;
    esac
done

# kick the detached preview builder so the grid never waits on a transcode.
if command -v setsid >/dev/null 2>&1 && command -v flock >/dev/null 2>&1; then
    setsid sh "$0" --previews >/dev/null 2>&1 </dev/null &
fi
