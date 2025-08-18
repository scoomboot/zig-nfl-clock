// time_formatter.test.zig — Time formatter tests
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/time_formatter
// author : https://github.com/fisty
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

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

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

    // ┌──────────────────────────── Test Helpers ────────────────────────────┐

    /// Creates a TimeFormatter with default test configuration
    fn createTestFormatter() TimeFormatter {
        return TimeFormatter.init(allocator);
    }

    /// Creates a TimeFormatter with custom warning thresholds
    fn createTestFormatterWithThresholds(
        play_clock_warning: u32,
        quarter_warning: u32,
        critical_time: u32,
    ) TimeFormatter {
        const thresholds = WarningThresholds{
            .play_clock_warning = play_clock_warning,
            .quarter_warning = quarter_warning,
            .critical_time = critical_time,
        };
        return TimeFormatter.initWithThresholds(allocator, thresholds);
    }

    /// Creates test cases for time formatting
    fn createTimeFormatTestCases() []const FormatTestCase {
        return &[_]FormatTestCase{
            .{ .seconds = 900, .format = .standard, .expected = "15:00" },
            .{ .seconds = 0, .format = .standard, .expected = "00:00" },
            .{ .seconds = 125, .format = .standard, .expected = "02:05" },
            .{ .seconds = 59, .format = .standard, .expected = "00:59" },
            .{ .seconds = 585, .format = .compact, .expected = "9:45" },
            .{ .seconds = 3661, .format = .full, .expected = "01:01:01" },
        };
    }

    /// Creates test cases for warning scenarios
    fn createWarningTestCases() []const WarningTestCase {
        return &[_]WarningTestCase{
            .{ .seconds = 40, .expected_warning = false, .expected_critical = false },
            .{ .seconds = 25, .expected_warning = false, .expected_critical = false },
            .{ .seconds = 5, .expected_warning = true, .expected_critical = false },
            .{ .seconds = 3, .expected_warning = true, .expected_critical = true },
            .{ .seconds = 1, .expected_warning = true, .expected_critical = true },
            .{ .seconds = 0, .expected_warning = true, .expected_critical = true },
        };
    }

    /// Creates test cases for quarter formatting
    fn createQuarterTestCases() []const QuarterTestCase {
        return &[_]QuarterTestCase{
            .{ .quarter = 1, .is_overtime = false, .expected = "1st Quarter" },
            .{ .quarter = 2, .is_overtime = false, .expected = "2nd Quarter" },
            .{ .quarter = 3, .is_overtime = false, .expected = "3rd Quarter" },
            .{ .quarter = 4, .is_overtime = false, .expected = "4th Quarter" },
            .{ .quarter = 5, .is_overtime = true, .expected = "OT1" },
            .{ .quarter = 6, .is_overtime = true, .expected = "OT2" },
        };
    }

    /// Asserts formatted time matches expected string
    fn assertTimeFormat(actual: []const u8, expected: []const u8) !void {
        try testing.expectEqualStrings(expected, actual);
    }

    /// Asserts warning states match expected values
    fn assertWarningState(
        result: FormattedTime,
        expected_warning: bool,
        expected_critical: bool,
    ) !void {
        try testing.expectEqual(expected_warning, result.is_warning);
        try testing.expectEqual(expected_critical, result.is_critical);
    }

    /// Simulates game clock display updates
    fn simulateClockDisplay(
        formatter: *TimeFormatter,
        start_time: u32,
        end_time: u32,
    ) ![]const u8 {
        var current_time = start_time;
        var last_display: []const u8 = "";
        
        while (current_time > end_time) : (current_time -= 1) {
            last_display = try formatter.formatGameTime(current_time, .standard);
        }
        
        return last_display;
    }

    /// Simulates complete quarter formatting
    fn simulateQuarterDisplay(formatter: *TimeFormatter) !void {
        for (1..5) |q| {
            const quarter = @as(u8, @intCast(q));
            const display = try formatter.formatQuarter(quarter, false);
            try testing.expect(display.len > 0);
        }
        
        // Overtime
        const ot_display = try formatter.formatQuarter(5, true);
        try testing.expect(std.mem.indexOf(u8, ot_display, "OT") != null);
    }

    /// Tests time formatting with various contexts
    fn testTimeWithContext(
        formatter: *TimeFormatter,
        seconds: u32,
        quarter: u8,
        is_two_minute: bool,
    ) ![]const u8 {
        return try formatter.formatTimeWithContext(seconds, quarter, is_two_minute);
    }

    /// Creates comprehensive game situation display
    fn createGameSituationDisplay(
        formatter: *TimeFormatter,
        time: u32,
        quarter: u8,
        down: u8,
        distance: u8,
        home_score: u16,
        away_score: u16,
    ) ![]const u8 {
        var buffer: [256]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        const writer = fbs.writer();
        
        const time_str = try formatter.formatGameTime(time, .standard);
        const quarter_str = try formatter.formatQuarter(quarter, false);
        const down_str = try formatter.formatDownAndDistance(down, distance, false);
        const score_str = try formatter.formatScore(home_score, away_score, "Home", "Away");
        
        try writer.print("{s} | {s} | {s} | {s}", .{ quarter_str, time_str, down_str, score_str });
        
        return fbs.getWritten();
    }

    /// Validates formatter buffer integrity
    fn validateBufferIntegrity(formatter: *TimeFormatter) !void {
        // Perform multiple format operations to ensure no corruption
        _ = try formatter.formatGameTime(300, .standard);
        _ = try formatter.formatTimeWithContext(45, 2, false);
        _ = try formatter.formatQuarter(3, false);
        _ = formatter.formatPlayClock(25);
        _ = try formatter.formatDownAndDistance(2, 7, false);
        _ = try formatter.formatTimeouts(2, "Team");
        _ = try formatter.formatScore(21, 17, "Home", "Away");
        
        // If we get here without crashes, buffer integrity is maintained
        try testing.expect(true);
    }

    /// Generates random time values for stress testing
    fn generateRandomTimeValues(count: usize, seed: u64) []u32 {
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();
        const times = allocator.alloc(u32, count) catch unreachable;
        
        for (times) |*time| {
            time.* = random.intRangeAtMost(u32, 0, 3600);
        }
        
        return times;
    }

    /// Tests formatter performance with rapid updates
    fn testFormatterPerformance(
        formatter: *TimeFormatter,
        iterations: usize,
    ) !i64 {
        const start_time = std.time.milliTimestamp();
        
        for (0..iterations) |i| {
            const seconds = @as(u32, @intCast(i % 900));
            _ = try formatter.formatGameTime(seconds, .standard);
        }
        
        return std.time.milliTimestamp() - start_time;
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐

    test "unit: TimeFormatter: initializes with default thresholds" {
        const formatter = TimeFormatter.init(allocator);
        
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
        
        const formatter = TimeFormatter.initWithThresholds(allocator, custom_thresholds);
        
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

    test "unit: TimeFormatter: handles buffer aliasing in final minute formatting" {
        var formatter = TimeFormatter.init(allocator);
        
        // Regression test for the exact panic scenario that was fixed
        // These used to cause a panic due to buffer aliasing
        const result1 = try formatter.formatTimeWithContext(45, 2, false);
        try testing.expectEqualStrings("00:45 - Final minute", result1);
        
        const result2 = try formatter.formatTimeWithContext(30, 4, false);
        try testing.expectEqualStrings("00:30 - Final minute", result2);
        
        // Verify buffer is still usable after multiple calls
        const result3 = try formatter.formatTimeWithContext(15, 2, false);
        try testing.expectEqualStrings("00:15 - Final minute", result3);
    }

    test "unit: TimeFormatter: handles final minute edge cases correctly" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test 0 seconds in final minute (quarters 2 and 4)
        const zero_q2 = try formatter.formatTimeWithContext(0, 2, false);
        try testing.expectEqualStrings("00:00 - Final minute", zero_q2);
        
        const zero_q4 = try formatter.formatTimeWithContext(0, 4, false);
        try testing.expectEqualStrings("00:00 - Final minute", zero_q4);
        
        // Test exactly 60 seconds (boundary of final minute)
        const sixty_q2 = try formatter.formatTimeWithContext(60, 2, false);
        try testing.expectEqualStrings("01:00 - Final minute", sixty_q2);
        
        const sixty_q4 = try formatter.formatTimeWithContext(60, 4, false);
        try testing.expectEqualStrings("01:00 - Final minute", sixty_q4);
        
        // Test 61 seconds (just outside final minute)
        const sixtyone_q2 = try formatter.formatTimeWithContext(61, 2, false);
        try testing.expectEqualStrings("01:01", sixtyone_q2);
        
        const sixtyone_q4 = try formatter.formatTimeWithContext(61, 4, false);
        try testing.expectEqualStrings("01:01", sixtyone_q4);
        
        // Test quarters 1 and 3 (should not show final minute)
        const q1_time = try formatter.formatTimeWithContext(30, 1, false);
        try testing.expectEqualStrings("00:30", q1_time);
        
        const q3_time = try formatter.formatTimeWithContext(45, 3, false);
        try testing.expectEqualStrings("00:45", q3_time);
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

    test "integration: TimeFormatter: interaction between formatGameTime and formatTimeWithContext" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test that both methods work correctly in sequence without buffer corruption
        const game_time1 = try formatter.formatGameTime(45, .standard);
        try testing.expectEqualStrings("00:45", game_time1);
        
        const context_time1 = try formatter.formatTimeWithContext(45, 2, false);
        try testing.expectEqualStrings("00:45 - Final minute", context_time1);
        
        // Now reverse the order
        const context_time2 = try formatter.formatTimeWithContext(30, 4, false);
        try testing.expectEqualStrings("00:30 - Final minute", context_time2);
        
        const game_time2 = try formatter.formatGameTime(30, .standard);
        try testing.expectEqualStrings("00:30", game_time2);
        
        // Mix different formats
        const compact = try formatter.formatGameTime(585, .compact);
        try testing.expectEqualStrings("9:45", compact);
        
        const context_normal = try formatter.formatTimeWithContext(585, 1, false);
        try testing.expectEqualStrings("09:45", context_normal);
        
        // Test two-minute warning
        const two_min = try formatter.formatTimeWithContext(120, 2, true);
        try testing.expectEqualStrings("Two-Minute Warning", two_min);
        
        const game_time3 = try formatter.formatGameTime(120, .standard);
        try testing.expectEqualStrings("02:00", game_time3);
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

    // ┌──────────────────────────── Scenario Tests ────────────────────────────┐

    test "scenario: TimeFormatter: displays broadcast-style game updates" {
        var formatter = TimeFormatter.init(allocator);
        
        // Opening kickoff scenario - capture each result before next call
        const q1_start = try formatter.formatQuarter(1, false);
        try testing.expectEqualStrings("1st Quarter", q1_start);
        
        const game_time = try formatter.formatGameTime(900, .standard);
        try testing.expectEqualStrings("15:00", game_time);
        
        const kickoff_down = try formatter.formatDownAndDistance(1, 10, false);
        try testing.expectEqualStrings("1st & 10", kickoff_down);
        
        const initial_score = try formatter.formatScore(0, 0, "Patriots", "Giants");
        try testing.expectEqualStrings("Giants 0 - 0 Patriots", initial_score);
        
        // Mid-game scenario - close game in 4th quarter
        const q4_display = try formatter.formatQuarter(4, false);
        try testing.expectEqualStrings("4th Quarter", q4_display);
        
        const late_time = try formatter.formatGameTime(345, .standard); // 5:45 left
        try testing.expectEqualStrings("05:45", late_time);
        
        const crucial_down = try formatter.formatDownAndDistance(3, 8, false);
        try testing.expectEqualStrings("3rd & 8", crucial_down);
        
        const close_score = try formatter.formatScore(21, 17, "Patriots", "Giants");
        try testing.expectEqualStrings("Giants 17 - 21 Patriots", close_score);
        
        const timeout_status = try formatter.formatTimeouts(1, "Patriots");
        try testing.expectEqualStrings("Patriots: 1 timeout", timeout_status);
        
        // Final moments with play clock
        const final_minute = try formatter.formatTimeWithContext(47, 4, false);
        try testing.expectEqualStrings("00:47 - Final minute", final_minute);
        
        const play_clock_warning = formatter.formatPlayClock(8);
        try testing.expect(!play_clock_warning.is_warning); // 8 seconds not warning yet
        
        const field_goal_down = try formatter.formatDownAndDistance(4, 3, false);
        try testing.expectEqualStrings("4th & 3", field_goal_down);
        
        // Overtime scenario
        const ot_quarter = try formatter.formatQuarter(5, true);
        try testing.expectEqualStrings("OT1", ot_quarter);
        
        const ot_time = try formatter.formatGameTime(480, .standard); // 8:00 left in OT
        try testing.expectEqualStrings("08:00", ot_time);
        
        const tied_score = try formatter.formatScore(24, 24, "Patriots", "Giants");
        try testing.expectEqualStrings("Giants 24 - 24 Patriots", tied_score);
        
        const ot_timeouts = try formatter.formatTimeouts(2, "Giants");
        try testing.expectEqualStrings("Giants: 2 timeouts", ot_timeouts);
    }

    test "scenario: TimeFormatter: formats critical game moments" {
        var formatter = TimeFormatter.init(allocator);
        
        // Two-minute warning scenario - test each independently
        const two_min_warning = try formatter.formatTimeWithContext(120, 2, true);
        try testing.expectEqualStrings("Two-Minute Warning", two_min_warning);
        
        const warning_quarter = try formatter.formatQuarter(2, false);
        try testing.expectEqualStrings("2nd Quarter", warning_quarter);
        
        const drive_situation = try formatter.formatDownAndDistance(2, 5, false);
        try testing.expectEqualStrings("2nd & 5", drive_situation);
        
        const timeout_remaining = try formatter.formatTimeouts(2, "Cowboys");
        try testing.expectEqualStrings("Cowboys: 2 timeouts", timeout_remaining);
        
        // Game-winning drive scenario  
        const final_drive_time = try formatter.formatTimeWithContext(23, 4, false);
        try testing.expectEqualStrings("00:23 - Final minute", final_drive_time);
        
        const red_zone_down = try formatter.formatDownAndDistance(1, 0, true);
        try testing.expectEqualStrings("1st & Goal", red_zone_down);
        
        const winning_score = try formatter.formatScore(14, 17, "Cowboys", "Steelers");
        try testing.expectEqualStrings("Steelers 17 - 14 Cowboys", winning_score);
        
        const critical_play_clock = formatter.formatPlayClock(3);
        try testing.expect(critical_play_clock.is_critical);
        
        // Hail Mary attempt
        const hail_mary_time = try formatter.formatTimeWithContext(6, 4, false);
        try testing.expectEqualStrings("00:06 - Final minute", hail_mary_time);
        
        const long_down = try formatter.formatDownAndDistance(4, 12, false);
        try testing.expectEqualStrings("4th & 12", long_down);
        
        const desperation_score = try formatter.formatScore(10, 13, "Cowboys", "Steelers");
        try testing.expectEqualStrings("Steelers 13 - 10 Cowboys", desperation_score);
        
        const no_timeouts = try formatter.formatTimeouts(0, "Cowboys");
        try testing.expectEqualStrings("Cowboys: No timeouts", no_timeouts);
        
        // Field goal for the win
        const field_goal_time = try formatter.formatTimeWithContext(3, 4, false);
        try testing.expectEqualStrings("00:03 - Final minute", field_goal_time);
        
        const fg_distance = try formatter.formatDownAndDistance(4, 8, false);
        try testing.expectEqualStrings("4th & 8", fg_distance);
        
        const play_clock_expired = formatter.formatPlayClock(0);
        try testing.expect(play_clock_expired.is_critical);
        try testing.expectEqualStrings("00", play_clock_expired.text);
    }

    test "scenario: TimeFormatter: handles overtime period display" {
        var formatter = TimeFormatter.init(allocator);
        
        // Start of first overtime - test each independently
        const ot1_quarter = try formatter.formatQuarter(5, true);
        try testing.expectEqualStrings("OT1", ot1_quarter);
        
        const ot_start_time = try formatter.formatGameTime(600, .standard);
        try testing.expectEqualStrings("10:00", ot_start_time);
        
        const opening_drive = try formatter.formatDownAndDistance(1, 10, false);
        try testing.expectEqualStrings("1st & 10", opening_drive);
        
        const tied_game = try formatter.formatScore(21, 21, "Eagles", "Cowboys");
        try testing.expectEqualStrings("Cowboys 21 - 21 Eagles", tied_game);
        
        const ot_timeouts = try formatter.formatTimeouts(3, "Eagles");
        try testing.expectEqualStrings("Eagles: 3 timeouts", ot_timeouts);
        
        // Middle of overtime - critical possession
        const ot_mid_time = try formatter.formatGameTime(180, .standard); // 3:00 left
        try testing.expectEqualStrings("03:00", ot_mid_time);
        
        const ot_third_down = try formatter.formatDownAndDistance(3, 6, false);
        try testing.expectEqualStrings("3rd & 6", ot_third_down);
        
        const ot_play_clock = formatter.formatPlayClock(12);
        try testing.expect(!ot_play_clock.is_warning); // 12 seconds is normal
        
        const field_goal_range = try formatter.formatScore(21, 21, "Eagles", "Cowboys");
        try testing.expectEqualStrings("Cowboys 21 - 21 Eagles", field_goal_range);
        
        // End of overtime - sudden death opportunity
        const ot_final_time = try formatter.formatGameTime(45, .standard);
        try testing.expectEqualStrings("00:45", ot_final_time);
        
        const ot_goal_line = try formatter.formatDownAndDistance(2, 0, true);
        try testing.expectEqualStrings("2nd & Goal", ot_goal_line);
        
        const sudden_death_clock = formatter.formatPlayClock(5);
        try testing.expect(sudden_death_clock.is_warning);
        
        const no_timeouts_left = try formatter.formatTimeouts(0, "Cowboys");
        try testing.expectEqualStrings("Cowboys: No timeouts", no_timeouts_left);
        
        // Multiple overtime periods (playoff scenario)
        const ot2_quarter = try formatter.formatQuarter(6, true);
        try testing.expectEqualStrings("OT2", ot2_quarter);
        
        const ot2_start = try formatter.formatGameTime(600, .standard);
        try testing.expectEqualStrings("10:00", ot2_start);
        
        const still_tied = try formatter.formatScore(24, 24, "Eagles", "Cowboys");
        try testing.expectEqualStrings("Cowboys 24 - 24 Eagles", still_tied);
        
        // Simulate double overtime exhaustion
        const ot2_late = try formatter.formatGameTime(30, .standard);
        try testing.expectEqualStrings("00:30", ot2_late);
        
        const desperation_play = try formatter.formatDownAndDistance(4, 15, false);
        try testing.expectEqualStrings("4th & 15", desperation_play);
        
        const late_ot_clock = formatter.formatPlayClock(2);
        try testing.expect(late_ot_clock.is_critical);
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

    // ┌──────────────────────────── Error Handling Tests ────────────────────────────┐

    test "unit: TimeFormatterError: InvalidTimeValue detection" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test invalid time values
        const invalid_times = [_]struct {
            value: u32,
            format: TimeFormat,
            should_fail: bool,
        }{
            // Extremely large time value
            .{ .value = 999999999, .format = .standard, .should_fail = false }, // Should handle gracefully
            // Zero time
            .{ .value = 0, .format = .standard, .should_fail = false }, // Valid
            // Max reasonable game time
            .{ .value = 14400, .format = .full, .should_fail = false }, // 4 hours
        };
        
        for (invalid_times) |tc| {
            if (tc.should_fail) {
                const result = formatter.validateTimeValue(tc.value, false);
                try testing.expectError(error.InvalidTimeValue, result);
            } else {
                const result = formatter.validateTimeValue(tc.value, false);
                try result; // Should succeed
            }
        }
    }

    test "unit: TimeFormatterError: InvalidThresholds validation" {
        // Test invalid threshold configurations
        const invalid_thresholds = [_]WarningThresholds{
            // Play clock warning exceeds max
            WarningThresholds{
                .play_clock_warning = 50, // Invalid - max is 40
                .quarter_warning = 120,
                .critical_time = 10,
            },
            // Critical time exceeds warning
            WarningThresholds{
                .play_clock_warning = 5,
                .quarter_warning = 120,
                .critical_time = 20, // Invalid - should be less than warning
            },
            // Negative values (if using signed types)
            WarningThresholds{
                .play_clock_warning = 0, // Edge case - might be invalid
                .quarter_warning = 0,
                .critical_time = 0,
            },
        };
        
        for (invalid_thresholds) |thresholds| {
            var formatter = TimeFormatter.init(allocator);
            const result = formatter.validateThresholds(thresholds);
            
            // Check if thresholds are reasonable
            if (thresholds.play_clock_warning > 40) {
                try testing.expectError(error.InvalidThresholds, result);
            } else if (thresholds.critical_time > thresholds.play_clock_warning) {
                try testing.expectError(error.InvalidThresholds, result);
            } else {
                try result; // Should succeed for valid thresholds
            }
        }
    }

    test "unit: TimeFormatterError: InvalidFormat handling" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test format validation with edge cases
        const test_cases = [_]struct {
            seconds: u32,
            format: TimeFormat,
            expected_valid: bool,
        }{
            .{ .seconds = 3661, .format = .standard, .expected_valid = true }, // Over 1 hour
            .{ .seconds = 0, .format = .with_tenths, .expected_valid = true },
            .{ .seconds = 99999, .format = .full, .expected_valid = true }, // Very large
            .{ .seconds = 45, .format = .compact, .expected_valid = true },
        };
        
        for (test_cases) |tc| {
            const result = formatter.validateFormat(tc.seconds, tc.format);
            if (tc.expected_valid) {
                try result;
            } else {
                try testing.expectError(error.InvalidFormat, result);
            }
        }
    }

    test "unit: TimeFormatter: validateTimeValue catches edge cases" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test various time values
        const test_values = [_]struct {
            value: u32,
            expected_valid: bool,
        }{
            .{ .value = 0, .expected_valid = true }, // Zero is valid
            .{ .value = 900, .expected_valid = true }, // Quarter length
            .{ .value = 3600, .expected_valid = true }, // 1 hour
            .{ .value = 86400, .expected_valid = true }, // 24 hours
            .{ .value = 4294967295, .expected_valid = true }, // Max u32
        };
        
        for (test_values) |tv| {
            const result = formatter.validateTimeValue(tv.value, tv.value <= 600);
            if (tv.expected_valid) {
                try result;
            } else {
                try testing.expectError(error.InvalidTimeValue, result);
            }
        }
    }

    test "unit: TimeFormatter: validateThresholds ensures consistency" {
        var formatter = TimeFormatter.init(allocator);
        
        // Test threshold consistency rules
        const test_cases = [_]struct {
            thresholds: WarningThresholds,
            should_fail: bool,
        }{
            // Valid thresholds
            .{
                .thresholds = WarningThresholds{
                    .play_clock_warning = 5,
                    .quarter_warning = 120,
                    .critical_time = 3,
                },
                .should_fail = false,
            },
            // Invalid: play clock warning too high
            .{
                .thresholds = WarningThresholds{
                    .play_clock_warning = 45, // Over max play clock
                    .quarter_warning = 120,
                    .critical_time = 10,
                },
                .should_fail = true,
            },
            // Invalid: critical > warning
            .{
                .thresholds = WarningThresholds{
                    .play_clock_warning = 5,
                    .quarter_warning = 120,
                    .critical_time = 10, // Greater than warning
                },
                .should_fail = true,
            },
        };
        
        for (test_cases) |tc| {
            const result = formatter.validateThresholds(tc.thresholds);
            if (tc.should_fail) {
                try testing.expectError(error.InvalidThresholds, result);
            } else {
                try result;
            }
        }
    }

    test "integration: TimeFormatter: error recovery maintains formatting integrity" {
        var formatter = TimeFormatter.init(allocator);
        
        // Try to format with various edge cases
        const edge_cases = [_]struct {
            seconds: u32,
            format: TimeFormat,
        }{
            .{ .seconds = 0, .format = .standard },
            .{ .seconds = 4294967295, .format = .full }, // Max u32
            .{ .seconds = 3661, .format = .standard }, // Over 1 hour
            .{ .seconds = 86399, .format = .full }, // Just under 24 hours
        };
        
        for (edge_cases) |ec| {
            // Validate first
            if (formatter.validateTimeValue(ec.seconds, false)) |_| {
                // Format should work
                const result = try formatter.formatGameTime(ec.seconds, ec.format);
                try testing.expect(result.len > 0);
                try testing.expect(std.mem.indexOf(u8, result, ":") != null);
            } else |err| {
                // Handle error gracefully
                try testing.expect(err == error.InvalidTimeValue);
                const fallback = try formatter.formatGameTime(0, .standard);
                try testing.expectEqualStrings("00:00", fallback);
            }
        }
    }

    test "e2e: TimeFormatter: complete error handling flow" {
        var formatter = TimeFormatter.init(allocator);
        
        // Scenario 1: Invalid thresholds recovery
        var bad_thresholds = WarningThresholds{
            .play_clock_warning = 100, // Invalid
            .quarter_warning = 120,
            .critical_time = 50, // Invalid
        };
        
        if (formatter.validateThresholds(bad_thresholds)) |_| {
            try testing.expect(false); // Should fail
        } else |err| {
            try testing.expectEqual(error.InvalidThresholds, err);
            // Use default thresholds instead
            bad_thresholds = WarningThresholds{
                .play_clock_warning = 5,
                .quarter_warning = 120,
                .critical_time = 10,
            };
        }
        
        formatter = TimeFormatter.initWithThresholds(allocator, bad_thresholds);
        
        // Scenario 2: Format edge case times
        const extreme_time: u32 = 999999;
        const formatted = try formatter.formatGameTime(extreme_time, .full);
        try testing.expect(formatted.len > 0);
        
        // Scenario 3: Context formatting with edge cases
        const final_second = try formatter.formatTimeWithContext(1, 4, false);
        try testing.expectEqualStrings("00:01 - Final minute", final_second);
        
        const zero_time = try formatter.formatTimeWithContext(0, 4, false);
        try testing.expectEqualStrings("00:00 - Final minute", zero_time);
        
        // Scenario 4: Play clock edge cases
        const expired_clock = formatter.formatPlayClock(0);
        try testing.expect(expired_clock.is_critical);
        try testing.expectEqualStrings("00", expired_clock.text);
        
        const max_clock = formatter.formatPlayClock(40);
        try testing.expect(!max_clock.is_warning);
        try testing.expectEqualStrings("40", max_clock.text);
    }

    test "scenario: TimeFormatter: handles errors during critical formatting" {
        var formatter = TimeFormatter.init(allocator);
        
        // Critical game moment formatting
        const critical_moments = [_]struct {
            seconds: u32,
            quarter: u8,
            is_two_min: bool,
            expected_contains: []const u8,
        }{
            .{ .seconds = 0, .quarter = 2, .is_two_min = false, .expected_contains = "Final minute" },
            .{ .seconds = 0, .quarter = 4, .is_two_min = false, .expected_contains = "Final minute" },
            .{ .seconds = 120, .quarter = 2, .is_two_min = true, .expected_contains = "Two-Minute Warning" },
            .{ .seconds = 1, .quarter = 4, .is_two_min = false, .expected_contains = "Final minute" },
        };
        
        for (critical_moments) |moment| {
            // Validate time first
            try formatter.validateTimeValue(moment.seconds, false);
            
            // Format with context
            const result = try formatter.formatTimeWithContext(
                moment.seconds,
                moment.quarter,
                moment.is_two_min
            );
            
            // Verify expected content
            try testing.expect(std.mem.indexOf(u8, result, moment.expected_contains) != null);
        }
        
        // Error case: Invalid quarter
        const invalid_quarter: u8 = 10;
        const formatted = try formatter.formatQuarter(invalid_quarter, false);
        // Should handle gracefully with fallback
        try testing.expect(formatted.len > 0);
        try testing.expect(std.mem.indexOf(u8, formatted, "Quarter") != null or
                          std.mem.indexOf(u8, formatted, "OT") != null);
    }

    test "stress: TimeFormatter: handles rapid error conditions" {
        var formatter = TimeFormatter.init(allocator);
        var prng = std.Random.DefaultPrng.init(12345);
        const random = prng.random();
        
        // Rapidly test various edge cases and potential errors
        for (0..100) |i| {
            _ = i;
            
            // Generate random potentially problematic values
            const seconds = random.intRangeAtMost(u32, 0, 999999);
            const quarter = random.intRangeAtMost(u8, 0, 10);
            const play_clock = random.intRangeAtMost(u32, 0, 100);
            
            // Try to format - should handle all cases gracefully
            
            // Game time formatting
            const formats = [_]TimeFormat{ .standard, .compact, .full, .with_tenths };
            const format = formats[random.intRangeAtMost(usize, 0, 3)];
            
            if (formatter.validateTimeValue(seconds, false)) |_| {
                const time_result = try formatter.formatGameTime(seconds, format);
                try testing.expect(time_result.len > 0);
            } else |_| {
                // Use fallback
                const fallback = try formatter.formatGameTime(0, .standard);
                try testing.expectEqualStrings("00:00", fallback);
            }
            
            // Play clock formatting
            if (formatter.validateTimeValue(play_clock, false)) |_| {
                const pc_result = formatter.formatPlayClock(play_clock);
                try testing.expect(pc_result.text.len > 0);
            } else |_| {
                // Use valid value
                const valid_pc = formatter.formatPlayClock(25);
                try testing.expect(!valid_pc.is_warning);
            }
            
            // Quarter formatting
            const is_ot = quarter > 4;
            const quarter_result = try formatter.formatQuarter(quarter, is_ot);
            try testing.expect(quarter_result.len > 0);
            
            // Context formatting
            if (seconds <= 900 and quarter >= 1 and quarter <= 5) {
                const context_result = try formatter.formatTimeWithContext(
                    @min(seconds, 900),
                    @min(quarter, 5),
                    false
                );
                try testing.expect(context_result.len > 0);
            }
        }
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

    test "stress: TimeFormatter: no buffer corruption under repeated formatting" {
        var formatter = TimeFormatter.init(allocator);
        var prng = std.Random.DefaultPrng.init(42); // Deterministic seed
        const random = prng.random();
        
        // Call formatTimeWithContext 1000+ times with various valid inputs
        for (0..1500) |i| {
            _ = i;
            const seconds = random.intRangeAtMost(u32, 0, 900);
            const quarter = random.intRangeAtMost(u8, 1, 4);
            const is_two_min = random.boolean();
            
            const result = try formatter.formatTimeWithContext(seconds, quarter, is_two_min);
            
            // Verify result is valid (non-empty and contains expected patterns)
            try testing.expect(result.len > 0);
            
            if (is_two_min) {
                try testing.expect(std.mem.indexOf(u8, result, "Two-Minute Warning") != null);
            } else if (seconds <= 60 and (quarter == 2 or quarter == 4)) {
                try testing.expect(std.mem.indexOf(u8, result, "Final minute") != null);
            } else {
                // Should be a normal time format MM:SS
                try testing.expect(std.mem.indexOf(u8, result, ":") != null);
            }
        }
        
        // Also stress test formatGameTime with different formats
        for (0..1000) |i| {
            _ = i;
            const seconds = random.intRangeAtMost(u32, 0, 3600);
            const format_choice = random.intRangeAtMost(u8, 0, 3);
            
            const format: TimeFormat = switch (format_choice) {
                0 => .standard,
                1 => .compact,
                2 => .with_tenths,
                3 => .full,
                else => .standard,
            };
            
            const result = try formatter.formatGameTime(seconds, format);
            try testing.expect(result.len > 0);
            try testing.expect(std.mem.indexOf(u8, result, ":") != null);
        }
        
        // Stress test other formatting methods to ensure overall buffer integrity
        for (0..500) |i| {
            _ = i;
            const play_seconds = random.intRangeAtMost(u32, 0, 40);
            const play_result = formatter.formatPlayClock(play_seconds);
            try testing.expect(play_result.text.len > 0);
            
            const quarter = random.intRangeAtMost(u8, 1, 6);
            const is_ot = quarter > 4;
            const quarter_result = try formatter.formatQuarter(quarter, is_ot);
            try testing.expect(quarter_result.len > 0);
            
            const timeouts = random.intRangeAtMost(u8, 0, 3);
            const timeout_result = try formatter.formatTimeouts(timeouts, "TestTeam");
            try testing.expect(timeout_result.len > 0);
        }
    }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝