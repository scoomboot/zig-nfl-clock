# Issue #041: Fix additional README field inconsistencies

## Summary
README.md documents multiple ClockConfig fields with incorrect names or that don't exist in the actual implementation, causing compilation errors for users following the documentation.

## Description
Following the resolution of Issue #040, additional field inconsistencies have been discovered between README.md and the actual ClockConfig implementation. These inconsistencies fall into two categories:

### Field Naming Mismatches
The README uses different field names than the actual implementation:
- README: `quarter_length_seconds` → Implementation: `quarter_length`
- README: `overtime_length_seconds` → Implementation: `overtime_length`

### Non-Existent Fields
The README documents fields that don't exist in ClockConfig:
- `enable_ten_second_runoff: bool = true` - Described as "Enable 10-second runoff rule"
- `stop_clock_on_first_down: bool = false` - Described as "Stop clock on first down (college rule)"
- `strict_mode: bool = false` - Described as "Enforce all rules strictly"
- `default_speed: ClockSpeed = .RealTime` - Described as "Default clock speed"

## Current State
- README.md lines 102-103 show incorrect field names (`quarter_length_seconds`, `overtime_length_seconds`)
- README.md lines 109-110, 113, 115 show non-existent fields
- Configuration table (lines 397-398, 402-403, 404, 406) documents these incorrect/missing fields
- Test file `readme_examples.test.zig` line 300 uses `quarter_length_seconds` causing compilation error
- Users following README documentation encounter compilation errors

## Acceptance Criteria
Choose one of two approaches:

### Option A: Fix Documentation (Recommended)
- [ ] Rename `quarter_length_seconds` to `quarter_length` in README
- [ ] Rename `overtime_length_seconds` to `overtime_length` in README
- [ ] Remove or comment out non-existent fields from README
- [ ] Update configuration table with correct field names
- [ ] Fix readme_examples.test.zig to use correct field names
- [ ] Ensure all README examples compile correctly

### Option B: Update Implementation
- [ ] Rename implementation fields to match README (breaking change)
- [ ] Add missing fields to ClockConfig struct
- [ ] Implement logic for new fields
- [ ] Add validation and tests

## Recommendation
**Option A (Fix Documentation)** is recommended because:
1. Non-breaking change that maintains API stability
2. Some fields like `default_speed` may not belong in config struct
3. Features like `enable_ten_second_runoff` may be better handled through rules engine
4. `strict_mode` is vague and would need clear specification
5. Simpler to fix documentation than add potentially unused fields

## Impact Analysis
- **Documentation-only fix**: Low risk, improves accuracy immediately
- **Implementation changes**: High risk, breaking changes, requires design decisions

## Dependencies
- Related to Issue #040 (already resolved)
- Affects Issue #039 implementation (config presets)
- Blocks successful compilation of readme_examples.test.zig

## Testing Requirements
If fixing documentation:
- Verify all README code examples compile
- Ensure readme_examples.test.zig passes
- Check field references are consistent throughout docs

If updating implementation:
- Test new fields with various values
- Verify validation logic
- Ensure backward compatibility or migration path

## References
- [README.md](/home/fisty/code/zig-nfl-clock/README.md) - Lines 102-103, 109-110, 113, 115, 397-398, 402-403, 404, 406
- [config.zig](/home/fisty/code/zig-nfl-clock/lib/game_clock/utils/config/config.zig) - ClockConfig struct definition
- [readme_examples.test.zig](/home/fisty/code/zig-nfl-clock/lib/game_clock/readme_examples.test.zig) - Line 300

## Estimated Time
- Option A (Fix Documentation): 30 minutes
- Option B (Update Implementation): 2-3 hours

## Priority
🔴 High - Documentation accuracy is critical for user experience

## Category
Documentation Fix / API Consistency

## Discovery Context
Found during session review after resolving Issue #040. Test compilation errors revealed additional field inconsistencies not addressed in the initial fix.

---
*Created: 2025-08-23*
*Status: Resolved*

## Resolution Summary

Successfully implemented Option A (Fix Documentation) to resolve all field inconsistencies.

### Changes Applied

#### 1. README.md ClockConfig Example (lines 99-125)
- Changed `quarter_length_seconds` to `quarter_length`
- Changed `overtime_length_seconds` to `overtime_length`
- Removed non-existent fields: `enable_ten_second_runoff`, `default_speed`, `strict_mode`
- Restructured to show `two_minute_warning` as part of `features` struct
- Updated `stop_clock_on_first_down` to `clock_stop_first_down`

#### 2. README.md Custom Configuration Example (lines 293-299)
- Changed `quarter_length_seconds` to `quarter_length`
- Removed non-existent `default_speed` field
- Updated `enable_two_minute_warning` to use `features.two_minute_warning` syntax

#### 3. README.md Configuration Table (lines 402-411)
- Updated all field names to match implementation
- Removed documentation for non-existent fields
- Clarified that `clock_stop_first_down` only applies in last 2 minutes

#### 4. readme_examples.test.zig Fixes
- Changed `quarter_length_seconds` to `quarter_length` (line 300)
- Updated `enable_two_minute_warning` to `features.two_minute_warning` (line 303)
- Fixed additional test compilation issues including playoff config requirements

### Verification
- All tests compile and pass successfully
- README documentation now accurately reflects the actual ClockConfig implementation
- No references to non-existent fields remain

### Impact
- Users following README documentation will no longer encounter compilation errors
- Documentation is now consistent with the actual API
- Test examples properly validate against the implementation

*Resolved: 2025-08-23*