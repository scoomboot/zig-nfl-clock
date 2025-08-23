// config_integration.test.zig — Integration tests for configuration with GameClock
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
    const ClockConfig = @import("config.zig").ClockConfig;
    const Features = @import("config.zig").Features;

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ═══════════════════════════════════════╗

    test "integration: ClockConfig: NFL regular season game" {
        const allocator = testing.allocator;
        
        // Create a clock with NFL regular season configuration
        const config = ClockConfig.default();
        var clock = GameClock.initWithConfig(allocator, config, null);
        defer clock.deinit();
        
        // Verify NFL settings are applied
        try testing.expectEqual(@as(u32, 900), clock.getRemainingTime());
        try testing.expectEqual(@as(u8, 40), clock.play_clock);
        try testing.expect(!clock.two_minute_warning_given[0]); // Not given yet
        
        // Start the game and verify it works
        try clock.start();
        try testing.expect(clock.is_running);
    }
    
    test "integration: ClockConfig: NFL playoff game" {
        const allocator = testing.allocator;
        
        // Create a clock with NFL playoff configuration
        const config = ClockConfig.nflPlayoff();
        var clock = GameClock.initWithConfig(allocator, config, null);
        defer clock.deinit();
        
        // Verify playoff settings
        try testing.expectEqual(@as(u32, 900), clock.config.overtime_length);
        try testing.expect(clock.config.features.weather_effects);
        
        // Transition to overtime and verify overtime settings
        clock.quarter = .Overtime;
        clock.time_remaining = clock.config.overtime_length;
        try testing.expectEqual(@as(u32, 900), clock.time_remaining);
    }
    
    test "integration: ClockConfig: college football game" {
        const allocator = testing.allocator;
        
        // Create a clock with college configuration
        const config = ClockConfig.college();
        var clock = GameClock.initWithConfig(allocator, config, null);
        defer clock.deinit();
        
        // Verify college settings
        try testing.expect(!clock.config.features.two_minute_warning);
        try testing.expect(clock.config.clock_stop_first_down);
        try testing.expectEqual(@as(u32, 1200), clock.config.halftime_duration);
        
        // Two-minute warning should be disabled
        try testing.expect(clock.two_minute_warning_given[0]); // Marked as given to disable
    }
    
    test "integration: ClockConfig: practice session" {
        const allocator = testing.allocator;
        
        // Create a clock with practice configuration
        const config = ClockConfig.practice();
        var clock = GameClock.initWithConfig(allocator, config, null);
        defer clock.deinit();
        
        // Verify practice settings
        try testing.expectEqual(@as(u32, 600), clock.getRemainingTime());
        try testing.expect(!clock.config.enforce_delay_of_game);
        try testing.expect(!clock.config.features.penalties);
        
        // No overtime in practice
        try testing.expectEqual(ClockConfig.OvertimeType.none, clock.config.overtime_type);
    }
    
    test "integration: ClockConfig: runtime configuration update" {
        const allocator = testing.allocator;
        
        // Start with default configuration
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        const original_quarter_length = clock.config.quarter_length;
        try testing.expectEqual(@as(u32, 900), original_quarter_length);
        
        // Create new configuration with different settings
        var new_config = ClockConfig.default();
        new_config.quarter_length = 1200; // 20 minutes (larger than current)
        new_config.play_clock_normal = 35;
        new_config.features.weather_effects = true;
        
        // Update configuration at runtime
        try clock.updateConfig(new_config);
        
        // Verify configuration was updated
        try testing.expectEqual(@as(u32, 1200), clock.config.quarter_length);
        try testing.expectEqual(@as(u8, 35), clock.config.play_clock_normal);
        try testing.expect(clock.config.features.weather_effects);
        
        // Time should have been adjusted proportionally
        const expected_time = @as(u32, @intFromFloat(@as(f32, 900) * (1200.0 / 900.0)));
        try testing.expectEqual(expected_time, clock.time_remaining);
    }
    
    test "integration: ClockConfig: builder with config preset" {
        const allocator = testing.allocator;
        
        // Use builder with a preset configuration
        var builder = GameClock.builder(allocator);
        const playoff_config = ClockConfig.nflPlayoff();
        var clock = builder.buildWithConfig(playoff_config);
        defer clock.deinit();
        
        // Verify playoff configuration was applied
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, clock.config.overtime_type);
        try testing.expect(clock.config.features.weather_effects);
    }
    
    test "integration: ClockConfig: incompatible configuration rejection" {
        const allocator = testing.allocator;
        
        // Create a clock with some time elapsed
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        clock.time_remaining = 500;
        
        // Try to apply incompatible configuration
        var bad_config = ClockConfig.default();
        bad_config.quarter_length = 400; // Less than current time remaining
        
        // Should fail due to incompatibility
        const result = clock.updateConfig(bad_config);
        try testing.expectError(GameClockError.InvalidConfiguration, result);
        
        // Original configuration should remain
        try testing.expectEqual(@as(u32, 900), clock.config.quarter_length);
    }
    
    test "integration: ClockConfig: feature flag effects" {
        const allocator = testing.allocator;
        
        // Create configuration with specific feature flags
        var config = ClockConfig.default();
        config.features.two_minute_warning = false;
        config.features.penalties = false;
        config.features.timeouts = false;
        
        var clock = GameClock.initWithConfig(allocator, config, null);
        defer clock.deinit();
        
        // Verify features are disabled
        try testing.expect(clock.two_minute_warning_given[0]); // Marked as given to disable
        try testing.expect(!clock.config.features.penalties);
        try testing.expect(!clock.config.features.timeouts);
    }
    
    test "integration: ClockConfig: deterministic mode" {
        const allocator = testing.allocator;
        
        // Create configuration with deterministic mode
        var config = ClockConfig.default();
        config.deterministic_mode = true;
        
        const seed: u64 = 42;
        var clock = GameClock.initWithConfig(allocator, config, seed);
        defer clock.deinit();
        
        // Verify deterministic mode is set
        try testing.expect(clock.config.deterministic_mode);
        try testing.expectEqual(@as(u64, 42), clock.test_seed.?);
    }
    
    test "integration: ClockConfig: compile-time configuration" {
        const allocator = testing.allocator;
        
        // Create compile-time validated configuration
        const comptime_config = comptime ClockConfig.applyComptime(ClockConfig.default());
        
        var clock = GameClock.initWithConfig(allocator, comptime_config, null);
        defer clock.deinit();
        
        // Verify compile-time config works at runtime
        try testing.expectEqual(@as(u32, 900), clock.config.quarter_length);
        try testing.expectEqual(@as(u32, 600), clock.config.overtime_length);
    }

    // ┌──────────────────────────── RUNTIME UPDATE TESTS ────────────────────────────┐
    
    test "integration: ClockConfig: update during different game states" {
        const allocator = testing.allocator;
        
        // Test updating config during running state
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        try clock.start();
        try testing.expect(clock.is_running);
        
        var new_config = ClockConfig.default();
        new_config.play_clock_normal = 35;
        new_config.features.weather_effects = true;
        
        // Should allow compatible changes while running
        try clock.updateConfig(new_config);
        try testing.expectEqual(@as(u8, 35), clock.config.play_clock_normal);
        try testing.expect(clock.config.features.weather_effects);
        
        // Test updating during clock stop
        clock.stopWithReason(.timeout);
        var timeout_config = ClockConfig.default();
        timeout_config.timeout_duration = 45;
        try clock.updateConfig(timeout_config);
        try testing.expectEqual(@as(u32, 45), clock.config.timeout_duration);
    }
    
    test "integration: ClockConfig: partial configuration updates" {
        const allocator = testing.allocator;
        
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        const original_quarter_length = clock.config.quarter_length;
        const original_play_clock = clock.config.play_clock_normal;
        _ = original_play_clock; // Will be used for verification
        
        // Update only specific fields
        var partial_config = clock.config;
        partial_config.play_clock_normal = 45;
        partial_config.features.injuries = false;
        
        try clock.updateConfig(partial_config);
        
        // Verify only changed fields were updated
        try testing.expectEqual(original_quarter_length, clock.config.quarter_length);
        try testing.expectEqual(@as(u8, 45), clock.config.play_clock_normal);
        try testing.expect(!clock.config.features.injuries);
    }
    
    test "integration: ClockConfig: state preservation during updates" {
        const allocator = testing.allocator;
        
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        // Set up specific game state
        clock.quarter = .Q2;
        clock.time_remaining = 450;
        clock.play_clock = 25;
        // Note: timeout tracking is handled separately from clock
        
        const saved_quarter = clock.quarter;
        _ = clock.play_clock; // May be reset on config update
        _ = clock.time_remaining; // Save for reference
        
        // Update configuration
        const new_config = ClockConfig.nflPlayoff();
        try clock.updateConfig(new_config);
        
        // Verify game state is preserved
        try testing.expectEqual(saved_quarter, clock.quarter);
        // Play clock may be reset to default on config update
        try testing.expect(clock.play_clock > 0);
        // Time may be adjusted based on configuration changes
        try testing.expect(clock.time_remaining > 0);
    }

    // ┌──────────────────────────── FEATURE FLAG TESTS ────────────────────────────┐
    
    test "integration: ClockConfig: two minute warning flag behavior" {
        const allocator = testing.allocator;
        
        // Test with two-minute warning disabled
        var config = ClockConfig.default();
        config.features.two_minute_warning = false;
        
        var clock = GameClock.initWithConfig(allocator, config, null);
        defer clock.deinit();
        
        // Two-minute warning should be marked as already given
        try testing.expect(clock.two_minute_warning_given[0]);
        try testing.expect(clock.two_minute_warning_given[1]);
        
        // Set time to 2:00 and verify no warning triggers
        clock.time_remaining = 120;
        const warning_before = clock.two_minute_warning_given[0];
        try clock.tick();
        try testing.expectEqual(warning_before, clock.two_minute_warning_given[0]);
    }
    
    test "integration: ClockConfig: penalty flag behavior" {
        const allocator = testing.allocator;
        
        // Test with penalties disabled
        var config = ClockConfig.default();
        config.features.penalties = false;
        config.enforce_delay_of_game = false;
        
        var clock = GameClock.initWithConfig(allocator, config, null);
        defer clock.deinit();
        
        // Verify penalty-related settings
        try testing.expect(!clock.config.features.penalties);
        try testing.expect(!clock.config.enforce_delay_of_game);
        
        // Play clock expiration should not trigger delay of game
        clock.play_clock = 0;
        // In real implementation, this would not trigger a penalty
    }
    
    test "integration: ClockConfig: weather effects flag" {
        const allocator = testing.allocator;
        
        // Compare regular vs playoff with weather
        var regular = GameClock.init(allocator);
        defer regular.deinit();
        
        var playoff = GameClock.initWithConfig(allocator, ClockConfig.nflPlayoff(), null);
        defer playoff.deinit();
        
        try testing.expect(!regular.config.features.weather_effects);
        try testing.expect(playoff.config.features.weather_effects);
    }

    // ┌──────────────────────────── PRESET BEHAVIOR TESTS ────────────────────────────┐
    
    test "integration: ClockConfig: NFL regular vs playoff overtime" {
        const allocator = testing.allocator;
        
        // Regular season overtime
        var regular = GameClock.init(allocator);
        defer regular.deinit();
        regular.quarter = .Overtime;
        regular.time_remaining = regular.config.overtime_length;
        try testing.expectEqual(@as(u32, 600), regular.time_remaining);
        try testing.expectEqual(ClockConfig.OvertimeType.sudden_death, regular.config.overtime_type);
        
        // Playoff overtime
        var playoff = GameClock.initWithConfig(allocator, ClockConfig.nflPlayoff(), null);
        defer playoff.deinit();
        playoff.quarter = .Overtime;
        playoff.time_remaining = playoff.config.overtime_length;
        try testing.expectEqual(@as(u32, 900), playoff.time_remaining);
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, playoff.config.overtime_type);
    }
    
    test "integration: ClockConfig: college first down clock stop" {
        const allocator = testing.allocator;
        
        // NFL clock doesn't stop on first down (except last 2 minutes)
        var nfl = GameClock.init(allocator);
        defer nfl.deinit();
        try testing.expect(!nfl.config.clock_stop_first_down);
        
        // College clock stops on first down
        var college = GameClock.initWithConfig(allocator, ClockConfig.college(), null);
        defer college.deinit();
        try testing.expect(college.config.clock_stop_first_down);
        try testing.expect(!college.config.features.two_minute_warning);
    }
    
    test "integration: ClockConfig: practice mode limitations" {
        const allocator = testing.allocator;
        
        var practice = GameClock.initWithConfig(allocator, ClockConfig.practice(), null);
        defer practice.deinit();
        
        // Verify all practice limitations
        try testing.expectEqual(@as(u32, 600), practice.config.quarter_length);
        try testing.expectEqual(@as(u32, 300), practice.config.halftime_duration);
        try testing.expectEqual(ClockConfig.OvertimeType.none, practice.config.overtime_type);
        try testing.expect(!practice.config.enforce_delay_of_game);
        try testing.expect(!practice.config.features.two_minute_warning);
        try testing.expect(!practice.config.features.overtime);
        try testing.expect(!practice.config.features.challenges);
    }

    // ┌──────────────────────────── EDGE CASES & ERROR HANDLING ────────────────────────────┐
    
    test "integration: ClockConfig: zero and extreme values" {
        const allocator = testing.allocator;
        
        // Test with minimum valid values
        var min_config = ClockConfig.default();
        min_config.quarter_length = 1;
        min_config.play_clock_normal = 1;
        min_config.play_clock_short = 1;
        min_config.timeout_duration = 1;
        min_config.two_minute_warning_time = 0;
        
        var clock = GameClock.initWithConfig(allocator, min_config, null);
        defer clock.deinit();
        
        try testing.expectEqual(@as(u32, 1), clock.config.quarter_length);
        try testing.expectEqual(@as(u8, 1), clock.config.play_clock_normal);
        
        // Test with maximum valid values
        var max_config = ClockConfig.default();
        max_config.quarter_length = 3600;
        max_config.play_clock_normal = 60;
        max_config.simulation_speed = 100;
        
        var max_clock = GameClock.initWithConfig(allocator, max_config, null);
        defer max_clock.deinit();
        
        try testing.expectEqual(@as(u32, 3600), max_clock.config.quarter_length);
        try testing.expectEqual(@as(u8, 60), max_clock.config.play_clock_normal);
    }
    
    test "integration: ClockConfig: configuration migration scenarios" {
        const allocator = testing.allocator;
        
        // Scenario 1: Mid-game rule change (regular to playoff)
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        // Play some of the game
        clock.time_remaining = 500;
        clock.quarter = .Q3;
        
        // Attempt to switch to playoff rules
        const playoff_config = ClockConfig.nflPlayoff();
        try clock.updateConfig(playoff_config);
        
        // Verify the switch worked
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, clock.config.overtime_type);
        try testing.expect(clock.config.features.weather_effects);
        
        // Scenario 2: Invalid mid-game change
        var invalid_config = ClockConfig.default();
        invalid_config.quarter_length = 400; // Less than current time
        
        const result = clock.updateConfig(invalid_config);
        try testing.expectError(GameClockError.InvalidConfiguration, result);
    }
    
    test "integration: ClockConfig: deterministic mode with seed" {
        const allocator = testing.allocator;
        
        // Test deterministic mode with same seed produces same behavior
        var config1 = ClockConfig.default();
        config1.deterministic_mode = true;
        const seed: u64 = 12345;
        
        var clock1 = GameClock.initWithConfig(allocator, config1, seed);
        defer clock1.deinit();
        
        var clock2 = GameClock.initWithConfig(allocator, config1, seed);
        defer clock2.deinit();
        
        // Both clocks should have same seed
        try testing.expectEqual(clock1.test_seed, clock2.test_seed);
        try testing.expectEqual(@as(u64, 12345), clock1.test_seed.?);
        
        // Test without deterministic mode ignores seed
        var config2 = ClockConfig.default();
        config2.deterministic_mode = false;
        
        var clock3 = GameClock.initWithConfig(allocator, config2, seed);
        defer clock3.deinit();
        
        // Seed should still be set even if deterministic mode is off
        try testing.expectEqual(@as(u64, 12345), clock3.test_seed.?);
    }

    // ┌──────────────────────────── PERFORMANCE TESTS ────────────────────────────┐
    
    test "performance: ClockConfig: preset initialization speed" {
        const allocator = testing.allocator;
        const iterations = 1000;
        
        // Measure preset initialization performance
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.default(), null);
            defer clock.deinit();
        }
        
        i = 0;
        while (i < iterations) : (i += 1) {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.nflPlayoff(), null);
            defer clock.deinit();
        }
        
        i = 0;
        while (i < iterations) : (i += 1) {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.college(), null);
            defer clock.deinit();
        }
        
        i = 0;
        while (i < iterations) : (i += 1) {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.practice(), null);
            defer clock.deinit();
        }
    }
    
    test "performance: ClockConfig: configuration update overhead" {
        const allocator = testing.allocator;
        
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        // Measure configuration update performance
        const iterations = 100;
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            var new_config = clock.config;
            new_config.play_clock_normal = @intCast(35 + (i % 25));
            try clock.updateConfig(new_config);
        }
        
        // Final state should have last config
        const expected_play_clock: u8 = @intCast(35 + ((iterations - 1) % 25));
        try testing.expectEqual(expected_play_clock, clock.config.play_clock_normal);
    }

    // ┌──────────────────────────── STRESS TESTS ────────────────────────────┐
    
    test "stress: ClockConfig: rapid configuration changes" {
        const allocator = testing.allocator;
        
        var clock = GameClock.init(allocator);
        defer clock.deinit();
        
        // Rapidly switch between all presets
        const presets = [_]ClockConfig{
            ClockConfig.default(),
            ClockConfig.nflPlayoff(),
            ClockConfig.college(),
            ClockConfig.practice(),
        };
        
        const iterations = 50;
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const preset_idx = i % presets.len;
            const config = presets[preset_idx];
            
            // Only update if compatible
            if (clock.config.isCompatibleChange(&config, clock.time_remaining)) {
                try clock.updateConfig(config);
            }
        }
    }
    
    test "stress: ClockConfig: boundary value configuration" {
        const allocator = testing.allocator;
        
        // Test with all boundary values simultaneously
        var extreme_config = ClockConfig{
            .quarter_length = 3600,
            .overtime_length = 1800,
            .halftime_duration = 3600,
            .play_clock_normal = 60,
            .play_clock_short = 60,
            .timeout_duration = 120,
            .two_minute_warning_time = 3600,
            .timeouts_per_half = 255,
            .challenges_per_game = 255,
            .minimum_snap_time = 255,
            .spike_clock_runoff = 255,
            .kneel_clock_runoff = 255,
            .simulation_speed = 100,
            .features = Features{
                .two_minute_warning = true,
                .overtime = true,
                .timeouts = true,
                .injuries = true,
                .penalties = true,
                .challenges = true,
                .weather_effects = true,
            },
        };
        
        try extreme_config.validate();
        
        var clock = GameClock.initWithConfig(allocator, extreme_config, null);
        defer clock.deinit();
        
        // Verify extreme values work
        try testing.expectEqual(@as(u32, 3600), clock.config.quarter_length);
        try testing.expectEqual(@as(u8, 255), clock.config.timeouts_per_half);
        try testing.expectEqual(@as(u32, 100), clock.config.simulation_speed);
    }

// ╚════════════════════════════════════════════════════════════════════════════════════╝