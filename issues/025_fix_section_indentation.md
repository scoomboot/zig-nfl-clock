# Issue #025: Fix missing 4-space indentation within sections

## Summary
Code within MCS sections is not indented by 4 spaces as required, breaking the visual structure philosophy of MCS.

## Description
MCS Rule 2.5 requires that all code within a section be indented by 4 spaces to create visual separation between section borders and code. Currently, most files have code flush against the left margin within sections, which is a critical violation of MCS standards.

## Current State
All implementation files have this issue:
- `lib/game_clock.zig` - Only partially compliant (some sections have indentation)
- `lib/game_clock/game_clock.zig` - No indentation within sections
- `lib/game_clock/utils/time_formatter/time_formatter.zig` - No indentation within sections
- `lib/game_clock/utils/rules_engine/rules_engine.zig` - No indentation within sections
- `lib/game_clock/utils/play_handler/play_handler.zig` - No indentation within sections
- All test files - No indentation within sections

## Acceptance Criteria
- [ ] All code within PACK sections indented by 4 spaces
- [ ] All code within INIT sections indented by 4 spaces
- [ ] All code within CORE sections indented by 4 spaces
- [ ] All code within TEST sections indented by 4 spaces
- [ ] Subsections maintain the same 4-space indentation
- [ ] Empty lines between code blocks maintain indentation level
- [ ] Section borders remain at column 0

## Dependencies
- [#008](008_implement_section_organization.md): Sections must be properly defined first

## Implementation Notes
Example of correct indentation:
```zig
// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");              // 4 spaces indentation
    const testing = std.testing;             // 4 spaces indentation
                                             // blank line, no indentation needed
    const game_clock = @import("game_clock/game_clock.zig");  // 4 spaces

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub fn init() GameClock {               // 4 spaces indentation
        return .{                            // 4 spaces indentation
            .time_remaining = QUARTER_DURATION,  // 8 spaces (4 + nested)
            .quarter = .Q1,                  // 8 spaces
        };                                   // 4 spaces
    }                                        // 4 spaces

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Verify all files compile after indentation changes
- Ensure no logic changes occurred during reformatting
- Check that all tests still pass
- Validate visual structure is consistent

## Reference
- MCS documentation: `/home/fisty/code/zig-nfl-clock/docs/MCS.md` (lines 169-172)
- Rule 2.5: "All code within a section is indented by 4 spaces"
- Philosophy: "Creates visual separation between section borders and code"

## Estimated Time
1 hour

## Priority
🔴 Critical - Fundamental MCS visual structure requirement

## Category
MCS Compliance

---
*Created: 2025-08-17*
*Status: Not Started*