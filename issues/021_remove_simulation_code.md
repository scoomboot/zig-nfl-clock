# Issue #021: Remove simulation-specific code

## Summary
Strip out all simulation-specific code to create a pure, reusable game clock library.

## Description
Identify and remove all code that is specific to the nfl-sim game simulation, keeping only the core clock functionality. This includes removing game state management, player references, score tracking, and any other simulation-specific features.

## Acceptance Criteria
- [ ] Remove simulation-specific fields:
  - [ ] Game state references
  - [ ] Team/player data
  - [ ] Score information
  - [ ] Play-by-play logging
  - [ ] Statistics tracking
- [ ] Remove simulation methods:
  - [ ] Game state updates
  - [ ] Event dispatching
  - [ ] Network synchronization
  - [ ] Save/load game state
  - [ ] Replay functionality
- [ ] Simplify data structures:
  - [ ] Remove unnecessary complexity
  - [ ] Flatten nested structures
  - [ ] Eliminate circular references
- [ ] Clean up interfaces:
  - [ ] Remove callbacks/hooks
  - [ ] Simplify parameter lists
  - [ ] Remove optional features
- [ ] Refactor remaining code:
  - [ ] Rename simulation terms
  - [ ] Generalize functionality
  - [ ] Improve abstraction
- [ ] Document removals:
  - [ ] List what was removed
  - [ ] Explain why removed
  - [ ] Note any impacts

## Dependencies
- [#020](020_dependency_analysis.md): Dependencies analyzed

## Implementation Notes
Common simulation-specific removals:

```zig
// REMOVE: Game state management
pub const GameState = struct {
    home_score: u32,
    away_score: u32,
    possession: Team,
    field_position: i32,
    // ... more game data
};

// REMOVE: Event system integration
fn notifyObservers(self: *GameClock, event: ClockEvent) void {
    for (self.observers) |observer| {
        observer.handleClockEvent(event);
    }
}

// REMOVE: Play-by-play logging
fn logPlay(self: *GameClock, play: Play) void {
    self.play_log.append(play);
    self.stats.updateWithPlay(play);
}

// SIMPLIFY: From complex to simple
// Before:
pub fn handlePlayOutcome(
    self: *GameClock,
    play: Play,
    game_state: *GameState,
    stats: *Statistics,
    network: *NetworkSync,
) void {
    // Complex implementation
}

// After:
pub fn handlePlayOutcome(self: *GameClock, outcome: PlayOutcome) void {
    // Simple, focused implementation
}
```

Areas to check:
1. **Struct fields**: Remove game-specific data
2. **Method parameters**: Simplify interfaces
3. **Return types**: Remove complex results
4. **Error handling**: Remove game-specific errors
5. **Configuration**: Remove game settings
6. **Tests**: Remove simulation tests

Keep only:
- Core clock functionality
- NFL timing rules
- Play clock management
- Quarter/game progression
- Time calculations

## Testing Requirements
- Ensure all core functionality preserved
- Verify no simulation references remain
- Check API is clean and simple
- Test library works standalone
- Validate no broken dependencies

## Source Reference
- Review entire `/home/fisty/code/nfl-sim/src/game_clock.zig`
- Identify simulation-specific sections

## Estimated Time
2 hours

## Priority
🟡 Medium - Library purity

## Category
Migration & Cleanup

---
*Created: 2025-08-17*
*Status: Not Started*