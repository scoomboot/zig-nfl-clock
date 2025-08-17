# Issue #024: Update build configuration for game_clock library

## Summary
Update the existing build configuration and lib.zig to properly expose the NFL game clock library.

## Description
The project has a build.zig file but it references lib/lib.zig which currently only exports an example module. We need to update lib/lib.zig to export the game_clock module and ensure the build configuration properly compiles and tests all components.

## Acceptance Criteria
- [ ] Update `lib/lib.zig` to export game_clock module
- [ ] Remove example module export
- [ ] Add test imports for all game_clock test files
- [ ] Verify build compiles the library successfully
- [ ] Ensure test step runs all game_clock tests
- [ ] Module should be importable as `@import("nflClock")`

## Dependencies
- [#023](023_fix_test_file_naming.md): Test files must have correct names

## Implementation Notes
Update lib/lib.zig to:
1. Export the game_clock module instead of example
2. Include all test files in the test block

Example lib/lib.zig structure:
```zig
// lib.zig — Central entry point for NFL Clock library.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    /// NFL game clock management library
    pub const game_clock = @import("./game_clock.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test {
        _ = @import("./game_clock.zig");
        _ = @import("./game_clock/game_clock.test.zig");
        _ = @import("./game_clock/utils/time_formatter/time_formatter.test.zig");
        _ = @import("./game_clock/utils/rules_engine/rules_engine.test.zig");
        _ = @import("./game_clock/utils/play_handler/play_handler.test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════╝
```

The existing build.zig already:
- Creates a module named "nflClock"
- Points to lib/lib.zig as root
- Has test step configured
- No changes needed to build.zig itself

## Testing Requirements
- Verify `zig build` completes successfully
- Verify `zig build test` runs all tests
- Test importing the library in a sample project
- Verify cross-compilation works

## Estimated Time
30 minutes

## Priority
🔴 Critical - Required for library usage

## Category
Build System

---
*Created: 2025-08-17*
*Status: Not Started*