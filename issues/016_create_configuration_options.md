# Issue #016: Create configuration options

## Summary
Implement a flexible configuration system allowing customization of clock behavior and rules.

## Description
Create a comprehensive configuration structure that allows users to customize various aspects of the game clock, including timing parameters, rule variations, and behavior options. Support both compile-time and runtime configuration.

## Acceptance Criteria
- [ ] Define ClockConfig struct:
  ```zig
  pub const ClockConfig = struct {
      // Time settings
      quarter_length_seconds: u32 = 900,  // 15 minutes
      overtime_length_seconds: u32 = 600,  // 10 minutes
      play_clock_normal: u32 = 40,
      play_clock_short: u32 = 25,
      
      // Rule settings  
      enable_two_minute_warning: bool = true,
      enable_ten_second_runoff: bool = true,
      stop_clock_on_first_down: bool = false,  // College rule
      
      // Behavior settings
      default_speed: ClockSpeed = .RealTime,
      auto_start_play_clock: bool = true,
      strict_mode: bool = false,  // Enforce all rules strictly
      
      // Advanced settings
      tick_interval_ms: u32 = 100,
      max_overtime_periods: u8 = 1,
      playoff_rules: bool = false,
  };
  ```
- [ ] Implement configuration validation:
  - [ ] Validate time values are reasonable
  - [ ] Check for conflicting settings
  - [ ] Provide default configurations
- [ ] Create preset configurations:
  ```zig
  pub const Presets = struct {
      pub const nfl_regular = ClockConfig{ };  // Default
      pub const nfl_playoff = ClockConfig{ .playoff_rules = true };
      pub const college = ClockConfig{
          .stop_clock_on_first_down = true,
          .overtime_length_seconds = 0,  // No OT clock
      };
      pub const practice = ClockConfig{
          .quarter_length_seconds = 600,  // 10 min quarters
          .strict_mode = false,
      };
  };
  ```
- [ ] Support configuration updates:
  - [ ] Allow some settings to change at runtime
  - [ ] Validate changes don't break current state
  - [ ] Provide migration for incompatible changes
- [ ] Implement feature flags:
  ```zig
  pub const Features = struct {
      experimental_rules: bool = false,
      debug_output: bool = false,
      performance_tracking: bool = false,
  };
  ```
- [ ] Add configuration to initialization:
  ```zig
  // With config
  const clock = GameClock.initWithConfig(Presets.nfl_playoff);
  
  // With builder
  const clock = GameClock.builder()
      .config(custom_config)
      .build();
  ```

## Dependencies
- [#014](014_design_public_interface.md): Public interface design complete

## Implementation Notes
Configuration categories:
1. **Timing**: Quarter length, play clock, etc.
2. **Rules**: NFL/College variations, special rules
3. **Behavior**: Auto-start, strict mode, etc.
4. **Performance**: Tick rate, optimization flags
5. **Debug**: Logging, tracking, validation

Usage examples:
```zig
// Simple usage with preset
var clock = GameClock.initWithConfig(ClockConfig.Presets.nfl_regular);

// Custom configuration
const config = ClockConfig{
    .quarter_length_seconds = 720,  // 12 minute quarters
    .enable_two_minute_warning = false,
    .default_speed = .Fast2x,
};
var clock = GameClock.initWithConfig(config);

// Runtime updates
try clock.updateConfig(.{ .default_speed = .Fast10x });
```

Compile-time configuration:
```zig
// build.zig options
const optimize_for_speed = b.option(bool, "speed", "Optimize for speed") orelse false;
const enable_debug = b.option(bool, "debug", "Enable debug features") orelse false;
```

## Testing Requirements
- Test all preset configurations
- Verify configuration validation
- Test runtime configuration changes
- Check feature flag behavior
- Validate incompatible setting detection

## Estimated Time
1.5 hours

## Priority
🟡 Medium - Flexibility and customization

## Category
API Refinement

---
*Created: 2025-08-17*
*Status: Not Started*