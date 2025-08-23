#!/usr/bin/env python3
"""Fix MCS section borders to be exactly 88 characters wide."""

import os
import re
import sys
from pathlib import Path

def fix_section_borders(content):
    """Fix all section borders to be exactly 88 characters wide."""
    lines = content.split('\n')
    modified = False
    
    for i, line in enumerate(lines):
        # Match main section borders
        if re.match(r'^// ╔═+\s+\w+\s+═+╗\s*$', line):
            # Extract the section name
            match = re.search(r'═+\s+(\w+)\s+═+', line)
            if match:
                section_name = match.group(1)
                # Calculate padding needed
                base_len = len("// ╔") + len(section_name) + len("╗") + 2  # 2 spaces around name
                padding_total = 88 - base_len
                padding_each = padding_total // 2
                
                # Create new border with exact width
                new_line = f"// ╔{'═' * padding_each} {section_name} {'═' * (padding_total - padding_each)}╗"
                if len(new_line) != 88:
                    # Adjust if needed due to odd number
                    diff = 88 - len(new_line)
                    new_line = f"// ╔{'═' * (padding_each + diff)} {section_name} {'═' * (padding_total - padding_each)}╗"
                
                if line != new_line:
                    lines[i] = new_line
                    modified = True
        
        # Match closing borders
        elif re.match(r'^// ╚═+╝\s*$', line):
            new_line = f"// ╚{'═' * 84}╝"
            if line != new_line:
                lines[i] = new_line
                modified = True
        
        # Match subsection borders (opening)
        elif re.match(r'^// ┌─+\s+\w+\s+─+┐\s*$', line):
            match = re.search(r'─+\s+(\w+)\s+─+', line)
            if match:
                section_name = match.group(1)
                base_len = len("// ┌") + len(section_name) + len("┐") + 2
                padding_total = 88 - base_len
                padding_each = padding_total // 2
                
                new_line = f"// ┌{'─' * padding_each} {section_name} {'─' * (padding_total - padding_each)}┐"
                if len(new_line) != 88:
                    diff = 88 - len(new_line)
                    new_line = f"// ┌{'─' * (padding_each + diff)} {section_name} {'─' * (padding_total - padding_each)}┐"
                
                if line != new_line:
                    lines[i] = new_line
                    modified = True
        
        # Match subsection borders (closing)
        elif re.match(r'^// └─+┘\s*$', line):
            new_line = f"// └{'─' * 84}┘"
            if line != new_line:
                lines[i] = new_line
                modified = True
    
    return '\n'.join(lines), modified

def process_file(filepath):
    """Process a single .zig file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        fixed_content, modified = fix_section_borders(content)
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"✓ Fixed borders in: {filepath}")
            return True
        else:
            print(f"  No changes needed: {filepath}")
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
    print(f"Summary: Fixed {modified_count}/{len(zig_files)} files")

if __name__ == "__main__":
    main()