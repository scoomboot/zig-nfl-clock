# Issue #010: Set up test categorization per MCS

## Summary
Establish test naming conventions and categories following MCS test organization standards.

## Description
Define and implement a consistent test categorization system for all tests in the library. Tests should be clearly labeled by type and scope, making it easy to run specific test suites and understand test coverage.

## Acceptance Criteria
- [ ] Define test categories:
  - [ ] `unit:` - Single function/method tests
  - [ ] `integration:` - Multi-component interaction tests
  - [ ] `performance:` - Speed and efficiency benchmarks
  - [ ] `stress:` - Concurrent operation and edge case tests
  - [ ] `scenario:` - Real-world usage scenarios
- [ ] Establish naming convention:
  ```zig
  test "unit: GameClock: initialization sets correct defaults" { }
  test "integration: ClockManager: handles quarter transitions" { }
  test "performance: tick: processes 1000 ticks under 1ms" { }
  ```
- [ ] Create test organization structure:
  - [ ] Group related tests with comments
  - [ ] Order tests from simple to complex
  - [ ] Separate categories with clear markers
- [ ] Document test strategy:
  - [ ] When to use each category
  - [ ] Expected coverage per category
  - [ ] Test execution guidelines
- [ ] Set up test helpers:
  - [ ] Common test utilities
  - [ ] Test data factories
  - [ ] Assertion helpers

## Dependencies
- [#009](009_add_function_documentation.md): Documentation standards in place
- 🔴 [#027](027_fix_test_compilation_errors.md): Utility module tests must compile before categorization can be applied

## Implementation Notes
Test naming format:
```zig
test "category: ComponentName: specific behavior being tested" {
    // Test implementation
}
```

Example test organization:
```zig
// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

// ┌────────────────────────────── Test Helpers ──────────────────────────────┐
fn createTestClock() GameClock { ... }
fn assertTimeEquals(expected: u32, actual: u32) void { ... }

// ┌────────────────────────────── Unit Tests ──────────────────────────────┐
test "unit: GameClock: initialization sets correct defaults" { ... }
test "unit: GameClock: start changes state to running" { ... }

// ┌────────────────────────────── Integration Tests ──────────────────────────────┐
test "integration: GameClock: quarter transition updates all state" { ... }

// ┌────────────────────────────── Performance Tests ──────────────────────────────┐
test "performance: tick: handles 1000 operations in under 1ms" { ... }
```

## Testing Requirements
- Apply categorization to existing tests
- Ensure all categories are represented
- Verify naming consistency
- Check test organization and grouping

## Reference
- MCS documentation: `/home/fisty/code/zig-nfl-clock/docs/MCS.md`
- Original tests: `/home/fisty/code/nfl-sim/src/game_clock.zig` (100+ tests)

## Estimated Time
1 hour

## Priority
🔴 Critical - Test organization foundation

## Category
Test Migration

---
*Created: 2025-08-17*
*Status: Not Started*