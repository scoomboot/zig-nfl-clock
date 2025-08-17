# Issue #014: Design simplified public interface

## Summary
Create a clean, intuitive public API that hides complexity while providing full functionality.

## Description
Design and implement a simplified public interface for the game clock library. The API should be easy to use for common cases while still allowing advanced usage. Focus on clarity, consistency, and ergonomics.

## Acceptance Criteria
- [ ] Define primary API surface:
  - [ ] Simple initialization: `GameClock.init()`
  - [ ] Basic controls: `start()`, `stop()`, `pause()`, `resume()`
  - [ ] Time queries: `getTime()`, `getQuarter()`, `getPlayClock()`
  - [ ] Play handling: `processPlay(play: Play)`
- [ ] Create convenience methods:
  - [ ] `isHalftime()` - Check if at halftime
  - [ ] `isOvertime()` - Check if in overtime
  - [ ] `getRemainingTime()` - Time left in quarter
  - [ ] `getElapsedTime()` - Time elapsed in quarter
  - [ ] `formatTime()` - Get formatted time string
- [ ] Implement builder pattern:
  ```zig
  const clock = GameClock.builder()
      .quarterLength(900)  // 15 minutes
      .startQuarter(.Q1)
      .enableTwoMinuteWarning(true)
      .build();
  ```
- [ ] Simplify play processing:
  ```zig
  // Simple API
  clock.processPlay(.{ .type = .Pass, .complete = false });
  
  // Advanced API
  clock.processPlayWithContext(.{
      .play = play,
      .penalties = penalties,
      .timeouts_remaining = 2,
  });
  ```
- [ ] Hide internal complexity:
  - [ ] Make internal modules private
  - [ ] Expose only necessary types
  - [ ] Provide sensible defaults
- [ ] Ensure API consistency:
  - [ ] Consistent naming patterns
  - [ ] Predictable return types
  - [ ] Clear method grouping

## Dependencies
- [#004](004_time_management_module.md): Time management module complete
- [#005](005_rules_engine_module.md): Rules engine module complete  
- [#006](006_play_handler_module.md): Play handler module complete

## Implementation Notes
API design principles:
1. **Simple things simple**: Common operations in one call
2. **Complex things possible**: Advanced features available
3. **Discoverable**: Intuitive naming and organization
4. **Consistent**: Similar operations work similarly
5. **Safe**: Hard to misuse, clear error cases

Example public API:
```zig
// Simple usage
pub fn init() GameClock
pub fn start(self: *GameClock) void
pub fn stop(self: *GameClock) void
pub fn tick(self: *GameClock) void
pub fn processPlay(self: *GameClock, play: Play) void

// Time queries
pub fn getTime(self: *const GameClock) Time
pub fn getQuarter(self: *const GameClock) Quarter
pub fn getPlayClock(self: *const GameClock) ?u32

// State queries  
pub fn isRunning(self: *const GameClock) bool
pub fn isQuarterEnd(self: *const GameClock) bool
pub fn isGameEnd(self: *const GameClock) bool

// Advanced usage
pub fn builder() ClockBuilder
pub fn withConfig(config: ClockConfig) GameClock
pub fn processPlayWithContext(self: *GameClock, context: PlayContext) PlayResult
```

## Testing Requirements
- Test all public API methods
- Verify builder pattern works correctly
- Check convenience methods accuracy
- Validate API is hard to misuse
- Ensure internal details aren't exposed

## Estimated Time
2 hours

## Priority
🔴 Critical - Library usability

## Category
API Refinement

---
*Created: 2025-08-17*
*Status: Not Started*