# Issue #038: Implement missing playoff_rules field in ClockConfig

## Summary
Add the `playoff_rules` field to ClockConfig that is documented in README but not implemented.

## Description
The README.md documentation shows a `playoff_rules` field in the ClockConfig struct, but this field doesn't actually exist in the implementation. Users following the documentation will encounter compilation errors when trying to use this field. The test file `readme_examples.test.zig` has 5 occurrences noting this field is "not yet implemented."

## Current State
- README documents `playoff_rules: bool = false` in ClockConfig
- Field is shown in configuration table
- Field is used in example code
- Actual ClockConfig struct in `lib/game_clock/utils/config/config.zig` doesn't have this field
- Test file comments out usage with note "not yet implemented"

## Acceptance Criteria
- [ ] Add `playoff_rules: bool = false` field to ClockConfig struct
- [ ] Update validation logic to handle playoff rules
- [ ] Implement playoff-specific timing rules:
  - [ ] Modified overtime rules for playoffs
  - [ ] No tie games allowed
  - [ ] Extended overtime periods
- [ ] Update ClockConfig tests to verify field
- [ ] Remove "not yet implemented" notes from readme_examples.test.zig
- [ ] Ensure all README examples compile without modification

## Implementation Notes
Playoff rules differences to implement:
1. **Overtime**: In playoffs, overtime continues until there's a winner
2. **Sudden Death**: Modified sudden death rules in playoffs
3. **Time Management**: Different timeout rules in playoff overtime
4. **Clock Operations**: May need different clock stopping rules

Code locations to update:
- `/lib/game_clock/utils/config/config.zig` - Add field to struct
- `/lib/game_clock/game_clock.zig` - Use field in game logic
- `/lib/game_clock/utils/rules_engine/rules_engine.zig` - Implement playoff-specific rules
- `/lib/game_clock/readme_examples.test.zig` - Enable commented code

## Dependencies
- [#016](016_create_configuration_options.md): Configuration system (completed)

## Testing Requirements
- Test default value is false
- Test playoff rules can be enabled
- Test playoff-specific timing behavior
- Verify all README examples work
- Add integration tests for playoff scenarios

## References
- [README.md](/home/fisty/code/zig-nfl-clock/README.md) - Lines showing playoff_rules usage
- [readme_examples.test.zig](/home/fisty/code/zig-nfl-clock/lib/game_clock/readme_examples.test.zig) - Lines 121, 130, 306, 459, 474

## Estimated Time
1 hour

## Priority
🟡 Medium - API completeness and documentation accuracy

## Category
API Enhancement

---
*Created: 2025-08-23*
*Status: Not Started*