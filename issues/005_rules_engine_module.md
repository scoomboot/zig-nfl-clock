# Issue #005: Implement Rules Engine Module

## Summary
Create the NFL rules engine that determines when the clock should stop, start, and handle special situations.

## Description
Implement comprehensive NFL clock rules including automatic stopping conditions, two-minute warning, ten-second runoffs, and play clock management. This module encapsulates all game rule logic that affects clock behavior.

## Acceptance Criteria
- [ ] Implement clock stopping rules:
  - [ ] `shouldStopClock(reason: ClockStoppingReason)` - Determine if clock stops
  - [ ] Incomplete pass stops clock
  - [ ] Out of bounds stops clock (with exceptions)
  - [ ] Score stops clock
  - [ ] Penalty stops clock (context-dependent)
  - [ ] Timeout stops clock
  - [ ] Two-minute warning stops clock
  - [ ] Quarter end stops clock
- [ ] Implement two-minute warning:
  - [ ] `checkTwoMinuteWarning()` - Detect 2:00 mark
  - [ ] `handleTwoMinuteWarning()` - Process warning
  - [ ] Track per-half warnings (only once per half)
- [ ] Implement ten-second runoff:
  - [ ] `shouldApplyTenSecondRunoff(situation)` - Determine if applicable
  - [ ] `applyTenSecondRunoff()` - Deduct 10 seconds
  - [ ] Handle game-ending runoffs
- [ ] Implement play clock rules:
  - [ ] `getPlayClockDuration(situation)` - Return 40 or 25 seconds
  - [ ] After timeout: 25 seconds
  - [ ] After penalty: Context-dependent
  - [ ] After score: 40 seconds
  - [ ] Normal play: 40 seconds
- [ ] Implement special situations:
  - [ ] Inside two minutes rules
  - [ ] Clock restart after out of bounds
  - [ ] Injury timeout handling

## Dependencies
- [#003](003_extract_gameclock_struct.md): GameClock struct must be defined

## Implementation Notes
- Consider creating `lib/game_clock/utils/rules_engine/rules_engine.zig`
- Use clear function names that express intent
- Document each rule with NFL rulebook references where applicable
- Create RulesContext struct if needed for complex decisions

## Testing Requirements
- Test each stopping condition individually
- Test two-minute warning triggers exactly once per half
- Verify ten-second runoff scenarios
- Test play clock duration for all situations
- Validate inside-two-minutes special rules
- Create comprehensive test cases for edge conditions

## Source Reference
- Original file: `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Focus on: handleClockStoppingReason, checkTwoMinuteWarning, determinePlayClockDuration

## Estimated Time
2-3 hours

## Priority
🔴 Critical - Essential for accurate NFL timing

## Category
Module Decomposition

---
*Created: 2025-08-17*
*Status: Not Started*