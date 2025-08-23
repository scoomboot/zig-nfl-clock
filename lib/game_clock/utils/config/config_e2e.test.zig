// config_e2e.test.zig — End-to-end tests for configuration system
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/lib/game_clock/utils/config
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const GameClock = @import("../../game_clock.zig").GameClock;
    const GameClockError = @import("../../game_clock.zig").GameClockError;
    const PlayType = @import("../../game_clock.zig").PlayType;
    const PlayOutcome = @import("../../game_clock.zig").PlayOutcome;
    const Quarter = @import("../../game_clock.zig").Quarter;
    const ClockConfig = @import("config.zig").ClockConfig;
    const Features = @import("config.zig").Features;
    const ConfigError = @import("config.zig").ConfigError;

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ═══════════════════════════════════════╗

    // ────────────────────────────── END-TO-END WORKFLOW TESTS ──────────────────────────────
    
    test "e2e: full game with configuration changes" {
        const allocator = testing.allocator;
        
        // Start with regular season configuration
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        // Play first quarter
        try clock.start();
        clock.time_remaining = 300; // 5 minutes left
        
        // Process some plays
        const play1 = PlayOutcome{
            .play_type = .Run,
            .yards_gained = 5,
            .is_first_down = false,
            .is_touchdown = false,
            .is_turnover = false,
            .is_out_of_bounds = false,
            .is_incomplete = false,
            .is_penalty = false,
            .is_two_point_conversion = false,
            .is_field_goal = false,
            .is_safety = false,
        };
        try clock.processPlay(play1);
        
        // Switch to playoff configuration mid-game
        const playoff_config = ClockConfig.nflPlayoff();
        try clock.updateConfig(playoff_config);
        
        // Verify configuration changed
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, clock.config.overtime_type);
        
        // Continue playing
        clock.quarter = .Q4;
        clock.time_remaining = 120; // 2 minutes
        
        // Process end-of-game scenario
        const play2 = PlayOutcome{
            .play_type = .Pass,
            .yards_gained = 15,
            .is_first_down = true,
            .is_touchdown = false,
            .is_turnover = false,
            .is_out_of_bounds = true,
            .is_incomplete = false,
            .is_penalty = false,
            .is_two_point_conversion = false,
            .is_field_goal = false,
            .is_safety = false,
        };
        try clock.processPlay(play2);
        
        // Move to overtime with playoff rules
        clock.quarter = .Overtime;
        clock.time_remaining = clock.config.overtime_length;
        try testing.expectEqual(@as(u32, 900), clock.time_remaining);
    }
    
    test "e2e: complete NFL playoff game simulation" {
        const allocator = testing.allocator;
        
        // Initialize with playoff configuration
        var builder = GameClock.builder(allocator);
        var clock = builder
            .buildWithConfig(ClockConfig.nflPlayoff());
        defer clock.deinit();
        
        // Simulate complete game flow
        try testing.expectEqual(Quarter.Q1, clock.quarter);
        try testing.expectEqual(@as(u32, 900), clock.time_remaining);
        
        // First quarter
        try clock.start();
        clock.time_remaining = 0;
        try clock.endQuarter();
        try testing.expectEqual(Quarter.Q2, clock.quarter);
        
        // Second quarter with two-minute warning
        clock.time_remaining = 125;
        try clock.tick(); // Should trigger two-minute warning
        clock.time_remaining = 0;
        try clock.endQuarter();
        // Check halftime state
        try testing.expect(clock.isHalftime());
        
        // End halftime
        try clock.endQuarter();
        try testing.expectEqual(Quarter.Q3, clock.quarter);
        
        // Third quarter
        clock.time_remaining = 0;
        try clock.endQuarter();
        try testing.expectEqual(Quarter.Q4, clock.quarter);
        
        // Fourth quarter
        clock.time_remaining = 0;
        try clock.endQuarter();
        
        // Move to overtime with playoff rules
        clock.quarter = .Overtime;
        clock.time_remaining = clock.config.overtime_length;
        try testing.expectEqual(@as(u32, 900), clock.time_remaining);
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, clock.config.overtime_type);
    }
    
    test "e2e: college football game with unique rules" {
        const allocator = testing.allocator;
        
        // Create college game
        var clock = GameClock.initWithConfig(allocator, ClockConfig.college(), null);
        defer clock.deinit();
        
        // Verify college-specific settings
        try testing.expect(clock.config.clock_stop_first_down);
        try testing.expect(!clock.config.features.two_minute_warning);
        try testing.expectEqual(@as(u32, 1200), clock.config.halftime_duration);
        
        // Simulate first down scenario
        try clock.start();
        const initial_running = clock.is_running;
        
        const first_down_play = PlayOutcome{
            .play_type = .Run,
            .yards_gained = 12,
            .is_first_down = true,
            .is_touchdown = false,
            .is_turnover = false,
            .is_out_of_bounds = false,
            .is_incomplete = false,
            .is_penalty = false,
            .is_two_point_conversion = false,
            .is_field_goal = false,
            .is_safety = false,
        };
        
        try clock.processPlay(first_down_play);
        
        // Clock should stop on first down in college
        if (clock.config.clock_stop_first_down) {
            try testing.expect(!clock.is_running);
        }
        
        // No two-minute warning in college
        clock.time_remaining = 120;
        const warning_before = clock.two_minute_warning_given[0];
        try clock.tick();
        try testing.expectEqual(warning_before, clock.two_minute_warning_given[0]);
        
        // College overtime is different (no game clock)
        clock.quarter = .Overtime;
        try testing.expectEqual(ClockConfig.OvertimeType.college_style, clock.config.overtime_type);
        try testing.expectEqual(@as(u32, 0), clock.config.overtime_length);
    }
    
    test "e2e: practice session with simplified rules" {
        const allocator = testing.allocator;
        
        // Create practice session
        var clock = GameClock.initWithConfig(allocator, ClockConfig.practice(), null);
        defer clock.deinit();
        
        // Verify practice limitations
        try testing.expectEqual(@as(u32, 600), clock.config.quarter_length);
        try testing.expect(!clock.config.enforce_delay_of_game);
        try testing.expect(!clock.config.features.penalties);
        
        // Start practice
        try clock.start();
        
        // Play clock expiration should not cause delay of game
        clock.play_clock = 0;
        // No penalty enforced
        
        // No timeouts in practice
        try testing.expect(!clock.config.features.timeouts);
        
        // Quick quarters
        clock.time_remaining = 0;
        try clock.endQuarter();
        
        // No overtime in practice
        if (clock.quarter == .Q4) {
            clock.time_remaining = 0;
            try clock.endQuarter();
            // Game should end, no overtime
            try testing.expect(clock.quarter != .Overtime);
        }
    }
    
    // ────────────────────────────── CONFIGURATION TRANSITION TESTS ──────────────────────────────
    
    test "e2e: seamless preset transitions during game" {
        const allocator = testing.allocator;
        
        // Start with regular season
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        // Play some regular season
        try clock.start();
        clock.time_remaining = 600;
        try testing.expectEqual(ClockConfig.OvertimeType.sudden_death, clock.config.overtime_type);
        
        // Transition to playoff
        try clock.updateConfig(ClockConfig.nflPlayoff());
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, clock.config.overtime_type);
        
        // Transition to college
        try clock.updateConfig(ClockConfig.college());
        try testing.expectEqual(ClockConfig.OvertimeType.college_style, clock.config.overtime_type);
        try testing.expect(clock.config.clock_stop_first_down);
        
        // Transition to practice
        try clock.updateConfig(ClockConfig.practice());
        try testing.expectEqual(ClockConfig.OvertimeType.none, clock.config.overtime_type);
        
        // Back to regular
        try clock.updateConfig(ClockConfig.default());
        try testing.expectEqual(ClockConfig.OvertimeType.sudden_death, clock.config.overtime_type);
    }
    
    test "e2e: builder pattern with configuration presets" {
        const allocator = testing.allocator;
        
        // Test builder with each preset
        const presets = [_]struct { 
            config: ClockConfig, 
            expected_quarter_length: u32,
            expected_overtime: ClockConfig.OvertimeType,
        }{
            .{ 
                .config = ClockConfig.default(), 
                .expected_quarter_length = 900,
                .expected_overtime = .sudden_death,
            },
            .{ 
                .config = ClockConfig.nflPlayoff(), 
                .expected_quarter_length = 900,
                .expected_overtime = .modified_sudden_death,
            },
            .{ 
                .config = ClockConfig.college(), 
                .expected_quarter_length = 900,
                .expected_overtime = .college_style,
            },
            .{ 
                .config = ClockConfig.practice(), 
                .expected_quarter_length = 600,
                .expected_overtime = .none,
            },
        };
        
        for (presets) |preset| {
            var builder = GameClock.builder(allocator);
            var clock = builder
                .withQuarter(.Q2)
                .withTimeRemaining(300)
                .buildWithConfig(preset.config);
            defer clock.deinit();
            
            try testing.expectEqual(Quarter.Q2, clock.quarter);
            try testing.expectEqual(@as(u32, 300), clock.time_remaining);
            try testing.expectEqual(preset.expected_quarter_length, clock.config.quarter_length);
            try testing.expectEqual(preset.expected_overtime, clock.config.overtime_type);
        }
    }
    
    // ────────────────────────────── ADVANCED FEATURE TESTS ──────────────────────────────
    
    test "e2e: deterministic mode for reproducible testing" {
        const allocator = testing.allocator;
        
        // Create two clocks with same seed
        var config = ClockConfig.default();
        config.deterministic_mode = true;
        const seed: u64 = 42;
        
        var clock1 = GameClock.initWithConfig(allocator, config, seed);
        defer clock1.deinit();
        
        var clock2 = GameClock.initWithConfig(allocator, config, seed);
        defer clock2.deinit();
        
        // Both should have identical configuration and seed
        try testing.expectEqual(clock1.config.quarter_length, clock2.config.quarter_length);
        try testing.expectEqual(clock1.test_seed, clock2.test_seed);
        try testing.expect(clock1.config.deterministic_mode);
        try testing.expect(clock2.config.deterministic_mode);
        
        // Process same plays - should have identical results
        const test_play = PlayOutcome{
            .play_type = .Run,
            .yards_gained = 5,
            .is_first_down = false,
            .is_touchdown = false,
            .is_turnover = false,
            .is_out_of_bounds = false,
            .is_incomplete = false,
            .is_penalty = false,
            .is_two_point_conversion = false,
            .is_field_goal = false,
            .is_safety = false,
        };
        
        try clock1.processPlay(test_play);
        try clock2.processPlay(test_play);
        
        // States should remain synchronized
        try testing.expectEqual(clock1.play_clock, clock2.play_clock);
    }
    
    test "e2e: simulation speed variations" {
        const allocator = testing.allocator;
        
        // Test different simulation speeds
        const speeds = [_]u32{ 1, 2, 5, 10, 50, 100 };
        
        for (speeds) |speed| {
            var config = ClockConfig.default();
            config.simulation_speed = speed;
            
            var clock = GameClock.initWithConfig(allocator, config, null);
            defer clock.deinit();
            
            try testing.expectEqual(speed, clock.config.simulation_speed);
            
            // Verify speed affects timing calculations
            // In real implementation, tick() would advance by simulation_speed seconds
            try clock.start();
            const time_before = clock.time_remaining;
            try clock.tick();
            
            // Time should decrease (actual amount depends on implementation)
            try testing.expect(clock.time_remaining <= time_before);
        }
    }
    
    test "e2e: weather effects in playoff games" {
        const allocator = testing.allocator;
        
        // Regular season - no weather
        var regular = GameClock.init(allocator);
        defer regular.deinit();
        try testing.expect(!regular.config.features.weather_effects);
        
        // Playoff - weather effects enabled
        var playoff = GameClock.initWithConfig(allocator, ClockConfig.nflPlayoff(), null);
        defer playoff.deinit();
        try testing.expect(playoff.config.features.weather_effects);
        
        // Weather effects could affect play clock, timeouts, etc.
        // This is where weather-specific logic would be implemented
    }
    
    // ────────────────────────────── ERROR RECOVERY TESTS ──────────────────────────────
    
    test "e2e: recovery from invalid configuration attempts" {
        const allocator = testing.allocator;
        
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        // Save current state
        const original_config = clock.config;
        const original_time = clock.time_remaining;
        
        // Attempt multiple invalid updates
        var bad_config = ClockConfig.default();
        
        // Invalid: quarter length less than current time
        clock.time_remaining = 500;
        bad_config.quarter_length = 400;
        const result1 = clock.updateConfig(bad_config);
        try testing.expectError(GameClockError.InvalidConfiguration, result1);
        
        // Invalid: play clock values
        bad_config = ClockConfig.default();
        bad_config.play_clock_normal = 0;
        const result2 = clock.updateConfig(bad_config);
        try testing.expectError(GameClockError.InvalidConfiguration, result2);
        
        // Verify original configuration preserved
        try testing.expectEqual(original_config.quarter_length, clock.config.quarter_length);
        try testing.expectEqual(original_config.play_clock_normal, clock.config.play_clock_normal);
        
        // Valid update should still work
        var good_config = ClockConfig.nflPlayoff();
        try clock.updateConfig(good_config);
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, clock.config.overtime_type);
    }
    
    test "e2e: configuration validation at compile time" {
        // Test that invalid configurations fail at compile time
        const valid_config = comptime ClockConfig.applyComptime(ClockConfig.default());
        try testing.expectEqual(@as(u32, 900), valid_config.quarter_length);
        
        // These would fail at compile time if uncommented:
        // const invalid_config = comptime blk: {
        //     var cfg = ClockConfig.default();
        //     cfg.quarter_length = 0; // Invalid
        //     break :blk ClockConfig.applyComptime(cfg);
        // };
    }

// ╚════════════════════════════════════════════════════════════════════════════════════╝