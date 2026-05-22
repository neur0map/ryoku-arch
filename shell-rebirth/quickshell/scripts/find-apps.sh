#!/bin/bash
# List desktop applications for the launcher
# from github.com/bgibson72/yahr-quickshell with modifications
# Blacklist - apps to hide (add desktop file basenames here)
BLACKLIST=(
    "xfce4-about.desktop"
    "avahi-discover.desktop"
    "bssh.desktop"
    "bvnc.desktop"
    "qv4l2.desktop"
    "qvidcap.desktop"
    "lstopo.desktop"
    "uuctl.desktop"
    "codium.desktop"          # Hide regular VSCodium (keep Wayland version)
    "xgps.desktop"            # Hide Xgps
    "xgpsspeed.desktop"       # Hide Xgpsspeed
)

# Whitelist - always include these desktop files
WHITELIST=(
    "wallpaper.desktop" 
    "theme.desktop"
    "powermenu.desktop"
)

# Search paths for .desktop files (local first so overrides work)
SEARCH_PATHS=(
    "$HOME/.local/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
    "/var/lib/flatpak/exports/share/applications"
    "/usr/local/share/applications"
    "/usr/share/applications"
)

# Function to find icon path
find_icon() {
    local icon_name="$1"
    local theme="Papirus"
    icon_name="${icon_name#theme://}"
    [[ "$icon_name" == /* ]] && { echo "$icon_name"; return; }

    local exts=(png svg xpm)
    local sizes=(16 22 24 32 48 64 128 256 512 scalable)
    local icon_bases=(
        "$HOME/.local/share/icons/$theme"
        "/usr/share/icons/$theme"
        "/usr/share/icons/hicolor"
        "/usr/share/pixmaps"
    )

    for base in "${icon_bases[@]}"; do
        for size in "${sizes[@]}"; do
            for ext in "${exts[@]}"; do
                for subdir in apps actions status devices places panel mimetypes; do
                    local candidate="$base/${size}x${size}/$subdir/$icon_name.$ext"
                    [[ -f "$candidate" ]] && { echo "$candidate"; return; }
                done
                local scalable="$base/scalable/apps/$icon_name.$ext"
                [[ -f "$scalable" ]] && { echo "$scalable"; return; }
            done
        done
    done

    for ext in "${exts[@]}"; do
        [[ -f "/usr/share/pixmaps/$icon_name.$ext" ]] && { echo "/usr/share/pixmaps/$icon_name.$ext"; return; }
    done

    echo "$icon_name"
}

# Collect all desktop files and process
declare -A seen_apps

for dir in "${SEARCH_PATHS[@]}"; do
    [ ! -d "$dir" ] && continue
    
    while IFS= read -r desktop_file; do
        basename_file=$(basename "$desktop_file")
        
        # Skip duplicates (local overrides system)
        [[ -n "${seen_apps[$basename_file]}" ]] && continue
        seen_apps[$basename_file]=1
        
        # Skip blacklisted unless whitelisted
        skip=0
        for blacklisted in "${BLACKLIST[@]}"; do
            [[ "$basename_file" == "$blacklisted" ]] && skip=1 && break
        done
        # Check whitelist override
        for whitelisted in "${WHITELIST[@]}"; do
            [[ "$basename_file" == "$whitelisted" ]] && skip=0 && break
        done
        [[ $skip -eq 1 ]] && continue
        
        # Skip if NoDisplay=true
        grep -q "^NoDisplay=true" "$desktop_file" 2>/dev/null && continue
        
        # Extract fields
        name=$(grep "^Name=" "$desktop_file" | head -1 | cut -d= -f2-)
        comment=$(grep "^Comment=" "$desktop_file" | head -1 | cut -d= -f2-)
        icon=$(grep "^Icon=" "$desktop_file" | head -1 | cut -d= -f2-)
        exec=$(grep "^Exec=" "$desktop_file" | head -1 | cut -d= -f2- | sed 's/%[uUfF]//g' | sed 's/%[cdnNvmki]//g')
        
        # Skip if no name or exec
        [ -z "$name" ] && continue
        [ -z "$exec" ] && continue
        
        # Default comment
        [ -z "$comment" ] && comment="Application"
        
        # Find icon
        icon_path=$(find_icon "$icon")
        
        # Output
        echo "$name|$comment|$icon_path|$exec"
        
    done < <(find -L "$dir" -name "*.desktop" -type f 2>/dev/null)
done | sort -u
