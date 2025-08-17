// time_formatter.test.zig — Tests for time formatting utilities
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/time_formatter/time_formatter.test.zig
// author : https://github.com/maysara-elshewehy
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const TimeFormatter = @import("time_formatter.zig").TimeFormatter;
    const TimeFormat = @import("time_formatter.zig").TimeFormat;
    const WarningThresholds = @import("time_formatter.zig").WarningThresholds;
    const FormattedTime = @import("time_formatter.zig").FormattedTime;
    const getTimeColorRecommendation = @import("time_formatter.zig").getTimeColorRecommendation;

    const allocator = testing.allocator;

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TYPES ══════════════════════════════════════╗

    /// Test data for format verification
    const FormatTestCase = struct {
        seconds: u32,
        format: TimeFormat,
        expected: []const u8,
    };

    /// Test data for warning thresholds
    const WarningTestCase = struct {
        seconds: u32,
        expected_warning: bool,
        expected_critical: bool,
    };

    /// Test data for quarter formatting
    const QuarterTestCase = struct {
        quarter: u8,
        is_overtime: bool,
        expected: []const u8,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐

    test "unit: TimeFormatter: initializes with default thresholds" {
        var formatter = TimeFormatter.init(allocator);
        
        try testing.expectEqual(@as(u32, 5), formatter.thresholds.play_clock_warning);
        try testing.expectEqual(@as(u32, 120), formatter.thresholds.quarter_warning);
        try testing.expectEqual(@as(u32, 10), formatter.thresholds.critical_time);
    }

    test "unit: TimeFormatter: initializes with custom thresholds" {
        const custom_thresholds = WarningThresholds{
            .play_clock_warning = 10,
            .quarter_warning = 60,
            .critical_time = 5,
        };
        
        var formatter = TimeFormatter.initWithThresholds(allocator, custom_thresholds);
        
        try testing.expectEqual(@as(u32, 10), formatter.thresholds.play_clock_warning);
        try testing.expectEqual(@as(u32, 60), formatter.thresholds.quarter_warning);
        try testing.expectEqual(@as(u32, 5), formatter.thresholds.critical_time);
    }

    test "unit: TimeFormatter: formats game time in standard format" {
        var formatter = TimeFormatter.init(allocator);
        
        const test_cases = [_]FormatTestCase{
            .{ .seconds = 900, .format = .standard, .expected = "15:00" },
            .{ .seconds = 0, .format = .standard, .expected = "00:00" },
            .{ .seconds = 125, .format = .standard, .expected = "02:05" },
            .{ .seconds = 59, .format = .standard, .expected = "00:59" },
            .{ .seconds = 3599, .format = .standard, .expected = "59:59" },
        };
        
        for (test_cases) |tc| {
            const result = try formatter.formatGameTime(tc.seconds, tc.format);
            try testing.expectEqualStrings(tc.expected, result);
        }
    }

    test "unit: TimeFormatter: formats game time in compact format" {
        var formatter = TimeFormatter.init(allocator);
        
        const test_cases = [_]FormatTestCase{
            .{ .seconds = 585, .format = .compact, .expected = "9:45" },
            .{ .seconds = 59, .format = .compact, .expected = "0:59" },
            .{ .seconds = 600, .format = .compact, .expected = "10:00" },
            .{ .seconds = 900, .format = .compact, .expected = "15:00" },
        };
        
        for (test_cases) |tc| {
            const result = try formatter.formatGameTime(tc.seconds, tc.format);
            try testing.expectEqualStrings(tc.expected, result);
        }
    }

    test "unit: TimeFormatter: formats game time in full format" {
        var formatter = TimeFormatter.init(allocator);
        
        const test_cases = [_]FormatTestCase{
            .{ .seconds = 3661, .format = .full, .expected = "01:01:01" },
            .{ .seconds = 7200, .format = .full, .expected = "02:00:00" },
            .{ .seconds = 0, .format = .full, .expected = "00:00:00" },
            .{ .seconds = 86399, .format = .full, .expected = "23:59:59" },
        };
        
        for (test_cases) |tc| {
            const result = try formatter.formatGameTime(tc.seconds, tc.format);
            try testing.expectEqualStrings(tc.expected, result);
        }
    }

    test "unit: TimeFormatter: formats play clock with warnings" {
        var formatter = TimeFormatter.init(allocator);
        
        const test_cases = [_]WarningTestCase{
            .{ .seconds = 40, .expected_warning = false, .expected_critical = false },
            .{ .seconds = 25, .expected_warning = false, .expected_critical = false },
            .{ .seconds = 5, .expected_warning = true, .expected_critical = false },
            .{ .seconds = 3, .expected_warning = true, .expected_critical = true },
            .{ .seconds = 1, .expected_warning = true, .expected_critical = true },
            .{ .seconds = 0, .expected_warning = true, .expected_critical = true },
        };
        
        for (test_cases) |tc| {
            const result = formatter.formatPlayClock(tc.seconds);
            try testing.expectEqual(tc.expected_warning, result.is_warning);
            try testing.expectEqual(tc.expected_critical, result.is_critical);
        }
    }

    test "unit: TimeFormatter: formats quarters correctly" {
        var formatter = TimeFormatter.init(allocator);
        
        const test_cases = [_]QuarterTestCase{
            .{ .quarter = 1, .is_overtime = false, .expected = "1st Quarter" },
            .{ .quarter = 2, .is_overtime = false, .expected = "2nd Quarter" },
            .{ .quarter = 3, .is_overtime = false, .expected = "3rd Quarter" },
            .{ .quarter = 4, .is_overtime = false, .expected = "4th Quarter" },
            .{ .quarter = 5, .is_overtime = true, .expected = "OT1" },
            .{ .quarter = 6, .is_overtime = true, .expected = "OT2" },
            .{ .quarter = 1, .is_overtime = true, .expected = "OT" },
        };
        
        for (test_cases) |tc| {
            const result = try formatter.formatQuarter(tc.quarter, tc.is_overtime);
            try testing.expectEqualStrings(tc.expected, result);
        }
    }

    test "unit: TimeFormatter: formats timeouts correctly" {
        var formatter = TimeFormatter.init(allocator);
        
        const result_none = try formatter.formatTimeouts(0, "Patriots");
        try testing.expectEqualStrings("Patriots: No timeouts", result_none);
        
        const result_one = try formatter.formatTimeouts(1, "Giants");
        try testing.expectEqualStrings("Giants: 1 timeout", result_one);
        
        const result_multiple = try formatter.formatTimeouts(3, "Cowboys");
        try testing.expectEqualStrings("Cowboys: 3 timeouts", result_multiple);
    }

    test "unit: TimeFormatter: formats down and distance" {
        var formatter = TimeFormatter.init(allocator);
        
        const normal = try formatter.formatDownAndDistance(3, 7, false);
        try testing.expectEqualStrings("3rd & 7", normal);
        
        const first = try formatter.formatDownAndDistance(1, 10, false);
        try testing.expectEqualStrings("1st & 10", first);
        
        const goal = try formatter.formatDownAndDistance(2, 0, true);
        try testing.expectEqualStrings("2nd & Goal", goal);
    }

    test "unit: TimeFormatter: formats score display" {
        var formatter = TimeFormatter.init(allocator);
        
        const result = try formatter.formatScore(21, 17, "Patriots", "Giants");
        try testing.expectEqualStrings("Giants 17 - 21 Patriots", result);
        
        const shutout = try formatter.formatScore(35, 0, "Cowboys", "Eagles");
        try testing.expectEqualStrings("Eagles 0 - 35 Cowboys", shutout);
    }

    test "unit: TimeFormatter: gets correct color recommendations" {
        const thresholds = WarningThresholds{
            .play_clock_warning = 5,
            .quarter_warning = 120,
            .critical_time = 10,
        };
        
        try testing.expectEqual(.normal, getTimeColorRecommendation(30, thresholds));
        try testing.expectEqual(.warning, getTimeColorRecommendation(5, thresholds));
        try testing.expectEqual(.critical, getTimeColorRecommendation(3, thresholds));
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Integration Tests ────────────────────────────┐

    test "integration: TimeFormatter: handles time with context correctly" {
        var formatter = TimeFormatter.init(allocator);
        
        // Normal time
        const normal = try formatter.formatTimeWithContext(300, 1, false);
        try testing.expectEqualStrings("05:00", normal);
        
        // Two-minute warning
        const warning = try formatter.formatTimeWithContext(120, 2, true);
        try testing.expectEqualStrings("Two-Minute Warning", warning);
        
        // Final minute of half
        const final_minute = try formatter.formatTimeWithContext(45, 2, false);
        try testing.expectEqualStrings("00:45 - Final minute", final_minute);
        
        // Final minute of game
        const final_game = try formatter.formatTimeWithContext(30, 4, false);
        try testing.expectEqualStrings("00:30 - Final minute", final_game);
    }

    test "integration: TimeFormatter: formats elapsed time correctly" {
        var formatter = TimeFormatter.init(allocator);
        
        // First quarter time
        const q1_time = try formatter.formatElapsedTime(300);
        try testing.expectEqualStrings("00:05:00", q1_time);
        
        // Half time elapsed
        const half_time = try formatter.formatElapsedTime(1800);
        try testing.expectEqualStrings("00:30:00", half_time);
        
        // Full game plus overtime
        const overtime = try formatter.formatElapsedTime(4200);
        try testing.expectEqualStrings("01:10:00", overtime);
    }

    test "integration: TimeFormatter: handles time remaining with tenths" {
        var formatter = TimeFormatter.init(allocator);
        
        // Time with tenths (under 10 seconds)
        const with_tenths = try formatter.formatTimeRemaining(5, true);
        // Note: This will include dynamic tenths, so we just check format
        try testing.expect(std.mem.indexOf(u8, with_tenths, ":") != null);
        
        // Time without tenths
        const without_tenths = try formatter.formatTimeRemaining(15, false);
        try testing.expectEqualStrings("00:15", without_tenths);
        
        // Time with tenths but over 10 seconds (should not show tenths)
        const no_tenths_high = try formatter.formatTimeRemaining(15, true);
        try testing.expectEqualStrings("00:15", no_tenths_high);
    }

    test "integration: TimeFormatter: handles custom warning thresholds" {
        const custom_thresholds = WarningThresholds{
            .play_clock_warning = 10,
            .quarter_warning = 180,
            .critical_time = 15,
        };
        
        var formatter = TimeFormatter.initWithThresholds(allocator, custom_thresholds);
        
        // Test play clock with custom threshold
        const warning = formatter.formatPlayClock(10);
        try testing.expect(warning.is_warning);
        
        const no_warning = formatter.formatPlayClock(11);
        try testing.expect(!no_warning.is_warning);
        
        // Test critical time with custom threshold
        const critical = formatter.formatPlayClock(3);
        try testing.expect(critical.is_critical);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── End-to-End Tests ────────────────────────────┐

    test "e2e: TimeFormatter: formats complete game scenario" {
        var formatter = TimeFormatter.init(allocator);
        
        // Start of game
        const start = try formatter.formatGameTime(900, .standard);
        try testing.expectEqualStrings("15:00", start);
        
        const q1 = try formatter.formatQuarter(1, false);
        try testing.expectEqualStrings("1st Quarter", q1);
        
        // During game
        const mid_q2 = try formatter.formatGameTime(450, .standard);
        try testing.expectEqualStrings("07:30", mid_q2);
        
        // Two minute warning
        const two_min = try formatter.formatTimeWithContext(120, 2, true);
        try testing.expectEqualStrings("Two-Minute Warning", two_min);
        
        // End of half
        const half_end = try formatter.formatGameTime(0, .standard);
        try testing.expectEqualStrings("00:00", half_end);
        
        // Overtime
        const ot = try formatter.formatQuarter(5, true);
        try testing.expectEqualStrings("OT1", ot);
        
        const ot_time = try formatter.formatGameTime(600, .standard);
        try testing.expectEqualStrings("10:00", ot_time);
    }

    test "e2e: TimeFormatter: handles complete drive formatting" {
        var formatter = TimeFormatter.init(allocator);
        
        // Drive start
        const down1 = try formatter.formatDownAndDistance(1, 10, false);
        try testing.expectEqualStrings("1st & 10", down1);
        
        var play_clock = formatter.formatPlayClock(40);
        try testing.expect(!play_clock.is_warning);
        
        // After first play
        const down2 = try formatter.formatDownAndDistance(2, 7, false);
        try testing.expectEqualStrings("2nd & 7", down2);
        
        // Third down
        const down3 = try formatter.formatDownAndDistance(3, 3, false);
        try testing.expectEqualStrings("3rd & 3", down3);
        
        // Play clock running down
        play_clock = formatter.formatPlayClock(4);
        try testing.expect(play_clock.is_warning);
        try testing.expect(!play_clock.is_critical);
        
        // Critical play clock
        play_clock = formatter.formatPlayClock(2);
        try testing.expect(play_clock.is_critical);
        
        // Red zone
        const goal = try formatter.formatDownAndDistance(1, 0, true);
        try testing.expectEqualStrings("1st & Goal", goal);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

    test "performance: TimeFormatter: formats time efficiently" {
        var formatter = TimeFormatter.init(allocator);
        
        const start_time = std.time.milliTimestamp();
        
        // Format 10000 times
        for (0..10000) |i| {
            const seconds = @as(u32, @intCast(i % 3600));
            _ = try formatter.formatGameTime(seconds, .standard);
        }
        
        const elapsed = std.time.milliTimestamp() - start_time;
        
        // Should complete in under 100ms
        try testing.expect(elapsed < 100);
    }

    test "performance: TimeFormatter: handles rapid format changes" {
        var formatter = TimeFormatter.init(allocator);
        
        const start_time = std.time.milliTimestamp();
        
        // Rapidly switch between formats
        for (0..5000) |i| {
            const seconds = @as(u32, @intCast(i % 900));
            const format_choice = i % 4;
            
            const format: TimeFormat = switch (format_choice) {
                0 => .standard,
                1 => .compact,
                2 => .with_tenths,
                3 => .full,
                else => .standard,
            };
            
            _ = try formatter.formatGameTime(seconds, format);
        }
        
        const elapsed = std.time.milliTimestamp() - start_time;
        
        // Should complete in under 100ms
        try testing.expect(elapsed < 100);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Stress Tests ────────────────────────────┐

    test "stress: TimeFormatter: handles extreme time values" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test with 0
        const zero = try formatter.formatGameTime(0, .standard);
        try testing.expectEqualStrings("00:00", zero);
        
        // Test with maximum reasonable game time (4 hours)
        const max_time = try formatter.formatGameTime(14400, .full);
        try testing.expectEqualStrings("04:00:00", max_time);
        
        // Test with very large number
        const huge = try formatter.formatGameTime(99999, .full);
        try testing.expectEqualStrings("27:46:39", huge);
        
        // Test play clock boundaries
        const pc_zero = formatter.formatPlayClock(0);
        try testing.expectEqualStrings("00", pc_zero.text);
        
        const pc_max = formatter.formatPlayClock(99);
        try testing.expectEqualStrings("99", pc_max.text);
    }

    test "stress: TimeFormatter: handles long team names" {
        var formatter = TimeFormatter.init(allocator);
        
        const long_name = "VeryLongTeamNameThatExceedsNormalLength";
        const result = try formatter.formatTimeouts(2, long_name);
        try testing.expect(std.mem.indexOf(u8, result, long_name) != null);
        try testing.expect(std.mem.indexOf(u8, result, "2 timeouts") != null);
    }

    test "stress: TimeFormatter: handles rapid threshold changes" {
        const allocator_local = testing.allocator;
        
        // Create formatters with different thresholds
        for (0..100) |i| {
            const thresholds = WarningThresholds{
                .play_clock_warning = @as(u32, @intCast((i % 20) + 1)),
                .quarter_warning = @as(u32, @intCast((i % 200) + 60)),
                .critical_time = @as(u32, @intCast((i % 15) + 1)),
            };
            
            var formatter = TimeFormatter.initWithThresholds(allocator_local, thresholds);
            
            // Test with various times
            const result = formatter.formatPlayClock(@as(u32, @intCast(i % 40)));
            
            // Verify warning logic
            if (result.text.len > 0) {
                const seconds = @as(u32, @intCast(i % 40));
                const should_warn = seconds <= thresholds.play_clock_warning;
                try testing.expectEqual(should_warn, result.is_warning);
            }
        }
    }

    test "stress: TimeFormatter: handles all quarter combinations" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test all regular quarters
        for (1..5) |q| {
            const quarter = @as(u8, @intCast(q));
            const result = try formatter.formatQuarter(quarter, false);
            try testing.expect(result.len > 0);
            try testing.expect(std.mem.indexOf(u8, result, "Quarter") != null);
        }
        
        // Test multiple overtimes
        for (5..10) |ot| {
            const quarter = @as(u8, @intCast(ot));
            const result = try formatter.formatQuarter(quarter, true);
            try testing.expect(result.len > 0);
            try testing.expect(std.mem.indexOf(u8, result, "OT") != null);
        }
        
        // Test edge cases
        const edge1 = try formatter.formatQuarter(0, false);
        try testing.expectEqualStrings("0th Quarter", edge1);
        
        const edge2 = try formatter.formatQuarter(255, false);
        try testing.expectEqualStrings("255th Quarter", edge2);
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝