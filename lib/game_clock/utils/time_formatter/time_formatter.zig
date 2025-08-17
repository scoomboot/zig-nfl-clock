// time_formatter.zig — Time display and formatting utilities
//
// repo   : https://github.com/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock/utils/time_formatter
// author : https://github.com/fisty
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

    /// Time formatting utilities for NFL game clock display.
    ///
    /// This module provides comprehensive time formatting functions for various
    /// NFL game clock display scenarios including game time, play clock, quarters,
    /// timeouts, and contextual time displays with warning indicators.

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TYPES ═════════════════════════════════════╗

    /// Time display format options
    pub const TimeFormat = enum {
        /// MM:SS format (e.g., "15:00")
        standard,
        /// M:SS format when minutes < 10 (e.g., "9:45")
        compact,
        /// MM:SS.T format with tenths (e.g., "00:04.7")
        with_tenths,
        /// Full HH:MM:SS format for total game time
        full,
    };

    /// Warning threshold configuration
    pub const WarningThresholds = struct {
        /// Play clock warning threshold in seconds
        play_clock_warning: u32 = 5,
        /// Quarter time warning threshold in seconds
        quarter_warning: u32 = 120, // 2 minutes
        /// Critical time threshold in seconds
        critical_time: u32 = 10,
    };

    /// Formatted time result
    pub const FormattedTime = struct {
        /// The formatted time string
        text: []const u8,
        /// Whether time is in warning zone
        is_warning: bool = false,
        /// Whether time is critical
        is_critical: bool = false,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Time formatter instance
    pub const TimeFormatter = struct {
        allocator: std.mem.Allocator,
        thresholds: WarningThresholds,
        buffer: [128]u8,

        /// Initialize a new time formatter.
        ///
        /// Creates a formatter with default warning thresholds.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for dynamic allocations
        ///
        /// __Return__
        ///
        /// - Initialized TimeFormatter instance
        pub fn init(allocator: std.mem.Allocator) TimeFormatter {
            return .{
                .allocator = allocator,
                .thresholds = .{},
                .buffer = undefined,
            };
        }

        /// Initialize with custom warning thresholds.
        ///
        /// Creates a formatter with specified warning thresholds.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for dynamic allocations
        /// - `thresholds`: Custom warning threshold configuration
        ///
        /// __Return__
        ///
        /// - Initialized TimeFormatter instance with custom thresholds
        pub fn initWithThresholds(allocator: std.mem.Allocator, thresholds: WarningThresholds) TimeFormatter {
            return .{
                .allocator = allocator,
                .thresholds = thresholds,
                .buffer = undefined,
            };
        }

        /// Format game clock time (quarter time).
        ///
        /// Returns formatted string in specified format.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `seconds`: Time in seconds to format
        /// - `format`: Display format to use
        ///
        /// __Return__
        ///
        /// - Formatted time string or error
        pub fn formatGameTime(self: *TimeFormatter, seconds: u32, format: TimeFormat) ![]const u8 {
            const minutes = seconds / 60;
            const secs = seconds % 60;

            const result = switch (format) {
                .standard => try std.fmt.bufPrint(&self.buffer, "{d:0>2}:{d:0>2}", .{ minutes, secs }),
                .compact => blk: {
                    if (minutes < 10) {
                        break :blk try std.fmt.bufPrint(&self.buffer, "{d}:{d:0>2}", .{ minutes, secs });
                    } else {
                        break :blk try std.fmt.bufPrint(&self.buffer, "{d:0>2}:{d:0>2}", .{ minutes, secs });
                    }
                },
                .with_tenths => blk: {
                    // For displaying final seconds with tenths
                    if (seconds < 10) {
                        const timestamp = std.time.milliTimestamp();
                        const tenths = @mod(@abs(timestamp), 10);
                        break :blk try std.fmt.bufPrint(&self.buffer, "00:{d:0>2}.{d}", .{ secs, tenths });
                    } else {
                        break :blk try std.fmt.bufPrint(&self.buffer, "{d:0>2}:{d:0>2}", .{ minutes, secs });
                    }
                },
                .full => blk: {
                    const hours = minutes / 60;
                    const mins = minutes % 60;
                    break :blk try std.fmt.bufPrint(&self.buffer, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hours, mins, secs });
                },
            };

            return result;
        }

        /// Format play clock time with warning indicators.
        ///
        /// Formats play clock and indicates warning states.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `seconds`: Play clock time in seconds
        ///
        /// __Return__
        ///
        /// - FormattedTime with text and warning flags
        pub fn formatPlayClock(self: *TimeFormatter, seconds: u32) FormattedTime {
            const text = std.fmt.bufPrint(&self.buffer, "{d:0>2}", .{seconds}) catch "00";
            
            return .{
                .text = text,
                .is_warning = seconds <= self.thresholds.play_clock_warning,
                .is_critical = seconds <= 3,
            };
        }

        /// Format quarter display.
        ///
        /// Formats quarter number with appropriate suffix.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `quarter`: Quarter number
        /// - `is_overtime`: Whether in overtime period
        ///
        /// __Return__
        ///
        /// - Formatted quarter string
        pub fn formatQuarter(self: *TimeFormatter, quarter: u8, is_overtime: bool) ![]const u8 {
            if (is_overtime) {
                if (quarter > 4) {
                    const ot_period = quarter - 4;
                    return try std.fmt.bufPrint(&self.buffer, "OT{d}", .{ot_period});
                }
                return try std.fmt.bufPrint(&self.buffer, "OT", .{});
            }

            const suffix = switch (quarter) {
                1 => "st",
                2 => "nd",
                3 => "rd",
                4 => "th",
                else => "th",
            };

            return try std.fmt.bufPrint(&self.buffer, "{d}{s} Quarter", .{ quarter, suffix });
        }

        /// Format timeout display.
        ///
        /// Shows remaining timeouts for a team.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `timeouts_remaining`: Number of timeouts left
        /// - `team_name`: Team name to display
        ///
        /// __Return__
        ///
        /// - Formatted timeout string
        pub fn formatTimeouts(self: *TimeFormatter, timeouts_remaining: u8, team_name: []const u8) ![]const u8 {
            if (timeouts_remaining == 0) {
                return try std.fmt.bufPrint(&self.buffer, "{s}: No timeouts", .{team_name});
            } else if (timeouts_remaining == 1) {
                return try std.fmt.bufPrint(&self.buffer, "{s}: 1 timeout", .{team_name});
            } else {
                return try std.fmt.bufPrint(&self.buffer, "{s}: {d} timeouts", .{ team_name, timeouts_remaining });
            }
        }

        /// Format time with contextual information.
        ///
        /// Adds context like two-minute warning or final minute.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `seconds`: Time remaining in seconds
        /// - `quarter`: Current quarter number
        /// - `is_two_minute_warning`: Whether at two-minute warning
        ///
        /// __Return__
        ///
        /// - Formatted time string with context
        pub fn formatTimeWithContext(self: *TimeFormatter, seconds: u32, quarter: u8, is_two_minute_warning: bool) ![]const u8 {
            if (is_two_minute_warning) {
                return try std.fmt.bufPrint(&self.buffer, "Two-Minute Warning", .{});
            }

            // Check if we're in the final minute
            if (seconds <= 60 and (quarter == 2 or quarter == 4)) {
                const minutes = seconds / 60;
                const secs = seconds % 60;
                return try std.fmt.bufPrint(&self.buffer, "{d:0>2}:{d:0>2} - Final minute", .{ minutes, secs });
            }

            // Normal time formatting
            return try self.formatGameTime(seconds, .standard);
        }

        /// Format elapsed game time.
        ///
        /// Shows total time since game start.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `total_seconds`: Total elapsed seconds
        ///
        /// __Return__
        ///
        /// - Formatted elapsed time string
        pub fn formatElapsedTime(self: *TimeFormatter, total_seconds: u32) ![]const u8 {
            return try self.formatGameTime(total_seconds, .full);
        }

        /// Format time remaining with appropriate precision.
        ///
        /// Shows tenths of seconds when under 10 seconds.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `seconds`: Time remaining in seconds
        /// - `show_tenths`: Whether to show tenths of seconds
        ///
        /// __Return__
        ///
        /// - Formatted time remaining string
        pub fn formatTimeRemaining(self: *TimeFormatter, seconds: u32, show_tenths: bool) ![]const u8 {
            if (show_tenths and seconds < 10) {
                return try self.formatGameTime(seconds, .with_tenths);
            }
            return try self.formatGameTime(seconds, .standard);
        }

        /// Format score display.
        ///
        /// Shows both teams' scores with names.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `home_score`: Home team score
        /// - `away_score`: Away team score
        /// - `home_name`: Home team name
        /// - `away_name`: Away team name
        ///
        /// __Return__
        ///
        /// - Formatted score string
        pub fn formatScore(self: *TimeFormatter, home_score: u16, away_score: u16, home_name: []const u8, away_name: []const u8) ![]const u8 {
            return try std.fmt.bufPrint(&self.buffer, "{s} {d} - {d} {s}", .{ away_name, away_score, home_score, home_name });
        }

        /// Format down and distance.
        ///
        /// Shows current down and yards to go.
        ///
        /// __Parameters__
        ///
        /// - `self`: Mutable reference to TimeFormatter
        /// - `down`: Current down number (1-4)
        /// - `distance`: Yards to first down
        /// - `is_goal_to_go`: Whether in goal-to-go situation
        ///
        /// __Return__
        ///
        /// - Formatted down and distance string
        pub fn formatDownAndDistance(self: *TimeFormatter, down: u8, distance: u8, is_goal_to_go: bool) ![]const u8 {
            if (is_goal_to_go) {
                const suffix = switch (down) {
                    1 => "st",
                    2 => "nd",
                    3 => "rd",
                    4 => "th",
                    else => "th",
                };
                return try std.fmt.bufPrint(&self.buffer, "{d}{s} & Goal", .{ down, suffix });
            }

            const suffix = switch (down) {
                1 => "st",
                2 => "nd",
                3 => "rd",
                4 => "th",
                else => "th",
            };

            return try std.fmt.bufPrint(&self.buffer, "{d}{s} & {d}", .{ down, suffix, distance });
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Get display color recommendation based on time remaining.
    ///
    /// Suggests color based on warning thresholds.
    ///
    /// __Parameters__
    ///
    /// - `seconds`: Time remaining in seconds
    /// - `thresholds`: Warning threshold configuration
    ///
    /// __Return__
    ///
    /// - Recommended display color state
    pub fn getTimeColorRecommendation(seconds: u32, thresholds: WarningThresholds) enum { normal, warning, critical } {
        if (seconds < thresholds.play_clock_warning) {
            return .critical;
        } else if (seconds <= thresholds.critical_time) {
            return .warning;
        }
        return .normal;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: TimeFormatter: formatGameTime standard format" {
        var formatter = TimeFormatter.init(std.testing.allocator);
        const result = try formatter.formatGameTime(900, .standard);
        try std.testing.expectEqualStrings("15:00", result);
    }

    test "unit: TimeFormatter: formatGameTime compact format" {
        var formatter = TimeFormatter.init(std.testing.allocator);
        const result = try formatter.formatGameTime(585, .compact);
        try std.testing.expectEqualStrings("9:45", result);
    }

    test "unit: TimeFormatter: formatPlayClock with warnings" {
        var formatter = TimeFormatter.init(std.testing.allocator);
        
        const normal = formatter.formatPlayClock(25);
        try std.testing.expect(!normal.is_warning);
        try std.testing.expect(!normal.is_critical);
        
        const warning = formatter.formatPlayClock(5);
        try std.testing.expect(warning.is_warning);
        try std.testing.expect(!warning.is_critical);
        
        const critical = formatter.formatPlayClock(2);
        try std.testing.expect(critical.is_warning);
        try std.testing.expect(critical.is_critical);
    }

    test "unit: TimeFormatter: formatQuarter regular and overtime" {
        var formatter = TimeFormatter.init(std.testing.allocator);
        
        const q1 = try formatter.formatQuarter(1, false);
        try std.testing.expectEqualStrings("1st Quarter", q1);
        
        const q4 = try formatter.formatQuarter(4, false);
        try std.testing.expectEqualStrings("4th Quarter", q4);
        
        const ot = try formatter.formatQuarter(5, true);
        try std.testing.expectEqualStrings("OT1", ot);
    }

    test "unit: TimeFormatter: formatDownAndDistance" {
        var formatter = TimeFormatter.init(std.testing.allocator);
        
        const normal = try formatter.formatDownAndDistance(3, 7, false);
        try std.testing.expectEqualStrings("3rd & 7", normal);
        
        const goal = try formatter.formatDownAndDistance(1, 0, true);
        try std.testing.expectEqualStrings("1st & Goal", goal);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝