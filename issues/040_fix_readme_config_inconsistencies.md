# Issue #040: Fix README documentation for non-existent ClockConfig fields

## Summary
README.md documents ClockConfig fields that don't exist in the actual implementation, causing compilation errors for users following the documentation.

## Description
The README.md file shows two fields in the ClockConfig struct that are not implemented in the actual code:
- `tick_interval_ms: u32 = 100` - Described as "Milliseconds per tick"
- `max_overtime_periods: u8 = 1` - Described as "Maximum overtime periods"

These fields appear in both the ClockConfig struct documentation and the configuration table, but they don't exist in `/lib/game_clock/utils/config/config.zig`. Users who try to use these fields based on the documentation will encounter compilation errors.

## Current State
- README.md lines 118-119 show these fields in the struct definition
- README.md lines 409-410 describe these fields in the configuration table
- Test file `readme_examples.test.zig` references these fields with comments about them not being implemented
- The actual ClockConfig struct in `config.zig` does not contain these fields
- Issue #039 also references `max_overtime_periods` in the context of preset configurations

## Acceptance Criteria
Choose one of two approaches:

### Option A: Remove from Documentation
- [ ] Remove `tick_interval_ms` field from README.md
- [ ] Remove `max_overtime_periods` field from README.md
- [ ] Update configuration table to remove these entries
- [ ] Update any examples that reference these fields

### Option B: Implement the Fields
- [ ] Add `tick_interval_ms: u32 = 100` to ClockConfig struct
- [ ] Add `max_overtime_periods: u8 = 1` to ClockConfig struct
- [ ] Implement logic to use tick_interval_ms for clock updates
- [ ] Implement logic to enforce max_overtime_periods limit
- [ ] Add validation for these fields
- [ ] Create tests for the new functionality

## Recommendation
**Option A (Remove from Documentation)** is recommended because:
1. These fields don't appear to be used in any actual game logic
2. The clock implementation doesn't need configurable tick intervals (it's event-driven)
3. Maximum overtime periods is already handled differently (playoff_rules determines unlimited OT)
4. Removing documentation is less risky than adding unused fields

## Impact Analysis
- **Documentation-only fix**: Low risk, improves accuracy
- **Implementation approach**: Medium risk, adds complexity for unclear benefit

## Dependencies
- Related to Issue #039 which references `max_overtime_periods` for preset configurations
- May affect Issue #038's playoff_rules implementation if max_overtime_periods is added

## Testing Requirements
If implementing the fields:
- Test default values
- Test validation boundaries
- Test integration with game clock logic
- Verify overtime period enforcement

If removing from documentation:
- Ensure all README examples still compile
- Verify no test references remain

## References
- [README.md](/home/fisty/code/zig-nfl-clock/README.md) - Lines 118-119, 409-410
- [config.zig](/home/fisty/code/zig-nfl-clock/lib/game_clock/utils/config/config.zig) - ClockConfig struct definition
- [readme_examples.test.zig](/home/fisty/code/zig-nfl-clock/lib/game_clock/readme_examples.test.zig) - Lines with field references
- [Issue #039](039_implement_config_presets.md) - References max_overtime_periods

## Estimated Time
- Option A (Remove): 15 minutes
- Option B (Implement): 1-2 hours

## Priority
🟡 Medium - Documentation accuracy affects user experience

## Category
Documentation Fix / API Enhancement

## Discovery Context
Found during Issue #038 implementation when reviewing README examples that reference these non-existent fields.

---
*Created: 2025-08-23*
*Status: Resolved*

## Resolution Summary

**Approach Taken**: Option A - Removed non-existent fields from documentation

**Changes Made**:
1. Removed `tick_interval_ms` and `max_overtime_periods` from README.md ClockConfig struct example (lines 118-119)
2. Removed both fields from the README.md configuration table (lines 409-410)
3. Cleaned up commented references in readme_examples.test.zig 
4. Updated Issue #039 to remove incorrect `max_overtime_periods` reference

**Rationale**:
- The clock implementation is event-driven, not tick-based, so `tick_interval_ms` is unnecessary
- Overtime handling uses the `playoff_rules` field to determine unlimited overtime periods
- Removing these fields from documentation prevents user confusion and compilation errors

**Verification**:
- All tests pass successfully after changes
- README documentation now accurately reflects the actual ClockConfig API
- No breaking changes to existing functionality

*Resolved: 2025-08-23*