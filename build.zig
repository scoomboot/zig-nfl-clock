// build.zig — Build configuration for NFL game clock library
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/build
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const Build = @import("std").Build;

// ╚════════════════════════════════════════════════════════════════════════════════════╝

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
        const lib_mod = b.createModule(.{
            .root_source_file = b.path("lib/game_clock.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = b.standardOptimizeOption(.{}),
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
    }

// ╚════════════════════════════════════════════════════════════════════════════════════╝
