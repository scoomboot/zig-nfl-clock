# Issue #037: Add missing LICENSE file

## Summary
Create the LICENSE file that is referenced in README.md and build.zig.zon but doesn't exist.

## Description
The project references a LICENSE file in multiple places but the file is missing from the repository. This is a critical issue for open source distribution as it leaves the legal status of the code unclear. The README states the project uses the MIT License.

## Current State
- README.md references LICENSE file in badge and license section
- build.zig.zon includes "LICENSE" in the paths array
- No LICENSE file exists in the repository root

## Acceptance Criteria
- [ ] Create LICENSE file in repository root
- [ ] Use standard MIT License text
- [ ] Include copyright year (2025) and author information
- [ ] Verify file is properly tracked in git
- [ ] Ensure build.zig.zon paths array is accurate

## Implementation Notes
Standard MIT License template:
```
MIT License

Copyright (c) 2025 [Author Name]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Dependencies
None - This is a standalone documentation task

## Testing Requirements
- Verify LICENSE file exists
- Confirm it's referenced correctly in build.zig.zon
- Ensure README badge links work (if applicable)

## References
- [README.md](/home/fisty/code/zig-nfl-clock/README.md) - Line mentioning MIT License
- [build.zig.zon](/home/fisty/code/zig-nfl-clock/build.zig.zon) - Line 10 includes LICENSE in paths

## Estimated Time
5 minutes

## Priority
🔴 Critical - Legal requirement for open source distribution

## Category
Documentation / Legal

---
*Created: 2025-08-23*
*Status: Not Started*