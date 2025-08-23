// benchmark.zig — Core benchmarking framework for NFL game clock library
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/benchmarks/benchmark
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    /// Result of a benchmark run containing timing and memory metrics.
    ///
    /// Stores statistical data about benchmark performance including
    /// minimum, maximum, and average execution times, as well as memory usage.
    ///
    /// __Fields__
    ///
    /// - `name`: Name of the benchmark
    /// - `min_ns`: Minimum execution time in nanoseconds
    /// - `max_ns`: Maximum execution time in nanoseconds
    /// - `avg_ns`: Average execution time in nanoseconds
    /// - `median_ns`: Median execution time in nanoseconds
    /// - `std_dev_ns`: Standard deviation in nanoseconds
    /// - `iterations`: Number of iterations performed
    /// - `memory_used`: Peak memory usage in bytes
    /// - `ops_per_second`: Operations per second throughput
    pub const BenchmarkResult = struct {
        name: []const u8,
        min_ns: u64,
        max_ns: u64,
        avg_ns: u64,
        median_ns: u64,
        std_dev_ns: u64,
        iterations: u32,
        memory_used: usize,
        ops_per_second: f64,
        
        /// Formats the result as a human-readable string.
        ///
        /// __Parameters__
        ///
        /// - `self`: The BenchmarkResult instance
        /// - `writer`: Writer to output formatted results
        ///
        /// __Return__
        ///
        /// - Error if writing fails, void otherwise
        pub fn format(
            self: BenchmarkResult,
            writer: anytype,
        ) !void {
            try writer.print("  {s}:\n", .{self.name});
            try writer.print("    Iterations: {d}\n", .{self.iterations});
            try writer.print("    Min:    {d:>12.3} ms\n", .{@as(f64, @floatFromInt(self.min_ns)) / 1_000_000});
            try writer.print("    Max:    {d:>12.3} ms\n", .{@as(f64, @floatFromInt(self.max_ns)) / 1_000_000});
            try writer.print("    Avg:    {d:>12.3} ms\n", .{@as(f64, @floatFromInt(self.avg_ns)) / 1_000_000});
            try writer.print("    Median: {d:>12.3} ms\n", .{@as(f64, @floatFromInt(self.median_ns)) / 1_000_000});
            try writer.print("    StdDev: {d:>12.3} ms\n", .{@as(f64, @floatFromInt(self.std_dev_ns)) / 1_000_000});
            try writer.print("    Ops/sec: {d:>10.0}\n", .{self.ops_per_second});
            if (self.memory_used > 0) {
                try writer.print("    Memory: {d} bytes\n", .{self.memory_used});
            }
        }
    };

    /// Benchmark runner that executes and measures performance.
    ///
    /// Provides a framework for running benchmarks with warmup phases,
    /// statistical analysis, and memory tracking.
    ///
    /// __Fields__
    ///
    /// - `name`: Name of the benchmark
    /// - `iterations`: Number of iterations to run
    /// - `warmup_iterations`: Number of warmup iterations
    /// - `allocator`: Memory allocator for benchmark
    pub const Benchmark = struct {
        name: []const u8,
        iterations: u32 = 10000,
        warmup_iterations: u32 = 100,
        allocator: std.mem.Allocator,
        
        /// Runs the benchmark with the provided function.
        ///
        /// __Parameters__
        ///
        /// - `self`: The Benchmark instance
        /// - `comptime func`: Function to benchmark
        /// - `context`: Context to pass to the function
        ///
        /// __Return__
        ///
        /// - BenchmarkResult with timing statistics
        pub fn run(
            self: *Benchmark,
            comptime func: anytype,
            context: anytype,
        ) !BenchmarkResult {
            // Warmup phase
            var i: u32 = 0;
            while (i < self.warmup_iterations) : (i += 1) {
                _ = try func(context);
            }
            
            // Allocate timing array
            var timings = try self.allocator.alloc(u64, self.iterations);
            defer self.allocator.free(timings);
            
            // Track memory (simplified for now)
            const initial_memory: usize = 0;
            
            // Main benchmark loop
            i = 0;
            while (i < self.iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                _ = try func(context);
                const end = std.time.nanoTimestamp();
                timings[i] = @intCast(end - start);
            }
            
            // Calculate memory usage (simplified for now)
            const final_memory: usize = 0;
            const memory_used: usize = 0;
            
            // Calculate statistics
            const stats = calculateStats(timings);
            
            return BenchmarkResult{
                .name = self.name,
                .min_ns = stats.min,
                .max_ns = stats.max,
                .avg_ns = stats.avg,
                .median_ns = stats.median,
                .std_dev_ns = stats.std_dev,
                .iterations = self.iterations,
                .memory_used = memory_used,
                .ops_per_second = if (stats.avg > 0) 
                    1_000_000_000.0 / @as(f64, @floatFromInt(stats.avg)) 
                else 
                    0,
            };
        }
        
        /// Reports benchmark result to stdout.
        ///
        /// __Parameters__
        ///
        /// - `self`: The Benchmark instance
        /// - `result`: Result to report
        ///
        /// __Return__
        ///
        /// - void
        pub fn report(self: *Benchmark, result: BenchmarkResult) void {
            _ = self;
            const stdout = std.io.getStdOut().writer();
            result.format(stdout) catch {};
        }
    };

    /// Statistics calculated from timing data.
    const Stats = struct {
        min: u64,
        max: u64,
        avg: u64,
        median: u64,
        std_dev: u64,
    };

    /// Calculates statistical metrics from timing data.
    ///
    /// __Parameters__
    ///
    /// - `timings`: Array of timing measurements
    ///
    /// __Return__
    ///
    /// - Stats structure with calculated metrics
    fn calculateStats(timings: []u64) Stats {
        if (timings.len == 0) {
            return Stats{
                .min = 0,
                .max = 0,
                .avg = 0,
                .median = 0,
                .std_dev = 0,
            };
        }
        
        // Sort for median calculation
        std.mem.sort(u64, timings, {}, std.sort.asc(u64));
        
        // Calculate min, max, sum
        var min: u64 = timings[0];
        var max: u64 = timings[0];
        var sum: u64 = 0;
        
        for (timings) |t| {
            if (t < min) min = t;
            if (t > max) max = t;
            sum += t;
        }
        
        const avg = sum / timings.len;
        const median = timings[timings.len / 2];
        
        // Calculate standard deviation
        var variance_sum: u64 = 0;
        for (timings) |t| {
            const diff = if (t > avg) t - avg else avg - t;
            variance_sum += diff * diff;
        }
        const variance = variance_sum / timings.len;
        const std_dev = std.math.sqrt(variance);
        
        return Stats{
            .min = min,
            .max = max,
            .avg = avg,
            .median = median,
            .std_dev = @intFromFloat(std_dev),
        };
    }

    /// Benchmark suite that runs multiple benchmarks together.
    ///
    /// Manages execution of related benchmarks and generates
    /// consolidated reports.
    ///
    /// __Fields__
    ///
    /// - `name`: Name of the suite
    /// - `allocator`: Memory allocator
    /// - `results`: Collection of benchmark results
    pub const BenchmarkSuite = struct {
        name: []const u8,
        allocator: std.mem.Allocator,
        results: std.ArrayList(BenchmarkResult),
        
        /// Initializes a new benchmark suite.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator
        /// - `name`: Suite name
        ///
        /// __Return__
        ///
        /// - Initialized BenchmarkSuite
        pub fn init(allocator: std.mem.Allocator, name: []const u8) BenchmarkSuite {
            return BenchmarkSuite{
                .name = name,
                .allocator = allocator,
                .results = std.ArrayList(BenchmarkResult).init(allocator),
            };
        }
        
        /// Deinitializes the benchmark suite.
        ///
        /// __Parameters__
        ///
        /// - `self`: The suite instance
        ///
        /// __Return__
        ///
        /// - void
        pub fn deinit(self: *BenchmarkSuite) void {
            self.results.deinit();
        }
        
        /// Adds a benchmark result to the suite.
        ///
        /// __Parameters__
        ///
        /// - `self`: The suite instance
        /// - `result`: Result to add
        ///
        /// __Return__
        ///
        /// - Error on allocation failure
        pub fn addResult(self: *BenchmarkSuite, result: BenchmarkResult) !void {
            try self.results.append(result);
        }
        
        /// Generates a report for all benchmarks in the suite.
        ///
        /// __Parameters__
        ///
        /// - `self`: The suite instance
        ///
        /// __Return__
        ///
        /// - void
        pub fn report(self: *BenchmarkSuite) void {
            const stdout = std.io.getStdOut().writer();
            stdout.print("\n{s} Benchmark Results\n", .{self.name}) catch {};
            stdout.print("{s}\n", .{"=" ** 60}) catch {};
            
            for (self.results.items) |result| {
                result.format(stdout) catch {};
                stdout.print("\n", .{}) catch {};
            }
        }
    };

// ╚════════════════════════════════════════════════════════════════════════════════╝