#!/usr/bin/env fish
# Quick QML syntax check for recently modified files
# Used by Kiro agent postToolUse hook

set -l project_root (dirname (status filename))/..
set -l errors 0

# Find QML files modified in last 5 minutes
set -l recent_files (find $project_root -name "*.qml" -mmin -5 2>/dev/null | head -10)

if test (count $recent_files) -eq 0
    exit 0
end

for file in $recent_files
    # Basic syntax checks
    set -l basename (basename $file)
    
    # Check for common issues
    if grep -qE 'Config\.options\.[a-zA-Z]+\.[a-zA-Z]+[^?]' $file 2>/dev/null
        if not grep -qE 'Config\.options\?\.' $file 2>/dev/null
            echo "⚠️  $basename: Config access may need optional chaining (?.)"
            set errors (math $errors + 1)
        end
    end
    
    # Check for hardcoded colors
    if grep -qE 'color:\s*"#[0-9a-fA-F]{6}"' $file 2>/dev/null
        echo "⚠️  $basename: Hardcoded color found - use Appearance.colors.*"
        set errors (math $errors + 1)
    end
    
    # Check for IPC functions without return type
    if grep -qE 'function\s+\w+\([^)]*\)\s*\{' $file 2>/dev/null
        if grep -qE 'IpcHandler' $file 2>/dev/null
            if not grep -qE 'function\s+\w+\([^)]*\):\s*\w+' $file 2>/dev/null
                echo "⚠️  $basename: IPC function may need return type annotation"
                set errors (math $errors + 1)
            end
        end
    end
end

if test $errors -gt 0
    echo "Found $errors potential issue(s) in recently modified files"
end

exit 0
