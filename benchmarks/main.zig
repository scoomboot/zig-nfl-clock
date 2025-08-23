// main.zig — Main benchmark runner for NFL game clock
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/main
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const reporter = @import("reporter.zig");

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Main entry point for benchmark runner.
    ///
    /// Executes all benchmark suites and generates comprehensive report.
    ///
    /// __Return__
    ///
    /// - Error code or success
    pub fn main() !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        const stdout = std.io.getStdOut().writer();
        
        try stdout.print("\n", .{});
        try stdout.print("╔══════════════════════════════════════════════════════════════╗\n", .{});
        try stdout.print("║         NFL Game Clock Library - Performance Benchmarks       ║\n", .{});
        try stdout.print("╚══════════════════════════════════════════════════════════════╝\n", .{});
        try stdout.print("\n", .{});
        
        const start_time = std.time.milliTimestamp();
        
        try stdout.print("Starting benchmark suite...\n", .{});
        try stdout.print("{s}\n\n", .{"=" ** 60});
        
        // Run all benchmarks and generate report
        try reporter.runAllBenchmarks(allocator);
        
        const total_time = std.time.milliTimestamp() - start_time;
        
        try stdout.print("\n{s}\n", .{"=" ** 60});
        try stdout.print("Benchmark suite completed in {d}ms\n", .{total_time});
        try stdout.print("\n", .{});
    }

// ╚════════════════════════════════════════════════════════════════════════════════╝