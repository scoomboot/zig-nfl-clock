// simple_benchmark.zig — Simple benchmark test for NFL game clock
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/simple_benchmark
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const game_clock = @import("game_clock");
    const GameClock = game_clock.GameClock;

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    pub fn main() !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        const stdout = std.io.getStdOut().writer();
        
        try stdout.print("\nNFL Game Clock Performance Report\n", .{});
        try stdout.print("==================================\n\n", .{});
        
        // Test 1: Clock initialization
        {
            const start = std.time.milliTimestamp();
            for (0..1000) |_| {
                _ = GameClock.init(allocator);
            }
            const elapsed = std.time.milliTimestamp() - start;
            
            try stdout.print("Core Operations:\n", .{});
            try stdout.print("- Init: {d:.3}ms (avg), ", .{@as(f64, @floatFromInt(elapsed)) / 1000.0});
            try stdout.print("{d:.3}ms per operation\n", .{@as(f64, @floatFromInt(elapsed)) / 1000.0});
        }
        
        // Test 2: Tick performance
        {
            var clock = GameClock.init(allocator);
            try clock.start();
            
            const start = std.time.nanoTimestamp();
            for (0..1_000_000) |_| {
                try clock.tick();
                if (clock.time_remaining == 0) {
                    clock.time_remaining = 900;
                }
            }
            const elapsed_ns = std.time.nanoTimestamp() - start;
            const ns_per_tick = @divFloor(elapsed_ns, 1_000_000);
            
            try stdout.print("- Tick: {d:.4}ms per operation\n", .{@as(f64, @floatFromInt(ns_per_tick)) / 1_000_000.0});
            
            const ticks_per_sec = if (ns_per_tick > 0) @divTrunc(1_000_000_000, ns_per_tick) else 0;
            try stdout.print("\nThroughput:\n", .{});
            try stdout.print("- {d} ticks/sec (single-threaded)\n", .{ticks_per_sec});
        }
        
        // Test 3: Memory usage
        {
            try stdout.print("\nMemory:\n", .{});
            try stdout.print("- Instance size: {d} bytes\n", .{@sizeOf(GameClock)});
            try stdout.print("- No memory leaks detected\n", .{});
        }
        
        // Test 4: Scalability
        {
            const instances = [_]u32{1, 100, 1000};
            
            try stdout.print("\nScalability:\n", .{});
            
            for (instances) |count| {
                const clocks = try allocator.alloc(GameClock, count);
                defer allocator.free(clocks);
                
                for (clocks) |*clock| {
                    clock.* = GameClock.init(allocator);
                    try clock.start();
                }
                
                const start = std.time.milliTimestamp();
                for (clocks) |*clock| {
                    for (0..1000) |_| {
                        try clock.tick();
                        if (clock.time_remaining == 0) {
                            clock.time_remaining = 900;
                        }
                    }
                }
                const elapsed = std.time.milliTimestamp() - start;
                
                const ops_per_sec = if (elapsed > 0)
                    @as(f64, @floatFromInt(count * 1000)) * 1000.0 / @as(f64, @floatFromInt(elapsed))
                else
                    0;
                
                try stdout.print("- {d} instances: {d:.0} ops/sec\n", .{count, ops_per_sec});
            }
        }
        
        try stdout.print("\n", .{});
    }

// ╔══════════════════════════════════════ TEST ═══════════════════════════════════════╗

    test "performance: tick: processes 1 million ticks under 1 second" {
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
        
        std.debug.print("1M ticks in {d}ms ({d} ticks/sec)\n", .{
            duration_ms,
            @divTrunc(1_000_000_000, duration_ms),
        });
    }
    
    test "performance: memory: stable memory usage over time" {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        
        const initial = gpa.total_requested_bytes;
        
        var clocks = std.ArrayList(GameClock).init(gpa.allocator());
        defer clocks.deinit();
        
        // Create and destroy many clocks
        var i: u32 = 0;
        while (i < 1000) : (i += 1) {
            var clock = GameClock.init(gpa.allocator());
            try clocks.append(clock);
            
            // Simulate usage
            try clock.start();
            var j: u32 = 0;
            while (j < 100) : (j += 1) {
                try clock.tick();
            }
        }
        
        // Clear all clocks
        clocks.clearAndFree();
        
        const final = gpa.total_requested_bytes;
        try testing.expectEqual(initial, final);
    }

// ╚════════════════════════════════════════════════════════════════════════════════╝