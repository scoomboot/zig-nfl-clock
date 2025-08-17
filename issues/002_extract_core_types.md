# Issue #002: Extract core types and enums

## Summary
Extract and adapt all core type definitions and enums from the nfl-sim game clock implementation.

## Description
Identify and extract all fundamental types, enums, and constants from `/home/fisty/code/nfl-sim/src/game_clock.zig`. These types form the foundation for the library's API and must be carefully selected to avoid simulation-specific dependencies.

## Acceptance Criteria
- [ ] Extract Quarter enum (Q1, Q2, Q3, Q4, Overtime)
- [ ] Extract ClockState enum (Stopped, Running, Expired)
- [ ] Extract PlayClockState enum (Active, Inactive, Warning)
- [ ] Extract PlayClockDuration enum (Normal40, Short25)
- [ ] Extract ClockStoppingReason enum with all NFL rules
- [ ] Extract ClockSpeed enum (Paused, RealTime, Fast2x, Fast10x, Fast30x, Fast60x)
- [ ] Extract PlayType enum (relevant clock-affecting plays)
- [ ] Extract PlayOutcome enum (clock-relevant outcomes)
- [ ] Define time-related constants:
  - [ ] QUARTER_LENGTH_SECONDS (900)
  - [ ] PLAY_CLOCK_NORMAL (40)
  - [ ] PLAY_CLOCK_SHORT (25)
  - [ ] TWO_MINUTE_WARNING (120)
  - [ ] TEN_SECOND_RUNOFF (10)
- [ ] Remove any simulation-specific types
- [ ] Add documentation for each type

## Dependencies
- [#001](001_create_directory_structure.md): Directory structure must exist

## Implementation Notes
- Place core types in `lib/game_clock/game_clock.zig`
- Use `pub const` for all exported types
- Follow MCS naming conventions (PascalCase for types, SCREAMING_SNAKE_CASE for constants)
- Consider creating a separate `types.zig` if the list becomes extensive
- Ensure all enums have explicit integer values where applicable

## Testing Requirements
- Verify all enum values are accessible
- Test enum conversions if applicable
- Ensure constants have correct values
- Validate no missing enum cases from original

## Source Reference
- Original file: `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Focus on lines containing type definitions and const declarations

## Estimated Time
1 hour

## Priority
🔴 Critical - Required by all other components

## Category
Core Extraction

---
*Created: 2025-08-17*
*Status: Not Started*