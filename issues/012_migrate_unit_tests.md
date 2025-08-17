# Issue #012: Migrate unit tests from nfl-sim

## Summary
Port all relevant unit tests from the original nfl-sim game clock implementation to the library.

## Description
Systematically migrate unit tests from `/home/fisty/code/nfl-sim/src/game_clock.zig`, adapting them to the library structure while maintaining comprehensive coverage. Remove simulation-specific tests and add library-specific ones.

## Acceptance Criteria
- [ ] Migrate initialization tests:
  - [ ] Default values test
  - [ ] Quarter initialization test
  - [ ] Clock state initialization test
- [ ] Migrate time management tests:
  - [ ] Start/stop functionality
  - [ ] Tick advancement
  - [ ] Time calculation (getMinutes, getSeconds)
  - [ ] Quarter transitions
  - [ ] Game end detection
- [ ] Migrate play clock tests:
  - [ ] Play clock start/stop
  - [ ] Play clock expiration
  - [ ] Play clock reset
  - [ ] Duration changes (40/25 seconds)
- [ ] Migrate rules tests:
  - [ ] Clock stopping conditions
  - [ ] Two-minute warning
  - [ ] Ten-second runoff
  - [ ] Inside two minutes rules
- [ ] Migrate play outcome tests:
  - [ ] Run play handling
  - [ ] Pass play handling
  - [ ] Score handling
  - [ ] Penalty handling
  - [ ] Timeout handling
- [ ] Add library-specific tests:
  - [ ] Thread safety tests
  - [ ] API consistency tests
  - [ ] Error handling tests
- [ ] Achieve test coverage targets:
  - [ ] Minimum 90% line coverage
  - [ ] 100% coverage of public API
  - [ ] All edge cases covered

## Dependencies
- [#011](011_organize_test_data.md): Test data organization complete

## Implementation Notes
Migration process:
1. Review original test in nfl-sim
2. Determine if test is relevant to library
3. Adapt test to library API
4. Apply MCS naming convention
5. Place in appropriate test file
6. Use organized test data from INIT section

Example migration:
```zig
// Original (nfl-sim)
test "game clock starts correctly" {
    var gc = GameClock.init(allocator);
    defer gc.deinit();
    gc.start();
    try expect(gc.clock_state == .Running);
}

// Migrated (library)
test "unit: GameClock: start changes state to running" {
    var clock = TestClockStates.game_start;
    clock.start();
    try testing.expectEqual(ClockState.Running, clock.clock_state);
}
```

Priority tests to migrate:
1. Core functionality (init, start, stop, tick)
2. Time calculations
3. Quarter management
4. Play clock operations
5. Rules engine
6. Play outcome handling

## Testing Requirements
- Ensure all migrated tests pass
- Verify tests are properly categorized
- Check test coverage metrics
- Validate no simulation dependencies remain

## Source Reference
- Original tests: `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Test count: 100+ test functions
- Focus on: Non-simulation-specific tests

## Estimated Time
3 hours

## Priority
🔴 Critical - Core test coverage

## Category
Test Migration

---
*Created: 2025-08-17*
*Status: Not Started*