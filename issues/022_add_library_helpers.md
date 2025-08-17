# Issue #022: Add library-specific helpers

## Summary
Create convenience functions and utilities that make the library easier to use as a standalone component.

## Description
Add helper functions, utilities, and convenience methods that enhance the library's usability. These additions should make common tasks simpler while maintaining the library's focus on clock management.

## Acceptance Criteria
- [ ] Add time formatting helpers:
  ```zig
  pub fn formatTime(self: *const GameClock) []const u8 {
      // Returns "Q1 15:00" format
  }
  
  pub fn formatPlayClock(self: *const GameClock) []const u8 {
      // Returns ":40" format
  }
  
  pub fn formatGameTime(self: *const GameClock) []const u8 {
      // Returns "1st Quarter - 15:00" format
  }
  ```
- [ ] Create state query helpers:
  ```zig
  pub fn isFirstHalf(self: *const GameClock) bool
  pub fn isSecondHalf(self: *const GameClock) bool
  pub fn isRegulationTime(self: *const GameClock) bool
  pub fn isInsideTwoMinutes(self: *const GameClock) bool
  pub fn getTimeUntilQuarterEnd(self: *const GameClock) u32
  pub fn getTimeUntilHalfEnd(self: *const GameClock) u32
  ```
- [ ] Add clock control conveniences:
  ```zig
  pub fn togglePause(self: *GameClock) void
  pub fn advanceToHalftime(self: *GameClock) void
  pub fn advanceToTwoMinuteWarning(self: *GameClock) void
  pub fn skipToNextQuarter(self: *GameClock) void
  pub fn resetQuarter(self: *GameClock) void
  ```
- [ ] Implement builder pattern helpers:
  ```zig
  pub const ClockBuilder = struct {
      pub fn new() ClockBuilder
      pub fn quarterLength(self: *ClockBuilder, seconds: u32) *ClockBuilder
      pub fn startingQuarter(self: *ClockBuilder, q: Quarter) *ClockBuilder
      pub fn withConfig(self: *ClockBuilder, config: ClockConfig) *ClockBuilder
      pub fn build(self: *ClockBuilder) GameClock
  };
  ```
- [ ] Create common scenario shortcuts:
  ```zig
  pub fn createHalftimeClock() GameClock
  pub fn createOvertimeClock() GameClock
  pub fn createTwoMinuteDrillClock() GameClock
  pub fn createEndOfGameClock() GameClock
  ```
- [ ] Add validation helpers:
  ```zig
  pub fn isValidState(self: *const GameClock) bool
  pub fn hasValidTime(self: *const GameClock) bool
  pub fn canAdvanceQuarter(self: *const GameClock) bool
  pub fn canStartPlayClock(self: *const GameClock) bool
  ```

## Dependencies
- [#014](014_design_public_interface.md): Public API defined

## Implementation Notes
Helper categories:

1. **Formatting helpers**
   - Human-readable time display
   - Different format options
   - Localization ready

2. **Query helpers**
   - Common state checks
   - Time calculations
   - Game situation detection

3. **Control helpers**
   - Shortcuts for common operations
   - Scenario setup
   - Testing utilities

4. **Builder pattern**
   ```zig
   const clock = ClockBuilder.new()
       .quarterLength(600)  // 10 minute quarters
       .startingQuarter(.Q3)
       .withConfig(Presets.practice)
       .build();
   ```

5. **Validation helpers**
   - State consistency checks
   - Pre-condition validation
   - Debug assistance

Example implementations:
```zig
pub fn formatTime(self: *const GameClock) []const u8 {
    const minutes = self.getMinutes();
    const seconds = self.getSeconds();
    return std.fmt.allocPrint(
        "Q{d} {d:0>2}:{d:0>2}",
        .{ @enumToInt(self.quarter) + 1, minutes, seconds }
    );
}

pub fn isInsideTwoMinutes(self: *const GameClock) bool {
    const remaining = self.getTimeUntilQuarterEnd();
    return remaining <= 120 and (self.quarter == .Q2 or self.quarter == .Q4);
}

pub fn createTwoMinuteDrillClock() GameClock {
    var clock = GameClock.init();
    clock.quarter = .Q4;
    clock.game_seconds = 3300;  // 14:00 in Q4 (2:00 remaining)
    return clock;
}
```

## Testing Requirements
- Test all helper functions
- Verify formatting output
- Check builder pattern works
- Validate shortcuts create correct state
- Ensure helpers don't break core functionality

## Estimated Time
2 hours

## Priority
🟢 Low - Usability enhancement

## Category
Migration & Cleanup

---
*Created: 2025-08-17*
*Status: Not Started*