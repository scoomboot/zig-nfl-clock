# Issue #035: Implement untimed downs for end-of-half scenarios

## Summary
The RulesEngine immediately stops play when time expires, but NFL rules allow untimed downs after certain defensive penalties at the end of a half or game.

## Description
During the validation logic fixes in Issue #033, a time expiration check was added to `RulesEngine.processPlay()` that immediately returns when `time_remaining = 0`. While this fixes some test failures, it prevents the implementation of legitimate untimed downs that are required by NFL rules.

## Problems Identified

### 1. Missing Untimed Down Logic
- **Issue**: Immediate return when time_remaining = 0 prevents untimed downs
- **Location**: `lib/game_clock/utils/rules_engine/rules_engine.zig:218-224`
- **Impact**: End-of-half/game scenarios not handled according to NFL rules
- **Code**:
  ```zig
  // Check if time has expired
  if (self.situation.time_remaining == 0) {
      decision.should_stop = true;
      decision.stop_reason = .quarter_end;
      decision.restart_on_ready = false;
      decision.restart_on_snap = false;
      return decision;
  }
  ```

### 2. NFL Rules Not Implemented
According to NFL rules, an untimed down is awarded when:
- Time expires during a play
- The defense commits a penalty that would normally result in an automatic first down
- This occurs at the end of either half

## NFL Rule Reference
**Rule 4, Section 8**: "If time expires while the ball is in play and a foul by either team is committed during the down, the period is extended for an untimed down."

Common scenarios:
- Defensive holding/pass interference on last play of half
- Defensive offside/encroachment with automatic first down
- Roughing the passer at end of half

## Acceptance Criteria
- [ ] Add untimed down support to RulesEngine
- [ ] Implement penalty detection that triggers untimed downs
- [ ] Handle end-of-half scenarios correctly
- [ ] Add game state tracking for when untimed downs are available
- [ ] Ensure regular time expiration still works when no penalties occur
- [ ] Add comprehensive tests for untimed down scenarios

## Implementation Notes

### Suggested approach:
1. **Add untimed down state tracking**:
   ```zig
   pub const GameSituation = struct {
       // existing fields...
       untimed_down_available: bool = false,
       last_play_had_penalty: bool = false,
   };
   ```

2. **Modify time expiration logic**:
   ```zig
   if (self.situation.time_remaining == 0) {
       if (self.situation.untimed_down_available and outcome.had_defensive_penalty) {
           // Allow the untimed down
           decision.should_stop = false;
           self.situation.untimed_down_available = false;
       } else {
           // Normal time expiration
           decision.should_stop = true;
           decision.stop_reason = .quarter_end;
       }
   }
   ```

3. **Add penalty detection**:
   - Extend PlayOutcome to include penalty information
   - Track defensive penalties that grant automatic first downs
   - Set untimed_down_available flag appropriately

### Testing approach:
```bash
# Test untimed down scenarios
zig build test -Dfilter="untimed"

# Test end-of-half penalty scenarios  
zig build test -Dfilter="end_of_half"
```

## Dependencies
- Related to: [#033](033_validation_logic_fixes.md) - Time expiration check added here
- Affects: GameClock timing logic
- Affects: RulesEngine penalty handling

## Estimated Time
90 minutes (requires new state tracking and penalty logic)

## Priority
🟡 Medium - Improves NFL rule accuracy but not critical for basic functionality

## Category
Feature Enhancement / NFL Rules Compliance

---
*Created: 2025-08-18*
*Status: Not Started*
*Found during: Session review after Issue #033 resolution*