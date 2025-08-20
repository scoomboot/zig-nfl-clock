# Issue #036: Restore reasonable time validation boundaries

## Summary
The TimeFormatter's validateTimeValue() function was completely gutted during validation fixes, now accepting any u32 value including unreasonably large ones that could cause display or memory issues.

## Description
During the validation logic fixes in Issue #033, the `validateTimeValue()` function in TimeFormatter was modified to accept any u32 value to fix failing tests. While this resolved the test failures, it removed all upper bound validation, potentially allowing values that could cause formatting problems or consume excessive memory.

## Problems Identified

### 1. No Upper Bound Validation
- **Issue**: Function accepts any u32 value, including max u32 (4,294,967,295 seconds ≈ 136 years)
- **Location**: `lib/game_clock/utils/time_formatter/time_formatter.zig:384-391`
- **Impact**: Could cause display formatting issues or memory problems
- **Current Code**:
  ```zig
  pub fn validateTimeValue(self: *const TimeFormatter, seconds: u32, is_overtime: bool) TimeFormatterError!void {
      _ = self;
      _ = seconds;
      _ = is_overtime;

      // All u32 values are valid for formatting purposes
      // The formatter can handle any time value
  }
  ```

### 2. Tests Expect Extreme Values
- **Issue**: Tests expect values like 86400 (24 hours) and max u32 to be valid
- **Location**: `lib/game_clock/utils/time_formatter/time_formatter.test.zig:947-948`
- **Evidence**: 
  ```zig
  .{ .value = 86400, .expected_valid = true }, // 24 hours
  .{ .value = 4294967295, .expected_valid = true }, // Max u32
  ```

### 3. Potential Display Issues
Large time values could cause:
- String formatting buffer overflows
- Excessive memory allocation
- UI display problems (e.g., "136 years, 23 days, 4 hours...")
- Performance degradation with very large calculations

## Acceptance Criteria
- [ ] Implement reasonable upper bound validation (e.g., 24-48 hours max)
- [ ] Maintain support for legitimate long games (overtime, delays)
- [ ] Update tests to use realistic maximum values
- [ ] Ensure formatter can handle the validated range without issues
- [ ] Add specific error messages for different validation failures
- [ ] Document the rationale for chosen limits

## Implementation Notes

### Suggested approach:
1. **Define reasonable limits**:
   ```zig
   const MAX_REASONABLE_GAME_TIME: u32 = 86400; // 24 hours
   const MAX_DISPLAY_TIME: u32 = 18000; // 5 hours for display purposes
   ```

2. **Implement tiered validation**:
   ```zig
   pub fn validateTimeValue(self: *const TimeFormatter, seconds: u32, is_overtime: bool) TimeFormatterError!void {
       _ = self;
       
       // Allow very large values but warn about display implications
       if (seconds > MAX_REASONABLE_GAME_TIME) {
           // Could return a warning or log, but still allow
           // This handles edge cases while flagging potential issues
       }
       
       // Only reject truly unreasonable values (e.g., > 1 week)
       if (seconds > 604800) { // 1 week in seconds
           return TimeFormatterError.InvalidTimeValue;
       }
   }
   ```

3. **Update test expectations**:
   - Keep 24-hour test as valid
   - Replace max u32 test with 1-week maximum
   - Add specific tests for edge cases around the boundaries

### Alternative approach:
Create separate validation levels:
- `validateForGame()` - strict limits for actual gameplay
- `validateForDisplay()` - broader limits for formatting
- `validateForStorage()` - maximum safe limits for data integrity

### Testing approach:
```bash
# Test time validation boundaries
zig build test -Dfilter="validateTimeValue"

# Test display formatting with large values
zig build test -Dfilter="TimeFormatter.*large"
```

## Dependencies
- Related to: [#033](033_validation_logic_fixes.md) - Validation was removed here
- Affects: TimeFormatter display logic
- Affects: GameClock time setting validation

## Estimated Time
45 minutes (straightforward validation logic restoration)

## Priority
🟡 Medium - Prevents potential issues but doesn't affect current functionality

## Category
Bug Fix / Input Validation

---
*Created: 2025-08-18*
*Status: **Resolved***
*Found during: Session review after Issue #033 resolution*

## Resolution Summary

### Changes Implemented

1. **Added Time Boundary Constants** (TimeFormatter struct):
   - `MAX_GAME_TIME`: 86400 seconds (24 hours) - for legitimate long games
   - `MAX_REASONABLE_TIME`: 604800 seconds (1 week) - absolute maximum
   - `DISPLAY_WARNING_TIME`: 18000 seconds (5 hours) - display warning threshold

2. **Restored Tiered Validation** in `validateTimeValue()`:
   - Values 0 to MAX_GAME_TIME: Accepted normally
   - Values MAX_GAME_TIME to MAX_REASONABLE_TIME: Accepted (edge cases)
   - Values above MAX_REASONABLE_TIME: Rejected with `InvalidTimeValue` error

3. **Enhanced Test Coverage**:
   - Updated boundary tests for new validation limits
   - Added integration tests for boundary formatting
   - Replaced max u32 test with 1-week boundary test
   - All 47 TimeFormatter tests passing

### Impact
- Prevents potential display/memory issues with extreme values (>1 week)
- Maintains support for legitimate long games (up to 24 hours normally)
- Provides clear, documented validation boundaries
- No performance impact on normal operations

### Files Modified
- `/lib/game_clock/utils/time_formatter/time_formatter.zig`: Added constants and validation logic
- `/lib/game_clock/utils/time_formatter/time_formatter.test.zig`: Updated test boundaries

### Testing Verification
✅ All TimeFormatter tests pass (47/47)
✅ Full test suite passes with no regressions
✅ Build completes successfully
✅ Boundary values format correctly when valid

*Resolved: 2025-08-20*