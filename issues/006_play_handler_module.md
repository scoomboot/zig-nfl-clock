# Issue #006: Implement Play Handler Module

## Summary
Create the play outcome processing module that updates clock state based on different play results.

## Description
Implement the logic that processes various play outcomes and their effects on both game clock and play clock. This module bridges between play results and clock behavior, automatically applying NFL rules for each play type.

## Acceptance Criteria
- [ ] Implement main handler:
  - [ ] `handlePlayOutcome(outcome: PlayOutcome, context: PlayContext)` - Process play result
- [ ] Handle run plays:
  - [ ] Clock continues running (normal situations)
  - [ ] Clock stops if out of bounds
  - [ ] Clock stops if first down inside 2 minutes
- [ ] Handle pass plays:
  - [ ] Complete pass: Clock runs (unless out of bounds)
  - [ ] Incomplete pass: Clock stops
  - [ ] Sack: Treated as run play
- [ ] Handle kicks:
  - [ ] Field goal: Clock stops after score
  - [ ] Punt: Clock runs after fair catch
  - [ ] Kickoff: Clock starts on first touch
- [ ] Handle special plays:
  - [ ] Touchdown: Clock stops, reset play clock
  - [ ] Safety: Clock stops
  - [ ] Turnover: Context-dependent
- [ ] Handle penalties:
  - [ ] Pre-snap: Clock remains in current state
  - [ ] Live-ball: Clock stops
  - [ ] Dead-ball: Clock remains stopped
- [ ] Implement play clock management:
  - [ ] Reset after each play
  - [ ] Start/stop based on ready-for-play
  - [ ] Handle delay of game
- [ ] Automatic state updates:
  - [ ] Update quarter if time expires
  - [ ] Trigger two-minute warning if applicable
  - [ ] Apply ten-second runoff if required

## Dependencies
- [#003](003_extract_gameclock_struct.md): GameClock struct must be defined
- [#005](005_rules_engine_module.md): Rules engine for clock decisions

## Implementation Notes
- Create `lib/game_clock/utils/play_handler/play_handler.zig`
- Define PlayContext struct for additional play information
- Use rules engine for clock stopping decisions
- Maintain clear separation between play logic and clock logic
- Consider creating PlayResult struct for return values

## Testing Requirements
- Test each play type with various contexts
- Verify clock behavior inside/outside two minutes
- Test play clock reset scenarios
- Validate penalty handling
- Test edge cases (quarter end during play, etc.)
- Create scenario-based integration tests

## Source Reference
- Original file: `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Focus on: handlePlayOutcome, processPlayResult, and related functions

## Estimated Time
2 hours

## Priority
🔴 Critical - Required for game simulation

## Category
Module Decomposition

---
*Created: 2025-08-17*
*Status: Not Started*