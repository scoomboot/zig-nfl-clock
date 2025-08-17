# Issue #013: Migrate integration tests

## Summary
Port complex multi-component tests and add new integration tests for library-specific scenarios.

## Description
Migrate integration tests that validate interactions between multiple components (time management, rules engine, play handler). Create comprehensive scenario-based tests that verify the library works correctly in real-world usage patterns.

## Acceptance Criteria
- [ ] Migrate scenario tests:
  - [ ] Complete game simulation test
  - [ ] Quarter transition scenarios
  - [ ] Two-minute drill scenarios
  - [ ] Overtime scenarios
- [ ] Migrate interaction tests:
  - [ ] Clock and play clock synchronization
  - [ ] Rules engine with play outcomes
  - [ ] Time management with rules
- [ ] Add library integration tests:
  - [ ] API workflow tests
  - [ ] Configuration change tests
  - [ ] Error recovery tests
  - [ ] Thread safety under load
- [ ] Create end-to-end scenarios:
  - [ ] Full quarter simulation
  - [ ] Critical game situations
  - [ ] Clock management sequences
  - [ ] Special teams scenarios
- [ ] Performance integration tests:
  - [ ] Multiple games in parallel
  - [ ] Rapid tick processing
  - [ ] Memory usage over time
- [ ] Edge case scenarios:
  - [ ] Game ending on penalty
  - [ ] Overtime sudden death
  - [ ] Multiple two-minute warnings (error case)
  - [ ] Clock expiration during play

## Dependencies
- [#012](012_migrate_unit_tests.md): Unit tests must be migrated first

## Implementation Notes
Test structure example:
```zig
test "integration: GameClock: complete quarter with multiple plays" {
    var clock = GameClock.init();
    clock.start();
    
    // Simulate multiple plays
    const plays = TestPlays.quarter_sequence;
    for (plays) |play| {
        clock.handlePlayOutcome(play, .{});
        try testing.expect(clock.isValidState());
    }
    
    // Verify quarter ended properly
    try testing.expect(clock.isQuarterEnd());
    try testing.expectEqual(@as(u32, 0), clock.getSeconds());
}

test "integration: ClockManager: two-minute drill sequence" {
    var clock = TestClockStates.two_minute_warning;
    
    // Run two-minute drill
    const result = runTwoMinuteDrill(&clock);
    
    // Verify correct behavior
    try testing.expect(result.warning_triggered);
    try testing.expect(result.clock_stopped_correctly);
    try testing.expectEqual(@as(u32, 4), result.plays_executed);
}
```

Scenario categories:
1. **Game flow**: Start to finish game sequences
2. **Critical moments**: Two-minute, overtime, game-ending
3. **Rule interactions**: Complex rule combinations
4. **Performance**: Load and stress testing
5. **Error handling**: Recovery from invalid states

## Testing Requirements
- Test complete workflows, not just individual calls
- Verify state consistency throughout scenarios
- Check performance metrics meet requirements
- Validate memory usage remains stable
- Ensure thread safety with concurrent operations

## Source Reference
- Original integration tests in `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Focus on multi-step test scenarios

## Estimated Time
2 hours

## Priority
🟡 Medium - System validation

## Category
Test Migration

---
*Created: 2025-08-17*
*Status: Not Started*