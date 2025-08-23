#!/usr/bin/env python3
"""Fix test naming to use PascalCase for components as per MCS guidelines."""

import os
import re
from pathlib import Path

def pascalize(snake_case):
    """Convert snake_case to PascalCase."""
    # Special cases for compound words
    special_cases = {
        'game_clock': 'GameClock',
        'time_formatter': 'TimeFormatter',
        'rules_engine': 'RulesEngine',
        'play_handler': 'PlayHandler',
        'config': 'Config',
    }
    
    if snake_case in special_cases:
        return special_cases[snake_case]
    
    # General conversion
    parts = snake_case.split('_')
    return ''.join(part.capitalize() for part in parts)

def fix_test_names(content):
    """Fix test naming conventions in content."""
    lines = content.split('\n')
    modified = False
    
    for i, line in enumerate(lines):
        # Match test declarations with category, component, and description
        # Pattern: test "category: component_name: description"
        match = re.match(r'^(\s*)test\s+"([^:]+):\s+([a-z_]+):\s+(.+)"', line)
        if match:
            indent, category, component, description = match.groups()
            # Convert component to PascalCase
            pascal_component = pascalize(component)
            if pascal_component != component:
                new_line = f'{indent}test "{category}: {pascal_component}: {description}"'
                lines[i] = new_line
                modified = True
                print(f"  Fixed test: {component} → {pascal_component}")
    
    return '\n'.join(lines), modified

def process_file(filepath):
    """Process a single .zig file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        fixed_content, modified = fix_test_names(content)
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"✓ Fixed test names in: {filepath}")
            return True
        else:
            print(f"  No test name changes needed: {filepath}")
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
    print(f"Summary: Fixed test names in {modified_count}/{len(zig_files)} files")

if __name__ == "__main__":
    main()