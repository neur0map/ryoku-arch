echo "Seed bundled live wallpapers into ~/videowalls"

# Fresh installs get the bundled live wallpapers via seed_default_videowalls in
# install/config/config.sh, but the update path only runs migrations - it never
# re-runs config.sh. Bring existing installs in line by copying the shipped
# *.mp4 from $RYOKU_PATH/videowalls into ~/videowalls (skwd-wall's videoWallpaper
# dir), which makes them show up in the SUPER+W picker's video section. Mirrors
# the seed function: only *.mp4, never clobbers a file the user already has,
# best-effort and idempotent.

source_dir="$RYOKU_PATH/videowalls"
target_dir="$HOME/videowalls"

[[ -d $source_dir ]] || exit 0

mkdir -p "$target_dir"

while IFS= read -r -d '' source_file; do
  target="$target_dir/$(basename "$source_file")"
  [[ -e $target ]] || cp -a "$source_file" "$target"
done < <(find "$source_dir" -maxdepth 1 -type f -iname '*.mp4' -print0)
