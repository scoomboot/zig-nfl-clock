// throughput.zig — Throughput benchmarks for NFL game clock
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/throughput
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const benchmark = @import("benchmark.zig");
    const game_clock = @import("game_clock");
    const GameClock = game_clock.GameClock;
    const PlayOutcome = game_clock.PlayOutcome;
    const Quarter = game_clock.Quarter;

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Measures ticks per second throughput.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    /// - `duration_ms`: Test duration in milliseconds
    ///
    /// __Return__
    ///
    /// - Ticks per second achieved
    pub fn measureTicksPerSecond(allocator: std.mem.Allocator, duration_ms: u64) !f64 {
        var clock = GameClock.init(allocator);
        try clock.start();
        
        const start = std.time.milliTimestamp();
        const end_time = start + @as(i64, @intCast(duration_ms));
        var tick_count: u64 = 0;
        
        while (std.time.milliTimestamp() < end_time) {
            try clock.tick();
            tick_count += 1;
            
            // Reset if quarter ends
            if (clock.time_remaining == 0) {
                clock.time_remaining = 900;
            }
        }
        
        const actual_duration = std.time.milliTimestamp() - start;
        return @as(f64, @floatFromInt(tick_count)) * 1000.0 / @as(f64, @floatFromInt(actual_duration));
    }

    /// Measures plays per second throughput.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    /// - `duration_ms`: Test duration in milliseconds
    ///
    /// __Return__
    ///
    /// - Plays per second achieved
    pub fn measurePlaysPerSecond(allocator: std.mem.Allocator, duration_ms: u64) !f64 {
        var clock = GameClock.init(allocator);
        try clock.start();
        
        const outcomes = [_]PlayOutcome{
            .{ .yards_gained = 5, .first_down = false, .touchdown = false, .out_of_bounds = false, .incomplete_pass = false, .penalty = null, .turnover = false, .two_point_attempt = false, .safety = false },
            .{ .yards_gained = 12, .first_down = true, .touchdown = false, .out_of_bounds = true, .incomplete_pass = false, .penalty = null, .turnover = false, .two_point_attempt = false, .safety = false },
            .{ .yards_gained = 0, .first_down = false, .touchdown = false, .out_of_bounds = false, .incomplete_pass = true, .penalty = null, .turnover = false, .two_point_attempt = false, .safety = false },
            .{ .yards_gained = 45, .first_down = true, .touchdown = true, .out_of_bounds = false, .incomplete_pass = false, .penalty = null, .turnover = false, .two_point_attempt = false, .safety = false },
            .{ .yards_gained = -3, .first_down = false, .touchdown = false, .out_of_bounds = false, .incomplete_pass = false, .penalty = null, .turnover = true, .two_point_attempt = false, .safety = false },
        };
        
        const start = std.time.milliTimestamp();
        const end_time = start + @as(i64, @intCast(duration_ms));
        var play_count: u64 = 0;
        var outcome_index: usize = 0;
        
        while (std.time.milliTimestamp() < end_time) {
            try clock.processPlayOutcome(outcomes[outcome_index]);
            play_count += 1;
            outcome_index = (outcome_index + 1) % outcomes.len;
            
            // Reset play clock
            clock.play_clock = 40;
            
            // Reset game if ended
            if (clock.time_remaining == 0 and clock.quarter == .fourth) {
                clock.reset();
                try clock.start();
            }
        }
        
        const actual_duration = std.time.milliTimestamp() - start;
        return @as(f64, @floatFromInt(play_count)) * 1000.0 / @as(f64, @floatFromInt(actual_duration));
    }

    /// Measures concurrent operations per second.
    ///
    /// Tests mixed operations (ticks, plays, queries) throughput.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    /// - `duration_ms`: Test duration in milliseconds
    ///
    /// __Return__
    ///
    /// - Operations per second achieved
    pub fn measureConcurrentOpsPerSecond(allocator: std.mem.Allocator, duration_ms: u64) !f64 {
        var clock = GameClock.init(allocator);
        try clock.start();
        var buffer: [16]u8 = undefined;
        
        const outcome = PlayOutcome{
            .yards_gained = 7,
            .first_down = false,
            .touchdown = false,
            .out_of_bounds = false,
            .incomplete_pass = false,
            .penalty = null,
            .turnover = false,
            .two_point_attempt = false,
            .safety = false,
        };
        
        const start = std.time.milliTimestamp();
        const end_time = start + @as(i64, @intCast(duration_ms));
        var ops_count: u64 = 0;
        var op_selector: u8 = 0;
        
        while (std.time.milliTimestamp() < end_time) {
            switch (op_selector % 10) {
                0...5 => {
                    // 60% ticks
                    try clock.tick();
                    if (clock.time_remaining == 0) {
                        clock.time_remaining = 900;
                    }
                },
                6...7 => {
                    // 20% plays
                    try clock.processPlayOutcome(outcome);
                    clock.play_clock = 40;
                },
                8 => {
                    // 10% state queries
                    _ = clock.getQuarter();
                    _ = clock.getTimeRemaining();
                    _ = clock.getPlayClock();
                },
                9 => {
                    // 10% time formatting
                    _ = clock.getTimeString(&buffer);
                },
                else => unreachable,
            }
            
            ops_count += 1;
            op_selector +%= 1;
        }
        
        const actual_duration = std.time.milliTimestamp() - start;
        return @as(f64, @floatFromInt(ops_count)) * 1000.0 / @as(f64, @floatFromInt(actual_duration));
    }

    /// Runs all throughput benchmarks.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    ///
    /// __Return__
    ///
    /// - void or error
    pub fn runBenchmarks(allocator: std.mem.Allocator) !void {
        const stdout = std.io.getStdOut().writer();
        
        try stdout.print("\nThroughput Benchmark Results\n", .{});
        try stdout.print("{s}\n", .{"=" ** 60});
        
        // Ticks per second
        {
            try stdout.print("\n  Measuring ticks per second (1 second test)...\n", .{});
            const tps = try measureTicksPerSecond(allocator, 1000);
            try stdout.print("    Ticks per second: {d:.0}\n", .{tps});
            
            // Verify goal: 1,000,000 ticks/sec
            if (tps >= 1_000_000) {
                try stdout.print("    ✓ Meets goal of 1M ticks/sec\n", .{});
            } else {
                try stdout.print("    ✗ Below goal of 1M ticks/sec\n", .{});
            }
        }
        
        // Plays per second
        {
            try stdout.print("\n  Measuring plays per second (1 second test)...\n", .{});
            const pps = try measurePlaysPerSecond(allocator, 1000);
            try stdout.print("    Plays per second: {d:.0}\n", .{pps});
            
            // Verify goal: 100,000 plays/sec
            if (pps >= 100_000) {
                try stdout.print("    ✓ Meets goal of 100K plays/sec\n", .{});
            } else {
                try stdout.print("    ✗ Below goal of 100K plays/sec\n", .{});
            }
        }
        
        // Concurrent operations per second
        {
            try stdout.print("\n  Measuring concurrent operations per second (1 second test)...\n", .{});
            const ops = try measureConcurrentOpsPerSecond(allocator, 1000);
            try stdout.print("    Mixed operations per second: {d:.0}\n", .{ops});
            try stdout.print("    (60% ticks, 20% plays, 20% queries)\n", .{});
        }
        
        try stdout.print("\n", .{});
    }

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

    test "performance: throughput: processes 1 million ticks under 1 second" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        try clock.start();
        
        const start = std.time.milliTimestamp();
        var i: u32 = 0;
        while (i < 1_000_000) : (i += 1) {
            try clock.tick();
            if (clock.time_remaining == 0) {
                clock.time_remaining = 900;
            }
        }
        const end = std.time.milliTimestamp();
        
        const duration_ms = end - start;
        try testing.expect(duration_ms < 1000);
        
        std.debug.print("\n  1M ticks in {d}ms ({d:.0} ticks/sec)\n", .{
            duration_ms,
            if (duration_ms > 0) 1_000_000_000.0 / @as(f64, @floatFromInt(duration_ms)) else 0,
        });
    }

    test "performance: throughput: processes 100k plays under 1 second" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        try clock.start();
        
        const outcome = PlayOutcome{
            .yards_gained = 5,
            .first_down = false,
            .touchdown = false,
            .out_of_bounds = false,
            .incomplete_pass = false,
            .penalty = null,
            .turnover = false,
            .two_point_attempt = false,
            .safety = false,
        };
        
        const start = std.time.milliTimestamp();
        var i: u32 = 0;
        while (i < 100_000) : (i += 1) {
            try clock.processPlayOutcome(outcome);
            clock.play_clock = 40;
        }
        const end = std.time.milliTimestamp();
        
        const duration_ms = end - start;
        try testing.expect(duration_ms < 1000);
        
        std.debug.print("\n  100K plays in {d}ms ({d:.0} plays/sec)\n", .{
            duration_ms,
            if (duration_ms > 0) 100_000_000.0 / @as(f64, @floatFromInt(duration_ms)) else 0,
        });
    }

    test "performance: throughput: sustained operations rate" {
        const allocator = testing.allocator;
        const ops_per_sec = try measureConcurrentOpsPerSecond(allocator, 100);
        
        // Should maintain high throughput with mixed operations
        try testing.expect(ops_per_sec > 500_000);
        
        std.debug.print("\n  Sustained mixed ops: {d:.0} ops/sec\n", .{ops_per_sec});
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════╝