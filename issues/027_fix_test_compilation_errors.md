# Issue #027: Fix test compilation errors

## Summary
Tests cannot compile due to missing method implementations and API mismatches between test files and implementation modules.

## Description
After fixing the test file naming convention (#023), attempting to run tests revealed numerous compilation errors. These errors indicate that the test files are calling methods that don't exist in the implementation files, suggesting either incomplete implementation or API changes that weren't reflected in tests.

## Current State

### Affected Files:
1. **game_clock.test.zig**: 
   - Type mismatch in error handling for `getTimeString()`
   - Line 236: expects `[]u8` but returns `*const [5:0]u8`

2. **time_formatter.test.zig**:
   - Missing methods: `formatGameTime`, `formatPlayClock`, `formatQuarter`, `formatTimeouts`, `formatDownAndDistance`, `formatScore`, `formatTimeWithContext`, `formatElapsedTime`
   - Variables declared as `var` should be `const` (lines 51, 65)

3. **rules_engine.test.zig**:
   - Missing methods: `processPlay`, `canCallTimeout`, `advanceQuarter`, `processPenalty`, `newPossession`, `isHalfOver`, `updateDownAndDistance`
   - Variables declared as `var` should be `const` (lines 57, 83, 575, 593)

4. **play_handler.test.zig**:
   - Missing methods: `processPlay`, `updateGameState`, `updateStatistics`
   - Type mismatch in `initWithState()` (enum types don't match)
   - Unused function parameter in `getFieldPosition()`
   - Variables declared as `var` should be `const` (lines 53, 80)

## Root Cause Analysis
The implementation modules appear to have different public APIs than what the tests expect. This suggests either:
- The implementations are incomplete
- The tests were written against a different API specification
- Methods were renamed or refactored without updating tests

## Acceptance Criteria
- [ ] All test files compile without errors
- [ ] Tests pass when executed with `zig test`
- [ ] API consistency between implementation and tests
- [ ] All `var` declarations that should be `const` are fixed

## Dependencies
- Depends on: #023 (test file naming) - ✅ Complete
- Blocks: All testing-related issues (#010, #011, #012, #013)

## Implementation Notes
1. Review each implementation module to determine actual public API
2. Either:
   - Add missing methods to implementations, OR
   - Update tests to match actual API
3. Fix all const-correctness issues
4. Ensure error handling patterns are consistent

## Testing Requirements
- Run `zig test` on each test file
- Verify all tests compile and pass
- Check test coverage remains comprehensive

## Reference
- Test compilation errors observed in session 2025-08-17
- Files: lib/game_clock/*.test.zig

## Estimated Time
2-3 hours (depending on whether implementations or tests need major changes)

## Priority
🔴 Critical - Tests cannot run, blocking all quality assurance

## Category
Bug Fix / Test Infrastructure

---
*Created: 2025-08-17*
*Status: Not Started*