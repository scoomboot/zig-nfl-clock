// build.zig — Build configuration for NFL game clock library
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/build
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const Build = @import("std").Build;

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Configures the build system for the NFL clock library.
    ///
    /// Sets up the library module, static library artifact, and test runner.
    ///
    /// __Parameters__
    ///
    /// - `b`: The build object providing build configuration options
    ///
    /// __Return__
    ///
    /// - void
    pub fn build(b: *Build) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});
        
        const lib_mod = b.createModule(.{
            .root_source_file = b.path("lib/game_clock.zig"),
            .target = target,
            .optimize = optimize,
        });

        const lib = b.addLibrary(.{
            .linkage = .static,
            .name = "nflClock",
            .root_module = lib_mod,
        });

        b.installArtifact(lib);

        const lib_tests = b.addTest(.{
            .root_module = lib_mod,
        });

        const run_lib_tests = b.addRunArtifact(lib_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_tests.step);
        
        // Benchmark configuration
        const benchmark_exe = b.addExecutable(.{
            .name = "benchmarks",
            .root_source_file = b.path("benchmarks/simple_benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        });
        
        benchmark_exe.root_module.addImport("game_clock", lib_mod);
        
        const run_benchmarks = b.addRunArtifact(benchmark_exe);
        
        const benchmark_step = b.step("benchmark", "Run performance benchmarks");
        benchmark_step.dependOn(&run_benchmarks.step);
        
        // Individual benchmark test suites
        const benchmark_tests = b.addTest(.{
            .root_source_file = b.path("benchmarks/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        });
        
        benchmark_tests.root_module.addImport("game_clock", lib_mod);
        
        const run_benchmark_tests = b.addRunArtifact(benchmark_tests);
        
        const benchmark_test_step = b.step("test:benchmark", "Run benchmark tests");
        benchmark_test_step.dependOn(&run_benchmark_tests.step);
    }

// ╚════════════════════════════════════════════════════════════════════════════════╝
