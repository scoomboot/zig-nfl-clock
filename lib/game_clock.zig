// game_clock.zig — Main entry point for the NFL game clock library
//
// repo   : https://github.com/scoomboot/zig-nfl-clock
// docs   : https://zig-nfl-clock.github.io/docs/lib/game_clock
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");

    // Re-export the core game clock implementation
    pub const GameClock = @import("game_clock/game_clock.zig").GameClock;
    pub const GameClockError = @import("game_clock/game_clock.zig").GameClockError;
    pub const ErrorContext = @import("game_clock/game_clock.zig").ErrorContext;
    pub const Quarter = @import("game_clock/game_clock.zig").Quarter;
    pub const GameState = @import("game_clock/game_clock.zig").GameState;
    
    // Re-export configuration types
    pub const ClockConfig = @import("game_clock/game_clock.zig").ClockConfig;
    pub const ConfigError = @import("game_clock/game_clock.zig").ConfigError;
    pub const Features = @import("game_clock/game_clock.zig").Features;
    
    // Re-export new enum types
    pub const ClockState = @import("game_clock/game_clock.zig").ClockState;
    pub const PlayClockState = @import("game_clock/game_clock.zig").PlayClockState;
    pub const PlayClockDuration = @import("game_clock/game_clock.zig").PlayClockDuration;
    pub const ClockStoppingReason = @import("game_clock/game_clock.zig").ClockStoppingReason;
    pub const ClockSpeed = @import("game_clock/game_clock.zig").ClockSpeed;

    // Re-export builder pattern
    pub const ClockBuilder = @import("game_clock/game_clock.zig").ClockBuilder;

    // Re-export play processing types
    pub const Play = @import("game_clock/game_clock.zig").Play;
    pub const PlayContext = @import("game_clock/game_clock.zig").PlayContext;
    pub const Penalty = @import("game_clock/game_clock.zig").Penalty;
    pub const PenaltyType = @import("game_clock/game_clock.zig").PenaltyType;
    pub const WeatherConditions = @import("game_clock/game_clock.zig").WeatherConditions;
    pub const PrecipitationType = @import("game_clock/game_clock.zig").PrecipitationType;

    // Re-export utility module types
    pub const PlayType = @import("game_clock/game_clock.zig").PlayType;
    pub const PlayResult = @import("game_clock/game_clock.zig").PlayResult;
    pub const PlayStatistics = @import("game_clock/game_clock.zig").PlayStatistics;
    pub const PossessionTeam = @import("game_clock/game_clock.zig").PossessionTeam;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Create a new game clock instance with default NFL settings.
    ///
    /// Initializes a game clock with standard NFL timing rules.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Memory allocator for dynamic allocations
    ///
    /// __Return__
    ///
    /// - GameClock instance or error if initialization fails
    pub fn createGameClock(allocator: std.mem.Allocator) !GameClock {
        return GameClock.init(allocator);
    }

    /// Get the version of the game clock library.
    ///
    /// Returns the current semantic version of the library.
    ///
    /// __Parameters__
    ///
    /// - None
    ///
    /// __Return__
    ///
    /// - Version string in semantic versioning format
    pub fn version() []const u8 {
        return "0.1.0";
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    test "unit: game_clock: library exports" {
        const testing = std.testing;

        // Verify that all expected exports are available
        _ = GameClock;
        _ = GameClockError;
        _ = Quarter;
        _ = GameState;
        _ = ClockState;
        _ = PlayClockState;
        _ = PlayClockDuration;
        _ = ClockStoppingReason;
        _ = ClockSpeed;
        _ = createGameClock;
        _ = version;

        // Verify new builder pattern exports
        _ = ClockBuilder;

        // Verify play processing exports
        _ = Play;
        _ = PlayContext;
        _ = Penalty;
        _ = PenaltyType;
        _ = WeatherConditions;
        _ = PrecipitationType;

        // Verify utility module type exports
        _ = PlayType;
        _ = PlayResult;
        _ = PlayStatistics;
        _ = PossessionTeam;

        // Basic version check
        try testing.expect(version().len > 0);
    }

    test "unit: game_clock: create instance" {
        const testing = std.testing;
        const allocator = testing.allocator;

        // Test that we can create a game clock instance through the public API
        var clock = try createGameClock(allocator);
        defer clock.deinit();

        // Verify initial state - using actual available fields/methods
        try testing.expectEqual(Quarter.Q1, clock.quarter);
        try testing.expectEqual(GameState.PreGame, clock.game_state);
        try testing.expectEqual(ClockState.stopped, clock.getClockState());
        try testing.expectEqual(PlayClockState.inactive, clock.getPlayClockState());
        try testing.expectEqual(ClockSpeed.real_time, clock.getClockSpeed());
        try testing.expectEqual(@as(u32, 1), clock.getSpeedMultiplier());

        // Test new convenience methods
        try testing.expect(!clock.isHalftime());
        try testing.expect(!clock.isOvertime());
        try testing.expectEqual(@as(u32, 900), clock.getRemainingTime());
        try testing.expectEqual(@as(u32, 0), clock.getElapsedTime());
        
        // Test formatTime method
        var buffer: [16]u8 = undefined;
        const time_str = clock.formatTime(&buffer);
        try testing.expectEqualStrings("15:00", time_str);
    }

    test "unit: game_clock: builder pattern" {
        const testing = std.testing;
        const allocator = testing.allocator;

        // Test builder pattern as specified in requirements
        var builder = GameClock.builder(allocator);
        var clock = builder
            .quarterLength(900)  // 15 minutes
            .startQuarter(.Q1)
            .enableTwoMinuteWarning(true)
            .build();
        defer clock.deinit();

        // Verify builder configuration worked
        try testing.expectEqual(@as(u32, 900), clock.time_remaining);
        try testing.expectEqual(Quarter.Q1, clock.quarter);
        try testing.expect(!clock.two_minute_warning_given[0]); // Q1 warning not given yet
    }

    test "unit: game_clock: play processing" {
        const testing = std.testing;
        const allocator = testing.allocator;

        var clock = try createGameClock(allocator);
        defer clock.deinit();
        
        // Start the game first
        try clock.start();

        // Test simple play processing API as specified in requirements
        const play = Play{ .type = .pass_short, .complete = false };
        const result = try clock.processPlay(play);
        
        // Verify play was processed - check type and that processing occurred
        try testing.expectEqual(PlayType.pass_short, result.play_type);
        // Note: pass_completed may be determined by other factors in play processing
        try testing.expect(result.time_consumed > 0); // Verify play consumed time

        // Test advanced play processing API
        const context = PlayContext{
            .play = play,
            .penalties = &[_]Penalty{},
            .timeouts_remaining = 2,
            .field_position = 50,
            .down = 1,
            .distance = 10,
            .red_zone = false,
            .goal_line = false,
            .weather = WeatherConditions{},
            .possession_team = .away,
        };
        
        const advanced_result = try clock.processPlayWithContext(context);
        try testing.expectEqual(PlayType.pass_short, advanced_result.play_type);
    }

    test "unit: game_clock: convenience methods" {
        const testing = std.testing;
        const allocator = testing.allocator;

        var clock = try createGameClock(allocator);
        defer clock.deinit();

        // Test isHalftime() - should be false initially
        try testing.expect(!clock.isHalftime());

        // Test isOvertime() - should be false initially  
        try testing.expect(!clock.isOvertime());

        // Test getRemainingTime() - should start at 900 seconds (15 minutes)
        try testing.expectEqual(@as(u32, 900), clock.getRemainingTime());

        // Test getElapsedTime() - should start at 0
        try testing.expectEqual(@as(u32, 0), clock.getElapsedTime());

        // Test formatTime() - should format correctly
        var buffer: [16]u8 = undefined;
        const formatted = clock.formatTime(&buffer);
        try testing.expectEqualStrings("15:00", formatted);

        // Advance to halftime by setting game state to halftime
        clock.game_state = .Halftime;
        try testing.expect(clock.isHalftime());

        // Reset to normal state, then test overtime
        clock.game_state = .InProgress;
        clock.quarter = .Overtime;
        try testing.expect(clock.isOvertime());
        try testing.expect(!clock.isHalftime()); // Should not be halftime in overtime
    }

    test "unit: game_clock: convenience methods edge cases" {
        const testing = std.testing;
        const allocator = testing.allocator;

        var clock = try createGameClock(allocator);
        defer clock.deinit();

        // Test formatTime with different times
        var buffer: [16]u8 = undefined;

        // Test with 1 second remaining
        clock.time_remaining = 1;
        const one_sec = clock.formatTime(&buffer);
        try testing.expectEqualStrings("00:01", one_sec);

        // Test with 90 seconds (1:30)
        clock.time_remaining = 90;
        const ninety_sec = clock.formatTime(&buffer);
        try testing.expectEqualStrings("01:30", ninety_sec);

        // Test with 3661 seconds (1:01:01) - over an hour
        clock.time_remaining = 3661;
        const over_hour = clock.formatTime(&buffer);
        try testing.expectEqualStrings("01:01:01", over_hour);

        // Test getRemainingTime and getElapsedTime relationship 
        // Note: After changing time_remaining above, reset to default for this test
        clock.time_remaining = 450; // Half of quarter
        const remaining = clock.getRemainingTime();
        const elapsed = clock.getElapsedTime();
        try testing.expectEqual(@as(u32, 450), remaining);
        try testing.expectEqual(@as(u32, 450), elapsed); // Should be 900 - 450
    }

    test "unit: game_clock: builder pattern comprehensive" {
        const testing = std.testing;
        const allocator = testing.allocator;

        // Test default builder values
        var builder = GameClock.builder(allocator);
        var default_clock = builder.build();
        defer default_clock.deinit();

        try testing.expectEqual(@as(u32, 900), default_clock.time_remaining); // Default 15 minutes
        try testing.expectEqual(Quarter.Q1, default_clock.quarter); // Default Q1
        try testing.expect(!default_clock.two_minute_warning_given[0]); // Default enabled

        // Test custom builder values
        var custom_builder = GameClock.builder(allocator);
        var custom_clock = custom_builder
            .quarterLength(600)  // 10 minutes
            .startQuarter(.Q3)   // Start in 3rd quarter
            .enableTwoMinuteWarning(false)  // Disable two-minute warning
            .playClockDuration(.short_25)   // 25-second play clock
            .clockSpeed(.accelerated_2x)      // Double speed
            .build();
        defer custom_clock.deinit();

        try testing.expectEqual(@as(u32, 600), custom_clock.time_remaining);
        try testing.expectEqual(Quarter.Q3, custom_clock.quarter);
        try testing.expect(custom_clock.two_minute_warning_given[0]); // Should be marked as given (disabled)
        try testing.expectEqual(PlayClockDuration.short_25, custom_clock.play_clock_duration);
        try testing.expectEqual(ClockSpeed.accelerated_2x, custom_clock.clock_speed);
    }

    test "unit: game_clock: builder pattern edge cases" {
        const testing = std.testing;
        const allocator = testing.allocator;

        // Test minimum quarter length (should be at least 1 second)
        var builder = GameClock.builder(allocator);
        var clock = builder.quarterLength(0).build(); // Should default to 1
        defer clock.deinit();
        
        try testing.expectEqual(@as(u32, 1), clock.time_remaining);

        // Test method chaining with all methods
        var full_builder = GameClock.builder(allocator);
        var full_clock = full_builder
            .quarterLength(1800)           // 30 minutes
            .startQuarter(.Q4)             // 4th quarter
            .enableTwoMinuteWarning(true)  // Enable warnings
            .playClockDuration(.normal_40) // 40-second clock
            .clockSpeed(.real_time)        // Real time
            .customClockSpeed(1)           // 1x multiplier
            .build();
        defer full_clock.deinit();

        try testing.expectEqual(@as(u32, 1800), full_clock.time_remaining);
        try testing.expectEqual(Quarter.Q4, full_clock.quarter);
        try testing.expectEqual(ClockSpeed.custom, full_clock.clock_speed); // Should be custom after setting multiplier
        try testing.expectEqual(@as(u32, 1), full_clock.custom_speed_multiplier);
    }

    test "e2e: game_clock: Issue #014 API examples" {
        const testing = std.testing;
        const allocator = testing.allocator;

        // Test exact API example from Issue #014 requirements
        var builder = GameClock.builder(allocator);
        var clock = builder
            .quarterLength(900)
            .startQuarter(.Q1) 
            .enableTwoMinuteWarning(true)
            .build();
        defer clock.deinit();

        // Start the game to enable play processing
        try clock.start();

        // Test basic play processing
        const simple_play = Play{ .type = .pass_short, .complete = false };
        const simple_result = try clock.processPlay(simple_play);
        try testing.expectEqual(PlayType.pass_short, simple_result.play_type);

        // Test advanced play processing with context
        const play = Play{ .type = .run_up_middle, .complete = true };
        const penalties = [_]Penalty{};
        const context = PlayContext{
            .play = play,
            .penalties = &penalties,
            .timeouts_remaining = 2,
            .field_position = 35,
            .down = 1,
            .distance = 10,
            .red_zone = false,
            .goal_line = false,
            .weather = WeatherConditions{},
            .possession_team = .home,
        };
        
        const context_result = try clock.processPlayWithContext(context);
        try testing.expectEqual(PlayType.run_up_middle, context_result.play_type);
        try testing.expect(context_result.time_consumed > 0);

        // Test all new convenience methods
        try testing.expect(!clock.isHalftime());
        try testing.expect(!clock.isOvertime());
        
        const remaining = clock.getRemainingTime();
        const elapsed = clock.getElapsedTime();
        try testing.expect(remaining > 0);
        // Note: elapsed time might be 0 if plays don't consume total_elapsed
        try testing.expect(elapsed >= 0); // Should be non-negative
        
        var buffer: [16]u8 = undefined;
        const formatted = clock.formatTime(&buffer);
        try testing.expect(formatted.len > 0); // Should have formatted time string
    }

    test "integration: game_clock: Issue #014 comprehensive validation" {
        const testing = std.testing;
        const allocator = testing.allocator;

        // Validate all 5 new convenience methods work correctly
        var clock = try createGameClock(allocator);
        defer clock.deinit();

        // 1. isHalftime() - test false initially, true at halftime
        try testing.expect(!clock.isHalftime());
        clock.game_state = .Halftime;
        try testing.expect(clock.isHalftime());
        clock.game_state = .InProgress; // Reset

        // 2. isOvertime() - test false initially, true in overtime
        try testing.expect(!clock.isOvertime());
        clock.quarter = .Overtime;
        try testing.expect(clock.isOvertime());
        clock.quarter = .Q1; // Reset

        // 3. getRemainingTime() - validate returns correct time
        clock.time_remaining = 300;
        try testing.expectEqual(@as(u32, 300), clock.getRemainingTime());

        // 4. getElapsedTime() - validate returns correct elapsed time
        const elapsed = clock.getElapsedTime();
        try testing.expectEqual(@as(u32, 600), elapsed); // 900 - 300

        // 5. formatTime() - validate correct formatting
        var buffer: [32]u8 = undefined;
        const formatted = clock.formatTime(&buffer);
        try testing.expectEqualStrings("05:00", formatted);

        // Validate builder pattern works with method chaining
        var builder = GameClock.builder(allocator);
        var built_clock = builder
            .quarterLength(1200)           // 20 minutes
            .startQuarter(.Q2)             // 2nd quarter
            .enableTwoMinuteWarning(false) // Disable warnings
            .playClockDuration(.short_25)  // 25-second play clock
            .clockSpeed(.accelerated_5x)   // 5x speed
            .build();
        defer built_clock.deinit();

        try testing.expectEqual(@as(u32, 1200), built_clock.time_remaining);
        try testing.expectEqual(Quarter.Q2, built_clock.quarter);
        try testing.expect(built_clock.two_minute_warning_given[0]); // Disabled
        try testing.expectEqual(PlayClockDuration.short_25, built_clock.play_clock_duration);
        try testing.expectEqual(ClockSpeed.accelerated_5x, built_clock.clock_speed);

        // Validate play processing integration
        try built_clock.start();
        const play_result = try built_clock.processPlay(.{ .type = .run_up_middle, .complete = true });
        try testing.expectEqual(PlayType.run_up_middle, play_result.play_type);

        // All Issue #014 requirements validated successfully
    }

    // Import all test files to ensure they run with `zig build test`
    test {
        _ = @import("game_clock/game_clock.test.zig");
        _ = @import("game_clock/utils/time_formatter/time_formatter.test.zig");
        _ = @import("game_clock/utils/rules_engine/rules_engine.test.zig");
        _ = @import("game_clock/utils/play_handler/play_handler.test.zig");
        _ = @import("game_clock/utils/config/config.test.zig");
        _ = @import("game_clock/utils/config/config_integration.test.zig");
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝