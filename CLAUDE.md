# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
# Build the library
zig build

# Run all tests
zig build test

# Build with optimizations
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSmall
zig build -Doptimize=ReleaseSafe
```

## Project Architecture

This is an NFL game clock library written in Zig that manages game timing, play clock, and clock rules. The project follows the **Maysara Code Style (MCS)** guidelines strictly.

### Core Components

1. **GameClock** (`lib/game_clock/game_clock.zig`): Main clock implementation managing game time, quarters, play clock, and state transitions
2. **RulesEngine** (`lib/game_clock/utils/rules_engine/`): Enforces NFL timing rules for different game situations
3. **PlayHandler** (`lib/game_clock/utils/play_handler/`): Processes play outcomes and their effects on the clock
4. **TimeFormatter** (`lib/game_clock/utils/time_formatter/`): Formats time displays for different contexts

### Module Structure

```
lib/
├── game_clock.zig                    # Public API entry point
└── game_clock/
    ├── game_clock.zig                # Core implementation
    ├── game_clock.test.zig           # Core tests
    └── utils/
        ├── rules_engine/
        │   ├── rules_engine.zig      # NFL timing rules
        │   └── rules_engine.test.zig
        ├── play_handler/
        │   ├── play_handler.zig      # Play outcome processing
        │   └── play_handler.test.zig
        └── time_formatter/
            ├── time_formatter.zig    # Time formatting utilities
            └── time_formatter.test.zig
```

## Critical Style Requirements (MCS)

### File Structure
Every `.zig` file MUST follow this exact structure:

```zig
// filename.zig — Brief description
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/path
// author : https://github.com/maysara-elshewehy
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    // Other imports, indented by 4 spaces

// ╚══════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Main implementation code, indented by 4 spaces

// ╚══════════════════════════════════════════════════════════════════════════════════╝
```

### Section Indentation
**CRITICAL**: All code within sections MUST be indented by exactly 4 spaces from the section borders.

### Function Documentation
All public functions require doc comments:

```zig
/// Brief description of the function.
///
/// Detailed explanation if needed.
///
/// __Parameters__
///
/// - `param`: Description
///
/// __Return__
///
/// - Description of return value
pub fn functionName() void {
    // Implementation
}
```

### Test Naming Convention
Tests MUST follow this exact format:

```zig
test "<category>: <component>: <description>" {
    // Test implementation
}
```

Categories: `unit`, `integration`, `e2e`, `performance`, `stress`

Example:
```zig
test "unit: GameClock: initializes with default values" {
    // Test code
}
```

## Testing Philosophy

- Every function must have comprehensive tests
- Test both positive and negative cases
- Include edge case testing
- Use `std.testing.allocator` for memory-safe tests with proper cleanup

## Common Issues and Solutions

### Issue Tracking
The `issues/` directory contains detailed issue descriptions and resolution plans. Check existing issues before implementing changes.

### MCS Compliance
Run `scripts/apply_mcs_fixes.py` to help ensure MCS compliance for file headers and basic structure.

## Key Dependencies

- Zig version: 0.14.1+ (minimum)
- No external dependencies (pure Zig implementation)

## Important Notes

1. **Never modify section borders** - They are exactly 88 characters wide
2. **Always maintain 4-space indentation** within sections
3. **Follow test naming conventions** strictly for automated test analysis
4. **Check MCS.md** for complete style guidelines
5. **Review TESTING_CONVENTIONS.md** for test categorization rules