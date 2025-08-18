# Issue #031: Fix error type inconsistencies in error handling implementation

## Summary
Error type naming and return value mismatches are causing test failures after the error handling implementation.

## Description
During the implementation of Issue #015 (error handling system), several error type inconsistencies were introduced that are causing test failures. These need to be fixed to ensure the error handling system works correctly and tests pass.

## Problems Identified

### 1. TimeFormatter Module
- **Issue**: Error enum defines `InvalidThreshold` (singular) but tests expect `InvalidThresholds` (plural)
- **Files affected**: 
  - `lib/game_clock/utils/time_formatter/time_formatter.zig` (line 60)
  - `lib/game_clock/utils/time_formatter/time_formatter.test.zig` (lines 873, 902, 904, 1001, 1051)
- **Impact**: 5 test failures

### 2. RulesEngine Module
- **Issue**: Validation functions return `InvalidDown` when tests expect `InvalidSituation`
- **Files affected**:
  - `lib/game_clock/utils/rules_engine/rules_engine.zig` (line 556)
  - `lib/game_clock/utils/rules_engine/rules_engine.test.zig` (lines 1005, 1065, 1079, 1159, 1191)
- **Impact**: 6 test failures

### 3. PlayHandler Module
- **Issue**: Validation returns `InvalidDownAndDistance` when tests expect `InvalidGameState`
- **Files affected**:
  - `lib/game_clock/utils/play_handler/play_handler.zig` (lines 756, 761)
  - `lib/game_clock/utils/play_handler/play_handler.test.zig` (lines 1104, 1234)
- **Impact**: 3 test failures

## Acceptance Criteria
- [ ] Standardize error naming (use plural forms consistently where appropriate)
- [ ] Fix validation functions to return appropriate error types based on context
- [ ] All error handling tests should pass
- [ ] Maintain backward compatibility with existing API

## Implementation Notes

### Recommended approach:
1. For TimeFormatter: Rename `InvalidThreshold` to `InvalidThresholds` throughout
2. For RulesEngine: When validating overall situation, return `InvalidSituation` as a general error, keep `InvalidDown` for specific down validation
3. For PlayHandler: Similar approach - use `InvalidGameState` for general state issues, `InvalidDownAndDistance` for specific down/distance problems

### Testing:
```bash
# Run specific test modules to verify fixes
zig build test --test-filter "TimeFormatter"
zig build test --test-filter "RulesEngine" 
zig build test --test-filter "PlayHandler"
```

## Dependencies
- Depends on: [#015](015_implement_error_handling.md) - Error handling implementation

## Reference
- Session where issues were discovered: 2025-08-18
- Test failure output showing the mismatches

## Estimated Time
30 minutes

## Priority
🔴 High - Blocking test suite from passing

## Category
Bug Fix / Error Handling

---
*Created: 2025-08-18*
*Status: Not Started*