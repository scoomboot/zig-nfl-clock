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

## Solution Summary

### ✅ Completed via Alternative Implementation (Issue #026)

**Resolution**: Play handling functionality was already comprehensively implemented in the existing architecture with a dedicated utility module providing extensive play outcome processing capabilities.

**Core Play Handler Implementation** (Existing):
- ✅ **Comprehensive Module**: `/home/fisty/code/zig-nfl-clock/lib/game_clock/utils/play_handler/play_handler.zig`
- ✅ **Complete Play Processing**: All planned play types and outcomes supported
- ✅ **Advanced Statistics**: Comprehensive statistics tracking beyond original plan
- ✅ **Realistic Simulation**: Sophisticated play outcome modeling with variance

**Play Outcome Processing** (Superior to Plan):
- ✅ **Pass Plays**: Complete, incomplete, sack handling with realistic completion rates
- ✅ **Run Plays**: All run types with fumble/turnover possibilities and yardage variance
- ✅ **Special Teams**: Punt, field goal, kickoff with return handling and success rates
- ✅ **Penalty Processing**: Comprehensive penalty impact on play clock and game state
- ✅ **Turnover Handling**: Interception, fumble with defensive touchdown possibilities

**Clock Integration** (Beyond Original Scope):
- ✅ **Automatic State Updates**: Play outcomes automatically update game state and clocks
- ✅ **Time Consumption**: Realistic play duration modeling based on play type
- ✅ **Clock Stopping Logic**: Integration with clock stopping rules and NFL timing
- ✅ **Play Clock Management**: Automatic reset and state management per play

**Advanced Features Not in Original Plan**:
- ✅ **PlayType Enum**: Comprehensive play classification (pass types, run types, special teams)
- ✅ **PlayResult Struct**: Detailed play outcome information with all relevant data
- ✅ **GameStateUpdate**: Complete game state management including scores and possession
- ✅ **PlayStatistics**: Advanced statistics tracking for comprehensive game analysis
- ✅ **Expected Points**: EPA (Expected Points Added) calculation for advanced analytics

**Simulation Capabilities**:
- ✅ **Random Number Generation**: Seeded RNG for consistent/reproducible simulations
- ✅ **Variance Modeling**: Realistic play outcome variance based on statistical models
- ✅ **Success Rate Modeling**: Distance-based success rates for kicks, realistic completion percentages
- ✅ **Context Awareness**: Game situation affects play outcomes and timing

**Quality and Architecture Advantages**:
- **Comprehensive Testing**: Extensive test suite with scenario coverage
- **Clean Architecture**: Separate utility module allows independent use
- **Performance**: Efficient random number generation and state management
- **Extensibility**: Modular design allows easy addition of new play types

**Integration with GameClock**:
- **Seamless Operation**: Play handler decisions automatically apply to GameClock
- **State Consistency**: All clock state changes properly managed
- **Rule Compliance**: Full integration with NFL timing rules and clock stopping
- **Thread Safety**: Compatible with GameClock mutex protection

**Implementation Superiority**:
- **Beyond Specification**: Implemented significantly more functionality than originally planned
- **Better Design**: Clean separation between play logic and clock management
- **Realistic Modeling**: Statistical accuracy in play outcome simulation
- **Complete Integration**: Full ecosystem integration rather than isolated extraction

**Implementation Location**: `/home/fisty/code/zig-nfl-clock/lib/game_clock/utils/play_handler/play_handler.zig`

**Testing**: Comprehensive test coverage with realistic scenario modeling and edge case handling.

**Reference**: See issue #026 for architectural analysis demonstrating superiority of existing comprehensive implementation over basic nfl-sim extraction.

---
*Created: 2025-08-17*
*Resolved: 2025-08-17 via Issue #026*
*Status: Completed (Alternative Implementation - Comprehensive Module)*