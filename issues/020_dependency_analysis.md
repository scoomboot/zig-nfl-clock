# Issue #020: Analyze and remove dependencies

## Summary
Identify and eliminate unnecessary dependencies to create a lean, standalone library.

## Description
Perform a comprehensive analysis of all dependencies in the extracted code. Remove simulation-specific dependencies, minimize standard library usage where appropriate, and ensure the library has zero external dependencies beyond Zig's standard library.

## Acceptance Criteria
- [ ] Analyze current dependencies:
  - [ ] List all imports from original code
  - [ ] Categorize as essential/optional/removable
  - [ ] Document why each is needed
- [ ] Remove simulation dependencies:
  - [ ] Event system dependencies
  - [ ] UI/rendering dependencies
  - [ ] Network/API dependencies
  - [ ] Database/persistence dependencies
- [ ] Minimize std library usage:
  - [ ] Use only necessary std modules
  - [ ] Avoid heavy std features if possible
  - [ ] Document each std import usage
- [ ] Verify zero external dependencies:
  - [ ] No third-party libraries
  - [ ] No system library requirements
  - [ ] No build-time dependencies
- [ ] Create dependency documentation:
  ```zig
  // Dependencies:
  // - std.Thread.Mutex: Thread safety
  // - std.time: Time operations
  // - std.fmt: String formatting
  // - std.testing: Test framework (dev only)
  ```
- [ ] Optimize imports:
  - [ ] Use specific imports vs entire modules
  - [ ] Group related imports
  - [ ] Remove unused imports

## Dependencies
- [#002](002_extract_core_types.md): Initial extraction complete

## Implementation Notes
Dependency analysis process:
1. **Inventory**: List all current imports
2. **Classify**: Essential vs removable
3. **Replace**: Find alternatives for removable deps
4. **Remove**: Eliminate unnecessary code
5. **Verify**: Ensure functionality preserved

Common removals from game engine:
```zig
// REMOVE: Simulation-specific
const EventSystem = @import("../events/event_system.zig");
const GameState = @import("../game/game_state.zig");
const NetworkSync = @import("../network/sync.zig");

// KEEP: Essential for library
const std = @import("std");
const Mutex = std.Thread.Mutex;
```

Replacement strategies:
- Event system → Direct function calls
- Allocators → Stack allocation where possible
- Complex data structures → Simple arrays/structs
- External config → Compile-time config

Minimal std usage:
```zig
// Only what we need
const std = @import("std");
const testing = std.testing;  // Dev only
const fmt = std.fmt;          // Formatting
const time = std.time;        // Time ops
const Thread = std.Thread;    // Mutex only
```

## Testing Requirements
- Verify all functionality works post-removal
- Check no runtime dependencies exist
- Test builds on multiple platforms
- Ensure no performance degradation
- Validate thread safety maintained

## Source Reference
- Original imports in `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Focus on removing game-specific dependencies

## Estimated Time
1.5 hours

## Priority
🔴 Critical - Library independence

## Category
Migration & Cleanup

---
*Created: 2025-08-17*
*Status: Not Started*