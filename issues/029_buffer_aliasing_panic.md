# Issue #029: Buffer Aliasing Panic in TimeFormatter

## Summary
The `formatTimeWithContext` method in TimeFormatter causes a runtime panic due to overlapping memory buffers in `@memcpy` operation.

## Description
During testing of the time_formatter module after fixing compilation errors (#027), a critical runtime bug was discovered. The `formatTimeWithContext` method attempts to copy memory that overlaps, causing a panic with the message "@memcpy arguments alias".

## Current State

### Error Details:
```
thread 63435 panic: @memcpy arguments alias
/home/fisty/.config/Code/User/globalStorage/ziglang.vscode-zig/zig/x86_64-linux-0.14.1/lib/std/io/fixed_buffer_stream.zig:66:57: 0x108dfa9 in write (test)
            @memcpy(self.buffer[self.pos..][0..n], bytes[0..n]);
```

### Location:
- **File**: `lib/game_clock/utils/time_formatter/time_formatter.zig`
- **Line**: 244
- **Method**: `formatTimeWithContext`
- **Problematic code**:
```zig
return try std.fmt.bufPrint(&self.buffer, "{s} - Final minute", .{time_str});
```

### Root Cause Analysis:
The method is trying to format a string into `self.buffer` while `time_str` is already pointing to data within the same `self.buffer`. This creates overlapping memory regions that `@memcpy` cannot handle safely.

## Impact Assessment
- **Severity**: 🔴 **CRITICAL** - Causes runtime crash
- **Affected functionality**: Any code that calls `formatTimeWithContext` with certain parameters
- **User impact**: Application crash when displaying time with context
- **Discovery**: Found during Issue #027 testing (2025-08-17)

## Reproduction Steps
1. Create a TimeFormatter instance
2. Call `formatTimeWithContext(45, 2, false)`
3. Observe panic with "@memcpy arguments alias" error

## Acceptance Criteria
- [ ] Fix the buffer aliasing issue in `formatTimeWithContext`
- [ ] Ensure method can safely format strings without memory overlap
- [ ] Add test coverage for edge cases that trigger the issue
- [ ] Verify all other formatting methods don't have similar issues
- [ ] No performance regression from the fix

## Proposed Solution

### Option 1: Use temporary buffer
Create a separate temporary buffer for intermediate formatting operations to avoid self-referential copying.

### Option 2: Pre-allocate result space
Calculate the final string size and format directly without intermediate steps.

### Option 3: Use a different formatting approach
Avoid the `bufPrint` pattern when the source and destination buffers might overlap.

## Testing Requirements
- Unit test that previously caused the panic should pass
- Test with various time values and contexts
- Ensure thread safety if buffer is shared
- Performance testing to ensure no significant overhead

## Dependencies
- Discovered during: #027 (Test compilation errors fix)
- Related to: TimeFormatter module functionality

## Estimated Time
**2-3 hours**
- 1 hour: Implement fix for buffer aliasing
- 1 hour: Add comprehensive test coverage
- 30 min: Test other methods for similar issues

## Priority
🔴 **CRITICAL** - Runtime crash bug affecting core functionality

## Category
Runtime Bug / Memory Safety / TimeFormatter Module

---
*Created: 2025-08-17*
*Status: Not Started*
*Discovered during Issue #027 resolution*