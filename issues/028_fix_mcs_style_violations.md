# Issue #028: Fix MCS style violations in test files

## Summary
Test files have minor MCS compliance violations related to import organization and indentation consistency that should be addressed for code quality.

## Description
During MCS compliance check following Issue #025 resolution, analysis revealed 8 style violations across 2 test files. While implementation files show excellent MCS compliance, test files need minor adjustments to achieve full compliance.

## Current State

**Overall Compliance: 75%** (2 out of 4 files fully compliant)

### Compliant Files (0 violations):
- ✅ `lib/game_clock/utils/play_handler/play_handler.zig`
- ✅ `lib/game_clock/utils/rules_engine/rules_engine.zig`

### Non-Compliant Files (8 total violations):

#### `lib/game_clock/utils/play_handler/play_handler.test.zig` (4 violations):
1. **🟡 HIGH**: Import organization - std import not properly placed in PACK section
2. **🟡 HIGH**: Code indentation - imports not indented within PACK section  
3. **🟡 MEDIUM**: Test naming - undefined `run_inbounds` PlayType reference (line 154)
4. **🟡 MEDIUM**: Indentation consistency in test blocks (lines 202-212)

#### `lib/game_clock/utils/rules_engine/rules_engine.test.zig` (4 violations):
1. **🟡 HIGH**: Import organization - std import should be first in PACK section
2. **🟡 MEDIUM**: Code indentation - complex imports not properly organized
3. **🟡 MEDIUM**: Struct initialization indentation inconsistency (lines 202-229)
4. **🟢 LOW**: Missing documentation for test utility structs (lines 34-52)

## Root Cause Analysis
The violations stem from:
- Import statements not following MCS organization rules
- Inconsistent application of 4-space indentation within sections
- Missing documentation for some test utilities
- One undefined enum reference

## Acceptance Criteria
- [ ] All imports properly organized within PACK sections with 4-space indentation
- [ ] Consistent 4-space indentation throughout all sections
- [ ] Fix undefined PlayType reference (`run_inbounds` → valid enum value)
- [ ] Add documentation for test utility structures
- [ ] Achieve 100% MCS compliance across all files

## Dependencies
- 🔴 Blocked by: [#027](027_fix_test_compilation_errors.md) - Critical blocker for utility module functionality
- ✅ Related to: [#025](025_fix_section_indentation.md) - Complete

## Implementation Notes

### Priority 1 (High Severity):
1. **Import Organization**: 
   - Move std imports to first position in PACK sections
   - Ensure all imports are indented by 4 spaces within sections

2. **Code Indentation**:
   - Apply consistent 4-space indentation within all sections
   - Fix inconsistent struct initialization patterns

### Priority 2 (Medium Severity):
3. **Enum Validation**:
   - Replace `run_inbounds` with valid PlayType (e.g., `run_up_middle`)
   - Verify all enum references are valid

### Priority 3 (Low Severity):
4. **Documentation**:
   - Add doc comments for PlayScenario and PenaltyScenario structs

## Testing Requirements
- Run MCS compliance check after fixes
- Ensure changes don't affect compilation or test functionality
- Verify 100% compliance score achieved

## Reference
- MCS compliance analysis conducted: 2025-08-17
- MCS documentation: `/home/fisty/code/zig-nfl-clock/docs/MCS.md`
- Analysis shows implementation files as excellent MCS examples

## Estimated Time
30 minutes (minor style fixes only)

## Priority
🟢 Low - Code quality improvement, deferred until after critical #027 completion

**Priority Rationale**: While MCS compliance is important for code quality, this issue is purely cosmetic and does not block library functionality. Priority lowered to focus development resources on Issue #027, which is the critical blocker for utility module functionality.

## Category
Code Quality / MCS Compliance

---
*Created: 2025-08-17*
*Updated: 2025-08-17 (Post-Issue #026 - Priority adjusted, blocked by #027)*
*Status: Deferred - Waiting for Issue #027 completion*