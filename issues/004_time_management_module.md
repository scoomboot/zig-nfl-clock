# Issue #004: Implement Time Management Module

## Summary
Create the core time management functionality for clock operations including start, stop, tick, and time calculations.

## Description
Extract and organize all time-related operations into a cohesive module. This includes basic clock control, time advancement, and quarter/half/game progression logic. The module should handle both game clock and play clock synchronization.

## Acceptance Criteria
- [ ] Implement core time operations:
  - [ ] `start()` - Start the game clock
  - [ ] `stop()` - Stop the game clock
  - [ ] `tick()` - Advance clock by one tick based on speed
  - [ ] `reset()` - Reset to beginning of current quarter
- [ ] Implement time getters:
  - [ ] `getMinutes()` - Get minutes remaining in quarter
  - [ ] `getSeconds()` - Get seconds remaining in quarter
  - [ ] `getTotalSeconds()` - Get total game seconds elapsed
  - [ ] `getFormattedTime()` - Return "MM:SS" format
- [ ] Implement quarter management:
  - [ ] `isQuarterEnd()` - Check if quarter has ended
  - [ ] `isHalfEnd()` - Check if half has ended
  - [ ] `isGameEnd()` - Check if game has ended
  - [ ] `advanceToNextQuarter()` - Move to next quarter
- [ ] Implement clock speed control:
  - [ ] `setSpeed(speed: ClockSpeed)` - Change simulation speed
  - [ ] `pause()` - Pause the clock
  - [ ] `resume()` - Resume at previous speed
- [ ] Handle tick intervals based on speed:
  - [ ] Real-time: 1 second per tick
  - [ ] Fast speeds: Proportional advancement

## Dependencies
- [#003](003_extract_gameclock_struct.md): GameClock struct must be defined

## Implementation Notes
- Create methods on GameClock struct
- Use mutex for thread-safe operations
- Consider extracting to `lib/game_clock/utils/time_manager/` if complex
- Ensure tick() respects current clock speed
- Handle edge cases (negative time, overflow)

## Testing Requirements
- Test all state transitions
- Verify time calculations are accurate
- Test quarter/half/game end detection
- Validate clock speed affects tick rate
- Test thread safety with concurrent operations

## Source Reference
- Original file: `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Focus on methods: start, stop, tick, getMinutes, getSeconds, advanceQuarter

## Estimated Time
2 hours

## Priority
🔴 Critical - Core functionality

## Category
Module Decomposition

---
*Created: 2025-08-17*
*Status: Not Started*