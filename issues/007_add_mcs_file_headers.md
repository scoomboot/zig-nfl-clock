# Issue #007: Add MCS file headers

## Summary
Add standardized Maysara Code Style (MCS) file headers to all source files in the library.

## Description
Apply consistent file headers across all `.zig` files following the MCS specification. Headers should include file purpose, repository information, documentation links, and the signature vibe line.

## Acceptance Criteria
- [ ] Add headers to main files:
  - [ ] `lib/game_clock.zig`
  - [ ] `lib/game_clock/game_clock.zig`
  - [ ] `lib/game_clock/game_clock.test.zig`
- [ ] Add headers to utility modules:
  - [ ] `time_formatter/time_formatter.zig`
  - [ ] `time_formatter/time_formatter.test.zig`
  - [ ] `rules_engine/rules_engine.zig`
  - [ ] `rules_engine/rules_engine.test.zig`
  - [ ] `play_handler/play_handler.zig`
  - [ ] `play_handler/play_handler.test.zig`
- [ ] Each header must include:
  - [ ] File name and brief description
  - [ ] Repository URL
  - [ ] Documentation URL (if applicable)
  - [ ] Author GitHub profile
  - [ ] "Vibe coded by Scoom." signature
- [ ] Headers must use consistent formatting:
  - [ ] Comment style: `//` for all lines
  - [ ] Blank comment line after header
  - [ ] Proper spacing and alignment

## Dependencies
- ✅ [#004](004_time_management_module.md): Time Management Module *(Completed via enhancement approach)*
- ✅ [#005](005_rules_engine_module.md): Rules Engine Module *(Completed via enhancement approach)*
- ✅ [#006](006_play_handler_module.md): Play Handler Module *(Completed via enhancement approach)*
- 🔴 [#027](027_fix_test_compilation_errors.md): Utility modules must be functional before headers can be properly added

## Implementation Notes
Template for file headers:
```zig
// game_clock.zig — NFL game clock management library
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/game_clock
// author : https://github.com/fisty
//
// Vibe coded by Scoom.
```

Adjust the description line for each file:
- Main entry: "NFL game clock management library"
- Core implementation: "Core game clock implementation"
- Tests: "Game clock unit tests"
- Time formatter: "Time display and formatting utilities"
- Rules engine: "NFL clock rules implementation"
- Play handler: "Play outcome processing"

## Testing Requirements
- Verify all files have headers
- Check header format consistency
- Ensure URLs are correct
- Validate comment style

## Reference
- MCS documentation: `/home/fisty/code/zig-nfl-clock/docs/MCS.md`
- Section: File Headers

## Estimated Time
30 minutes

## Priority
🟡 Medium - Code quality and consistency

## Category
MCS Compliance

---
*Created: 2025-08-17*
*Status: Not Started*