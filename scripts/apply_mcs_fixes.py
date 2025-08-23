#!/usr/bin/env python3
"""Apply MCS compliance fixes to remaining Zig files."""

import re
import sys
from pathlib import Path

def get_mcs_header(filename: str, description: str, path: str) -> str:
    """Generate MCS-compliant file header."""
    return f"""// {filename} — {description}
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/{path}
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom."""

def apply_mcs_fixes(file_path: Path) -> None:
    """Apply MCS compliance fixes to a Zig file."""
    
    content = file_path.read_text()
    filename = file_path.name
    
    # Determine file type and description
    if "test" in filename:
        if "rules_engine" in filename:
            description = "Tests for NFL game clock rules engine"
        elif "play_handler" in filename:
            description = "Tests for play outcome processing"
        else:
            description = "Test file"
    else:
        if "rules_engine" in filename:
            description = "NFL game clock rules engine"
        elif "play_handler" in filename:
            description = "Play outcome processing for game clock"
        else:
            description = "Implementation file"
    
    # Get relative path for docs
    rel_path = str(file_path).replace("/home/fisty/code/zig-nfl-clock/", "")
    
    # Generate new header
    new_header = get_mcs_header(filename, description, rel_path)
    
    # Remove old header (first 5-6 lines with ===)
    lines = content.split('\n')
    start_idx = 0
    for i, line in enumerate(lines[:10]):
        if line.strip() and not line.startswith('//'):
            start_idx = i
            break
    
    # Keep imports and rest of file
    remaining_content = '\n'.join(lines[start_idx:])
    
    # Fix section borders
    remaining_content = re.sub(
        r'// =+\n//  PACK\n// =+',
        '// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗',
        remaining_content
    )
    
    remaining_content = re.sub(
        r'// =+\n//  INIT\n// =+',
        '// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗',
        remaining_content
    )
    
    remaining_content = re.sub(
        r'// =+\n//  CORE\n// =+',
        '// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗',
        remaining_content
    )
    
    remaining_content = re.sub(
        r'// =+\n//  TEST.*?\n// =+',
        '// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗',
        remaining_content
    )
    
    remaining_content = re.sub(
        r'// =+\n//  TYPES\n// =+',
        '// ╔══════════════════════════════════════ TYPES ══════════════════════════════════════╗',
        remaining_content
    )
    
    # Add section closers before next section or at end
    sections = ['PACK', 'INIT', 'CORE', 'TEST', 'TYPES']
    lines = remaining_content.split('\n')
    new_lines = []
    in_section = None
    
    for i, line in enumerate(lines):
        # Check if we're starting a new section
        for section in sections:
            if f'══════════════════════════════════════ {section} ═══' in line:
                # Close previous section if exists
                if in_section and i > 0:
                    new_lines.append('')
                    new_lines.append('// ╚══════════════════════════════════════════════════════════════════════════════════════════╝')
                    new_lines.append('')
                in_section = section
                break
        
        new_lines.append(line)
        
        # Add indentation to content within sections
        if in_section and not line.startswith('//') and line.strip():
            # This line should be indented
            if not line.startswith('    ') and not line.startswith('test '):
                # Add 4-space indent
                new_lines[-1] = '    ' + line.lstrip()
    
    # Close last section
    if in_section:
        new_lines.append('')
        new_lines.append('// ╚══════════════════════════════════════════════════════════════════════════════════════════╝')
    
    # Fix test indentation specifically
    final_lines = []
    for line in new_lines:
        if line.strip().startswith('test "'):
            # Ensure test declarations are indented
            final_lines.append('    ' + line.lstrip())
        else:
            final_lines.append(line)
    
    # Combine header with fixed content
    final_content = new_header + '\n\n' + '\n'.join(final_lines)
    
    # Write back
    file_path.write_text(final_content)
    print(f"Fixed: {file_path}")

def main():
    """Main entry point."""
    files_to_fix = [
        Path("/home/fisty/code/zig-nfl-clock/lib/game_clock/utils/rules_engine/rules_engine.test.zig"),
        Path("/home/fisty/code/zig-nfl-clock/lib/game_clock/utils/play_handler/play_handler.zig"),
        Path("/home/fisty/code/zig-nfl-clock/lib/game_clock/utils/play_handler/play_handler.test.zig"),
    ]
    
    for file_path in files_to_fix:
        if file_path.exists():
            apply_mcs_fixes(file_path)
        else:
            print(f"File not found: {file_path}")
    
    print("\nMCS compliance fixes applied successfully!")

if __name__ == "__main__":
    main()