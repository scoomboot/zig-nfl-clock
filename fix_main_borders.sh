#!/bin/bash

# Fix main section closing borders to be exactly 88 characters
# The correct format is: // ╚ + 84 '═' + ╝ = 88 chars total

echo "Fixing main section closing borders to be exactly 88 characters..."

# Find all .zig files and fix the closing borders
find /home/fisty/code/zig-nfl-clock -name "*.zig" -type f | while read -r file; do
    # Create temp file
    temp_file="${file}.tmp"
    
    # Process the file
    sed 's/^\/\/ ╚═*╝$/\/\/ ╚════════════════════════════════════════════════════════════════════════════════╝/' "$file" > "$temp_file"
    
    # Check if changes were made
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        echo "Fixed: $file"
    else
        rm "$temp_file"
    fi
done

echo "Main section borders fixed!"