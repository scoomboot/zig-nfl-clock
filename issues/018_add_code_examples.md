# Issue #018: Add code examples and quick start

## Summary
Create comprehensive code examples demonstrating library usage patterns and best practices.

## Description
Develop a collection of well-documented examples that showcase different aspects of the library, from basic usage to advanced scenarios. Examples should be runnable and serve as both documentation and integration tests.

## Acceptance Criteria
- [ ] Create examples directory structure:
  ```
  examples/
  ├── basic_usage.zig         # Simple clock operations
  ├── game_simulation.zig     # Full game simulation
  ├── play_processing.zig     # Play outcome handling
  ├── configuration.zig       # Custom configurations
  ├── two_minute_drill.zig    # Two-minute scenario
  ├── overtime.zig           # Overtime rules
  ├── concurrent_games.zig    # Multiple games
  └── integration.zig        # Integration with game engine
  ```
- [ ] Implement basic usage example:
  ```zig
  // examples/basic_usage.zig
  const std = @import("std");
  const game_clock = @import("game_clock");
  
  pub fn main() !void {
      // Initialize clock
      var clock = game_clock.GameClock.init();
      defer clock.deinit();
      
      // Start the clock
      clock.start();
      
      // Run for 10 seconds of game time
      var count: u32 = 0;
      while (count < 100) : (count += 1) {
          clock.tick();
          
          const time = clock.getTime();
          std.debug.print("Q{d} - {d:0>2}:{d:0>2}\n", .{
              @enumToInt(clock.getQuarter()) + 1,
              time.minutes,
              time.seconds,
          });
          
          std.time.sleep(100_000_000); // 100ms
      }
  }
  ```
- [ ] Create game simulation example:
  - [ ] Complete game with all quarters
  - [ ] Random play generation
  - [ ] Score tracking
  - [ ] Clock management
- [ ] Implement play processing example:
  - [ ] Different play types
  - [ ] Clock behavior per play
  - [ ] Penalty handling
  - [ ] Timeout usage
- [ ] Add configuration examples:
  - [ ] Using presets
  - [ ] Custom configurations
  - [ ] Runtime updates
  - [ ] Feature flags
- [ ] Create scenario examples:
  - [ ] Two-minute drill
  - [ ] Overtime sudden death
  - [ ] End-of-game situations
  - [ ] Clock management strategies
- [ ] Document each example:
  - [ ] Purpose and learning goals
  - [ ] Key concepts demonstrated
  - [ ] Expected output
  - [ ] Variations to try

## Dependencies
- [#017](017_create_readme.md): README should reference examples

## Implementation Notes
Example categories and purposes:

1. **basic_usage.zig**
   - Target: New users
   - Shows: Init, start, stop, tick, time queries
   - Complexity: Minimal

2. **game_simulation.zig**
   - Target: Integration developers
   - Shows: Full game flow, state management
   - Complexity: Medium

3. **play_processing.zig**
   - Target: Game engine developers
   - Shows: Play outcomes, clock rules
   - Complexity: Medium

4. **configuration.zig**
   - Target: Customization needs
   - Shows: Config options, presets
   - Complexity: Low

5. **two_minute_drill.zig**
   - Target: Scenario handling
   - Shows: Special rules, warnings
   - Complexity: Medium

6. **overtime.zig**
   - Target: Extended game rules
   - Shows: OT initialization, sudden death
   - Complexity: Medium

7. **concurrent_games.zig**
   - Target: Server applications
   - Shows: Thread safety, multiple instances
   - Complexity: High

Each example should:
- Be self-contained and runnable
- Include helpful comments
- Show best practices
- Handle errors properly
- Print informative output

## Testing Requirements
- Ensure all examples compile
- Verify examples run without errors
- Check output is informative
- Test examples with different configurations
- Validate examples demonstrate stated concepts

## Estimated Time
2 hours

## Priority
🟢 Low - User education and adoption

## Category
Documentation

---
*Created: 2025-08-17*
*Status: Not Started*