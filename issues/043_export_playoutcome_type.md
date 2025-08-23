# Issue #043: Export PlayOutcome type from main module

## Summary
The `PlayOutcome` type is not exported from the main library module, preventing external code from using it for play processing operations.

## Description
The `PlayOutcome` enum is defined in `lib/game_clock/utils/rules_engine/rules_engine.zig` and is used internally for play processing logic. However, it is not re-exported from the main `lib/game_clock.zig` module, making it inaccessible to library users and external code such as benchmarks.

This limits the ability to:
- Create play outcome structures for testing
- Benchmark play processing operations  
- Use the full play processing API from external code

## Current State
```zig
// In rules_engine.zig - type is defined
pub const PlayOutcome = enum {
    incomplete_pass,
    complete_pass_inbounds,
    complete_pass_out_of_bounds,
    run_inbounds,
    run_out_of_bounds,
    // ... etc
};

// In game_clock.zig - internal import only
const PlayOutcome = @import("utils/rules_engine/rules_engine.zig").PlayOutcome;

// NOT exported in lib/game_clock.zig main module
// Missing: pub const PlayOutcome = ...
```

## Impact
- External code cannot create `PlayOutcome` values
- Benchmarks cannot properly test play processing performance
- Library API is incomplete for play processing features
- Tests in other modules (like config_e2e.test.zig) expect this type to be available

## Acceptance Criteria
- [ ] Add PlayOutcome export to `lib/game_clock.zig`:
  ```zig
  pub const PlayOutcome = @import("game_clock/game_clock.zig").PlayOutcome;
  ```
  Note: May need to trace through the import chain to get the correct path
- [ ] Verify external code can import and use PlayOutcome
- [ ] Update benchmarks to use PlayOutcome for play processing tests
- [ ] Ensure all existing tests still pass

## Implementation Notes
This is a simple one-line addition to the main module exports. The type is already public in its source file, it just needs to be re-exported through the proper chain:
1. rules_engine.zig exports PlayOutcome (already done)
2. game_clock.zig imports it internally (already done)  
3. game_clock.zig needs to export it publicly (missing)
4. lib/game_clock.zig needs to re-export from game_clock.zig (missing)

## Testing Requirements
- Verify PlayOutcome can be imported from the main module
- Test that all enum values are accessible
- Ensure benchmarks can create and use PlayOutcome values
- Confirm no breaking changes to existing code

## Estimated Time
15 minutes

## Priority
🟡 Medium - Improves API completeness and enables proper benchmarking

## Category
API Enhancement

## Resolution Summary
**Status: Resolved** ✅

**Changes Made:**
1. Added public export of `PlayOutcome` in `lib/game_clock/game_clock.zig` (line 508)
2. Re-exported `PlayOutcome` from main library module `lib/game_clock.zig` (line 48)
3. Added `PlayOutcome` to library exports test for verification (line 120)
4. Removed duplicate private import to avoid compilation errors

**Implementation Details:**
- The `PlayOutcome` enum was already defined as public in `rules_engine.zig`
- It was being imported privately in `game_clock.zig` but not exported
- Following the existing pattern used for other utility types (PlayType, PlayResult, etc.)
- All tests pass successfully after the changes

**Files Modified:**
- `/home/fisty/code/zig-nfl-clock/lib/game_clock/game_clock.zig` - Added public export
- `/home/fisty/code/zig-nfl-clock/lib/game_clock.zig` - Added re-export from main module

The PlayOutcome type is now fully accessible to external code, benchmarks, and tests as required.

---
*Created: 2025-08-23*
*Status: Resolved*
*Resolved: 2025-08-23*
*Discovered during: Benchmark implementation session*