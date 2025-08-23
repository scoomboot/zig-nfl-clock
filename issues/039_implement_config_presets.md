# Issue #039: Implement missing ClockConfig preset configurations

## Summary
Add the preset configurations (Presets struct) that are documented in README but not implemented.

## Description
The README.md documentation shows a `ClockConfig.Presets` struct with predefined configurations for common use cases (nfl_regular, nfl_playoff, college, practice), but these presets don't exist in the actual implementation. Users expecting these convenience presets will need to manually configure all settings.

## Current State
- README documents `ClockConfig.Presets` with four configurations
- Test file notes "preset configurations are mentioned in README but not yet implemented"
- Users must manually create configurations instead of using presets
- No Presets struct exists in config.zig

## Acceptance Criteria
- [ ] Create Presets struct within ClockConfig module
- [ ] Implement `nfl_regular` preset (default NFL settings)
- [ ] Implement `nfl_playoff` preset (playoff-specific settings)
- [ ] Implement `college` preset (college football rules)
- [ ] Implement `practice` preset (shortened quarters for practice)
- [ ] Add tests for each preset configuration
- [ ] Update examples to use presets
- [ ] Ensure README documentation matches implementation

## Implementation Notes
Preset configurations to implement:

```zig
pub const Presets = struct {
    // NFL Regular Season (default)
    pub const nfl_regular = ClockConfig{
        // All defaults
    };
    
    // NFL Playoffs
    pub const nfl_playoff = ClockConfig{
        .playoff_rules = true,
        .max_overtime_periods = 99, // Unlimited in playoffs
    };
    
    // College Football
    pub const college = ClockConfig{
        .stop_clock_on_first_down = true,
        .overtime_length_seconds = 0, // No clock in college OT
        .play_clock_normal = 40,
        .play_clock_short = 25,
    };
    
    // Practice/Training
    pub const practice = ClockConfig{
        .quarter_length_seconds = 600, // 10 minute quarters
        .strict_mode = false,
        .default_speed = .Fast2x,
    };
};
```

## Dependencies
- [#016](016_create_configuration_options.md): Configuration system (completed)
- [#038](038_implement_playoff_rules_field.md): playoff_rules field needed for nfl_playoff preset

## Testing Requirements
- Test each preset has expected values
- Test presets can be used with initWithConfig()
- Test presets can be modified after selection
- Verify README examples using presets work

## References
- [README.md](/home/fisty/code/zig-nfl-clock/README.md) - Preset Configurations section
- [readme_examples.test.zig](/home/fisty/code/zig-nfl-clock/lib/game_clock/readme_examples.test.zig) - Line 306

## Estimated Time
30 minutes

## Priority
🟢 Low - Convenience feature for better developer experience

## Category
API Enhancement

---
*Created: 2025-08-23*
*Status: Not Started*