// core_operations.zig — Core operation benchmarks for NFL game clock
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/core_operations
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const benchmark = @import("benchmark.zig");
    const game_clock = @import("game_clock");
    const GameClock = game_clock.GameClock;
    const Quarter = game_clock.Quarter;
    const ClockConfig = game_clock.ClockConfig;

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Context for clock initialization benchmark.
    const InitContext = struct {
        allocator: std.mem.Allocator,
    };

    /// Benchmarks clock initialization time.
    ///
    /// __Parameters__
    ///
    /// - `ctx`: InitContext with allocator
    ///
    /// __Return__
    ///
    /// - Initialized GameClock or error
    fn benchmarkInit(ctx: *InitContext) !GameClock {
        return GameClock.init(ctx.allocator);
    }

    /// Context for tick operation benchmark.
    const TickContext = struct {
        clock: *GameClock,
    };

    /// Benchmarks single tick operation.
    ///
    /// __Parameters__
    ///
    /// - `ctx`: TickContext with clock instance
    ///
    /// __Return__
    ///
    /// - void or error
    fn benchmarkTick(ctx: *TickContext) !void {
        try ctx.clock.tick();
        // Reset if quarter ends to continue ticking
        if (ctx.clock.time_remaining == 0) {
            ctx.clock.time_remaining = 900;
        }
    }

    /// Context for play clock reset benchmark.
    const PlayClockContext = struct {
        clock: *GameClock,
    };

    /// Benchmarks play clock reset.
    ///
    /// __Parameters__
    ///
    /// - `ctx`: PlayClockContext with clock
    ///
    /// __Return__
    ///
    /// - void or error
    fn benchmarkPlayClockReset(ctx: *PlayClockContext) !void {
        try ctx.clock.resetPlayClock();
    }

    /// Context for state query benchmark.
    const StateContext = struct {
        clock: *GameClock,
        buffer: []u8,
    };

    /// Benchmarks state query operations.
    ///
    /// __Parameters__
    ///
    /// - `ctx`: StateContext with clock
    ///
    /// __Return__
    ///
    /// - void
    fn benchmarkStateQuery(ctx: *StateContext) !void {
        _ = ctx.clock.getQuarter();
        _ = ctx.clock.getTimeRemaining();
        _ = ctx.clock.getPlayClock();
        _ = ctx.clock.isRunning();
        _ = ctx.clock.getTimeString(ctx.buffer);
    }

    /// Context for quarter transition benchmark.
    const TransitionContext = struct {
        clock: *GameClock,
    };

    /// Benchmarks quarter transition overhead.
    ///
    /// __Parameters__
    ///
    /// - `ctx`: TransitionContext with clock
    ///
    /// __Return__
    ///
    /// - void or error
    fn benchmarkQuarterTransition(ctx: *TransitionContext) !void {
        // Set up for transition
        ctx.clock.time_remaining = 1;
        ctx.clock.is_running = true;
        
        // Trigger transition
        try ctx.clock.tick();
        
        // Reset for next iteration
        ctx.clock.quarter = .first;
        ctx.clock.time_remaining = 900;
    }

    /// Runs all core operation benchmarks.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    ///
    /// __Return__
    ///
    /// - void or error
    pub fn runBenchmarks(allocator: std.mem.Allocator) !void {
        var suite = benchmark.BenchmarkSuite.init(allocator, "Core Operations");
        defer suite.deinit();
        
        // Clock initialization benchmark
        {
            var bench = benchmark.Benchmark{
                .name = "Clock initialization",
                .iterations = 10000,
                .warmup_iterations = 100,
                .allocator = allocator,
            };
            
            var ctx = InitContext{ .allocator = allocator };
            const result = try bench.run(benchmarkInit, &ctx);
            try suite.addResult(result);
        }
        
        // Tick operation benchmark
        {
            var clock = GameClock.init(allocator);
            try clock.start();
            
            var bench = benchmark.Benchmark{
                .name = "Tick operation",
                .iterations = 1000000,
                .warmup_iterations = 1000,
                .allocator = allocator,
            };
            
            var ctx = TickContext{ .clock = &clock };
            const result = try bench.run(benchmarkTick, &ctx);
            try suite.addResult(result);
        }
        
        // Play processing benchmark
        {
            var clock = GameClock.init(allocator);
            try clock.start();
            
            var bench = benchmark.Benchmark{
                .name = "Play outcome processing",
                .iterations = 100000,
                .warmup_iterations = 1000,
                .allocator = allocator,
            };
            
            var ctx = PlayContext{ 
                .clock = &clock,
                .outcome = .{ 
                    .yards_gained = 5,
                    .first_down = false,
                    .touchdown = false,
                    .out_of_bounds = false,
                    .incomplete_pass = false,
                    .penalty = null,
                    .turnover = false,
                    .two_point_attempt = false,
                    .safety = false,
                },
            };
            const result = try bench.run(benchmarkPlayProcessing, &ctx);
            try suite.addResult(result);
        }
        
        // State query benchmark
        {
            var clock = GameClock.init(allocator);
            var buffer: [16]u8 = undefined;
            
            var bench = benchmark.Benchmark{
                .name = "State query operations",
                .iterations = 1000000,
                .warmup_iterations = 1000,
                .allocator = allocator,
            };
            
            var ctx = StateContext{ 
                .clock = &clock,
                .buffer = &buffer,
            };
            const result = try bench.run(benchmarkStateQuery, &ctx);
            try suite.addResult(result);
        }
        
        // Quarter transition benchmark
        {
            var clock = GameClock.init(allocator);
            try clock.start();
            
            var bench = benchmark.Benchmark{
                .name = "Quarter transition overhead",
                .iterations = 10000,
                .warmup_iterations = 100,
                .allocator = allocator,
            };
            
            var ctx = TransitionContext{ .clock = &clock };
            const result = try bench.run(benchmarkQuarterTransition, &ctx);
            try suite.addResult(result);
        }
        
        suite.report();
    }

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

    test "performance: core_operations: clock initialization time" {
        const allocator = testing.allocator;
        
        const start = std.time.milliTimestamp();
        for (0..1000) |_| {
            _ = GameClock.init(allocator);
        }
        const elapsed = std.time.milliTimestamp() - start;
        
        // Should initialize 1000 clocks in under 10ms
        try testing.expect(elapsed < 10);
        
        std.debug.print("\n  Clock init: {d}μs per operation\n", .{
            @as(f64, @floatFromInt(elapsed)) * 1000 / 1000,
        });
    }

    test "performance: core_operations: tick processing speed" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        try clock.start();
        
        const start = std.time.nanoTimestamp();
        for (0..1_000_000) |_| {
            try clock.tick();
            if (clock.time_remaining == 0) {
                clock.time_remaining = 900;
            }
        }
        const elapsed = std.time.nanoTimestamp() - start;
        
        const ns_per_tick = @divFloor(elapsed, 1_000_000);
        
        // Should be under 1000ns (1μs) per tick
        try testing.expect(ns_per_tick < 1000);
        
        std.debug.print("\n  Tick: {d}ns per operation ({d} ticks/sec)\n", .{
            ns_per_tick,
            if (ns_per_tick > 0) 1_000_000_000 / ns_per_tick else 0,
        });
    }

    test "performance: core_operations: play outcome processing" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        try clock.start();
        
        const outcome = PlayOutcome{
            .yards_gained = 7,
            .first_down = true,
            .touchdown = false,
            .out_of_bounds = false,
            .incomplete_pass = false,
            .penalty = null,
            .turnover = false,
            .two_point_attempt = false,
            .safety = false,
        };
        
        const start = std.time.nanoTimestamp();
        for (0..100_000) |_| {
            try clock.processPlayOutcome(outcome);
            clock.play_clock = 40; // Reset for next iteration
        }
        const elapsed = std.time.nanoTimestamp() - start;
        
        const ns_per_play = @divFloor(elapsed, 100_000);
        
        // Should be under 10,000ns (10μs) per play
        try testing.expect(ns_per_play < 10_000);
        
        std.debug.print("\n  Play processing: {d}ns per operation ({d} plays/sec)\n", .{
            ns_per_play,
            if (ns_per_play > 0) 1_000_000_000 / ns_per_play else 0,
        });
    }

    test "performance: core_operations: state query performance" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        var buffer: [16]u8 = undefined;
        
        const start = std.time.nanoTimestamp();
        for (0..1_000_000) |_| {
            _ = clock.getQuarter();
            _ = clock.getTimeRemaining();
            _ = clock.getPlayClock();
            _ = clock.isRunning();
            _ = clock.getTimeString(&buffer);
        }
        const elapsed = std.time.nanoTimestamp() - start;
        
        const ns_per_query = @divFloor(elapsed, 1_000_000);
        
        // Should be under 100ns per query set
        try testing.expect(ns_per_query < 500);
        
        std.debug.print("\n  State queries: {d}ns per operation set\n", .{ns_per_query});
    }

    test "performance: core_operations: quarter transition overhead" {
        const allocator = testing.allocator;
        var clock = GameClock.init(allocator);
        try clock.start();
        
        const start = std.time.nanoTimestamp();
        for (0..10_000) |_| {
            clock.time_remaining = 1;
            try clock.tick(); // Triggers transition
            clock.quarter = .first; // Reset
            clock.time_remaining = 900;
        }
        const elapsed = std.time.nanoTimestamp() - start;
        
        const ns_per_transition = @divFloor(elapsed, 10_000);
        
        // Should be under 5000ns (5μs) per transition
        try testing.expect(ns_per_transition < 5000);
        
        std.debug.print("\n  Quarter transition: {d}ns per operation\n", .{ns_per_transition});
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════╝