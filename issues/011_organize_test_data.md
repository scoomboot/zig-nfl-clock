# Issue #011: Organize test data in INIT sections

## Summary
Structure all test constants, fixtures, and helper data in properly organized INIT sections.

## Description
Create a comprehensive test data organization system with all test constants, mock data, and fixtures defined in INIT sections of test files. This ensures test data is easily maintainable and reusable across test suites.

## Acceptance Criteria
- [ ] Create test constants in INIT sections:
  - [ ] Time values for testing
  - [ ] Standard game situations
  - [ ] Common play outcomes
  - [ ] Error conditions
- [ ] Define test fixtures:
  ```zig
  // ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗
  
  const TestScenarios = struct {
      const two_minute_drill = GameState{
          .quarter = .Q2,
          .game_seconds = 720,  // 12:00 in Q2
          .clock_state = .Running,
      };
      
      const overtime_start = GameState{
          .quarter = .Overtime,
          .game_seconds = 3600,  // Start of OT
          .clock_state = .Stopped,
      };
  };
  
  const TestPlayOutcomes = struct {
      const touchdown = PlayOutcome{ .type = .Touchdown, .yards = 25 };
      const incomplete_pass = PlayOutcome{ .type = .IncompletePass, .yards = 0 };
      const out_of_bounds_run = PlayOutcome{ .type = .Run, .yards = 7, .out_of_bounds = true };
  };
  ```
- [ ] Create data factories:
  - [ ] `createClockAtTime(minutes: u32, seconds: u32)` - Clock at specific time
  - [ ] `createClockInQuarter(quarter: Quarter)` - Clock in specific quarter
  - [ ] `createExpiredClock()` - Clock with no time remaining
- [ ] Organize test data by category:
  - [ ] Clock states
  - [ ] Play scenarios
  - [ ] Rule situations
  - [ ] Edge cases
- [ ] Document test data purpose:
  ```zig
  /// Standard test scenarios for two-minute warning logic
  const TwoMinuteScenarios = struct { ... };
  ```

## Dependencies
- [#010](010_setup_test_categorization.md): Test categorization must be defined

## Implementation Notes
- Place all test data in test file INIT sections
- Use nested structs for organization
- Keep test data immutable (const)
- Name data descriptively
- Group related test data together

Example structure:
```zig
// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

// Test-specific constants
const TEST_TIMEOUT_MS = 1000;
const MAX_TEST_ITERATIONS = 100;

// Clock test states
const TestClockStates = struct {
    const game_start = GameClock{ ... };
    const quarter_end = GameClock{ ... };
    const two_minute_warning = GameClock{ ... };
};

// Play test scenarios  
const TestPlays = struct {
    const run_plays = [_]PlayOutcome{ ... };
    const pass_plays = [_]PlayOutcome{ ... };
    const special_teams = [_]PlayOutcome{ ... };
};

// Helper factories
fn createTestClock() GameClock {
    return GameClock.init();
}
```

## Testing Requirements
- Verify all test data is in INIT sections
- Check data is properly categorized
- Ensure factories work correctly
- Validate test data covers all scenarios

## Reference
- MCS documentation: `/home/fisty/code/zig-nfl-clock/docs/MCS.md`
- Section: Test Organization

## Estimated Time
1 hour

## Priority
🟡 Medium - Test maintainability

## Category
Test Migration

## ✅ RESOLUTION (2025-08-17)

**Completed as part of Issue #010.** All test data organization requirements were fulfilled during the comprehensive test categorization implementation.

### Work Completed via Issue #010:

#### ✅ Test Data in INIT Sections
- **Test helper functions** added to all test files' INIT sections
- **Factory functions**: `createTestClock()`, `createTestClockWithState()`, etc.
- **Test constants**: Comprehensive test scenarios and data structures
- **Custom assertions**: `assertTimeEquals()`, `assertClockState()`, etc.

#### ✅ Test Data Organization
- **Factory Functions**: 43 comprehensive test helper functions across all modules
- **Test Scenarios**: Organized by category (unit, integration, e2e, scenario, performance, stress)
- **Data Structures**: TestScenarios, TestPlayOutcomes, and component-specific test data
- **MCS Compliance**: All test data properly organized with 4-space indentation

#### ✅ Test Data Categories Implemented
- **Clock States**: Various game clock configurations for testing
- **Play Scenarios**: Comprehensive play outcome test data
- **Rule Situations**: NFL timing rule test scenarios
- **Edge Cases**: Extreme conditions and boundary testing data

### Files Enhanced:
- `lib/game_clock/game_clock.test.zig` - 12 test helper functions
- `lib/game_clock/utils/rules_engine/rules_engine.test.zig` - 9 test helpers
- `lib/game_clock/utils/play_handler/play_handler.test.zig` - 10 test helpers
- `lib/game_clock/utils/time_formatter/time_formatter.test.zig` - 12 test helpers

### Verification:
- All test data is properly organized in INIT sections
- Factory functions work correctly across all test files
- Test data covers comprehensive scenarios
- 100% MCS compliance achieved

---
*Created: 2025-08-17*
*Resolved: 2025-08-17 via Issue #010*
*Status: ✅ RESOLVED*