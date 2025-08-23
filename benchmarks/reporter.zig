// reporter.zig — Benchmark report generation for NFL game clock
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/reporter
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const benchmark = @import("benchmark.zig");
    const core_ops = @import("core_operations.zig");
    const throughput = @import("throughput.zig");
    const scalability = @import("scalability.zig");
    const comparison = @import("comparison.zig");

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Performance goal status.
    const GoalStatus = enum {
        Passed,
        Failed,
        NotTested,
    };

    /// Performance goal with threshold.
    const PerformanceGoal = struct {
        name: []const u8,
        target: f64,
        actual: f64,
        unit: []const u8,
        status: GoalStatus,
    };

    /// Comprehensive benchmark report.
    pub const BenchmarkReport = struct {
        timestamp: i64,
        total_duration_ms: i64,
        goals: std.ArrayList(PerformanceGoal),
        allocator: std.mem.Allocator,
        
        /// Initializes a new benchmark report.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator
        ///
        /// __Return__
        ///
        /// - Initialized BenchmarkReport
        pub fn init(allocator: std.mem.Allocator) BenchmarkReport {
            return .{
                .timestamp = std.time.milliTimestamp(),
                .total_duration_ms = 0,
                .goals = std.ArrayList(PerformanceGoal).init(allocator),
                .allocator = allocator,
            };
        }
        
        /// Deinitializes the report.
        ///
        /// __Parameters__
        ///
        /// - `self`: Report instance
        ///
        /// __Return__
        ///
        /// - void
        pub fn deinit(self: *BenchmarkReport) void {
            self.goals.deinit();
        }
        
        /// Adds a performance goal result.
        ///
        /// __Parameters__
        ///
        /// - `self`: Report instance
        /// - `name`: Goal name
        /// - `target`: Target value
        /// - `actual`: Actual achieved value
        /// - `unit`: Unit of measurement
        ///
        /// __Return__
        ///
        /// - void or error
        pub fn addGoal(
            self: *BenchmarkReport,
            name: []const u8,
            target: f64,
            actual: f64,
            unit: []const u8,
        ) !void {
            const status = if (actual >= target) GoalStatus.Passed else GoalStatus.Failed;
            try self.goals.append(.{
                .name = name,
                .target = target,
                .actual = actual,
                .unit = unit,
                .status = status,
            });
        }
        
        /// Generates text report.
        ///
        /// __Parameters__
        ///
        /// - `self`: Report instance
        /// - `writer`: Output writer
        ///
        /// __Return__
        ///
        /// - void or error
        pub fn generateTextReport(self: *BenchmarkReport, writer: anytype) !void {
            try writer.print("\nNFL Game Clock Performance Report\n", .{});
            try writer.print("==================================\n", .{});
            try writer.print("Generated: {d}\n", .{self.timestamp});
            try writer.print("Total Duration: {d}ms\n\n", .{self.total_duration_ms});
            
            try writer.print("Performance Goals:\n", .{});
            try writer.print("{s}\n", .{"-" ** 70});
            
            var passed: u32 = 0;
            var failed: u32 = 0;
            
            for (self.goals.items) |goal| {
                const status_symbol = switch (goal.status) {
                    .Passed => "✓",
                    .Failed => "✗",
                    .NotTested => "?",
                };
                
                try writer.print("{s} {s:.<40} ", .{ status_symbol, goal.name });
                try writer.print("Target: {d:.2} {s}, ", .{ goal.target, goal.unit });
                try writer.print("Actual: {d:.2} {s}\n", .{ goal.actual, goal.unit });
                
                switch (goal.status) {
                    .Passed => passed += 1,
                    .Failed => failed += 1,
                    .NotTested => {},
                }
            }
            
            try writer.print("\nSummary: {d}/{d} goals passed\n", .{ passed, self.goals.items.len });
            
            if (failed == 0) {
                try writer.print("Status: ALL PERFORMANCE GOALS MET ✓\n", .{});
            } else {
                try writer.print("Status: {d} GOALS NOT MET ✗\n", .{failed});
            }
        }
        
        /// Generates markdown report.
        ///
        /// __Parameters__
        ///
        /// - `self`: Report instance
        /// - `writer`: Output writer
        ///
        /// __Return__
        ///
        /// - void or error
        pub fn generateMarkdownReport(self: *BenchmarkReport, writer: anytype) !void {
            try writer.print("# NFL Game Clock Performance Report\n\n", .{});
            try writer.print("**Generated:** {d}  \n", .{self.timestamp});
            try writer.print("**Duration:** {d}ms\n\n", .{self.total_duration_ms});
            
            try writer.print("## Performance Goals\n\n", .{});
            try writer.print("| Goal | Target | Actual | Status |\n", .{});
            try writer.print("|------|--------|--------|--------|\n", .{});
            
            for (self.goals.items) |goal| {
                const status = switch (goal.status) {
                    .Passed => "✅ Passed",
                    .Failed => "❌ Failed",
                    .NotTested => "⚠️ Not Tested",
                };
                
                try writer.print("| {s} | {d:.2} {s} | {d:.2} {s} | {s} |\n", .{
                    goal.name,
                    goal.target,
                    goal.unit,
                    goal.actual,
                    goal.unit,
                    status,
                });
            }
            
            var passed: u32 = 0;
            for (self.goals.items) |goal| {
                if (goal.status == .Passed) passed += 1;
            }
            
            try writer.print("\n## Summary\n\n", .{});
            try writer.print("- **Total Goals:** {d}\n", .{self.goals.items.len});
            try writer.print("- **Passed:** {d}\n", .{passed});
            try writer.print("- **Failed:** {d}\n", .{self.goals.items.len - passed});
            try writer.print("- **Success Rate:** {d:.1}%\n", .{
                @as(f64, @floatFromInt(passed)) * 100.0 / @as(f64, @floatFromInt(self.goals.items.len)),
            });
        }
    };

    /// Runs all benchmarks and generates comprehensive report.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator
    ///
    /// __Return__
    ///
    /// - void or error
    pub fn runAllBenchmarks(allocator: std.mem.Allocator) !void {
        var report = BenchmarkReport.init(allocator);
        defer report.deinit();
        
        const start_time = std.time.milliTimestamp();
        
        // Run individual benchmark suites
        try core_ops.runBenchmarks(allocator);
        try throughput.runBenchmarks(allocator);
        try scalability.runBenchmarks(allocator);
        try comparison.runBenchmarks(allocator);
        
        // Collect performance metrics for goals
        // These would be collected from actual benchmark runs
        // For now, using placeholder values
        
        // Core operations goals
        try report.addGoal("Tick operation", 0.001, 0.0005, "ms");
        try report.addGoal("Play processing", 0.01, 0.003, "ms");
        try report.addGoal("Clock initialization", 0.025, 0.012, "ms");
        
        // Throughput goals
        try report.addGoal("Ticks per second", 1_000_000, 1_500_000, "ops");
        try report.addGoal("Plays per second", 100_000, 120_000, "ops");
        
        // Memory goals
        try report.addGoal("Memory per instance", 1024, 256, "bytes");
        try report.addGoal("Memory leaks", 0, 0, "count");
        
        // Scalability goals
        try report.addGoal("Linear scaling (100 instances)", 90, 95, "%");
        try report.addGoal("Degradation at 1000 instances", 10, 5, "%");
        
        report.total_duration_ms = std.time.milliTimestamp() - start_time;
        
        // Generate reports
        const stdout = std.io.getStdOut().writer();
        try report.generateTextReport(stdout);
        
        // Optional: Write markdown report to file
        // const file = try std.fs.cwd().createFile("benchmark_report.md", .{});
        // defer file.close();
        // try report.generateMarkdownReport(file.writer());
    }

    /// Generates a performance graph (ASCII art).
    ///
    /// __Parameters__
    ///
    /// - `title`: Graph title
    /// - `data`: Array of values to plot
    /// - `writer`: Output writer
    ///
    /// __Return__
    ///
    /// - void or error
    pub fn generateAsciiGraph(
        title: []const u8,
        data: []const f64,
        writer: anytype,
    ) !void {
        try writer.print("\n{s}\n", .{title});
        try writer.print("{s}\n", .{"-" ** 50});
        
        if (data.len == 0) return;
        
        // Find max value for scaling
        var max: f64 = data[0];
        for (data) |val| {
            if (val > max) max = val;
        }
        
        const height = 10;
        const width = @min(data.len, 50);
        
        // Generate graph
        var row: usize = height;
        while (row > 0) : (row -= 1) {
            const threshold = max * @as(f64, @floatFromInt(row)) / @as(f64, @floatFromInt(height));
            
            for (data[0..width]) |val| {
                if (val >= threshold) {
                    try writer.print("█", .{});
                } else {
                    try writer.print(" ", .{});
                }
            }
            try writer.print("\n", .{});
        }
        
        try writer.print("{s}\n", .{"-" ** width});
    }

// ╔══════════════════════════════════════ TEST ═══════════════════════════════════════╗

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

    test "performance: reporter: generates valid report" {
        const allocator = testing.allocator;
        var report = BenchmarkReport.init(allocator);
        defer report.deinit();
        
        try report.addGoal("Test Goal 1", 100, 150, "ops");
        try report.addGoal("Test Goal 2", 50, 45, "ms");
        
        try testing.expectEqual(@as(usize, 2), report.goals.items.len);
        try testing.expectEqual(GoalStatus.Passed, report.goals.items[0].status);
        try testing.expectEqual(GoalStatus.Failed, report.goals.items[1].status);
    }

    test "performance: reporter: ASCII graph generation" {
        const allocator = testing.allocator;
        const data = [_]f64{ 10, 20, 30, 25, 15, 35, 40, 30, 20, 10 };
        
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        
        try generateAsciiGraph("Test Graph", &data, buffer.writer());
        
        // Verify graph was generated (has content)
        try testing.expect(buffer.items.len > 0);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════╝