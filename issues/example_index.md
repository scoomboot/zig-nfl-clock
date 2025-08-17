# GLPK Zig Wrapper - Issue Index

## Active Issues

### Phase 1: Setup & Foundation (Days 1-2)
- ✅ [#001](001_issue.md): Install and verify GLPK system dependencies
- ✅ [#002](002_issue.md): Create project structure and directories → [#001](001_issue.md)
- ✅ [#003](003_issue.md): Configure build.zig for GLPK linking → [#001](001_issue.md), [#002](002_issue.md)
- ✅ [#028](028_issue.md): Fix critical cross-platform build configuration → [#003](003_issue.md)

### Critical Fixes (Immediate)
- ✅ [#029](029_issue.md): Restructure module directory to comply with MCS rules → [#006](006_issue.md)
- ✅ [#030](030_issue.md): Fix GLPK array pointer handling in setMatrixRow → [#004](004_issue.md), [#006](006_issue.md)

### Phase 2: Core Types & Problem Management (Days 3-5)
- ✅ [#004](004_issue.md): Implement C bindings layer for GLPK → [#002](002_issue.md), [#003](003_issue.md)
- ✅ [#005](005_issue.md): Define Zig-friendly type definitions → [#004](004_issue.md)
- ✅ [#006](006_issue.md): Implement Problem struct with basic management → [#004](004_issue.md), [#005](005_issue.md)
- ✅ [#007](007_issue.md): Implement row (constraint) management methods → [#006](006_issue.md), [#029](029_issue.md)
- ✅ [#008](008_issue.md): Implement column (variable) management methods → [#006](006_issue.md), [#029](029_issue.md)
- 🟡 [#009](009_issue.md): Implement sparse matrix loading → [#006](006_issue.md), [#007](007_issue.md), [#008](008_issue.md), [#030](030_issue.md)

### Phase 3: LP Solver Interface (Days 6-8)
- 🔴 [#010](010_issue.md): Define SimplexOptions configuration structure → [#005](005_issue.md)
- 🔴 [#011](011_issue.md): Implement SimplexSolver with solve method → [#006](006_issue.md), [#010](010_issue.md)
- 🟡 [#012](012_issue.md): Add LP solution retrieval methods → [#006](006_issue.md), [#011](011_issue.md)
- 🟢 [#013](013_issue.md): Implement Interior Point Solver (optional) → [#011](011_issue.md), [#012](012_issue.md)

### Phase 4: MIP Solver Interface (Days 9-11)
- 🟡 [#014](014_issue.md): Add MIP extensions to Problem struct → [#006](006_issue.md), [#008](008_issue.md)
- 🟡 [#015](015_issue.md): Define MIPOptions configuration structure → [#010](010_issue.md)
- 🔴 [#016](016_issue.md): Implement MIPSolver with solve method → [#011](011_issue.md), [#014](014_issue.md), [#015](015_issue.md)
- 🟡 [#017](017_issue.md): Add MIP-specific solution retrieval methods → [#016](016_issue.md)

### Phase 5: Testing & Examples (Days 12-15)
- ✅ [#018](018_issue.md): Create unit tests for type conversions and utilities → [#005](005_issue.md)
- 🔴 [#019](019_issue.md): Create unit tests for Problem management → [#006](006_issue.md), [#007](007_issue.md), [#008](008_issue.md), [#009](009_issue.md)
- 🟡 [#020](020_issue.md): Create integration test for simple LP problem → [#011](011_issue.md), [#012](012_issue.md)
- 🟡 [#021](021_issue.md): Create integration test for MIP problem → [#016](016_issue.md), [#017](017_issue.md)
- 🟢 [#022](022_issue.md): Create example programs → [#020](020_issue.md), [#021](021_issue.md)

### Phase 6: Polish & Optimization (Days 16-18)
- 🔴 [#023](023_issue.md): Implement custom error handling → [#004](004_issue.md), [#006](006_issue.md)
- 🟡 [#024](024_issue.md): Add memory management verification → [#019](019_issue.md), [#020](020_issue.md), [#021](021_issue.md)
- 🟡 [#025](025_issue.md): Performance benchmarking and optimization → [#020](020_issue.md), [#021](021_issue.md)
- 🟢 [#026](026_issue.md): Write comprehensive documentation → [#022](022_issue.md)
- 🟢 [#027](027_issue.md): Set up CI/CD pipeline → [#018](018_issue.md), [#019](019_issue.md), [#020](020_issue.md), [#021](021_issue.md)

---

## Priority Legend
- 🔴 **Critical**: Core functionality required for basic operation
- 🟡 **Medium**: Important features for full functionality
- 🟢 **Low**: Nice-to-have features and polish

## Status Legend
- 🔴/🟡/🟢 **Not Started**: Issue not yet begun (color indicates priority)
- 🚧 **In Progress**: Currently being worked on
- ✅ **Completed**: Issue fully resolved

## Dependencies
Issues with arrows (→) indicate dependencies. Complete prerequisite issues first.

## Implementation Order

### Suggested Sequence
1. **Foundation** (Critical): Complete issues #001-#003 to establish build environment
2. **Core Infrastructure** (Critical): Complete issues #004-#006 for basic GLPK integration
3. **Problem Building** (Medium): Complete issues #007-#009 for problem construction
4. **LP Solving** (Critical): Complete issues #010-#012 for basic solving capability
5. **MIP Extensions** (Medium): Complete issues #014-#017 for integer programming
6. **Testing** (Critical): Complete issues #018-#021 for validation
7. **Polish** (Low): Complete issues #022-#027 for production readiness

### Parallel Work Opportunities
Once core infrastructure is complete:
- Testing (#018-#019) can proceed alongside solver implementation
- Documentation (#026) can begin once basic functionality exists
- Examples (#022) can be developed incrementally

## Success Metrics
Per the implementation plan, success is measured by:
1. Successfully solving reference LP/MIP problems
2. Performance within 5% of C API
3. No memory leaks or safety issues
4. Comprehensive test coverage (>80%)
5. Clear, complete documentation
6. Working examples for common use cases

## Notes
- Each phase builds upon the previous one
- Core C bindings (#004) are essential for all subsequent work
- Optional features (Interior Point #013) can be deferred if time constraints arise
- MIP functionality depends on LP implementation working correctly
- Performance optimization should only occur after correctness is verified