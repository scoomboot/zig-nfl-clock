# Issue #032: Additional error type inconsistencies found after Issue #031

## Summary
Additional error type mismatches discovered during test execution after resolving Issue #031, preventing full test suite pass.

## Description
After fixing the initial error type inconsistencies in Issue #031, test execution revealed additional error type problems that need resolution. These issues are causing 8+ test failures and represent genuine bugs in the error handling implementation.

## Problems Identified

### 1. RulesEngine Module
- **Issue**: Tests expect `InvalidClockDecision` error that doesn't exist in `RulesEngineError` enum
- **Location**: `lib/game_clock/utils/rules_engine/rules_engine.test.zig:1123`
- **Current behavior**: Returns `ClockManagementError`
- **Expected behavior**: Should return `InvalidClockDecision`
- **Impact**: 1 test failure

### 2. PlayHandler Module - InvalidPlayResult
- **Issue**: Validation functions return specific errors when tests expect general `InvalidPlayResult`
- **Locations**:
  - Returns `InvalidYardage` instead of `InvalidPlayResult` (3 test failures)
  - Returns `InvalidFieldPosition` instead of `InvalidPlayResult` (1 test failure)
- **Files affected**: 
  - `lib/game_clock/utils/play_handler/play_handler.zig` (validation functions)
  - `lib/game_clock/utils/play_handler/play_handler.test.zig` (multiple tests)
- **Impact**: 4 test failures

### 3. PlayHandler Module - InvalidStatistics
- **Issue**: Tests expect `InvalidStatistics` error but validation passes (returns void)
- **Location**: `lib/game_clock/utils/play_handler/play_handler.test.zig`
- **Current behavior**: Validation succeeds when it should fail
- **Expected behavior**: Should return `InvalidStatistics` error
- **Impact**: 1 test failure

## Test Evidence
```bash
error: 'RulesEngine: validateClockDecision ensures valid decisions' failed: expected error.InvalidClockDecision, found error.ClockManagementError
error: 'PlayHandlerError: InvalidPlayResult validation' failed: expected error.InvalidPlayResult, found error.InvalidYardage
error: 'PlayHandlerError: InvalidStatistics detection' failed: expected error.InvalidStatistics, found void
error: 'PlayHandler: error recovery maintains game continuity' failed: expected error.InvalidPlayResult, found error.InvalidYardage
error: 'PlayHandler: complete error handling during drive' failed: expected error.InvalidPlayResult, found error.InvalidYardage
```

## Acceptance Criteria
- [ ] Add missing error types to respective error enums
- [ ] Update validation functions to return appropriate error types
- [ ] Ensure consistent error handling patterns across modules
- [ ] All affected tests should pass

## Implementation Notes

### Recommended approach:
1. **RulesEngine**: Add `InvalidClockDecision` to the `RulesEngineError` enum
2. **PlayHandler**: 
   - Consider if `InvalidPlayResult` should be added as a general error
   - Or update tests to expect the specific error types
   - Verify `InvalidStatistics` exists in enum and fix validation logic

### Testing:
```bash
# Run specific test modules to verify fixes
zig build test 2>&1 | grep -E "InvalidPlayResult|InvalidClockDecision|InvalidStatistics"
```

## Dependencies
- Related to: [#031](031_fix_error_type_inconsistencies.md) - Initial error type fixes

## Estimated Time
20 minutes

## Priority
🔴 High - Blocking test suite from achieving 100% pass rate

## Category
Bug Fix / Error Handling

---
*Created: 2025-08-18*
*Status: Not Started*
*Found during: Session review after Issue #031 resolution*