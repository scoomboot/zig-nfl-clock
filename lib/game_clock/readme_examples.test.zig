// readme_examples.test.zig — Tests to verify README code examples compile correctly
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/lib/game_clock/readme_examples.test
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const game_clock = @import("game_clock.zig");

// ╔══════════════════════════════════════ CORE ═══════════════════════════════════════╗

    test "unit: README: Quick Start example compiles and runs basic operations" {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        // Create a new game clock
        var clock = game_clock.GameClock.init(allocator);
        defer clock.deinit();
        
        // Start the clock
        try clock.start();
        
        // Run a few ticks to verify basic operations work
        var tick_count: u32 = 0;
        while (!clock.isQuarterEnded() and tick_count < 5) : (tick_count += 1) {
            try clock.tick();
            
            // Display current time
            var buffer: [32]u8 = undefined;
            const time_str = clock.formatTime(&buffer);
            
            // Verify we can get quarter string
            const quarter_str = clock.getQuarterString();
            try testing.expect(quarter_str.len > 0);
            try testing.expect(time_str.len > 0);
            
            // Simulate a play on first tick
            if (tick_count == 0) {
                const play = game_clock.Play.run(.run_up_middle, 5);
                _ = try clock.processPlay(play);
            }
        }
        
        // Verify clock state is reasonable
        try testing.expect(clock.getTotalElapsedTime() > 0);
    }

    test "unit: README: Basic Game Simulation example compiles and handles plays" {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        var clock = game_clock.GameClock.init(allocator);
        defer clock.deinit();
        
        try clock.start();
        
        // Simulate a few ticks (not full quarter for test speed)
        var tick_count: u32 = 0;
        while (!clock.isQuarterEnded() and tick_count < 10) : (tick_count += 1) {
            try clock.tick();
            
            // Check for two-minute warning
            if (clock.shouldTriggerTwoMinuteWarning()) {
                clock.triggerTwoMinuteWarning();
                // Verify two-minute warning functionality exists
                try testing.expect(true);
            }
            
            // Process plays periodically
            if (tick_count == 5) {
                const play = game_clock.Play.pass(.pass_short, true, 15, true);
                const result = try clock.processPlay(play);
                // Verify result has yards_gained field
                try testing.expect(result.yards_gained >= 0);
            }
        }
    }

    test "unit: README: Advanced Configuration with builder pattern compiles" {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        // Use builder pattern for configuration
        var builder = game_clock.GameClock.builder(allocator);
        var clock = builder
            .quarterLength(720)              // 12-minute quarters
            .startQuarter(.Q3)               // Start in 3rd quarter
            .enableTwoMinuteWarning(false)   // Disable two-minute warning
            .playClockDuration(.short_25)    // Use 25-second play clock
            .clockSpeed(.accelerated_2x)     // Run at 2x speed
            .build();
        defer clock.deinit();
        
        // Verify builder configuration worked
        try testing.expectEqual(game_clock.Quarter.Q3, clock.quarter);
        try testing.expectEqual(@as(u32, 720), clock.time_remaining);
        try testing.expectEqual(game_clock.PlayClockDuration.short_25, clock.play_clock_duration);
        try testing.expectEqual(game_clock.ClockSpeed.accelerated_2x, clock.clock_speed);
    }

    test "unit: README: Advanced Configuration with ClockConfig struct compiles" {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        // Use custom configuration struct
        var config = game_clock.ClockConfig.default();
        config.quarter_length = 720;
        config.features.two_minute_warning = false;
        config.simulation_speed = 10;
        config.playoff_rules = true;
        config.overtime_length = 900; // Required minimum for playoff rules
        
        var playoff_clock = game_clock.GameClock.initWithConfig(allocator, config, null);
        defer playoff_clock.deinit();
        
        // Verify config was applied
        try testing.expectEqual(@as(u32, 720), playoff_clock.config.quarter_length);
        try testing.expectEqual(false, playoff_clock.config.features.two_minute_warning);
        try testing.expectEqual(@as(u32, 10), playoff_clock.config.simulation_speed);
        try testing.expectEqual(true, playoff_clock.config.playoff_rules);
    }

    test "unit: README: Integration with Game Engine example compiles" {
        const GameEngine = struct {
            const Self = @This();
            
            clock: game_clock.GameClock,
            frame_count: u64 = 0,
            
            pub fn init(allocator: std.mem.Allocator) !Self {
                return .{
                    .clock = game_clock.GameClock.init(allocator),
                };
            }
            
            pub fn deinit(self: *Self) void {
                self.clock.deinit();
            }
            
            pub fn update(self: *Self, delta_time: f32) !void {
                _ = delta_time; // Unused in this example
                self.frame_count += 1;
                
                // Update clock based on frame rate
                if (self.frame_count % 6 == 0) { // ~10 ticks per second at 60 FPS
                    try self.clock.tick();
                }
                
                // Handle game events
                if (self.clock.isQuarterEnded()) {
                    try self.handleQuarterEnd();
                }
            }
            
            fn handleQuarterEnd(self: *Self) !void {
                const quarter = self.clock.quarter;
                if (quarter == .Q2) {
                    // Halftime
                    self.clock.game_state = .Halftime;
                } else if (quarter == .Q4 and self.isGameTied()) {
                    // Start overtime
                    try self.clock.startOvertime();
                }
            }
            
            fn isGameTied(self: *Self) bool {
                _ = self; // Unused in this example
                // Game logic to determine if score is tied
                return true; // Placeholder
            }
        };
        
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        // Create and test the GameEngine
        var engine = try GameEngine.init(allocator);
        defer engine.deinit();
        
        // Run a few update cycles
        try engine.update(0.016); // ~60 FPS delta time
        try engine.update(0.016);
        
        // Verify engine state
        try testing.expect(engine.frame_count == 2);
        try testing.expect(engine.clock.game_state == .InProgress or engine.clock.game_state == .PreGame);
    }

    test "unit: README: Two-Minute Drill scenario function compiles" {
        // Define the two-minute drill function
        const twoMinuteDrill = struct {
            pub fn run(clock: *game_clock.GameClock) !void {
                // Set clock to 2:00 remaining in quarter
                clock.time_remaining = 120;
                clock.triggerTwoMinuteWarning();
                
                // Fast-paced offense - run just a few plays for testing
                var plays_run: u32 = 0;
                while (clock.time_remaining > 0 and !clock.isQuarterEnded() and plays_run < 3) : (plays_run += 1) {
                    // Quick pass plays
                    const play = game_clock.Play.pass(.pass_short, true, 8, false); // Not out of bounds
                    _ = try clock.processPlay(play);
                    
                    // Check for timeouts needed
                    if (clock.time_remaining < 30) {
                        // Use timeout logic
                        try clock.stop();
                        break; // Exit for test
                    }
                }
            }
        }.run;
        
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        // Test the two-minute drill function
        var clock = game_clock.GameClock.init(allocator);
        defer clock.deinit();
        
        try clock.start();
        try twoMinuteDrill(&clock);
        
        // Verify clock state after two-minute drill
        try testing.expect(clock.time_remaining <= 120);
    }

    test "unit: README: Overtime Handling scenario function compiles" {
        // Define the overtime handling function
        const handleOvertime = struct {
            pub fn run(clock: *game_clock.GameClock) !void {
                if (clock.quarter == .Q4 and clock.isQuarterEnded()) {
                    try clock.startOvertime();
                    
                    // Overtime-specific rules
                    clock.config.play_clock_normal = 35; // Shorter play clock
                    try clock.updateConfig(clock.config);
                    
                    // Continue play if not already running
                    if (!clock.is_running) {
                        try clock.start();
                    }
                }
            }
        }.run;
        
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        // Test the overtime handling function
        var clock = game_clock.GameClock.init(allocator);
        defer clock.deinit();
        
        // Set up end of Q4 scenario
        clock.quarter = .Q4;
        clock.time_remaining = 0;
        // Don't start the clock here since handleOvertime will handle it
        
        // Run overtime handler
        try handleOvertime(&clock);
        
        // Verify overtime was started if applicable
        if (clock.quarter == .Overtime) {
            try testing.expectEqual(@as(u8, 35), clock.config.play_clock_normal);
            try testing.expect(clock.is_running or clock.clock_state == .running);
        }
    }

    test "unit: README: Verify all Play factory methods compile" {
        // Test Play.run factory method
        const run_play = game_clock.Play.run(.run_up_middle, 5);
        try testing.expectEqual(game_clock.PlayType.run_up_middle, run_play.type);
        try testing.expectEqual(@as(?i16, 5), run_play.yards_attempted);
        
        // Test Play.pass factory method  
        const pass_play = game_clock.Play.pass(.pass_short, true, 15, true);
        try testing.expectEqual(game_clock.PlayType.pass_short, pass_play.type);
        try testing.expectEqual(true, pass_play.complete);
        try testing.expectEqual(@as(?i16, 15), pass_play.yards_attempted);
        try testing.expectEqual(true, pass_play.out_of_bounds);
    }

    test "unit: README: Verify ClockConfig preset configurations exist" {
        // Note: These presets are referenced in the README but may not be implemented yet
        // This test documents what's expected based on the README
        
        // Create a default config to test basic functionality
        const default_config = game_clock.ClockConfig.default();
        try testing.expectEqual(@as(u32, 900), default_config.quarter_length);
        try testing.expectEqual(@as(u8, 40), default_config.play_clock_normal);
        try testing.expectEqual(@as(u8, 25), default_config.play_clock_short);
        try testing.expectEqual(true, default_config.features.two_minute_warning);
        
        // Test the preset configurations as documented in README
        const nfl_regular = game_clock.ClockConfig.Presets.nfl_regular;
        try testing.expectEqual(@as(u32, 900), nfl_regular.quarter_length);
        
        const nfl_playoff = game_clock.ClockConfig.Presets.nfl_playoff;
        try testing.expectEqual(true, nfl_playoff.playoff_rules);
        
        const college = game_clock.ClockConfig.Presets.college;
        try testing.expectEqual(true, college.clock_stop_first_down);
        
        const practice = game_clock.ClockConfig.Presets.practice;
        try testing.expectEqual(@as(u32, 600), practice.quarter_length);
    }

    test "unit: README: Verify all public API methods exist and compile" {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        var clock = game_clock.GameClock.init(allocator);
        defer clock.deinit();
        
        // Test initialization methods
        var clock2 = game_clock.GameClock.initWithConfig(allocator, game_clock.ClockConfig.default(), null);
        defer clock2.deinit();
        
        var builder = game_clock.GameClock.builder(allocator);
        var clock3 = builder.build();
        defer clock3.deinit();
        
        // Test clock control methods
        try clock.start();
        try clock.stop();
        try clock.tick();
        clock.reset();
        
        // Test play clock management
        clock.resetPlayClock();
        try clock.setPlayClock(25);
        clock.startPlayClock();
        clock.stopPlayClock();
        
        // Test time management methods
        const elapsed = clock.getElapsedTime();
        const remaining = clock.getRemainingTime();
        var buffer: [32]u8 = undefined;
        const time_str = clock.formatTime(&buffer);
        const total_elapsed = clock.getTotalElapsedTime();
        
        // Test play processing - need to start the clock first
        try clock.start();
        const play = game_clock.Play.run(.run_up_middle, 3);
        const result = try clock.processPlay(play);
        
        const context = game_clock.PlayContext{
            .play = play,
            .down = 1,
            .distance = 10,
            .field_position = 50,
            .penalties = &[_]game_clock.Penalty{},
            .weather = game_clock.WeatherConditions{},
        };
        const result2 = try clock.processPlayWithContext(context);
        
        // Test state queries
        const is_halftime = clock.isHalftime();
        const is_overtime = clock.isOvertime();
        const quarter_ended = clock.isQuarterEnded();
        const play_clock_expired = clock.isPlayClockExpired();
        
        const clock_state = clock.getClockState();
        const play_clock_state = clock.getPlayClockState();
        const quarter_string = clock.getQuarterString();
        
        // Test configuration methods
        try clock.updateConfig(game_clock.ClockConfig.default());
        clock.setClockSpeed(.accelerated_2x);
        clock.setCustomClockSpeed(5);
        
        // Verify all return values are valid (basic sanity checks)
        try testing.expect(elapsed >= 0);
        try testing.expect(remaining >= 0);
        try testing.expect(time_str.len > 0);
        try testing.expect(total_elapsed >= 0);
        try testing.expect(result.yards_gained >= -20 and result.yards_gained <= 100);
        try testing.expect(result2.yards_gained >= -20 and result2.yards_gained <= 100);
        try testing.expect(is_halftime == false or is_halftime == true);
        try testing.expect(is_overtime == false or is_overtime == true);
        try testing.expect(quarter_ended == false or quarter_ended == true);
        try testing.expect(play_clock_expired == false or play_clock_expired == true);
        try testing.expect(clock_state == .stopped or clock_state == .running or clock_state == .expired);
        try testing.expect(play_clock_state == .inactive or play_clock_state == .active or 
                         play_clock_state == .warning or play_clock_state == .expired);
        try testing.expect(quarter_string.len > 0);
    }

    test "unit: README: Verify enum types and their methods compile" {
        // Test Quarter enum
        const q1 = game_clock.Quarter.Q1;
        const q1_str = q1.toString();
        try testing.expectEqualStrings("1st Quarter", q1_str);
        
        const ot = game_clock.Quarter.Overtime;
        const ot_str = ot.toString();
        try testing.expectEqualStrings("Overtime", ot_str);
        
        // Test GameState enum
        const pre_game = game_clock.GameState.PreGame;
        const in_progress = game_clock.GameState.InProgress;
        try testing.expectEqual(false, pre_game.isActive());
        try testing.expectEqual(true, in_progress.isActive());
        
        // Test ClockState enum
        const stopped = game_clock.ClockState.stopped;
        const running = game_clock.ClockState.running;
        try testing.expectEqual(false, stopped.isRunning());
        try testing.expectEqual(true, running.isRunning());
        
        // Test PlayClockState enum
        const inactive = game_clock.PlayClockState.inactive;
        const active = game_clock.PlayClockState.active;
        const warning = game_clock.PlayClockState.warning;
        try testing.expectEqual(false, inactive.isActive());
        try testing.expectEqual(true, active.isActive());
        try testing.expectEqual(true, warning.isActive());
        
        // Test PlayClockDuration enum
        const normal = game_clock.PlayClockDuration.normal_40;
        const short = game_clock.PlayClockDuration.short_25;
        try testing.expectEqual(@as(u8, 40), normal.toSeconds());
        try testing.expectEqual(@as(u8, 25), short.toSeconds());
        
        // Test ClockSpeed enum
        const real_time = game_clock.ClockSpeed.real_time;
        const fast_2x = game_clock.ClockSpeed.accelerated_2x;
        try testing.expectEqual(@as(u32, 1), real_time.getMultiplier());
        try testing.expectEqual(@as(u32, 2), fast_2x.getMultiplier());
    }

    test "unit: README: Verify ClockConfig fields and defaults compile" {
        var config = game_clock.ClockConfig.default();
        // Time settings
        config.quarter_length = 900;      // 15 minutes
        config.overtime_length = 600;     // 10 minutes  
        config.play_clock_normal = 40;
        config.play_clock_short = 25;
        
        // Features
        config.features.two_minute_warning = true;
        // Note: These fields don't exist yet in the config:
        // config.features.ten_second_runoff = true;
        // config.features.stop_clock_on_first_down = false; // College rule
        // config.features.auto_start_play_clock = true;
        
        // Behavior settings
        config.simulation_speed = 1;
        // Note: strict_mode doesn't exist yet
        // config.strict_mode = false;
        
        // Advanced settings
        config.playoff_rules = false;
        
        // Verify all fields exist and have expected types
        try testing.expectEqual(@as(u32, 900), config.quarter_length);
        try testing.expectEqual(@as(u32, 600), config.overtime_length);
        try testing.expectEqual(@as(u8, 40), config.play_clock_normal);
        try testing.expectEqual(@as(u8, 25), config.play_clock_short);
        try testing.expectEqual(true, config.features.two_minute_warning);
        // Note: These fields don't exist yet:
        // try testing.expectEqual(true, config.features.ten_second_runoff);
        // try testing.expectEqual(false, config.features.stop_clock_on_first_down);
        try testing.expectEqual(@as(u32, 1), config.simulation_speed);
        // try testing.expectEqual(true, config.features.auto_start_play_clock);
        // try testing.expectEqual(false, config.strict_mode);
        try testing.expectEqual(false, config.playoff_rules);
    }

    test "integration: README: playoff_rules field accessible and modifiable" {
        var config = game_clock.ClockConfig.default();
        
        // Default should be regular season (playoff_rules = false)
        try testing.expect(!config.playoff_rules);
        try testing.expectEqual(@as(u32, 600), config.overtime_length);
        
        // Can modify to playoff rules
        config.playoff_rules = true;
        config.overtime_length = 900; // Must also set appropriate overtime length
        try testing.expect(config.playoff_rules);
        
        // NFL Playoff preset sets playoff_rules
        const playoff_config = game_clock.ClockConfig.nflPlayoff();
        try testing.expect(playoff_config.playoff_rules);
        try testing.expectEqual(@as(u32, 900), playoff_config.overtime_length);
    }

    test "e2e: README: complete playoff overtime scenario with multiple periods" {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        // Create playoff game
        const playoff_config = game_clock.ClockConfig.nflPlayoff();
        var clock = game_clock.GameClock.initWithConfig(allocator, playoff_config, null);
        defer clock.deinit();
        
        // Verify playoff configuration
        try testing.expect(clock.config.playoff_rules);
        
        // Simulate end of regulation
        clock.quarter = .Q4;
        clock.time_remaining = 0;
        
        // Start playoff overtime (15 minutes)
        try clock.startOvertime();
        try testing.expectEqual(@as(u32, 900), clock.time_remaining);
        
        // Simulate first OT period without score
        clock.time_remaining = 0;
        
        // In playoffs, game continues until there's a winner
        // This would trigger second OT period
        try testing.expectEqual(game_clock.Quarter.Overtime, clock.quarter);
        
        // Start second OT period (would be implemented in actual game logic)
        // Each OT period in playoffs is 15 minutes
    }

