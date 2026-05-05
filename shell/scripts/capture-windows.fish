#!/usr/bin/env fish
# Capture screenshots of windows for TaskView
# Handles cliphist cleanup to prevent screenshot spam

set -l preview_dir ~/.cache/inir/window-previews
set -l ids_to_capture
set -l capture_all false

set -l niri_bin /usr/bin/niri
set -l jq_bin /usr/bin/jq
set -l cliphist_bin /usr/bin/cliphist
set -l head_bin /usr/bin/head
set -l wlpaste_bin /usr/bin/wl-paste
set -l wlcopy_bin /usr/bin/wl-copy

# Parse arguments
for arg in $argv
    switch $arg
        case --all
            set capture_all true
        case '*'
            if string match -qr '^\d+$' $arg
                set -a ids_to_capture $arg
            end
    end
end

mkdir -p $preview_dir

if not test -x $niri_bin
    echo "[capture-windows] missing niri: $niri_bin" 1>&2
    exit 127
end
if not test -x $jq_bin
    echo "[capture-windows] missing jq: $jq_bin" 1>&2
    exit 127
end
if not test -x $cliphist_bin
    echo "[capture-windows] missing cliphist: $cliphist_bin" 1>&2
    exit 127
end
if not test -x $head_bin
    echo "[capture-windows] missing head: $head_bin" 1>&2
    exit 127
end

# Preserve clipboard (best-effort) so previews never replace user clipboard.
set -l saved_clip_mime ""
set -l saved_clip_file ""
if test -x $wlpaste_bin; and test -x $wlcopy_bin
    set -l mime_list ($wlpaste_bin -l 2>/dev/null)
    if test (count $mime_list) -gt 0
        if contains -- "text/plain;charset=utf-8" $mime_list
            set saved_clip_mime "text/plain;charset=utf-8"
        else if contains -- "text/plain" $mime_list
            set saved_clip_mime "text/plain"
        else if contains -- "UTF8_STRING" $mime_list
            set saved_clip_mime "UTF8_STRING"
        else if contains -- "image/png" $mime_list
            set saved_clip_mime "image/png"
        end
    end

    if test -n "$saved_clip_mime"
        set saved_clip_file (mktemp -t inir-clipboard.XXXXXX 2>/dev/null)
        if test -n "$saved_clip_file"
            $wlpaste_bin --type "$saved_clip_mime" > "$saved_clip_file" 2>/dev/null || begin
                set saved_clip_mime ""
                rm -f "$saved_clip_file" 2>/dev/null
                set saved_clip_file ""
            end
        else
            set saved_clip_mime ""
        end
    end
end

# Get all window IDs from Niri
set -l all_windows ($niri_bin msg -j windows 2>/dev/null | $jq_bin -r '.[].id')

if test -z "$all_windows"
    exit 0
end

# Determine which windows to capture
set -l windows_to_capture

if test "$capture_all" = true; or test (count $ids_to_capture) -eq 0
    set windows_to_capture $all_windows
else
    for id in $ids_to_capture
        if contains $id $all_windows
            set -a windows_to_capture $id
        end
    end
end

if test (count $windows_to_capture) -eq 0
    exit 0
end

# Get the current highest cliphist ID BEFORE capturing
set -l before_id 0
set -l first_entry ($cliphist_bin list 2>/dev/null | $head_bin -1)
if test -n "$first_entry"
    set before_id (string split \t $first_entry)[1]
end

# Capture windows (limit concurrency)
set -l max_concurrent 4
set -l count 0

for id in $windows_to_capture
    set -l path "$preview_dir/window-$id.png"
    $niri_bin msg action screenshot-window --id $id --path $path 2>/dev/null &
    
    set count (math $count + 1)
    if test $count -ge $max_concurrent
        wait
        set count 0
    end
end

wait

# Cleanup ALL new clipboard entries from screenshots
# Short delay — QML side does a second clipboard restore 1.5s after script exits
sleep 0.2

set -l max_cleanup 100
set -l cleanup_count 0

while test $cleanup_count -lt $max_cleanup
    set -l entry ($cliphist_bin list 2>/dev/null | $head_bin -1)
    if test -z "$entry"
        break
    end
    
    set -l entry_id (string split \t $entry)[1]
    if test -n "$entry_id"; and test "$entry_id" -gt "$before_id"
        echo $entry | $cliphist_bin delete 2>/dev/null
        set cleanup_count (math $cleanup_count + 1)
    else
        break
    end
end

# Second cleanup pass — catch any entries that arrived after first pass
sleep 0.15
set -l cleanup_count2 0
while test $cleanup_count2 -lt 50
    set -l entry ($cliphist_bin list 2>/dev/null | $head_bin -1)
    if test -z "$entry"
        break
    end
    set -l entry_id (string split \t $entry)[1]
    if test -n "$entry_id"; and test "$entry_id" -gt "$before_id"
        echo $entry | $cliphist_bin delete 2>/dev/null
        set cleanup_count2 (math $cleanup_count2 + 1)
    else
        break
    end
end

# Restore clipboard AFTER cleanup so screenshot-window side effects never persist.
if test -n "$saved_clip_mime"; and test -n "$saved_clip_file"; and test -x $wlcopy_bin
    $wlcopy_bin --type "$saved_clip_mime" < "$saved_clip_file" 2>/dev/null || true
end
rm -f "$saved_clip_file" 2>/dev/null || true

set -l missing 0
for id in $windows_to_capture
    set -l path "$preview_dir/window-$id.png"
    if not test -s "$path"
        echo "[capture-windows] missing output file: $path" 1>&2
        set missing 1
    end
end

if test $missing -ne 0
    exit 1
end
