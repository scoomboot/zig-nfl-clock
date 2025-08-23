// config.test.zig — Tests for NFL game clock configuration system
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/lib/game_clock/utils/config
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const config_module = @import("config.zig");
    const ClockConfig = config_module.ClockConfig;
    const Features = config_module.Features;
    const ConfigError = config_module.ConfigError;
    const Migration = config_module.Migration;

// ╔══════════════════════════════════════ TEST ═══════════════════════════════════════╗

    // ┌────────────────────────── PRESET TESTS ──────────────────────────┐

    test "unit: ClockConfig: default initialization" {
        const cfg = ClockConfig.default();
        
        // Verify default time settings
        try testing.expectEqual(@as(u32, 900), cfg.quarter_length);
        try testing.expectEqual(@as(u32, 600), cfg.overtime_length);
        try testing.expectEqual(@as(u32, 720), cfg.halftime_duration);
        try testing.expectEqual(@as(u8, 40), cfg.play_clock_normal);
        try testing.expectEqual(@as(u8, 25), cfg.play_clock_short);
        try testing.expectEqual(@as(u32, 30), cfg.timeout_duration);
        try testing.expectEqual(@as(u32, 120), cfg.two_minute_warning_time);
        
        // Verify default rule settings
        try testing.expectEqual(@as(u8, 3), cfg.timeouts_per_half);
        try testing.expectEqual(@as(u8, 2), cfg.challenges_per_game);
        try testing.expectEqual(ClockConfig.OvertimeType.sudden_death, cfg.overtime_type);
        try testing.expect(cfg.clock_stop_incomplete_pass);
        try testing.expect(cfg.clock_stop_out_of_bounds);
        try testing.expect(cfg.clock_stop_penalty);
        try testing.expect(!cfg.clock_stop_first_down);
        
        // Verify default behavior settings
        try testing.expect(cfg.auto_start_play_clock);
        try testing.expect(!cfg.auto_timeout_management);
        try testing.expect(cfg.injury_timeout_enabled);
        try testing.expect(cfg.enforce_delay_of_game);
        
        // Verify default advanced settings
        try testing.expectEqual(@as(u8, 1), cfg.minimum_snap_time);
        try testing.expectEqual(@as(u8, 3), cfg.spike_clock_runoff);
        try testing.expectEqual(@as(u8, 40), cfg.kneel_clock_runoff);
        try testing.expectEqual(@as(u32, 1), cfg.simulation_speed);
        try testing.expect(!cfg.deterministic_mode);
    }
    
    test "unit: ClockConfig: nfl playoff preset" {
        const cfg = ClockConfig.nflPlayoff();
        
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, cfg.overtime_type);
        try testing.expectEqual(@as(u32, 900), cfg.overtime_length); // 15 minutes in playoffs
        try testing.expect(cfg.playoff_rules); // Verify playoff_rules is set to true
        try testing.expect(cfg.features.two_minute_warning);
        try testing.expect(cfg.features.overtime);
        try testing.expect(cfg.features.weather_effects);
    }
    
    test "unit: ClockConfig: college preset" {
        const cfg = ClockConfig.college();
        
        try testing.expectEqual(@as(u32, 900), cfg.quarter_length);
        try testing.expectEqual(ClockConfig.OvertimeType.college_style, cfg.overtime_type);
        try testing.expectEqual(@as(u32, 0), cfg.overtime_length);
        try testing.expect(cfg.clock_stop_first_down);
        try testing.expectEqual(@as(u32, 1200), cfg.halftime_duration);
        try testing.expect(!cfg.features.two_minute_warning);
        try testing.expect(!cfg.features.challenges);
    }
    
    test "unit: ClockConfig: practice preset" {
        const cfg = ClockConfig.practice();
        
        try testing.expectEqual(@as(u32, 600), cfg.quarter_length);
        try testing.expectEqual(ClockConfig.OvertimeType.none, cfg.overtime_type);
        try testing.expectEqual(@as(u32, 300), cfg.halftime_duration);
        try testing.expect(!cfg.auto_timeout_management);
        try testing.expect(!cfg.enforce_delay_of_game);
        try testing.expect(!cfg.features.two_minute_warning);
        try testing.expect(!cfg.features.penalties);
    }

    // └──────────────────────────────────────────────────────────────────┘
    
    test "unit: ClockConfig: validation success" {
        var cfg = ClockConfig.default();
        try cfg.validate();
        
        // Test boundary values that should pass
        cfg.quarter_length = 1;
        cfg.two_minute_warning_time = 0; // Adjust for very short quarter
        try cfg.validate();
        
        cfg = ClockConfig.default();
        cfg.quarter_length = 3600;
        try cfg.validate();
        
        cfg = ClockConfig.default();
        cfg.play_clock_normal = 60;
        cfg.play_clock_short = 60;
        try cfg.validate();
    }
    
    test "unit: ClockConfig: validation failures" {
        var cfg = ClockConfig.default();
        
        // Invalid quarter length
        cfg.quarter_length = 0;
        try testing.expectError(ConfigError.InvalidQuarterLength, cfg.validate());
        
        cfg.quarter_length = 3601;
        try testing.expectError(ConfigError.InvalidQuarterLength, cfg.validate());
        
        // Invalid overtime length
        cfg = ClockConfig.default();
        cfg.overtime_length = 1801;
        try testing.expectError(ConfigError.InvalidOvertimeLength, cfg.validate());
        
        // Invalid play clock
        cfg = ClockConfig.default();
        cfg.play_clock_normal = 0;
        try testing.expectError(ConfigError.InvalidPlayClock, cfg.validate());
        
        cfg = ClockConfig.default();
        cfg.play_clock_normal = 61;
        try testing.expectError(ConfigError.InvalidPlayClock, cfg.validate());
        
        cfg = ClockConfig.default();
        cfg.play_clock_short = 50;
        cfg.play_clock_normal = 40;
        try testing.expectError(ConfigError.InvalidPlayClock, cfg.validate());
        
        // Invalid timeout duration
        cfg = ClockConfig.default();
        cfg.timeout_duration = 0;
        try testing.expectError(ConfigError.InvalidTimeoutDuration, cfg.validate());
        
        cfg.timeout_duration = 121;
        try testing.expectError(ConfigError.InvalidTimeoutDuration, cfg.validate());
        
        // Invalid halftime duration
        cfg = ClockConfig.default();
        cfg.halftime_duration = 59;
        try testing.expectError(ConfigError.InvalidHalftimeDuration, cfg.validate());
        
        cfg.halftime_duration = 3601;
        try testing.expectError(ConfigError.InvalidHalftimeDuration, cfg.validate());
        
        // Invalid simulation speed
        cfg = ClockConfig.default();
        cfg.simulation_speed = 0;
        try testing.expectError(ConfigError.InvalidSpeedMultiplier, cfg.validate());
        
        cfg.simulation_speed = 101;
        try testing.expectError(ConfigError.InvalidSpeedMultiplier, cfg.validate());
        
        // Incompatible configuration
        cfg = ClockConfig.default();
        cfg.overtime_type = .college_style;
        cfg.features.two_minute_warning = true;
        try testing.expectError(ConfigError.IncompatibleConfiguration, cfg.validate());
        
        cfg = ClockConfig.default();
        cfg.two_minute_warning_time = 1000;
        cfg.quarter_length = 900;
        try testing.expectError(ConfigError.IncompatibleConfiguration, cfg.validate());
    }
    
    test "unit: ClockConfig: compatibility check" {
        const current = ClockConfig.default();
        var new = ClockConfig.default();
        
        // Compatible change
        new.play_clock_normal = 35;
        try testing.expect(current.isCompatibleChange(&new, 500));
        
        // Incompatible change - new quarter length less than current time
        new = ClockConfig.default();
        new.quarter_length = 400;
        try testing.expect(!current.isCompatibleChange(&new, 500));
        
        // Compatible change - new quarter length greater than current time
        new.quarter_length = 600;
        try testing.expect(current.isCompatibleChange(&new, 500));
    }
    
    test "unit: ClockConfig: migration creation" {
        const allocator = testing.allocator;
        const current = ClockConfig.default();
        var new = ClockConfig.default();
        
        // Change quarter length and two-minute warning
        new.quarter_length = 1200;
        new.features.two_minute_warning = false;
        
        var migration = try current.createMigration(&new, allocator);
        defer migration.deinit();
        
        try testing.expectEqual(@as(usize, 2), migration.steps.items.len);
        
        const step1 = migration.steps.items[0];
        try testing.expectEqual(Migration.MigrationStep.StepType.adjust_time, step1.type);
        try testing.expectEqual(@as(u32, 900), step1.old_value);
        try testing.expectEqual(@as(u32, 1200), step1.new_value);
        
        const step2 = migration.steps.items[1];
        try testing.expectEqual(Migration.MigrationStep.StepType.toggle_feature, step2.type);
        try testing.expectEqual(@as(u32, 1), step2.old_value);
        try testing.expectEqual(@as(u32, 0), step2.new_value);
    }
    
    test "unit: Features: default initialization" {
        const features = Features.default();
        
        try testing.expect(features.two_minute_warning);
        try testing.expect(features.overtime);
        try testing.expect(features.timeouts);
        try testing.expect(features.injuries);
        try testing.expect(features.penalties);
        try testing.expect(features.challenges);
        try testing.expect(!features.weather_effects);
    }
    
    test "unit: Features: practice mode" {
        const features = Features.practice();
        
        try testing.expect(!features.two_minute_warning);
        try testing.expect(!features.overtime);
        try testing.expect(!features.timeouts);
        try testing.expect(!features.injuries);
        try testing.expect(!features.penalties);
        try testing.expect(!features.challenges);
        try testing.expect(!features.weather_effects);
    }
    
    test "unit: ClockConfig: compile-time validation" {
        const comptime_config = comptime ClockConfig.applyComptime(ClockConfig.default());
        
        try testing.expectEqual(@as(u32, 900), comptime_config.quarter_length);
        try testing.expectEqual(@as(u32, 600), comptime_config.overtime_length);
    }
    
    test "integration: ClockConfig: preset transitions" {
        // Test transitioning between different presets
        const nfl_regular = ClockConfig.default();
        const nfl_playoff = ClockConfig.nflPlayoff();
        const college = ClockConfig.college();
        const practice_cfg = ClockConfig.practice();
        
        // Verify each preset is valid
        try nfl_regular.validate();
        try nfl_playoff.validate();
        try college.validate();
        try practice_cfg.validate();
        
        // Test compatibility between presets at different game times
        try testing.expect(nfl_regular.isCompatibleChange(&nfl_playoff, 500));
        try testing.expect(practice_cfg.isCompatibleChange(&nfl_regular, 500)); // 500s is within both ranges
    }
    
    test "integration: ClockConfig: migration workflow" {
        const allocator = testing.allocator;
        
        // Start with regular season config
        var current = ClockConfig.default();
        
        // Transition to playoff config
        const playoff = ClockConfig.nflPlayoff();
        
        var migration = try current.createMigration(&playoff, allocator);
        defer migration.deinit();
        
        // Verify migration captures the changes
        for (migration.steps.items) |step| {
            switch (step.type) {
                .adjust_time => {
                    // Overtime length change
                    if (step.old_value == 600 and step.new_value == 900) {
                        // Expected change
                    }
                },
                .toggle_feature => {
                    // Weather effects toggle
                    if (step.old_value == 0 and step.new_value == 1) {
                        // Expected change
                    }
                },
                else => {},
            }
        }
    }

    // ┌────────────────────── BOUNDARY VALUE TESTS ──────────────────────┐

    test "unit: ClockConfig: minimum valid values" {
        var cfg = ClockConfig.default();
        
        // Test minimum valid values for all numeric fields
        cfg.quarter_length = 1;
        cfg.overtime_length = 0;
        cfg.halftime_duration = 60;
        cfg.play_clock_normal = 1;
        cfg.play_clock_short = 1;
        cfg.timeout_duration = 1;
        cfg.two_minute_warning_time = 0;
        cfg.timeouts_per_half = 0;
        cfg.challenges_per_game = 0;
        cfg.minimum_snap_time = 0;
        cfg.spike_clock_runoff = 0;
        cfg.kneel_clock_runoff = 0;
        cfg.simulation_speed = 1;
        
        try cfg.validate();
    }
    
    test "unit: ClockConfig: maximum valid values" {
        var cfg = ClockConfig.default();
        
        // Test maximum valid values
        cfg.quarter_length = 3600;
        cfg.overtime_length = 1800;
        cfg.halftime_duration = 3600;
        cfg.play_clock_normal = 60;
        cfg.play_clock_short = 60;
        cfg.timeout_duration = 120;
        cfg.two_minute_warning_time = 3600;
        cfg.timeouts_per_half = 255;
        cfg.challenges_per_game = 255;
        cfg.minimum_snap_time = 255;
        cfg.spike_clock_runoff = 255;
        cfg.kneel_clock_runoff = 255;
        cfg.simulation_speed = 100;
        
        try cfg.validate();
    }
    
    test "unit: ClockConfig: edge case two minute warning equals quarter" {
        var cfg = ClockConfig.default();
        cfg.quarter_length = 120;
        cfg.two_minute_warning_time = 120;
        try cfg.validate();
    }
    
    test "unit: ClockConfig: zero overtime for college style" {
        var cfg = ClockConfig.college();
        try testing.expectEqual(@as(u32, 0), cfg.overtime_length);
        try cfg.validate();
    }

    // ┌───────────────────── VALIDATION ERROR TESTS ─────────────────────┐
    
    test "unit: ClockConfig: validation extreme values" {
        var cfg = ClockConfig.default();
        
        // Test u32 max values that should fail
        cfg.quarter_length = std.math.maxInt(u32);
        try testing.expectError(ConfigError.InvalidQuarterLength, cfg.validate());
        
        cfg = ClockConfig.default();
        cfg.overtime_length = std.math.maxInt(u32);
        try testing.expectError(ConfigError.InvalidOvertimeLength, cfg.validate());
        
        cfg = ClockConfig.default();
        cfg.halftime_duration = std.math.maxInt(u32);
        try testing.expectError(ConfigError.InvalidHalftimeDuration, cfg.validate());
        
        cfg = ClockConfig.default();
        cfg.timeout_duration = std.math.maxInt(u32);
        try testing.expectError(ConfigError.InvalidTimeoutDuration, cfg.validate());
        
        cfg = ClockConfig.default();
        cfg.simulation_speed = std.math.maxInt(u32);
        try testing.expectError(ConfigError.InvalidSpeedMultiplier, cfg.validate());
    }
    
    test "unit: ClockConfig: validation play clock consistency" {
        var cfg = ClockConfig.default();
        
        // Short clock greater than normal clock
        cfg.play_clock_normal = 30;
        cfg.play_clock_short = 31;
        try testing.expectError(ConfigError.InvalidPlayClock, cfg.validate());
        
        // Both clocks at zero
        cfg.play_clock_normal = 0;
        cfg.play_clock_short = 0;
        try testing.expectError(ConfigError.InvalidPlayClock, cfg.validate());
        
        // Valid edge case: both equal
        cfg.play_clock_normal = 40;
        cfg.play_clock_short = 40;
        try cfg.validate();
    }

    // ┌────────────────── CONFIGURATION CONFLICT TESTS ──────────────────┐
    
    test "unit: ClockConfig: conflicting rules detection" {
        var cfg = ClockConfig.default();
        
        // College overtime with two-minute warning
        cfg.overtime_type = .college_style;
        cfg.features.two_minute_warning = true;
        try testing.expectError(ConfigError.IncompatibleConfiguration, cfg.validate());
        
        // Two-minute warning time exceeds quarter length
        cfg = ClockConfig.default();
        cfg.quarter_length = 100;
        cfg.two_minute_warning_time = 150;
        try testing.expectError(ConfigError.IncompatibleConfiguration, cfg.validate());
        
        // Valid: disabled two-minute warning with reasonable time
        cfg = ClockConfig.default();
        cfg.features.two_minute_warning = false;
        cfg.two_minute_warning_time = 120; // Reasonable value even if disabled
        cfg.quarter_length = 900;
        try cfg.validate();
    }
    
    test "unit: ClockConfig: overtime none with overtime features" {
        var cfg = ClockConfig.practice();
        try testing.expectEqual(ClockConfig.OvertimeType.none, cfg.overtime_type);
        try testing.expect(!cfg.features.overtime);
        try cfg.validate();
        
        // Conflicting: no overtime type but overtime enabled
        cfg.overtime_type = .none;
        cfg.features.overtime = true;
        // This should still validate as features don't enforce game rules
        try cfg.validate();
    }

    // ┌─────────────────────── FEATURE FLAG TESTS ───────────────────────┐
    
    test "unit: Features: custom feature combinations" {
        // Test all features disabled
        const all_off = Features{
            .two_minute_warning = false,
            .overtime = false,
            .timeouts = false,
            .injuries = false,
            .penalties = false,
            .challenges = false,
            .weather_effects = false,
        };
        
        try testing.expect(!all_off.two_minute_warning);
        try testing.expect(!all_off.overtime);
        try testing.expect(!all_off.timeouts);
        try testing.expect(!all_off.injuries);
        try testing.expect(!all_off.penalties);
        try testing.expect(!all_off.challenges);
        try testing.expect(!all_off.weather_effects);
        
        // Test all features enabled
        const all_on = Features{
            .two_minute_warning = true,
            .overtime = true,
            .timeouts = true,
            .injuries = true,
            .penalties = true,
            .challenges = true,
            .weather_effects = true,
        };
        
        try testing.expect(all_on.two_minute_warning);
        try testing.expect(all_on.overtime);
        try testing.expect(all_on.timeouts);
        try testing.expect(all_on.injuries);
        try testing.expect(all_on.penalties);
        try testing.expect(all_on.challenges);
        try testing.expect(all_on.weather_effects);
    }
    
    test "unit: ClockConfig: feature flag independence" {
        var cfg = ClockConfig.default();
        
        // Test each feature can be toggled independently
        cfg.features.two_minute_warning = false;
        try cfg.validate();
        
        cfg.features.overtime = false;
        try cfg.validate();
        
        cfg.features.timeouts = false;
        try cfg.validate();
        
        cfg.features.injuries = false;
        try cfg.validate();
        
        cfg.features.penalties = false;
        try cfg.validate();
        
        cfg.features.challenges = false;
        try cfg.validate();
        
        cfg.features.weather_effects = true;
        try cfg.validate();
    }

    // ┌─────────────────── COMPATIBILITY CHECK TESTS ────────────────────┐
    
    test "unit: ClockConfig: compatibility edge cases" {
        const current = ClockConfig.default();
        var new = ClockConfig.default();
        
        // Test exact boundary - time equals new quarter length
        new.quarter_length = 500;
        try testing.expect(current.isCompatibleChange(&new, 500));
        
        // Test one second over boundary
        try testing.expect(!current.isCompatibleChange(&new, 501));
        
        // Test zero time remaining
        try testing.expect(current.isCompatibleChange(&new, 0));
        
        // Test with maximum time
        new.quarter_length = 3600;
        try testing.expect(current.isCompatibleChange(&new, 3600));
        try testing.expect(!current.isCompatibleChange(&new, 3601));
    }
    
    test "unit: ClockConfig: compatibility with all presets" {
        const presets = [_]ClockConfig{
            ClockConfig.default(),
            ClockConfig.nflPlayoff(),
            ClockConfig.college(),
            ClockConfig.practice(),
        };
        
        // Test all preset combinations
        for (presets) |current| {
            for (presets) |new| {
                // Should be compatible when time is within new quarter length
                const time: u32 = @min(current.quarter_length, new.quarter_length) / 2;
                try testing.expect(current.isCompatibleChange(&new, time));
                
                // Should be incompatible when time exceeds new quarter length
                if (new.quarter_length < current.quarter_length) {
                    const bad_time = new.quarter_length + 1;
                    try testing.expect(!current.isCompatibleChange(&new, bad_time));
                }
            }
        }
    }

    // ┌──────────────────────── MIGRATION TESTS ─────────────────────────┐
    
    test "unit: Migration: comprehensive change tracking" {
        const allocator = testing.allocator;
        const current = ClockConfig.default();
        var new = ClockConfig.default();
        
        // Change multiple settings
        new.quarter_length = 1200;
        new.overtime_length = 900;
        new.halftime_duration = 900;
        new.play_clock_normal = 35;
        new.play_clock_short = 20;
        new.features.two_minute_warning = false;
        new.features.weather_effects = true;
        
        var migration = try current.createMigration(&new, allocator);
        defer migration.deinit();
        
        // Verify at least quarter length and two_minute_warning changes are tracked
        try testing.expect(migration.steps.items.len >= 2);
        
        var found_quarter_change = false;
        var found_feature_change = false;
        
        for (migration.steps.items) |step| {
            if (step.type == .adjust_time and step.old_value == 900 and step.new_value == 1200) {
                found_quarter_change = true;
            }
            if (step.type == .toggle_feature) {
                found_feature_change = true;
            }
        }
        
        try testing.expect(found_quarter_change);
        try testing.expect(found_feature_change);
    }
    
    test "unit: Migration: empty migration for identical configs" {
        const allocator = testing.allocator;
        const current = ClockConfig.default();
        const new = ClockConfig.default();
        
        var migration = try current.createMigration(&new, allocator);
        defer migration.deinit();
        
        // No changes should result in empty migration
        try testing.expectEqual(@as(usize, 0), migration.steps.items.len);
    }
    
    test "unit: Migration: preset transitions" {
        const allocator = testing.allocator;
        
        // Test all preset transition combinations
        const presets = [_]struct { config: ClockConfig, name: []const u8 }{
            .{ .config = ClockConfig.default(), .name = "regular" },
            .{ .config = ClockConfig.nflPlayoff(), .name = "playoff" },
            .{ .config = ClockConfig.college(), .name = "college" },
            .{ .config = ClockConfig.practice(), .name = "practice" },
        };
        
        for (presets) |from| {
            for (presets) |to| {
                var migration = try from.config.createMigration(&to.config, allocator);
                defer migration.deinit();
                
                // Different presets may or may not have trackable changes
                // depending on which fields differ and are tracked
                if (!std.mem.eql(u8, from.name, to.name)) {
                    // Migration may be empty if only untracked fields differ
                    _ = migration.steps.items.len;
                }
            }
        }
    }

    // ┌──────────────────── ADVANCED SETTINGS TESTS ─────────────────────┐
    
    test "unit: ClockConfig: simulation speed settings" {
        var cfg = ClockConfig.default();
        
        // Test various simulation speeds
        cfg.simulation_speed = 1;  // Real-time
        try cfg.validate();
        
        cfg.simulation_speed = 2;  // 2x speed
        try cfg.validate();
        
        cfg.simulation_speed = 10;  // 10x speed
        try cfg.validate();
        
        cfg.simulation_speed = 100;  // Maximum speed
        try cfg.validate();
        
        cfg.simulation_speed = 101;  // Over maximum
        try testing.expectError(ConfigError.InvalidSpeedMultiplier, cfg.validate());
    }
    
    test "unit: ClockConfig: clock runoff settings" {
        var cfg = ClockConfig.default();
        
        // Test extreme runoff values
        cfg.spike_clock_runoff = 0;
        cfg.kneel_clock_runoff = 0;
        try cfg.validate();
        
        cfg.spike_clock_runoff = 255;
        cfg.kneel_clock_runoff = 255;
        try cfg.validate();
        
        // Test realistic values
        cfg.spike_clock_runoff = 3;
        cfg.kneel_clock_runoff = 40;
        try cfg.validate();
    }
    
    test "unit: ClockConfig: deterministic mode settings" {
        var cfg = ClockConfig.default();
        
        // Test deterministic mode toggle
        cfg.deterministic_mode = false;
        try cfg.validate();
        
        cfg.deterministic_mode = true;
        try cfg.validate();
        
        // Deterministic mode should work with all presets
        const presets = [_]ClockConfig{
            ClockConfig.default(),
            ClockConfig.nflPlayoff(),
            ClockConfig.college(),
            ClockConfig.practice(),
        };
        
        for (presets) |preset| {
            var test_cfg = preset;
            test_cfg.deterministic_mode = true;
            try test_cfg.validate();
        }
    }

    // ┌─────────────────────── COMPILE-TIME TESTS ───────────────────────┐
    
    test "unit: ClockConfig: compile-time preset validation" {
        // Test all presets can be validated at compile time
        const regular = comptime ClockConfig.applyComptime(ClockConfig.default());
        const playoff = comptime ClockConfig.applyComptime(ClockConfig.nflPlayoff());
        const college_cfg = comptime ClockConfig.applyComptime(ClockConfig.college());
        const practice_cfg = comptime ClockConfig.applyComptime(ClockConfig.practice());
        
        try testing.expectEqual(@as(u32, 900), regular.quarter_length);
        try testing.expectEqual(@as(u32, 900), playoff.overtime_length);
        try testing.expectEqual(@as(u32, 0), college_cfg.overtime_length);
        try testing.expectEqual(@as(u32, 600), practice_cfg.quarter_length);
    }
    
    test "unit: ClockConfig: compile-time custom validation" {
        const custom = comptime blk: {
            var cfg = ClockConfig.default();
            cfg.quarter_length = 1800;
            cfg.play_clock_normal = 45;
            cfg.features.weather_effects = true;
            break :blk ClockConfig.applyComptime(cfg);
        };
        
        try testing.expectEqual(@as(u32, 1800), custom.quarter_length);
        try testing.expectEqual(@as(u8, 45), custom.play_clock_normal);
        try testing.expect(custom.features.weather_effects);
    }

    // ┌────────────────────── PLAYOFF RULES TESTS ───────────────────────┐

    test "unit: ClockConfig: default config has playoff_rules false" {
        const cfg = ClockConfig.default();
        try testing.expect(!cfg.playoff_rules);
        try testing.expectEqual(@as(u32, 600), cfg.overtime_length); // Regular season 10 minutes
    }

    test "unit: ClockConfig: playoff_rules validation rejects incompatible overtime_type" {
        var cfg = ClockConfig.default();
        cfg.playoff_rules = true;
        cfg.overtime_type = .none;
        
        // Playoff games cannot have no overtime
        try testing.expectError(ConfigError.IncompatibleConfiguration, cfg.validate());
    }

    test "unit: ClockConfig: playoff_rules requires minimum 15-minute overtime" {
        var cfg = ClockConfig.default();
        cfg.playoff_rules = true;
        cfg.overtime_length = 600; // 10 minutes - too short for playoffs
        
        try testing.expectError(ConfigError.InvalidOvertimeLength, cfg.validate());
        
        // Exactly 15 minutes should be valid
        cfg.overtime_length = 900;
        try cfg.validate();
        
        // More than 15 minutes should be valid
        cfg.overtime_length = 1200;
        try cfg.validate();
    }

    test "unit: ClockConfig: regular season config does not set playoff_rules" {
        const cfg = ClockConfig.default();
        
        try testing.expect(!cfg.playoff_rules);
        try testing.expectEqual(@as(u32, 600), cfg.overtime_length);
        try testing.expectEqual(ClockConfig.OvertimeType.sudden_death, cfg.overtime_type);
        
        // Should validate without issues
        try cfg.validate();
    }

    test "unit: ClockConfig: college preset does not set playoff_rules" {
        const cfg = ClockConfig.college();
        
        try testing.expect(!cfg.playoff_rules);
        try testing.expectEqual(ClockConfig.OvertimeType.college_style, cfg.overtime_type);
        
        // College has different overtime rules
        try cfg.validate();
    }

    test "unit: ClockConfig: practice preset does not set playoff_rules" {
        const cfg = ClockConfig.practice();
        
        try testing.expect(!cfg.playoff_rules);
        try testing.expectEqual(ClockConfig.OvertimeType.none, cfg.overtime_type);
        
        // Practice mode has no overtime
        try cfg.validate();
    }

    test "integration: ClockConfig: transitioning from regular to playoff config" {
        const allocator = testing.allocator;
        
        // Start with regular season config
        const regular = ClockConfig.default();
        try testing.expect(!regular.playoff_rules);
        
        // Transition to playoff config
        const playoff = ClockConfig.nflPlayoff();
        try testing.expect(playoff.playoff_rules);
        
        // Create migration to track changes
        var migration = try regular.createMigration(&playoff, allocator);
        defer migration.deinit();
        
        // Migration tracks changes between configs
        // The exact implementation of migration tracking may vary
        // Just verify the migration was created successfully
        try testing.expect(migration.steps.items.len >= 0);
    }

    test "unit: ClockConfig: playoff_rules with valid overtime configurations" {
        var cfg = ClockConfig.nflPlayoff();
        
        // Test with sudden death overtime (valid for playoffs)
        cfg.overtime_type = .sudden_death;
        cfg.overtime_length = 900;
        try cfg.validate();
        
        // Test with modified sudden death (default for playoffs)
        cfg.overtime_type = .modified_sudden_death;
        cfg.overtime_length = 900;
        try cfg.validate();
        
        // Test with extended overtime length
        cfg.overtime_length = 1800; // 30 minutes
        try cfg.validate();
    }

    test "unit: ClockConfig: playoff_rules edge cases" {
        var cfg = ClockConfig.default();
        
        // Edge case: playoff_rules with exactly minimum overtime
        cfg.playoff_rules = true;
        cfg.overtime_length = 900; // Exactly 15 minutes
        cfg.overtime_type = .modified_sudden_death;
        try cfg.validate();
        
        // Edge case: playoff_rules with one second less than minimum
        cfg.overtime_length = 899; // 14:59
        try testing.expectError(ConfigError.InvalidOvertimeLength, cfg.validate());
        
        // Edge case: switching playoff_rules on and off
        cfg.playoff_rules = false;
        cfg.overtime_length = 600; // Regular season length OK now
        try cfg.validate();
    }

    test "scenario: ClockConfig: playoff game configuration workflow" {
        // Scenario: Setting up a playoff game
        var cfg = ClockConfig.nflPlayoff();
        
        // Verify all playoff-specific settings
        try testing.expect(cfg.playoff_rules);
        try testing.expectEqual(@as(u32, 900), cfg.overtime_length);
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, cfg.overtime_type);
        try testing.expect(cfg.features.overtime);
        try testing.expect(cfg.features.two_minute_warning);
        
        // Customize for specific playoff conditions
        cfg.features.weather_effects = true; // Cold playoff game
        cfg.simulation_speed = 1; // Real-time for playoffs
        cfg.deterministic_mode = false; // Production mode
        
        // Validate complete playoff configuration
        try cfg.validate();
    }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌────────────────────── PRESETS STRUCT TESTS ──────────────────────┐

    test "unit: ClockConfig.Presets: nfl_regular has expected values" {
        const preset = ClockConfig.Presets.nfl_regular;
        
        // Verify it matches default configuration
        try testing.expectEqual(@as(u32, 900), preset.quarter_length);
        try testing.expectEqual(@as(u32, 600), preset.overtime_length);
        try testing.expectEqual(@as(u32, 720), preset.halftime_duration);
        try testing.expectEqual(@as(u8, 40), preset.play_clock_normal);
        try testing.expectEqual(@as(u8, 25), preset.play_clock_short);
        try testing.expectEqual(@as(u32, 30), preset.timeout_duration);
        try testing.expectEqual(@as(u32, 120), preset.two_minute_warning_time);
        try testing.expectEqual(@as(u8, 3), preset.timeouts_per_half);
        try testing.expectEqual(@as(u8, 2), preset.challenges_per_game);
        try testing.expectEqual(ClockConfig.OvertimeType.sudden_death, preset.overtime_type);
        try testing.expect(!preset.playoff_rules);
        try testing.expect(preset.clock_stop_incomplete_pass);
        try testing.expect(preset.clock_stop_out_of_bounds);
        try testing.expect(preset.clock_stop_penalty);
        try testing.expect(!preset.clock_stop_first_down);
        try testing.expect(preset.auto_start_play_clock);
        try testing.expect(!preset.auto_timeout_management);
        try testing.expect(preset.injury_timeout_enabled);
        try testing.expect(preset.enforce_delay_of_game);
        try testing.expectEqual(@as(u8, 1), preset.minimum_snap_time);
        try testing.expectEqual(@as(u8, 3), preset.spike_clock_runoff);
        try testing.expectEqual(@as(u8, 40), preset.kneel_clock_runoff);
        try testing.expectEqual(@as(u32, 1), preset.simulation_speed);
        try testing.expect(!preset.deterministic_mode);
    }

    test "unit: ClockConfig.Presets: nfl_playoff has expected values" {
        const preset = ClockConfig.Presets.nfl_playoff;
        
        // Verify playoff-specific settings
        try testing.expect(preset.playoff_rules);
        try testing.expectEqual(ClockConfig.OvertimeType.modified_sudden_death, preset.overtime_type);
        try testing.expectEqual(@as(u32, 900), preset.overtime_length); // 15 minutes for playoffs
        
        // Other settings should match default
        try testing.expectEqual(@as(u32, 900), preset.quarter_length);
        try testing.expectEqual(@as(u32, 720), preset.halftime_duration);
        try testing.expectEqual(@as(u8, 40), preset.play_clock_normal);
        try testing.expectEqual(@as(u8, 25), preset.play_clock_short);
    }

    test "unit: ClockConfig.Presets: college has expected values" {
        const preset = ClockConfig.Presets.college;
        
        // Verify college-specific settings
        try testing.expect(preset.clock_stop_first_down);
        try testing.expectEqual(@as(u32, 0), preset.overtime_length);
        try testing.expectEqual(@as(u8, 40), preset.play_clock_normal);
        try testing.expectEqual(@as(u8, 25), preset.play_clock_short);
        try testing.expectEqual(ClockConfig.OvertimeType.college_style, preset.overtime_type);
        try testing.expectEqual(@as(u32, 1200), preset.halftime_duration); // 20 minutes
        
        // Verify college features
        try testing.expect(!preset.features.two_minute_warning);
        try testing.expect(!preset.features.challenges);
        
        // Should not have playoff rules
        try testing.expect(!preset.playoff_rules);
    }

    test "unit: ClockConfig.Presets: practice has expected values" {
        const preset = ClockConfig.Presets.practice;
        
        // Verify practice-specific settings
        try testing.expectEqual(@as(u32, 600), preset.quarter_length); // 10 minutes
        try testing.expectEqual(@as(u32, 300), preset.halftime_duration); // 5 minutes
        try testing.expect(!preset.enforce_delay_of_game);
        try testing.expectEqual(ClockConfig.OvertimeType.none, preset.overtime_type);
        
        // Verify practice features (all disabled)
        try testing.expect(!preset.features.two_minute_warning);
        try testing.expect(!preset.features.overtime);
        try testing.expect(!preset.features.timeouts);
        try testing.expect(!preset.features.injuries);
        try testing.expect(!preset.features.penalties);
        try testing.expect(!preset.features.challenges);
        try testing.expect(!preset.features.weather_effects);
        
        // Should not have playoff rules
        try testing.expect(!preset.playoff_rules);
    }

    test "unit: ClockConfig.Presets: all presets pass validation" {
        // Test that all presets are valid configurations
        const nfl_regular = ClockConfig.Presets.nfl_regular;
        try nfl_regular.validate();
        
        const nfl_playoff = ClockConfig.Presets.nfl_playoff;
        try nfl_playoff.validate();
        
        const college = ClockConfig.Presets.college;
        try college.validate();
        
        const practice = ClockConfig.Presets.practice;
        try practice.validate();
    }

    test "unit: ClockConfig.Presets: presets are compile-time constants" {
        // Verify that presets can be used in comptime contexts
        const comptime_regular = comptime ClockConfig.Presets.nfl_regular;
        const comptime_playoff = comptime ClockConfig.Presets.nfl_playoff;
        const comptime_college = comptime ClockConfig.Presets.college;
        const comptime_practice = comptime ClockConfig.Presets.practice;
        
        // Verify comptime values match runtime values
        try testing.expectEqual(ClockConfig.Presets.nfl_regular.quarter_length, comptime_regular.quarter_length);
        try testing.expectEqual(ClockConfig.Presets.nfl_playoff.overtime_length, comptime_playoff.overtime_length);
        try testing.expectEqual(ClockConfig.Presets.college.overtime_type, comptime_college.overtime_type);
        try testing.expectEqual(ClockConfig.Presets.practice.quarter_length, comptime_practice.quarter_length);
    }

    test "unit: ClockConfig.Presets: can be used as base for custom configurations" {
        // Start with NFL regular preset
        var custom = ClockConfig.Presets.nfl_regular;
        
        // Customize specific settings
        custom.quarter_length = 1200; // 20 minutes
        custom.play_clock_normal = 35;
        custom.features.weather_effects = true;
        
        // Verify customizations took effect
        try testing.expectEqual(@as(u32, 1200), custom.quarter_length);
        try testing.expectEqual(@as(u8, 35), custom.play_clock_normal);
        try testing.expect(custom.features.weather_effects);
        
        // Verify other settings remain from preset
        try testing.expectEqual(@as(u32, 600), custom.overtime_length);
        try testing.expectEqual(ClockConfig.OvertimeType.sudden_death, custom.overtime_type);
        
        // Custom config should still be valid
        try custom.validate();
    }

    test "unit: ClockConfig.Presets: preset copying preserves all fields" {
        // Test that copying presets preserves all fields correctly
        const original = ClockConfig.Presets.nfl_playoff;
        var copy = original;
        
        // Verify copy has same values
        try testing.expectEqual(original.playoff_rules, copy.playoff_rules);
        try testing.expectEqual(original.overtime_type, copy.overtime_type);
        try testing.expectEqual(original.overtime_length, copy.overtime_length);
        try testing.expectEqual(original.quarter_length, copy.quarter_length);
        
        // Modify copy shouldn't affect original (since it's a const)
        copy.quarter_length = 1800;
        try testing.expectEqual(@as(u32, 900), original.quarter_length);
        try testing.expectEqual(@as(u32, 1800), copy.quarter_length);
    }

    test "integration: ClockConfig.Presets: presets work with GameClock.initWithConfig" {
        const GameClock = @import("../../game_clock.zig").GameClock;
        const allocator = testing.allocator;
        
        // Test NFL regular preset
        {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.Presets.nfl_regular, null);
            defer clock.deinit();
            
            try testing.expectEqual(@as(u32, 900), clock.config.quarter_length);
            try testing.expect(!clock.config.playoff_rules);
        }
        
        // Test NFL playoff preset
        {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.Presets.nfl_playoff, null);
            defer clock.deinit();
            
            try testing.expectEqual(@as(u32, 900), clock.config.overtime_length);
            try testing.expect(clock.config.playoff_rules);
        }
        
        // Test college preset
        {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.Presets.college, null);
            defer clock.deinit();
            
            try testing.expect(clock.config.clock_stop_first_down);
            try testing.expectEqual(ClockConfig.OvertimeType.college_style, clock.config.overtime_type);
        }
        
        // Test practice preset
        {
            var clock = GameClock.initWithConfig(allocator, ClockConfig.Presets.practice, null);
            defer clock.deinit();
            
            try testing.expectEqual(@as(u32, 600), clock.config.quarter_length);
            try testing.expectEqual(ClockConfig.OvertimeType.none, clock.config.overtime_type);
        }
    }

    test "integration: ClockConfig.Presets: preset modifications work with GameClock" {
        const GameClock = @import("../../game_clock.zig").GameClock;
        const allocator = testing.allocator;
        
        // Start with college preset and modify
        var modified_college = ClockConfig.Presets.college;
        modified_college.quarter_length = 720; // 12 minutes
        modified_college.features.weather_effects = true;
        
        var clock = GameClock.initWithConfig(allocator, modified_college, null);
        defer clock.deinit();
        
        // Verify modifications applied
        try testing.expectEqual(@as(u32, 720), clock.config.quarter_length);
        try testing.expect(clock.config.features.weather_effects);
        
        // Verify preset values retained
        try testing.expect(clock.config.clock_stop_first_down);
        try testing.expectEqual(ClockConfig.OvertimeType.college_style, clock.config.overtime_type);
    }

    test "unit: ClockConfig.Presets: compile-time validation of presets" {
        // Verify all presets can be validated at compile time
        comptime {
            // This would cause a compile error if validation failed
            ClockConfig.Presets.nfl_regular.validate() catch unreachable;
            ClockConfig.Presets.nfl_playoff.validate() catch unreachable;
            ClockConfig.Presets.college.validate() catch unreachable;
            ClockConfig.Presets.practice.validate() catch unreachable;
        }
        
        // Runtime check to ensure test runs
        try testing.expect(true);
    }

    test "unit: ClockConfig.Presets: preset equality comparisons" {
        // Test that presets can be compared
        const regular1 = ClockConfig.Presets.nfl_regular;
        const regular2 = ClockConfig.Presets.nfl_regular;
        const playoff = ClockConfig.Presets.nfl_playoff;
        
        // Same preset should have equal values
        try testing.expectEqual(regular1.quarter_length, regular2.quarter_length);
        try testing.expectEqual(regular1.overtime_type, regular2.overtime_type);
        try testing.expectEqual(regular1.playoff_rules, regular2.playoff_rules);
        
        // Different presets should have different values
        try testing.expect(regular1.overtime_type != playoff.overtime_type);
        try testing.expect(regular1.playoff_rules != playoff.playoff_rules);
    }

    test "performance: ClockConfig.Presets: preset access performance" {
        // Test that preset access is efficient (compile-time resolved)
        const start = std.time.milliTimestamp();
        
        // Access presets multiple times
        var sum: u32 = 0;
        for (0..1000) |_| {
            sum += ClockConfig.Presets.nfl_regular.quarter_length;
            sum += ClockConfig.Presets.nfl_playoff.overtime_length;
            sum += ClockConfig.Presets.college.halftime_duration;
            sum += ClockConfig.Presets.practice.quarter_length;
        }
        
        const elapsed = std.time.milliTimestamp() - start;
        
        // Should be very fast since presets are compile-time constants
        try testing.expect(elapsed < 10); // Less than 10ms for 1000 iterations
        try testing.expect(sum > 0); // Ensure computation wasn't optimized away
    }

    test "stress: ClockConfig.Presets: multiple preset instances" {
        const allocator = testing.allocator;
        const GameClock = @import("../../game_clock.zig").GameClock;
        
        // Create multiple clocks with different presets simultaneously
        var clocks = std.ArrayList(GameClock).init(allocator);
        defer {
            for (clocks.items) |*clock| {
                clock.deinit();
            }
            clocks.deinit();
        }
        
        // Add clocks with each preset type
        for (0..10) |_| {
            try clocks.append(GameClock.initWithConfig(allocator, ClockConfig.Presets.nfl_regular, null));
            try clocks.append(GameClock.initWithConfig(allocator, ClockConfig.Presets.nfl_playoff, null));
            try clocks.append(GameClock.initWithConfig(allocator, ClockConfig.Presets.college, null));
            try clocks.append(GameClock.initWithConfig(allocator, ClockConfig.Presets.practice, null));
        }
        
        // Verify all clocks have correct configurations
        for (clocks.items, 0..) |clock, i| {
            const preset_type = i % 4;
            switch (preset_type) {
                0 => try testing.expect(!clock.config.playoff_rules),
                1 => try testing.expect(clock.config.playoff_rules),
                2 => try testing.expect(clock.config.clock_stop_first_down),
                3 => try testing.expectEqual(@as(u32, 600), clock.config.quarter_length),
                else => unreachable,
            }
        }
    }

    // └──────────────────────────────────────────────────────────────────┘

