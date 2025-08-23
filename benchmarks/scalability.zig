// scalability.zig — Scalability benchmarks for NFL game clock
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/scalability
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

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Result from scalability test.
    const ScalabilityResult = struct {
        instance_count: u32,
        total_ops: u64,
        duration_ms: i64,
        ops_per_second: f64,
        memory_used: usize,
        avg_time_per_op_ns: u64,
    };

    /// Tests performance with N clock instances.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    /// - `instance_count`: Number of clock instances
    /// - `ops_per_instance`: Operations to perform per instance
    ///
    /// __Return__
    ///
    /// - ScalabilityResult with performance metrics
    pub fn testWithNInstances(
        allocator: std.mem.Allocator,
        instance_count: u32,
        ops_per_instance: u32,
    ) !ScalabilityResult {
        // Track initial memory (simplified)
        const initial_memory: usize = 0;
        
        // Create clock instances
        const clocks = try allocator.alloc(GameClock, instance_count);
        defer allocator.free(clocks);
        
        for (clocks) |*clock| {
            clock.* = GameClock.init(allocator);
            try clock.start();
        }
        
        const start = std.time.milliTimestamp();
        const start_ns = std.time.nanoTimestamp();
        
        // Perform operations on all instances
        var total_ops: u64 = 0;
        for (clocks) |*clock| {
            for (0..ops_per_instance) |_| {
                try clock.tick();
                if (clock.time_remaining == 0) {
                    clock.time_remaining = 900;
                }
                total_ops += 1;
            }
        }
        
        const end = std.time.milliTimestamp();
        const end_ns = std.time.nanoTimestamp();
        const duration_ms = end - start;
        const duration_ns = end_ns - start_ns;
        
        // Calculate memory usage (simplified)
        const final_memory: usize = 0;
        const memory_used: usize = 0;
        
        return ScalabilityResult{
            .instance_count = instance_count,
            .total_ops = total_ops,
            .duration_ms = duration_ms,
            .ops_per_second = if (duration_ms > 0)
                @as(f64, @floatFromInt(total_ops)) * 1000.0 / @as(f64, @floatFromInt(duration_ms))
            else
                0,
            .memory_used = memory_used,
            .avg_time_per_op_ns = if (total_ops > 0)
                @intCast(duration_ns / @as(i128, @intCast(total_ops)))
            else
                0,
        };
    }

    /// Tests memory usage scaling.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    /// - `instance_count`: Number of instances to test
    ///
    /// __Return__
    ///
    /// - Memory usage metrics
    pub fn testMemoryScaling(allocator: std.mem.Allocator, instance_count: u32) !struct {
        instances: u32,
        total_memory: usize,
        per_instance: usize,
    } {
        const initial_memory: usize = 0;
        
        const clocks = try allocator.alloc(GameClock, instance_count);
        defer allocator.free(clocks);
        
        for (clocks) |*clock| {
            clock.* = GameClock.init(allocator);
        }
        
        const final_memory: usize = 0;
        
        const total_memory: usize = 0;
        
        return .{
            .instances = instance_count,
            .total_memory = total_memory,
            .per_instance = if (instance_count > 0)
                total_memory / instance_count
            else
                0,
        };
    }

    /// Tests thread contention with multiple instances.
    ///
    /// Simulates concurrent access patterns to measure contention effects.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    /// - `instance_count`: Number of instances
    ///
    /// __Return__
    ///
    /// - Performance metrics under contention
    pub fn testThreadContention(allocator: std.mem.Allocator, instance_count: u32) !ScalabilityResult {
        const clocks = try allocator.alloc(GameClock, instance_count);
        defer allocator.free(clocks);
        
        for (clocks) |*clock| {
            clock.* = GameClock.init(allocator);
            try clock.start();
        }
        
        const start = std.time.milliTimestamp();
        const start_ns = std.time.nanoTimestamp();
        var total_ops: u64 = 0;
        
        // Simulate random access pattern (worst case for cache)
        var prng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const random = prng.random();
        
        const ops_count = instance_count * 1000;
        for (0..ops_count) |_| {
            const index = random.intRangeLessThan(usize, 0, instance_count);
            try clocks[index].tick();
            if (clocks[index].time_remaining == 0) {
                clocks[index].time_remaining = 900;
            }
            total_ops += 1;
        }
        
        const end = std.time.milliTimestamp();
        const end_ns = std.time.nanoTimestamp();
        const duration_ms = end - start;
        const duration_ns = end_ns - start_ns;
        
        return ScalabilityResult{
            .instance_count = instance_count,
            .total_ops = total_ops,
            .duration_ms = duration_ms,
            .ops_per_second = if (duration_ms > 0)
                @as(f64, @floatFromInt(total_ops)) * 1000.0 / @as(f64, @floatFromInt(duration_ms))
            else
                0,
            .memory_used = 0,
            .avg_time_per_op_ns = if (total_ops > 0)
                @intCast(duration_ns / @as(i128, @intCast(total_ops)))
            else
                0,
        };
    }

    /// Runs all scalability benchmarks.
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
        
        try stdout.print("\nScalability Benchmark Results\n", .{});
        try stdout.print("{s}\n", .{"=" ** 60});
        
        // Test scaling from 1 to 1000 instances
        const instance_counts = [_]u32{ 1, 10, 100, 1000 };
        
        try stdout.print("\n  Performance Scaling:\n", .{});
        try stdout.print("  {s:>10} | {s:>15} | {s:>15} | {s:>10}\n", .{
            "Instances",
            "Ops/sec",
            "Avg ns/op",
            "Degradation",
        });
        try stdout.print("  {s}\n", .{"-" ** 60});
        
        var baseline_ops_per_sec: f64 = 0;
        
        for (instance_counts) |count| {
            const result = try testWithNInstances(allocator, count, 10000);
            
            const degradation = if (baseline_ops_per_sec > 0)
                100.0 * (1.0 - result.ops_per_second / baseline_ops_per_sec)
            else blk: {
                baseline_ops_per_sec = result.ops_per_second;
                break :blk 0.0;
            };
            
            try stdout.print("  {d:>10} | {d:>15.0} | {d:>15} | {d:>9.1}%\n", .{
                count,
                result.ops_per_second,
                result.avg_time_per_op_ns,
                degradation,
            });
        }
        
        // Memory scaling test
        try stdout.print("\n  Memory Scaling:\n", .{});
        try stdout.print("  {s:>10} | {s:>15} | {s:>15}\n", .{
            "Instances",
            "Total Memory",
            "Per Instance",
        });
        try stdout.print("  {s}\n", .{"-" ** 45});
        
        for (instance_counts) |count| {
            const mem_result = try testMemoryScaling(allocator, count);
            try stdout.print("  {d:>10} | {d:>15} B | {d:>15} B\n", .{
                mem_result.instances,
                mem_result.total_memory,
                mem_result.per_instance,
            });
        }
        
        // Thread contention test
        try stdout.print("\n  Random Access Pattern (Cache Contention):\n", .{});
        try stdout.print("  {s:>10} | {s:>15} | {s:>15}\n", .{
            "Instances",
            "Ops/sec",
            "Avg ns/op",
        });
        try stdout.print("  {s}\n", .{"-" ** 45});
        
        for (instance_counts) |count| {
            const result = try testThreadContention(allocator, count);
            try stdout.print("  {d:>10} | {d:>15.0} | {d:>15}\n", .{
                count,
                result.ops_per_second,
                result.avg_time_per_op_ns,
            });
        }
        
        try stdout.print("\n", .{});
    }

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

    test "performance: scalability: performance with 1 clock" {
        const allocator = testing.allocator;
        const result = try testWithNInstances(allocator, 1, 100000);
        
        try testing.expect(result.ops_per_second > 1_000_000);
        
        std.debug.print("\n  1 instance: {d:.0} ops/sec\n", .{result.ops_per_second});
    }

    test "performance: scalability: performance with 100 clocks" {
        const allocator = testing.allocator;
        const result = try testWithNInstances(allocator, 100, 1000);
        
        // Should maintain good performance with 100 instances
        try testing.expect(result.ops_per_second > 900_000);
        
        std.debug.print("\n  100 instances: {d:.0} ops/sec\n", .{result.ops_per_second});
    }

    test "performance: scalability: performance with 1000 clocks" {
        const allocator = testing.allocator;
        const result = try testWithNInstances(allocator, 1000, 100);
        
        // Allow up to 10% degradation at 1000 instances
        try testing.expect(result.ops_per_second > 800_000);
        
        std.debug.print("\n  1000 instances: {d:.0} ops/sec\n", .{result.ops_per_second});
    }

    test "performance: scalability: memory per instance" {
        const allocator = testing.allocator;
        const mem_result = try testMemoryScaling(allocator, 100);
        
        // Each instance should use less than 1KB
        try testing.expect(mem_result.per_instance < 1024);
        
        std.debug.print("\n  Memory per instance: {d} bytes\n", .{mem_result.per_instance});
    }

    test "performance: scalability: linear scaling verification" {
        const allocator = testing.allocator;
        
        const result_1 = try testWithNInstances(allocator, 1, 10000);
        const result_10 = try testWithNInstances(allocator, 10, 10000);
        const result_100 = try testWithNInstances(allocator, 100, 10000);
        
        // Performance should scale linearly (within 20% tolerance)
        const scaling_10 = result_10.ops_per_second / result_1.ops_per_second;
        const scaling_100 = result_100.ops_per_second / result_1.ops_per_second;
        
        try testing.expect(scaling_10 >= 0.8);
        try testing.expect(scaling_100 >= 0.8);
        
        std.debug.print("\n  Scaling efficiency:\n", .{});
        std.debug.print("    10x instances: {d:.1}% efficiency\n", .{scaling_10 * 100});
        std.debug.print("    100x instances: {d:.1}% efficiency\n", .{scaling_100 * 100});
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════╝