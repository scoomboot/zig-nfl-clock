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

---
*Created: 2025-08-17*
*Status: Not Started*