// comparison.zig — Comparison benchmarks for NFL game clock
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/comparison
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const benchmark = @import("benchmark.zig");
    const game_clock = @import("game_clock");
    const GameClock = game_clock.GameClock;
    const ClockConfig = game_clock.ClockConfig;
    const PlayOutcome = game_clock.PlayOutcome;

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Comparison result between two implementations.
    const ComparisonResult = struct {
        name: []const u8,
        baseline_ns: u64,
        variant_ns: u64,
        speedup: f64,
        baseline_memory: usize,
        variant_memory: usize,
        memory_ratio: f64,
    };

    /// Naive implementation for comparison.
    ///
    /// A simplified version to establish baseline performance.
    const NaiveClock = struct {
        time_remaining: u32,
        quarter: u8,
        is_running: bool,
        play_clock: u8,
        
        fn init() NaiveClock {
            return .{
                .time_remaining = 900,
                .quarter = 1,
                .is_running = false,
                .play_clock = 40,
            };
        }
        
        fn tick(self: *NaiveClock) void {
            if (self.is_running and self.time_remaining > 0) {
                self.time_remaining -= 1;
                if (self.play_clock > 0) {
                    self.play_clock -= 1;
                }
            }
        }
        
        fn start(self: *NaiveClock) void {
            self.is_running = true;
        }
        
        fn stop(self: *NaiveClock) void {
            self.is_running = false;
        }
    };

    /// Compares optimized vs naive implementation.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    /// - `iterations`: Number of iterations
    ///
    /// __Return__
    ///
    /// - ComparisonResult with metrics
    pub fn compareImplementations(allocator: std.mem.Allocator, iterations: u32) !ComparisonResult {
        // Benchmark naive implementation
        var naive_clock = NaiveClock.init();
        naive_clock.start();
        
        const naive_start = std.time.nanoTimestamp();
        for (0..iterations) |_| {
            naive_clock.tick();
            if (naive_clock.time_remaining == 0) {
                naive_clock.time_remaining = 900;
            }
        }
        const naive_end = std.time.nanoTimestamp();
        const naive_ns: u64 = @intCast(@divFloor(naive_end - naive_start, iterations));
        
        // Benchmark optimized implementation
        var opt_clock = GameClock.init(allocator);
        try opt_clock.start();
        
        const opt_start = std.time.nanoTimestamp();
        for (0..iterations) |_| {
            try opt_clock.tick();
            if (opt_clock.time_remaining == 0) {
                opt_clock.time_remaining = 900;
            }
        }
        const opt_end = std.time.nanoTimestamp();
        const opt_ns: u64 = @intCast(@divFloor(opt_end - opt_start, iterations));
        
        return ComparisonResult{
            .name = "Optimized vs Naive",
            .baseline_ns = naive_ns,
            .variant_ns = opt_ns,
            .speedup = @as(f64, @floatFromInt(naive_ns)) / @as(f64, @floatFromInt(opt_ns)),
            .baseline_memory = @sizeOf(NaiveClock),
            .variant_memory = @sizeOf(GameClock),
            .memory_ratio = @as(f64, @floatFromInt(@sizeOf(GameClock))) / @as(f64, @floatFromInt(@sizeOf(NaiveClock))),
        };
    }

    /// Compares performance at different clock speeds.
    ///
    /// Tests real-time vs fast-forward speeds.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    ///
    /// __Return__
    ///
    /// - Comparison metrics
    pub fn compareClockSpeeds(allocator: std.mem.Allocator) !struct {
        realtime_ops_per_sec: f64,
        fast_ops_per_sec: f64,
        superfast_ops_per_sec: f64,
    } {
        var clock = GameClock.init(allocator);
        
        // Test real-time speed (1x)
        clock.config.clock_speed = .RealTime;
        try clock.start();
        
        var start = std.time.milliTimestamp();
        var ticks: u32 = 0;
        while (std.time.milliTimestamp() - start < 100) {
            try clock.tick();
            ticks += 1;
            if (clock.time_remaining == 0) {
                clock.time_remaining = 900;
            }
        }
        const realtime_ops = @as(f64, @floatFromInt(ticks)) * 10.0; // per second
        
        // Test fast speed (10x)
        clock.config.clock_speed = .Fast;
        clock.reset();
        try clock.start();
        
        start = std.time.milliTimestamp();
        ticks = 0;
        while (std.time.milliTimestamp() - start < 100) {
            try clock.tick();
            ticks += 1;
            if (clock.time_remaining == 0) {
                clock.time_remaining = 900;
            }
        }
        const fast_ops = @as(f64, @floatFromInt(ticks)) * 10.0;
        
        // Test super fast speed (60x)
        clock.config.clock_speed = .SuperFast;
        clock.reset();
        try clock.start();
        
        start = std.time.milliTimestamp();
        ticks = 0;
        while (std.time.milliTimestamp() - start < 100) {
            try clock.tick();
            ticks += 1;
            if (clock.time_remaining == 0) {
                clock.time_remaining = 900;
            }
        }
        const superfast_ops = @as(f64, @floatFromInt(ticks)) * 10.0;
        
        return .{
            .realtime_ops_per_sec = realtime_ops,
            .fast_ops_per_sec = fast_ops,
            .superfast_ops_per_sec = superfast_ops,
        };
    }

    /// Compares different configuration presets.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    ///
    /// __Return__
    ///
    /// - Performance metrics for each preset
    pub fn comparePresets(allocator: std.mem.Allocator) !void {
        const presets = [_]struct {
            name: []const u8,
            config: ClockConfig,
        }{
            .{ .name = "NFL Standard", .config = ClockConfig.Presets.nfl_standard },
            .{ .name = "NFL Playoffs", .config = ClockConfig.Presets.nfl_playoffs },
            .{ .name = "Practice Mode", .config = ClockConfig.Presets.practice_mode },
            .{ .name = "TV Broadcast", .config = ClockConfig.Presets.tv_broadcast },
            .{ .name = "Simulation", .config = ClockConfig.Presets.simulation },
        };
        
        const stdout = std.io.getStdOut().writer();
        try stdout.print("\n  Configuration Preset Performance:\n", .{});
        try stdout.print("  {s:>15} | {s:>15} | {s:>15}\n", .{
            "Preset",
            "Init Time (ns)",
            "Tick Time (ns)",
        });
        try stdout.print("  {s}\n", .{"-" ** 50});
        
        for (presets) |preset| {
            // Measure initialization time
            const init_start = std.time.nanoTimestamp();
            var clock = GameClock.init(allocator);
            clock.config = preset.config;
            const init_end = std.time.nanoTimestamp();
            const init_time = @as(u64, @intCast(init_end - init_start));
            
            // Measure tick time
            try clock.start();
            const tick_start = std.time.nanoTimestamp();
            for (0..10000) |_| {
                try clock.tick();
                if (clock.time_remaining == 0) {
                    clock.time_remaining = 900;
                }
            }
            const tick_end = std.time.nanoTimestamp();
            const tick_time = @divFloor(@as(u64, @intCast(tick_end - tick_start)), 10000);
            
            try stdout.print("  {s:>15} | {d:>15} | {d:>15}\n", .{
                preset.name,
                init_time,
                tick_time,
            });
        }
    }

    /// Runs all comparison benchmarks.
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
        
        try stdout.print("\nComparison Benchmark Results\n", .{});
        try stdout.print("{s}\n", .{"=" ** 60});
        
        // Implementation comparison
        {
            try stdout.print("\n  Implementation Comparison:\n", .{});
            const result = try compareImplementations(allocator, 1000000);
            
            try stdout.print("    Naive implementation:     {d} ns/op\n", .{result.baseline_ns});
            try stdout.print("    Optimized implementation: {d} ns/op\n", .{result.variant_ns});
            try stdout.print("    Speedup: {d:.2}x\n", .{result.speedup});
            try stdout.print("    Memory - Naive: {d} bytes, Optimized: {d} bytes\n", .{
                result.baseline_memory,
                result.variant_memory,
            });
        }
        
        // Clock speed comparison
        {
            try stdout.print("\n  Clock Speed Performance:\n", .{});
            const speeds = try compareClockSpeeds(allocator);
            
            try stdout.print("    Real-time (1x):   {d:>10.0} ops/sec\n", .{speeds.realtime_ops_per_sec});
            try stdout.print("    Fast (10x):       {d:>10.0} ops/sec\n", .{speeds.fast_ops_per_sec});
            try stdout.print("    Super Fast (60x): {d:>10.0} ops/sec\n", .{speeds.superfast_ops_per_sec});
        }
        
        // Preset comparison
        try comparePresets(allocator);
        
        try stdout.print("\n", .{});
    }

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

    test "performance: comparison: optimized vs naive implementation" {
        const allocator = testing.allocator;
        const result = try compareImplementations(allocator, 100000);
        
        // Optimized should be at least as fast as naive
        try testing.expect(result.speedup >= 0.9);
        
        std.debug.print("\n  Optimized speedup: {d:.2}x\n", .{result.speedup});
    }

    test "performance: comparison: real-time vs fast speeds" {
        const allocator = testing.allocator;
        const speeds = try compareClockSpeeds(allocator);
        
        // All speeds should maintain good performance
        try testing.expect(speeds.realtime_ops_per_sec > 100_000);
        try testing.expect(speeds.fast_ops_per_sec > 100_000);
        try testing.expect(speeds.superfast_ops_per_sec > 100_000);
        
        std.debug.print("\n  Speed comparison:\n", .{});
        std.debug.print("    RealTime: {d:.0} ops/sec\n", .{speeds.realtime_ops_per_sec});
        std.debug.print("    Fast: {d:.0} ops/sec\n", .{speeds.fast_ops_per_sec});
        std.debug.print("    SuperFast: {d:.0} ops/sec\n", .{speeds.superfast_ops_per_sec});
    }

    test "performance: comparison: preset initialization overhead" {
        const allocator = testing.allocator;
        
        // Test that presets don't add significant overhead
        const start_standard = std.time.nanoTimestamp();
        var clock_standard = GameClock.init(allocator);
        clock_standard.config = ClockConfig.Presets.nfl_standard;
        const end_standard = std.time.nanoTimestamp();
        
        const start_playoffs = std.time.nanoTimestamp();
        var clock_playoffs = GameClock.init(allocator);
        clock_playoffs.config = ClockConfig.Presets.nfl_playoffs;
        const end_playoffs = std.time.nanoTimestamp();
        
        const standard_time = @as(u64, @intCast(end_standard - start_standard));
        const playoffs_time = @as(u64, @intCast(end_playoffs - start_playoffs));
        
        // Different presets should have similar initialization times (within 2x)
        const ratio = if (standard_time > playoffs_time)
            @as(f64, @floatFromInt(standard_time)) / @as(f64, @floatFromInt(playoffs_time))
        else
            @as(f64, @floatFromInt(playoffs_time)) / @as(f64, @floatFromInt(standard_time));
        
        try testing.expect(ratio < 2.0);
        
        std.debug.print("\n  Preset init times - Standard: {d}ns, Playoffs: {d}ns\n", .{
            standard_time,
            playoffs_time,
        });
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════╝