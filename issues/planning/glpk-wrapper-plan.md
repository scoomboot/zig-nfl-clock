# GLPK Zig Wrapper Implementation Plan

## Overview
This document outlines the plan for building a Zig wrapper for the GNU Linear Programming Kit (GLPK), focusing on the core LP/MIP solver interface. GLPK is a powerful open-source library for solving large-scale linear programming (LP), mixed integer programming (MIP), and related optimization problems.

## Project Goals
- Create a safe, idiomatic Zig wrapper for GLPK's C API
- Focus initially on core LP/MIP solver functionality
- Provide both low-level (direct C bindings) and high-level (Zig-friendly) interfaces
- Ensure memory safety and proper error handling
- Maintain performance parity with the C library

## Phase 1: Setup & Foundation

### 1.1 System Dependencies
- Install GLPK development library:
  - Ubuntu/Debian: `apt-get install libglpk-dev`
  - macOS: `brew install glpk`
  - Windows: Download pre-built binaries or build from source
- Verify installation by locating `glpk.h` header file

### 1.2 Project Structure
```
zig-glpk/
├── build.zig              # Build configuration
├── build.zig.zon          # Package dependencies
├── lib/
│   ├── lib.zig           # Main library entry point
│   ├── c/
│   │   ├── c.zig         # C module entry point
│   │   └── utils/
│   │       └── glpk/
│   │           ├── glpk.zig       # GLPK C bindings and imports
│   │           └── glpk.test.zig  # GLPK bindings tests
│   └── core/
│       ├── core.zig      # Core module entry point
│       └── utils/
│           ├── problem/
│           │   ├── problem.zig       # Problem struct and management
│           │   └── problem.test.zig  # Problem tests
│           ├── solver/
│           │   ├── solver.zig        # LP/MIP solver interfaces
│           │   └── solver.test.zig   # Solver tests
│           └── types/
│               ├── types.zig         # Zig-friendly type definitions
│               └── types.test.zig    # Types tests
├── docs/
│   ├── MCS.md            # Maysara Code Style guidelines
│   ├── MCS_AUTOMATION.md # Code style automation
│   └── brain-storm/      # Planning documents
│       └── glpk-wrapper-plan.md
├── issues/               # Issue tracking
│   ├── 000_index.md
│   └── 001_issue.md
└── zig-out/              # Build output
    └── lib/
        ├── libio.a
        └── liblib.a
```

### 1.3 Build Configuration
Configure `build.zig` to:
- Link with GLPK library (`-lglpk`)
- Include GLPK headers path
- Support cross-platform builds
- Enable testing infrastructure

## Phase 2: Core Types & Problem Management

### 2.1 C Bindings Layer (`lib/c/glpk.zig`)
```zig
// Import GLPK C API
pub const c = @cImport({
    @cInclude("glpk.h");
});

// Re-export common constants
pub const GLP_MIN = c.GLP_MIN;
pub const GLP_MAX = c.GLP_MAX;
pub const GLP_FR = c.GLP_FR;   // Free variable
pub const GLP_LO = c.GLP_LO;   // Lower bound
pub const GLP_UP = c.GLP_UP;   // Upper bound
pub const GLP_DB = c.GLP_DB;   // Double bound
pub const GLP_FX = c.GLP_FX;   // Fixed variable
```

### 2.2 Zig-Friendly Types (`lib/core/types.zig`)
```zig
pub const OptimizationDirection = enum {
    minimize,
    maximize,
    
    pub fn toGLPK(self: @This()) c_int {
        return switch (self) {
            .minimize => GLP_MIN,
            .maximize => GLP_MAX,
        };
    }
};

pub const BoundType = enum {
    free,        // -∞ < x < +∞
    lower,       // lb ≤ x < +∞
    upper,       // -∞ < x ≤ ub
    double,      // lb ≤ x ≤ ub
    fixed,       // x = lb = ub
};

pub const VariableKind = enum {
    continuous,
    integer,
    binary,
};

pub const SolutionStatus = enum {
    optimal,
    feasible,
    infeasible,
    no_feasible,
    unbounded,
    undefined,
};
```

### 2.3 Problem Structure (`lib/core/problem.zig`)
```zig
pub const Problem = struct {
    ptr: *c.glp_prob,
    
    pub fn init(allocator: Allocator) !Problem {
        // Create new GLPK problem
    }
    
    pub fn deinit(self: *Problem) void {
        // Free GLPK problem
    }
    
    pub fn setName(self: *Problem, name: []const u8) !void {}
    pub fn setObjectiveDirection(self: *Problem, dir: OptimizationDirection) void {}
    
    // Row (constraint) management
    pub fn addRows(self: *Problem, count: usize) !void {}
    pub fn setRowName(self: *Problem, row: usize, name: []const u8) !void {}
    pub fn setRowBounds(self: *Problem, row: usize, bound_type: BoundType, lb: f64, ub: f64) !void {}
    
    // Column (variable) management
    pub fn addColumns(self: *Problem, count: usize) !void {}
    pub fn setColumnName(self: *Problem, col: usize, name: []const u8) !void {}
    pub fn setColumnBounds(self: *Problem, col: usize, bound_type: BoundType, lb: f64, ub: f64) !void {}
    pub fn setObjectiveCoefficient(self: *Problem, col: usize, coef: f64) void {}
    
    // Matrix loading (sparse format)
    pub fn loadMatrix(self: *Problem, data: SparseMatrix) !void {}
};
```

## Phase 3: LP Solver Interface

### 3.1 Simplex Solver Configuration
```zig
pub const SimplexOptions = struct {
    presolve: bool = true,
    method: enum { primal, dual, dual_primal } = .dual_primal,
    pricing: enum { standard, steepest_edge } = .steepest_edge,
    ratio_test: enum { standard, harris } = .harris,
    time_limit: ?f64 = null,  // seconds
    iteration_limit: ?usize = null,
};
```

### 3.2 LP Solver Implementation (`lib/core/solver.zig`)
```zig
pub const SimplexSolver = struct {
    options: SimplexOptions,
    
    pub fn init(options: SimplexOptions) SimplexSolver {
        return .{ .options = options };
    }
    
    pub fn solve(self: *SimplexSolver, problem: *Problem) !SolutionStatus {
        // Configure GLPK parameters
        // Call glp_simplex()
        // Return solution status
    }
};

// Solution retrieval methods for Problem
pub fn getSolutionStatus(self: *const Problem) SolutionStatus {}
pub fn getObjectiveValue(self: *const Problem) f64 {}
pub fn getColumnPrimal(self: *const Problem, col: usize) f64 {}
pub fn getRowPrimal(self: *const Problem, row: usize) f64 {}
pub fn getColumnDual(self: *const Problem, col: usize) f64 {}
pub fn getRowDual(self: *const Problem, row: usize) f64 {}
```

### 3.3 Interior Point Solver (Optional)
```zig
pub const InteriorPointSolver = struct {
    // Similar structure to SimplexSolver
    // Uses glp_interior() instead
};
```

## Phase 4: MIP Solver Interface

### 4.1 MIP Extensions to Problem
```zig
// Additional methods for Problem struct
pub fn setColumnKind(self: *Problem, col: usize, kind: VariableKind) !void {
    // Map to GLP_CV (continuous), GLP_IV (integer), GLP_BV (binary)
}
```

### 4.2 MIP Solver Configuration
```zig
pub const MIPOptions = struct {
    presolve: bool = true,
    branching: enum { first_fractional, last_fractional, most_fractional, driebeek_tomlin } = .driebeek_tomlin,
    backtracking: enum { depth_first, breadth_first, best_local, best_projection } = .best_local,
    preprocessing: enum { none, root, all } = .all,
    cuts: bool = true,
    time_limit: ?f64 = null,
    mip_gap: f64 = 0.0,  // relative MIP gap tolerance
};
```

### 4.3 MIP Solver Implementation
```zig
pub const MIPSolver = struct {
    options: MIPOptions,
    
    pub fn init(options: MIPOptions) MIPSolver {
        return .{ .options = options };
    }
    
    pub fn solve(self: *MIPSolver, problem: *Problem) !SolutionStatus {
        // First solve LP relaxation with glp_simplex()
        // Then solve MIP with glp_intopt()
        // Return solution status
    }
};

// MIP-specific solution retrieval
pub fn getMIPStatus(self: *const Problem) SolutionStatus {}
pub fn getMIPObjectiveValue(self: *const Problem) f64 {}
pub fn getMIPColumnValue(self: *const Problem, col: usize) f64 {}
pub fn getMIPRowValue(self: *const Problem, row: usize) f64 {}
```

## Phase 5: Testing & Examples

### 5.1 Unit Tests
- Test each module independently:
  - Type conversions (Zig ↔ GLPK)
  - Problem creation and configuration
  - Matrix loading with various sparse formats
  - Solver options configuration
  - Error handling for invalid inputs

### 5.2 Integration Tests
Small test problems with known solutions:

#### Example: Simple LP Problem
```zig
// Maximize: 3x + 2y
// Subject to:
//   2x + y ≤ 18
//   2x + 3y ≤ 42
//   3x + y ≤ 24
//   x, y ≥ 0
test "simple LP problem" {
    var problem = try Problem.init(allocator);
    defer problem.deinit();
    
    try problem.setName("Simple LP");
    problem.setObjectiveDirection(.maximize);
    
    // Add variables
    try problem.addColumns(2);
    try problem.setColumnName(0, "x");
    try problem.setColumnBounds(0, .lower, 0, 0);
    try problem.setObjectiveCoefficient(0, 3);
    
    try problem.setColumnName(1, "y");
    try problem.setColumnBounds(1, .lower, 0, 0);
    try problem.setObjectiveCoefficient(1, 2);
    
    // Add constraints
    try problem.addRows(3);
    // ... set row bounds and load matrix
    
    var solver = SimplexSolver.init(.{});
    const status = try solver.solve(&problem);
    
    try expectEqual(status, .optimal);
    try expectApproxEq(problem.getObjectiveValue(), 33.0);
}
```

#### Example: Simple MIP Problem (Knapsack)
```zig
test "knapsack problem" {
    // Binary knapsack problem
    // Items with values and weights
    // Maximize value subject to weight constraint
}
```

### 5.3 Example Programs
Create standalone examples in `examples/` directory:
- `diet_problem.zig` - Classic diet optimization
- `transportation.zig` - Transportation problem
- `knapsack.zig` - 0-1 knapsack problem
- `production_planning.zig` - Multi-period production planning

## Phase 6: Polish & Optimization

### 6.1 Error Handling
- Create custom error set for GLPK operations
- Map GLPK error codes to Zig errors
- Provide helpful error messages
- Handle memory allocation failures gracefully

### 6.2 Memory Management
- Ensure all GLPK resources are properly freed
- Use defer for cleanup
- Consider arena allocators for temporary data
- Verify no memory leaks with valgrind

### 6.3 Performance Considerations
- Minimize allocations in hot paths
- Use appropriate data structures for sparse matrices
- Benchmark against C implementation
- Profile and optimize bottlenecks

### 6.4 Documentation
- Generate API documentation from doc comments
- Write user guide with examples
- Create migration guide from C API
- Document performance characteristics

### 6.5 CI/CD Setup
- GitHub Actions workflow for:
  - Building on multiple platforms
  - Running test suite
  - Checking code formatting
  - Generating documentation
- Release automation

## API Design Principles

### Safety First
- No raw pointer manipulation in public API
- Bounds checking for array access
- Null-safety through optionals
- Error unions for fallible operations

### Ergonomics
- Intuitive naming following Zig conventions
- Builder pattern for complex configurations
- Sensible defaults for all options
- Clear separation between low-level and high-level APIs

### Performance
- Zero-cost abstractions where possible
- Minimal overhead over C API
- Efficient memory usage
- Support for large-scale problems

## Future Enhancements (Out of Initial Scope)

1. **Advanced Features**:
   - Network flow algorithms
   - Sensitivity analysis
   - Parametric analysis
   - Gomory cuts configuration

2. **File I/O**:
   - MPS format reader/writer
   - CPLEX LP format support
   - GLPK native format support
   - Solution file export

3. **Modeling Language**:
   - GNU MathProg support
   - DSL for problem specification

4. **Parallel Solving**:
   - Multi-threaded branch-and-bound
   - Distributed solving

5. **Additional Solvers**:
   - Exact arithmetic solver
   - Network simplex
   - Cost scaling algorithm

## Dependencies and Requirements

### Minimum Requirements
- Zig 0.11.0 or later
- GLPK 4.65 or later
- C compiler (for GLPK if building from source)

### Optional Dependencies
- Valgrind (for memory leak detection)
- gprof/perf (for profiling)
- Doxygen (for C API documentation reference)

## Timeline Estimate

- **Phase 1**: 1-2 days (setup and basic structure)
- **Phase 2**: 2-3 days (core types and problem management)
- **Phase 3**: 2-3 days (LP solver interface)
- **Phase 4**: 2-3 days (MIP solver interface)
- **Phase 5**: 3-4 days (testing and examples)
- **Phase 6**: 2-3 days (polish and optimization)

**Total**: 2-3 weeks for initial release

## Success Criteria

1. Successfully solve reference LP/MIP problems
2. Performance within 5% of C API
3. No memory leaks or safety issues
4. Comprehensive test coverage (>80%)
5. Clear, complete documentation
6. Working examples for common use cases

## References

- [GLPK Official Documentation](https://www.gnu.org/software/glpk/)
- [GLPK Reference Manual (PDF)](https://www.gnu.org/software/glpk/glpk.pdf)
- [GLPK Wikibook](https://en.wikibooks.org/wiki/GLPK)
- [Zig Language Reference](https://ziglang.org/documentation/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)