# Issue #003: Extract GameClock struct

## Summary
Extract the core GameClock struct with its essential fields and initialization logic.

## Description
Extract the main GameClock struct from the nfl-sim implementation, adapting it for library use. Remove simulation-specific fields and methods while preserving core clock functionality. Implement proper initialization with sensible defaults.

## Acceptance Criteria
- [ ] Extract GameClock struct with essential fields:
  - [ ] `game_seconds: u32` - Total elapsed game time
  - [ ] `play_clock_seconds: u32` - Current play clock time
  - [ ] `quarter: Quarter` - Current quarter
  - [ ] `clock_state: ClockState` - Running/stopped status
  - [ ] `play_clock_state: PlayClockState` - Play clock status
  - [ ] `play_clock_duration: PlayClockDuration` - 40 or 25 seconds
  - [ ] `clock_speed: ClockSpeed` - Simulation speed
  - [ ] `two_minute_warning_given: [4]bool` - Per-half tracking
  - [ ] `mutex: std.Thread.Mutex` - Thread safety
- [ ] Implement `init()` function with defaults:
  - [ ] Start at Q1, 15:00
  - [ ] Clock stopped
  - [ ] Play clock inactive
  - [ ] Real-time speed
- [ ] Implement `deinit()` for cleanup
- [ ] Add basic getters:
  - [ ] `getGameTime()` - Returns current game time
  - [ ] `getQuarter()` - Returns current quarter
  - [ ] `getPlayClock()` - Returns play clock value
- [ ] Apply MCS formatting to struct definition

## Dependencies
- [#001](001_create_directory_structure.md): Directory structure must exist
- [#002](002_extract_core_types.md): Core types must be defined

## Implementation Notes
- Place in `lib/game_clock/game_clock.zig`
- Use `pub const GameClock = struct { ... }` format
- Initialize mutex properly in init()
- Consider using default field values where appropriate
- Remove any fields specific to simulation (e.g., event handlers, UI state)

## Testing Requirements
- Test initialization creates valid default state
- Verify all getters return expected values
- Test thread safety with mutex
- Ensure struct size is reasonable

## Source Reference
- Original file: `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Focus on GameClock struct definition and init function

## Estimated Time
1.5 hours

## Priority
🔴 Critical - Core component required by all modules

## Category
Core Extraction

---
*Created: 2025-08-17*
*Status: Not Started*