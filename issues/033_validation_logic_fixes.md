# Issue #033: Fix validation logic errors in error handling implementation

## Summary
Multiple validation functions have incorrect logic causing tests to fail - either returning errors when they shouldn't or passing when they should fail.

## Description
After implementing the error handling system (Issue #015) and fixing error type naming (Issues #031, #032), several validation functions contain logic errors that cause legitimate operations to fail or invalid operations to succeed. These represent bugs in the business logic rather than simple type mismatches.

## Problems Identified

### 1. TimeFormatter Module - validateTimeValue()
- **Issue**: Function returns `InvalidTimeValue` error for valid inputs
- **Location**: `lib/game_clock/utils/time_formatter/time_formatter.zig:391`
- **Test failures**: 
  - `unit: TimeFormatterError: InvalidTimeValue detection`
  - `unit: TimeFormatter: validateTimeValue catches edge cases`
- **Impact**: 2 test failures
- **Root cause**: Likely incorrect boundary checking or validation logic

### 2. TimeFormatter Module - validateThresholds()
- **Issue**: Function returns void (success) when it should return `InvalidThresholds` error
- **Location**: `lib/game_clock/utils/time_formatter/time_formatter.zig:425`
- **Test failures**:
  - `unit: TimeFormatterError: InvalidThresholds validation`
  - `unit: TimeFormatter: validateThresholds ensures consistency`
- **Impact**: 2 test failures
- **Root cause**: Validation conditions may be too permissive or incorrectly structured

### 3. Multiple Modules - Scenario Test Failures
- **Issue**: 6+ tests fail basic `testing.expect()` assertions
- **Affected tests**:
  - GameClock: handles errors during critical game moments
  - RulesEngine: processes onside kick recovery
  - RulesEngine: InvalidClockState recovery
  - RulesEngine: handles extreme game situations
  - PlayHandler: processes complete touchdown drive
  - PlayHandler: handles goal-line stand sequence
- **Impact**: 6+ test failures
- **Root cause**: Business logic doesn't match expected NFL rules behavior

### 4. PlayHandler Module - Game State Calculations
- **Issue**: Score calculation error (expected 1005, got 999)
- **Location**: PlayHandler extreme game states test
- **Impact**: 1 test failure
- **Root cause**: Likely arithmetic or state update error

## Test Evidence
```bash
error: 'validateTimeValue' failed: /time_formatter.zig:391:17: return TimeFormatterError.InvalidTimeValue
error: 'InvalidThresholds validation' failed: expected error.InvalidThresholds, found void
error: 'handles errors during critical game moments' failed: testing.zig:580:14: in expect
error: 'processes onside kick recovery' failed: try testing.expect(!decision.should_stop)
error: 'handles extreme game states' failed: expected 1005, found 999
```

## Acceptance Criteria
- [ ] Fix TimeFormatter validateTimeValue() boundary conditions
- [ ] Fix TimeFormatter validateThresholds() validation logic
- [ ] Review and fix scenario test business logic
- [ ] Fix score calculation in PlayHandler
- [ ] All validation functions should correctly distinguish valid from invalid inputs
- [ ] Scenario tests should pass with correct NFL rules behavior

## Implementation Notes

### Investigation needed:
1. Review TimeFormatter validation boundary conditions against NFL rules
2. Trace through scenario test failures to understand business logic issues
3. Debug score calculation in extreme game states

### Testing approach:
```bash
# Test TimeFormatter validation
zig build test 2>&1 | grep -A5 "TimeFormatter.*validate"

# Test scenario failures
zig build test 2>&1 | grep -A5 "scenario:"

# Full test suite
zig build test
```

## Dependencies
- Related to: [#015](015_implement_error_handling.md) - Error handling implementation
- Related to: [#031](031_fix_error_type_inconsistencies.md) - Initial error fixes
- Related to: [#032](032_additional_error_type_fixes.md) - Additional error type fixes

## Estimated Time
45 minutes (requires debugging and logic analysis)

## Priority
🔴 High - Core validation logic affects system reliability

## Category
Bug Fix / Validation Logic

---
*Created: 2025-08-18*
*Status: Not Started*
*Found during: Session review after Issue #031 resolution*