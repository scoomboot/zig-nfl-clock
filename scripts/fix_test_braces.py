#!/usr/bin/env python3
"""Fix missing opening braces in test declarations."""

import os
import re
from pathlib import Path

def fix_test_braces(content):
    """Fix test declarations missing opening braces."""
    lines = content.split('\n')
    modified = False
    
    for i, line in enumerate(lines):
        # Match test declaration without opening brace
        if re.match(r'^(\s*)test\s+"[^"]+"\s*$', line):
            # Add opening brace
            lines[i] = line + ' {'
            modified = True
            print(f"  Fixed test declaration: {line.strip()}")
    
    return '\n'.join(lines), modified

def process_file(filepath):
    """Process a single .zig file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        fixed_content, modified = fix_test_braces(content)
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"✓ Fixed test braces in: {filepath}")
            return True
        else:
            print(f"  No brace fixes needed: {filepath}")
            return False
    except Exception as e:
        print(f"✗ Error processing {filepath}: {e}")
        return False

def main():
    """Main function to process all .zig files."""
    project_root = Path("/home/fisty/code/zig-nfl-clock")
    zig_files = []
    
    # Find all .zig files
    for root, dirs, files in os.walk(project_root):
        # Skip build directories
        if '.zig-cache' in root or 'zig-out' in root:
            continue
        for file in files:
            if file.endswith('.zig'):
                zig_files.append(os.path.join(root, file))
    
    print(f"Found {len(zig_files)} .zig files to process\n")
    
    modified_count = 0
    for filepath in sorted(zig_files):
        if process_file(filepath):
            modified_count += 1
    
    print(f"\n{'='*50}")
    print(f"Summary: Fixed test braces in {modified_count}/{len(zig_files)} files")

if __name__ == "__main__":
    main()