#!/usr/bin/env python3
"""Fix repository URLs in file headers to match actual project location."""

import os
import re
from pathlib import Path

def fix_repo_urls(content):
    """Fix repository URLs in file headers."""
    lines = content.split('\n')
    modified = False
    
    for i, line in enumerate(lines):
        # Fix repo URL
        if line.startswith('// repo   : '):
            new_line = '// repo   : https://github.com/fisty/zig-nfl-clock'
            if line != new_line:
                lines[i] = new_line
                modified = True
        
        # Fix docs URL
        elif line.startswith('// docs   : '):
            # Extract the path part after the domain
            match = re.search(r'// docs   : https://[^/]+/(.*)', line)
            if match:
                path = match.group(1)
                # Update to use correct domain
                new_line = f'// docs   : https://fisty.github.io/zig-nfl-clock/{path}'
                if line != new_line:
                    lines[i] = new_line
                    modified = True
        
        # Fix author URL if needed
        elif line.startswith('// author : '):
            # Keep existing author URLs as they are
            pass
    
    return '\n'.join(lines), modified

def process_file(filepath):
    """Process a single .zig file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        fixed_content, modified = fix_repo_urls(content)
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"✓ Fixed URLs in: {filepath}")
            return True
        else:
            print(f"  No URL changes needed: {filepath}")
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
    print(f"Summary: Fixed URLs in {modified_count}/{len(zig_files)} files")

if __name__ == "__main__":
    main()