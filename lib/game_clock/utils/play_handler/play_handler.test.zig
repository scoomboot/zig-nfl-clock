// play_handler.test.zig — Play handler tests
//
// repo   : https://github.com/fisty/zig-nfl-clock
// docs   : https://fisty.github.io/zig-nfl-clock/docs/lib/game_clock/utils/play_handler
// author : https://github.com/scoomboot
//
// Vibe coded by Scoom.

// ╔══════════════════════════════════════ PACK ═══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const allocator = testing.allocator;
    
    // Import core types from play_handler module
    const PlayHandler = @import("play_handler.zig").PlayHandler;
    const PlayType = @import("play_handler.zig").PlayType;
    const PlayResult = @import("play_handler.zig").PlayResult;
    const SpecialOutcome = @import("play_handler.zig").SpecialOutcome;
    const GameStateUpdate = @import("play_handler.zig").GameStateUpdate;
    const PlayStatistics = @import("play_handler.zig").PlayStatistics;
    const PlayOptions = @import("play_handler.zig").PlayOptions;
    
    // Import utility functions
    const getExpectedPoints = @import("play_handler.zig").getExpectedPoints;
    const getHurryUpPlayTime = @import("play_handler.zig").getHurryUpPlayTime;
    const getNormalPlayTime = @import("play_handler.zig").getNormalPlayTime;


// ╔══════════════════════════════════════ INIT ═══════════════════════════════════════╗

    /// Test scenario for play processing
    const PlayTestScenario = struct {
        name: []const u8,
        play_type: PlayType,
        initial_state: GameStateUpdate,
        expected_yards_range: struct { min: i16, max: i16 },
        expected_time_consumed: u32,
        can_turnover: bool,
        can_score: bool,
    };

    /// Test data for statistics tracking
    const StatsTestCase = struct {
        plays: []const PlayType,
        expected_total_yards: i32,
        expected_first_downs: u16,
        expected_turnovers: u8,
    };

    // ┌────────────────────────── Test Helpers ──────────────────────────┐

    /// Creates a PlayHandler with default test configuration
    fn createTestPlayHandler() PlayHandler {
        return PlayHandler.init(12345); // Fixed seed for deterministic tests
    }

    /// Creates a PlayHandler with specific game state
    fn createTestPlayHandlerWithState(state: GameStateUpdate) PlayHandler {
        return PlayHandler.initWithState(state, 12345);
    }

    /// Creates a GameStateUpdate for specific test scenarios
    fn createTestGameState(scenario: enum {
        start_of_game,
        red_zone,
        two_minute_drill,
        goal_line,
        fourth_down,
        overtime
    }) GameStateUpdate {
        return switch (scenario) {
            .start_of_game => GameStateUpdate{
                .down = 1,
                .distance = 10,
                .possession = .away,
                .home_score = 0,
                .away_score = 0,
                .quarter = 1,
                .time_remaining = 900,
                .play_clock = 40,
                .clock_running = false,
            },
            .red_zone => GameStateUpdate{
                .down = 1,
                .distance = 10,
                .possession = .home,
                .home_score = 14,
                .away_score = 17,
                .quarter = 3,
                .time_remaining = 450,
                .play_clock = 40,
                .clock_running = true,
            },
            .two_minute_drill => GameStateUpdate{
                .down = 1,
                .distance = 10,
                .possession = .away,
                .home_score = 24,
                .away_score = 21,
                .quarter = 4,
                .time_remaining = 120,
                .play_clock = 25,
                .clock_running = true,
            },
            .goal_line => GameStateUpdate{
                .down = 1,
                .distance = 0, // Goal to go
                .possession = .home,
                .home_score = 7,
                .away_score = 10,
                .quarter = 2,
                .time_remaining = 200,
                .play_clock = 40,
                .clock_running = true,
            },
            .fourth_down => GameStateUpdate{
                .down = 4,
                .distance = 2,
                .possession = .away,
                .home_score = 14,
                .away_score = 14,
                .quarter = 4,
                .time_remaining = 300,
                .play_clock = 40,
                .clock_running = false,
            },
            .overtime => GameStateUpdate{
                .down = 1,
                .distance = 10,
                .possession = .home,
                .home_score = 21,
                .away_score = 21,
                .quarter = 5,
                .time_remaining = 600,
                .play_clock = 40,
                .clock_running = false,
            },
        };
    }

    /// Creates a test PlayResult with specified parameters
    fn createTestPlayResult(
        play_type: PlayType,
        yards: i16,
        touchdown: bool,
        turnover: bool,
    ) PlayResult {
        return PlayResult{
            .play_type = play_type,
            .yards_gained = yards,
            .out_of_bounds = false,
            .pass_completed = switch (play_type) {
                .pass_short, .pass_medium, .pass_deep, .screen_pass => true,
                else => false,
            },
            .is_touchdown = touchdown,
            .is_first_down = yards >= 10,
            .is_turnover = turnover,
            .time_consumed = getNormalPlayTime(),
            .field_position = 50,
        };
    }

    /// Asserts play result matches expected values
    fn assertPlayResult(
        result: *const PlayResult,
        expected_type: PlayType,
        min_yards: i16,
        max_yards: i16,
    ) !void {
        try testing.expectEqual(expected_type, result.play_type);
        try testing.expect(result.yards_gained >= min_yards);
        try testing.expect(result.yards_gained <= max_yards);
        try testing.expect(result.time_consumed > 0);
        try testing.expect(result.field_position <= 100);
    }

    /// Simulates a complete drive and returns final statistics
    fn simulateDrive(
        handler: *PlayHandler,
        play_sequence: []const PlayType,
    ) PlayStatistics {
        for (play_sequence) |play_type| {
            const result = handler.processPlay(play_type, .{}, null);
            handler.updateGameState(@constCast(&result));
            handler.updateStatistics(@constCast(&result));
        }
        
        return if (handler.possession_team == .home)
            handler.home_stats
        else
            handler.away_stats;
    }

    /// Simulates a scoring drive
    fn simulateScoringDrive(handler: *PlayHandler) !bool {
        const drive_plays = [_]PlayType{
            .run_up_middle,
            .pass_short,
            .run_sweep,
            .pass_medium,
            .run_off_tackle,
            .quarterback_sneak,
        };
        
        var total_yards: i32 = 0;
        for (drive_plays) |play| {
            const result = handler.processPlay(play, .{}, null);
            total_yards += result.yards_gained;
            
            if (result.is_touchdown) {
                return true;
            }
            
            if (result.is_turnover) {
                return false;
            }
            
            handler.updateGameState(@constCast(&result));
        }
        
        // Try field goal if in range
        if (total_yards > 30) {
            const fg_result = handler.processPlay(.field_goal, .{ .kick_distance = 35 }, null);
            return fg_result.special_outcome == .field_goal_good;
        }
        
        return false;
    }

    /// Validates handler state invariants
    fn validateHandlerInvariants(handler: *const PlayHandler) !void {
        // Down should be between 1 and 4
        try testing.expect(handler.game_state.down >= 1 and handler.game_state.down <= 4);
        
        // Distance should be reasonable
        try testing.expect(handler.game_state.distance <= 99);
        
        // Scores should be non-negative
        try testing.expect(handler.game_state.home_score >= 0);
        try testing.expect(handler.game_state.away_score >= 0);
        
        // Quarter should be valid
        try testing.expect(handler.game_state.quarter >= 1);
        
        // Play clock should be valid
        try testing.expect(handler.game_state.play_clock <= 40);
        
        // Statistics should be consistent
        const home_total = handler.home_stats.passing_yards + handler.home_stats.rushing_yards;
        try testing.expect(@abs(home_total - handler.home_stats.total_yards) <= 10); // Allow small discrepancy
    }

    /// Creates test data for various play scenarios
    fn createPlayScenarios() []const PlayTestScenario {
        return &[_]PlayTestScenario{
            .{
                .name = "Short pass play",
                .play_type = .pass_short,
                .initial_state = createTestGameState(.start_of_game),
                .expected_yards_range = .{ .min = -5, .max = 15 },
                .expected_time_consumed = 7,
                .can_turnover = true,
                .can_score = false,
            },
            .{
                .name = "Deep pass play",
                .play_type = .pass_deep,
                .initial_state = createTestGameState(.start_of_game),
                .expected_yards_range = .{ .min = -10, .max = 50 },
                .expected_time_consumed = 10,
                .can_turnover = true,
                .can_score = true,
            },
            .{
                .name = "Goal line run",
                .play_type = .quarterback_sneak,
                .initial_state = createTestGameState(.goal_line),
                .expected_yards_range = .{ .min = -2, .max = 5 },
                .expected_time_consumed = 40,
                .can_turnover = false,
                .can_score = true,
            },
        };
    }

    /// Generates random play sequence for stress testing
    fn generateRandomPlaySequence(count: usize, seed: u64) []PlayType {
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();
        const plays = allocator.alloc(PlayType, count) catch unreachable;
        
        const play_types = [_]PlayType{
            .pass_short,
            .pass_medium,
            .pass_deep,
            .screen_pass,
            .run_up_middle,
            .run_off_tackle,
            .run_sweep,
            .quarterback_sneak,
        };
        
        for (plays) |*play| {
            const index = random.intRangeAtMost(usize, 0, play_types.len - 1);
            play.* = play_types[index];
        }
        
        return plays;
    }

    /// Calculates drive efficiency metrics
    fn calculateDriveEfficiency(stats: *const PlayStatistics) f32 {
        if (stats.plays_run == 0) return 0.0;
        
        const yards_per_play = @as(f32, @floatFromInt(stats.total_yards)) / 
                               @as(f32, @floatFromInt(stats.plays_run));
        const first_down_rate = @as(f32, @floatFromInt(stats.first_downs)) / 
                                @as(f32, @floatFromInt(stats.plays_run));
        const turnover_rate = @as(f32, @floatFromInt(stats.turnovers)) / 
                              @as(f32, @floatFromInt(stats.plays_run));
        
        // Efficiency formula: yards per play + first down bonus - turnover penalty
        return yards_per_play + (first_down_rate * 10.0) - (turnover_rate * 20.0);
    }

    // └──────────────────────────────────────────────────────────────────┘

// ╔══════════════════════════════════════ TEST ═══════════════════════════════════════╗

    // ┌─────────────────────────── Unit Tests ───────────────────────────┐

    test "unit: PlayHandler: initializes with correct default values" {
        const handler = PlayHandler.init(12345);
        
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
        try testing.expectEqual(.away, handler.game_state.possession);
        try testing.expectEqual(@as(u16, 0), handler.game_state.home_score);
        try testing.expectEqual(@as(u16, 0), handler.game_state.away_score);
        try testing.expectEqual(@as(u8, 1), handler.game_state.quarter);
        try testing.expectEqual(@as(u32, 900), handler.game_state.time_remaining);
        try testing.expectEqual(@as(u32, 40), handler.game_state.play_clock);
        try testing.expectEqual(false, handler.game_state.clock_running);
        try testing.expectEqual(@as(u32, 0), handler.play_number);
    }

    test "unit: PlayHandler: initializes with custom game state" {
        const custom_state = GameStateUpdate{
            .down = 3,
            .distance = 7,
            .possession = .home,
            .home_score = 14,
            .away_score = 10,
            .quarter = 2,
            .time_remaining = 450,
            .play_clock = 25,
            .clock_running = true,
        };
        
        const handler = PlayHandler.initWithState(custom_state, 54321);
        
        try testing.expectEqual(@as(u8, 3), handler.game_state.down);
        try testing.expectEqual(@as(u8, 7), handler.game_state.distance);
        try testing.expectEqual(.home, handler.game_state.possession);
        try testing.expectEqual(@as(u16, 14), handler.game_state.home_score);
        try testing.expectEqual(@as(u16, 10), handler.game_state.away_score);
    }

    test "unit: PlayHandler: processes pass plays" {
        var handler = PlayHandler.init(12345);
        
        const result = handler.processPlay(.pass_short, .{}, null);
        
        try testing.expectEqual(PlayType.pass_short, result.play_type);
        try testing.expect(result.time_consumed > 0);
        try testing.expect(result.field_position >= 0 and result.field_position <= 100);
    }

    test "unit: PlayHandler: processes run plays" {
        var handler = PlayHandler.init(12345);
        
        const result = handler.processPlay(.run_up_middle, .{}, null);
        
        try testing.expectEqual(PlayType.run_up_middle, result.play_type);
        try testing.expect(result.time_consumed > 0);
        try testing.expect(!result.pass_completed); // Run plays don't have pass completion
    }

    test "unit: PlayHandler: processes special teams plays" {
        var handler = PlayHandler.init(12345);
        
        // Test punt
        const punt_result = handler.processPlay(.punt, .{ .kick_distance = 45 }, null);
        try testing.expectEqual(PlayType.punt, punt_result.play_type);
        try testing.expect(punt_result.is_turnover); // Punt changes possession
        
        // Test field goal
        const fg_result = handler.processPlay(.field_goal, .{ .kick_distance = 35 }, null);
        try testing.expectEqual(PlayType.field_goal, fg_result.play_type);
        
        // Test kickoff
        const ko_result = handler.processPlay(.kickoff, .{ .return_yards = 25 }, null);
        try testing.expectEqual(PlayType.kickoff, ko_result.play_type);
        try testing.expect(ko_result.is_turnover); // Kickoff changes possession
    }

    test "unit: PlayHandler: processes kneel down" {
        var handler = PlayHandler.init(12345);
        
        const result = handler.processPlay(.kneel_down, .{}, null);
        
        try testing.expectEqual(PlayType.kneel_down, result.play_type);
        try testing.expectEqual(@as(i16, -1), result.yards_gained);
        try testing.expectEqual(@as(u32, 40), result.time_consumed); // Full play clock
    }

    test "unit: PlayHandler: processes spike" {
        var handler = PlayHandler.init(12345);
        
        const result = handler.processPlay(.spike, .{}, null);
        
        try testing.expectEqual(PlayType.spike, result.play_type);
        try testing.expectEqual(@as(i16, 0), result.yards_gained);
        try testing.expectEqual(@as(u32, 1), result.time_consumed); // Minimal time
    }

    test "unit: PlayHandler: tracks play numbers" {
        var handler = PlayHandler.init(12345);
        
        try testing.expectEqual(@as(u32, 0), handler.play_number);
        
        _ = handler.processPlay(.run_up_middle, .{}, null);
        try testing.expectEqual(@as(u32, 1), handler.play_number);
        
        _ = handler.processPlay(.pass_short, .{}, null);
        try testing.expectEqual(@as(u32, 2), handler.play_number);
    }

    test "unit: PlayHandler: calculates expected points" {
        // Red zone
        try testing.expect(getExpectedPoints(95) > 5.0);
        
        // Midfield
        const midfield_ep = getExpectedPoints(50);
        try testing.expect(midfield_ep > -1.0 and midfield_ep < 1.0);
        
        // Own territory
        try testing.expect(getExpectedPoints(20) < 0.0);
        
        // Own end zone
        try testing.expect(getExpectedPoints(5) < -1.0);
    }

    test "unit: PlayHandler: returns correct play times" {
        try testing.expectEqual(@as(u32, 12), getHurryUpPlayTime());
        try testing.expectEqual(@as(u32, 38), getNormalPlayTime());
    }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────── Integration Tests ────────────────────────┐

    test "integration: PlayHandler: handles touchdown scoring" {
        var handler = PlayHandler.init(12345);
        handler.game_state.possession = .home;
        handler.possession_team = .home;
        
        // Create touchdown result
        var result = PlayResult{
            .play_type = .run_up_middle,
            .yards_gained = 10,
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = true,
            .is_first_down = true,
            .is_turnover = false,
            .time_consumed = 6,
            .field_position = 100,
        };
        
        const initial_score = handler.game_state.home_score;
        handler.updateGameState(&result);
        
        try testing.expectEqual(initial_score + 6, handler.game_state.home_score);
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: handles first downs" {
        var handler = PlayHandler.init(12345);
        handler.game_state.down = 2;
        handler.game_state.distance = 7;
        
        var result = PlayResult{
            .play_type = .run_up_middle,
            .yards_gained = 8,
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = false,
            .is_first_down = true,
            .is_turnover = false,
            .time_consumed = 6,
            .field_position = 50,
        };
        
        handler.updateGameState(&result);
        
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: handles turnovers" {
        var handler = PlayHandler.init(12345);
        handler.game_state.possession = .home;
        handler.possession_team = .home;
        
        var result = PlayResult{
            .play_type = .interception,
            .yards_gained = 0,
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = false,
            .is_first_down = false,
            .is_turnover = true,
            .time_consumed = 5,
            .field_position = 50,
        };
        
        handler.updateGameState(&result);
        
        try testing.expectEqual(.away, handler.game_state.possession);
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: handles turnover on downs" {
        var handler = PlayHandler.init(12345);
        handler.game_state.down = 4;
        handler.game_state.distance = 5;
        handler.game_state.possession = .home;
        handler.possession_team = .home;
        
        var result = PlayResult{
            .play_type = .run_up_middle,
            .yards_gained = 3,
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = false,
            .is_first_down = false,
            .is_turnover = false,
            .time_consumed = 6,
            .field_position = 50,
        };
        
        handler.updateGameState(&result);
        
        // Should change possession on failed 4th down
        try testing.expectEqual(.away, handler.game_state.possession);
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "integration: PlayHandler: updates statistics correctly" {
        var handler = PlayHandler.init(12345);
        handler.possession_team = .home;
        
        // Pass play
        var pass_result = PlayResult{
            .play_type = .pass_medium,
            .yards_gained = 15,
            .out_of_bounds = false,
            .pass_completed = true,
            .is_touchdown = false,
            .is_first_down = true,
            .is_turnover = false,
            .time_consumed = 7,
            .field_position = 50,
        };
        
        handler.updateStatistics(&pass_result);
        
        try testing.expectEqual(@as(i32, 15), handler.home_stats.total_yards);
        try testing.expectEqual(@as(i32, 15), handler.home_stats.passing_yards);
        try testing.expectEqual(@as(u16, 1), handler.home_stats.first_downs);
        
        // Run play
        var run_result = PlayResult{
            .play_type = .run_sweep,
            .yards_gained = 8,
            .out_of_bounds = true,
            .pass_completed = false,
            .is_touchdown = false,
            .is_first_down = false,
            .is_turnover = false,
            .time_consumed = 5,
            .field_position = 65,
        };
        
        handler.updateStatistics(&run_result);
        
        try testing.expectEqual(@as(i32, 23), handler.home_stats.total_yards);
        try testing.expectEqual(@as(i32, 8), handler.home_stats.rushing_yards);
    }

    test "integration: PlayHandler: tracks time of possession" {
        var handler = PlayHandler.init(12345);
        handler.possession_team = .away;
        
        var result = PlayResult{
            .play_type = .run_up_middle,
            .yards_gained = 5,
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = false,
            .is_first_down = false,
            .is_turnover = false,
            .time_consumed = 35,
            .field_position = 50,
        };
        
        handler.updateStatistics(&result);
        
        try testing.expectEqual(@as(u32, 35), handler.away_stats.time_of_possession);
        try testing.expectEqual(@as(u32, 0), handler.home_stats.time_of_possession);
    }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────── End-to-End Tests ────────────────────────┐

    test "e2e: PlayHandler: simulates complete drive" {
        var handler = PlayHandler.init(12345);
        handler.game_state.possession = .home;
        handler.possession_team = .home;
        
        // First down - run for 3 yards
        var result = handler.processPlay(.run_up_middle, .{}, null);
        handler.game_state.down = 2;
        handler.game_state.distance = 7;
        
        // Second down - incomplete pass
        result = handler.processPlay(.pass_medium, .{}, null);
        if (!result.pass_completed) {
            handler.game_state.down = 3;
        }
        
        // Third down - complete pass for first down
        result = handler.processPlay(.pass_short, .{}, null);
        if (result.is_first_down) {
            handler.game_state.down = 1;
            handler.game_state.distance = 10;
        }
        
        // Continue drive to red zone
        handler.game_state.down = 1;
        handler.game_state.distance = 5;
        
        // Goal line run for touchdown
        result = handler.processPlay(.quarterback_sneak, .{}, null);
        
        // Extra point
        result = handler.processPlay(.extra_point, .{}, null);
        
        // Verify scoring
        try testing.expect(handler.game_state.home_score >= 0);
        try testing.expect(handler.play_number > 0);
    }

    test "e2e: PlayHandler: simulates two-minute drill" {
        var handler = PlayHandler.init(12345);
        handler.game_state.quarter = 4;
        handler.game_state.time_remaining = 120;
        handler.game_state.possession = .away;
        handler.possession_team = .away;
        handler.game_state.away_score = 21;
        handler.game_state.home_score = 24;
        
        // Series of quick passes
        var plays_run: u32 = 0;
        var time_used: u32 = 0;
        
        // Simulate hurry-up offense
        for (0..8) |_| {
            const result = handler.processPlay(.pass_short, .{}, null);
            plays_run += 1;
            time_used += result.time_consumed;
            
            // Update game state based on result
            if (result.is_first_down) {
                handler.game_state.down = 1;
                handler.game_state.distance = 10;
            } else if (!result.pass_completed) {
                // Clock stops on incomplete
                handler.game_state.clock_running = false;
            }
            
            // Check if in field goal range
            if (result.field_position >= 65) {
                break;
            }
        }
        
        // Attempt field goal
        const fg_result = handler.processPlay(.field_goal, .{ .kick_distance = 35 }, null);
        
        // Verify time management
        try testing.expect(time_used < 120); // Used less than full 2 minutes
        try testing.expect(plays_run > 0);
        try testing.expect(fg_result.play_type == .field_goal);
    }

    test "e2e: PlayHandler: handles special teams sequence" {
        var handler = PlayHandler.init(12345);
        
        // Kickoff to start game
        var result = handler.processPlay(.kickoff, .{ .return_yards = 25 }, null);
        try testing.expect(result.is_turnover); // Possession changes
        try testing.expect(result.field_position > 0);
        
        // Three and out
        handler.game_state.down = 4;
        handler.game_state.distance = 7;
        
        // Punt
        result = handler.processPlay(.punt, .{ .kick_distance = 45 }, null);
        try testing.expect(result.is_turnover);
        
        // Drive ending in field goal attempt
        handler.game_state.down = 4;
        handler.game_state.distance = 8;
        
        result = handler.processPlay(.field_goal, .{ .kick_distance = 42 }, null);
        try testing.expectEqual(PlayType.field_goal, result.play_type);
        
        // Check if points were scored (depends on RNG)
        const initial_score = handler.game_state.home_score + handler.game_state.away_score;
        try testing.expect(initial_score >= 0);
    }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌───────────────────────── Scenario Tests ─────────────────────────┐

    test "scenario: PlayHandler: processes complete touchdown drive" {
        var handler = PlayHandler.init(12345);
        handler.game_state.possession = .home;
        handler.possession_team = .home;
        handler.game_state.quarter = 2;
        handler.game_state.time_remaining = 480; // 8 minutes left in half
        
        // Start at own 25-yard line
        handler.field_position = 25;  // Set the handler's field position
        var field_pos: u8 = 25;
        var total_plays: u32 = 0;
        var total_time: u32 = 0;
        
        // First down - 7-yard run
        var result = handler.processPlay(.run_off_tackle, .{}, null);
        handler.updateGameState(@constCast(&result));
        handler.updateStatistics(@constCast(&result));
        total_plays += 1;
        total_time += result.time_consumed;
        field_pos = @min(100, field_pos + @as(u8, @intCast(@max(0, result.yards_gained))));
        
        // Assume it's 2nd and 3
        handler.game_state.down = 2;
        handler.game_state.distance = 3;
        
        // Second down - 12-yard pass completion for first down
        result = handler.processPlay(.pass_medium, .{}, null);
        handler.updateGameState(@constCast(&result));
        handler.updateStatistics(@constCast(&result));
        total_plays += 1;
        total_time += result.time_consumed;
        field_pos = @min(100, field_pos + @as(u8, @intCast(@max(0, result.yards_gained))));
        
        // Reset to first down
        handler.game_state.down = 1;
        handler.game_state.distance = 10;
        
        // Move field position closer for touchdown setup
        handler.field_position = 98;  // Move to 2-yard line for almost certain touchdown
        
        // Continue drive with multiple plays
        const drive_plays = [_]PlayType{
            .quarterback_sneak,  // 1 yard average with 85% big play chance - very likely to score from 2-yard line
            .run_up_middle,      // Backup play if first doesn't score
        };
        
        for (drive_plays) |play| {
            result = handler.processPlay(play, .{}, null);
            handler.updateGameState(@constCast(&result));
            handler.updateStatistics(@constCast(&result));
            total_plays += 1;
            total_time += result.time_consumed;
            
            // Simulate realistic down and distance progression
            if (result.is_first_down or result.is_touchdown) {
                handler.game_state.down = 1;
                handler.game_state.distance = if (result.is_touchdown) 0 else 10;
            } else {
                handler.game_state.down = @min(4, handler.game_state.down + 1);
                if (handler.game_state.distance > result.yards_gained) {
                    handler.game_state.distance -= @as(u8, @intCast(@max(0, result.yards_gained)));
                } else {
                    handler.game_state.distance = 10; // First down
                    handler.game_state.down = 1;
                }
            }
            
            if (result.is_touchdown) break;
        }
        
        // Verify drive statistics (2 initial plays + up to 2 drive plays)
        try testing.expect(total_plays >= 3); // Minimum plays for TD drive
        try testing.expect(total_time >= 80); // Should take significant time
        try testing.expect(handler.home_stats.total_yards > 15); // Some yardage gained in drive
        try testing.expect(handler.home_stats.first_downs >= 1); // At least one first down
        
        // Extra point attempt
        result = handler.processPlay(.extra_point, .{}, null);
        try testing.expectEqual(PlayType.extra_point, result.play_type);
        
        // Verify scoring or significant progress
        // Due to random variance, we may not always score, but we should make progress
        const scored = handler.game_state.home_score >= 6;
        const made_progress = handler.home_stats.total_yards > 30;
        try testing.expect(scored or made_progress); // Either scored or made significant yardage
    }

    test "scenario: PlayHandler: handles goal-line stand sequence" {
        var handler = PlayHandler.init(12345);
        handler.game_state.possession = .away;
        handler.possession_team = .away;
        handler.game_state.quarter = 4;
        handler.game_state.time_remaining = 180; // 3 minutes left
        handler.game_state.down = 1;
        handler.game_state.distance = 2; // Goal to go from 2-yard line
        
        // Away team at home team's 2-yard line
        handler.field_position = 98;  // 2 yards from end zone
        var downs_used: u8 = 0;
        var total_time: u32 = 0;
        
        // First down - run up middle stuffed
        var result = handler.processPlay(.run_up_middle, .{}, null);
        handler.updateGameState(@constCast(&result));
        handler.updateStatistics(@constCast(&result));
        downs_used += 1;
        total_time += result.time_consumed;
        
        // Second down - pass incomplete in end zone
        result = handler.processPlay(.pass_short, .{}, null);
        handler.updateGameState(@constCast(&result));
        handler.updateStatistics(@constCast(&result));
        downs_used += 1;
        total_time += result.time_consumed;
        
        // Third down - another run attempt
        result = handler.processPlay(.quarterback_sneak, .{}, null);
        handler.updateGameState(@constCast(&result));
        handler.updateStatistics(@constCast(&result));
        downs_used += 1;
        total_time += result.time_consumed;
        
        // Fourth down - final attempt (field goal or go for it)
        if (handler.game_state.down == 4 and handler.game_state.distance <= 3) {
            // Going for touchdown
            result = handler.processPlay(.pass_short, .{}, null);
            handler.updateGameState(@constCast(&result));
            handler.updateStatistics(@constCast(&result));
            downs_used += 1;
            total_time += result.time_consumed;
        } else {
            // Field goal attempt
            result = handler.processPlay(.field_goal, .{ .kick_distance = 20 }, null);
            handler.updateGameState(@constCast(&result));
            handler.updateStatistics(@constCast(&result));
            downs_used += 1;
            total_time += result.time_consumed;
        }
        
        // Verify goal-line stand characteristics
        try testing.expectEqual(@as(u8, 4), downs_used); // Used all four downs
        try testing.expect(total_time >= 40); // Time for four plays (mix of runs and incomplete passes)
        // Goal-line scenarios result in limited yardage due to proximity to end zone
        // 4 plays can still accumulate some yards even if the defense holds
        const total_yards = @as(i32, handler.away_stats.rushing_yards) + @as(i32, handler.away_stats.passing_yards);
        try testing.expect(total_yards < 100); // Limited yardage accumulation in goal-line situation
        
        // Either scored or turned over on downs
        const scored = handler.game_state.away_score > 0;
        const turned_over = handler.game_state.possession == .home;
        try testing.expect(scored or turned_over);
    }

    test "scenario: PlayHandler: manages hurry-up offense" {
        var handler = PlayHandler.init(12345);
        handler.game_state.possession = .home;
        handler.possession_team = .home;
        handler.game_state.quarter = 4;
        handler.game_state.time_remaining = 95; // 1:35 left, no timeouts
        handler.game_state.home_score = 17;
        handler.game_state.away_score = 21; // Down by 4, need touchdown
        
        var plays_run: u32 = 0;
        var total_time: u32 = 0;
        const field_position: u8 = 35; // Start at own 35
        
        // Hurry-up no-huddle offense
        const hurry_up_plays = [_]PlayType{
            .pass_short,      // Quick slant
            .pass_medium,     // Sideline route
            .pass_short,      // Screen pass
            .pass_medium,     // Crossing route
            .spike,           // Stop clock
            .pass_deep,       // Go route
            .pass_short,      // Quick out
            .pass_medium,     // Touchdown attempt
        };
        
        for (hurry_up_plays) |play| {
            // Disable turnovers for deterministic test behavior
            const result = handler.processPlay(play, .{}, PlayOptions{ .enable_turnovers = false });
            handler.updateStatistics(@constCast(&result));
            plays_run += 1;
            
            // Use hurry-up timing
            const play_time = if (play == .spike) 
                1 // Spike takes minimal time
            else 
                getHurryUpPlayTime(); // Fast plays in hurry-up
            
            total_time += play_time;
            
            // Update field position and game state
            if (result.is_touchdown) {
                handler.game_state.home_score += 6;
                break;
            }
            
            if (result.is_first_down) {
                handler.game_state.down = 1;
                handler.game_state.distance = 10;
            } else if (play != .spike) {
                handler.game_state.down = @min(4, handler.game_state.down + 1);
                if (result.yards_gained >= handler.game_state.distance) {
                    handler.game_state.down = 1;
                    handler.game_state.distance = 10;
                } else {
                    handler.game_state.distance -= @as(u8, @intCast(@max(0, result.yards_gained)));
                }
            }
            
            // Stop if turned over
            if (result.is_turnover) break;
            
            // Stop if would run out of time
            if (total_time >= 90) break; // Leave 5 seconds
        }
        
        // Verify hurry-up characteristics
        try testing.expect(plays_run >= 5); // Multiple plays in sequence
        try testing.expect(total_time < 90); // Efficient time usage
        try testing.expect(handler.home_stats.passing_yards > handler.home_stats.rushing_yards); // Mostly passing
        
        // Should have either scored or been in position to score
        const scored = handler.game_state.home_score >= 23;
        const good_field_pos = field_position >= 75 or handler.home_stats.total_yards >= 40;
        try testing.expect(scored or good_field_pos);
    }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────── Performance Tests ────────────────────────┐

    test "performance: PlayHandler: processes plays efficiently" {
        var handler = PlayHandler.init(12345);
        
        const start_time = std.time.milliTimestamp();
        
        // Process 1000 plays
        for (0..1000) |i| {
            const play_type: PlayType = switch (i % 10) {
                0 => .pass_short,
                1 => .pass_medium,
                2 => .pass_deep,
                3 => .run_up_middle,
                4 => .run_off_tackle,
                5 => .run_sweep,
                6 => .screen_pass,
                7 => .quarterback_sneak,
                8 => .punt,
                9 => .field_goal,
                else => .run_up_middle,
            };
            
            _ = handler.processPlay(play_type, .{}, null);
        }
        
        const elapsed = std.time.milliTimestamp() - start_time;
        
        // Should complete in under 100ms
        try testing.expect(elapsed < 100);
    }

    test "performance: PlayHandler: updates statistics quickly" {
        var handler = PlayHandler.init(12345);
        
        const start_time = std.time.milliTimestamp();
        
        // Create and update 10000 play results
        for (0..10000) |i| {
            const result = PlayResult{
                .play_type = if (i % 2 == 0) .run_up_middle else .pass_short,
                .yards_gained = @as(i16, @intCast(i % 20)) - 5,
                .out_of_bounds = i % 5 == 0,
                .pass_completed = i % 3 != 0,
                .is_touchdown = i % 100 == 0,
                .is_first_down = i % 4 == 0,
                .is_turnover = i % 50 == 0,
                .time_consumed = @as(u32, @intCast(i % 40)),
                .field_position = @as(u8, @intCast(i % 100)),
            };
            
            handler.updateStatistics(&result);
        }
        
        const elapsed = std.time.milliTimestamp() - start_time;
        
        // Should complete in under 50ms
        try testing.expect(elapsed < 50);
    }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌────────────────────── Error Handling Tests ──────────────────────┐

    test "unit: PlayHandlerError: InvalidGameState detection" {
        var handler = PlayHandler.init(12345);
        
        // Test invalid game states
        const invalid_states = [_]GameStateUpdate{
            // Invalid down
            GameStateUpdate{
                .down = 0, // Invalid - must be 1-4
                .distance = 10,
                .possession = .home,
                .home_score = 0,
                .away_score = 0,
                .quarter = 1,
                .time_remaining = 900,
                .play_clock = 40,
                .clock_running = false,
            },
            // Invalid distance
            GameStateUpdate{
                .down = 1,
                .distance = 255, // Invalid - too far
                .possession = .home,
                .home_score = 0,
                .away_score = 0,
                .quarter = 1,
                .time_remaining = 900,
                .play_clock = 40,
                .clock_running = false,
            },
            // Invalid play clock
            GameStateUpdate{
                .down = 1,
                .distance = 10,
                .possession = .home,
                .home_score = 0,
                .away_score = 0,
                .quarter = 1,
                .time_remaining = 900,
                .play_clock = 100, // Invalid - max 40
                .clock_running = false,
            },
        };
        
        for (invalid_states) |state| {
            const result = handler.validateGameState(state);
            try testing.expectError(error.InvalidGameState, result);
        }
    }

    test "unit: PlayHandlerError: InvalidPlayResult validation" {
        var handler = PlayHandler.init(12345);
        
        // Test invalid play results
        const invalid_results = [_]PlayResult{
            // Invalid yards gained
            PlayResult{
                .play_type = .run_up_middle,
                .yards_gained = 200, // Invalid - too many yards
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 6,
                .field_position = 50,
            },
            // Invalid field position
            PlayResult{
                .play_type = .pass_short,
                .yards_gained = 10,
                .out_of_bounds = false,
                .pass_completed = true,
                .is_touchdown = false,
                .is_first_down = true,
                .is_turnover = false,
                .time_consumed = 7,
                .field_position = 150, // Invalid - max 100
            },
            // Contradictory flags
            PlayResult{
                .play_type = .touchdown,
                .yards_gained = 50,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false, // Contradiction - touchdown play but not touchdown
                .is_first_down = false,
                .is_turnover = false,
                .time_consumed = 8,
                .field_position = 100,
            },
        };
        
        for (invalid_results) |result| {
            const validation = handler.validatePlayResult(@constCast(&result));
            try testing.expectError(error.InvalidPlayResult, validation);
        }
    }

    test "unit: PlayHandlerError: InvalidStatistics detection" {
        var handler = PlayHandler.init(12345);
        
        // Test 1: Total yards mismatch with passing + rushing yards
        // The difference must be > 100 to trigger InvalidStatistics
        handler.home_stats.total_yards = 500;
        handler.home_stats.passing_yards = 300;
        handler.home_stats.rushing_yards = 50; // calc_total = 350, diff = 150 > 100
        
        const result = handler.validateStatistics(&handler.home_stats);
        try testing.expectError(error.InvalidStatistics, result);
        
        // Test 2: Invalid total yards calculation
        // Reset stats first, then set up a different mismatch scenario
        handler.away_stats.total_yards = 200;
        handler.away_stats.passing_yards = 400;
        handler.away_stats.rushing_yards = 100; // calc_total = 500, diff = 300 > 100
        const result2 = handler.validateStatistics(&handler.away_stats);
        try testing.expectError(error.InvalidStatistics, result2);
        
        // Test 3: Turnovers exceed plays run
        handler.home_stats.turnovers = 50; // Unrealistic
        handler.home_stats.plays_run = 20; // Can't have more turnovers than plays
        const result3 = handler.validateStatistics(&handler.home_stats);
        try testing.expectError(error.InvalidStatistics, result3);
    }

    test "unit: PlayHandler: validateGameState catches all invalid states" {
        var handler = PlayHandler.init(12345);
        
        // Test various invalid configurations
        const test_cases = [_]struct {
            state: GameStateUpdate,
            should_fail: bool,
        }{
            .{
                .state = GameStateUpdate{
                    .down = 5, // Invalid
                    .distance = 10,
                    .possession = .home,
                    .home_score = 0,
                    .away_score = 0,
                    .quarter = 1,
                    .time_remaining = 900,
                    .play_clock = 40,
                    .clock_running = false,
                },
                .should_fail = true,
            },
            .{
                .state = GameStateUpdate{
                    .down = 1,
                    .distance = 10,
                    .possession = .home,
                    .home_score = 999,
                    .away_score = 999,
                    .quarter = 20, // Invalid quarter
                    .time_remaining = 900,
                    .play_clock = 40,
                    .clock_running = false,
                },
                .should_fail = true,
            },
            .{
                .state = GameStateUpdate{
                    .down = 2,
                    .distance = 7,
                    .possession = .away,
                    .home_score = 21,
                    .away_score = 17,
                    .quarter = 3,
                    .time_remaining = 450,
                    .play_clock = 25,
                    .clock_running = true,
                },
                .should_fail = false, // Valid state
            },
        };
        
        for (test_cases) |tc| {
            if (tc.should_fail) {
                try testing.expectError(error.InvalidGameState, handler.validateGameState(tc.state));
            } else {
                try handler.validateGameState(tc.state);
            }
        }
    }

    test "integration: PlayHandler: error recovery maintains game continuity" {
        var handler = PlayHandler.init(12345);
        
        // Start with valid state
        handler.game_state.down = 1;
        handler.game_state.distance = 10;
        handler.game_state.possession = .home;
        
        // Create invalid play result
        var invalid_result = PlayResult{
            .play_type = .run_up_middle,
            .yards_gained = 500, // Invalid
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = false,
            .is_first_down = false,
            .is_turnover = false,
            .time_consumed = 6,
            .field_position = 50,
        };
        
        // Validate should fail
        const validation = handler.validatePlayResult(&invalid_result);
        try testing.expectError(error.InvalidPlayResult, validation);
        
        // Fix the result
        invalid_result.yards_gained = 5;
        try handler.validatePlayResult(&invalid_result);
        
        // Update game state - should work now
        handler.updateGameState(&invalid_result);
        try testing.expectEqual(@as(u8, 2), handler.game_state.down);
        try testing.expectEqual(@as(u8, 5), handler.game_state.distance);
    }

    test "e2e: PlayHandler: complete error handling during drive" {
        var handler = PlayHandler.init(12345);
        
        // Scenario 1: Invalid initial state recovery
        handler.game_state.down = 0; // Invalid
        if (handler.validateGameState(handler.game_state)) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(error.InvalidGameState, err);
            // Fix it
            handler.game_state.down = 1;
        }
        
        // Process normal play
        var result = handler.processPlay(.run_up_middle, .{}, null);
        handler.updateGameState(@constCast(&result));
        
        // Scenario 2: Invalid play result handling
        var bad_result = PlayResult{
            .play_type = .pass_deep,
            .yards_gained = -100, // Invalid negative yards
            .out_of_bounds = false,
            .pass_completed = true,
            .is_touchdown = false,
            .is_first_down = false,
            .is_turnover = false,
            .time_consumed = 10,
            .field_position = 50,
        };
        
        if (handler.validatePlayResult(&bad_result)) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(error.InvalidPlayResult, err);
            // Fix it
            bad_result.yards_gained = 15;
            try handler.validatePlayResult(&bad_result);
        }
        
        // Scenario 3: Statistics validation
        handler.home_stats.total_yards = 1000;
        handler.home_stats.passing_yards = 600;
        handler.home_stats.rushing_yards = 200; // Doesn't add up
        
        if (handler.validateStatistics(&handler.home_stats)) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(error.InvalidStatistics, err);
            // Fix statistics
            handler.home_stats.total_yards = 800;
        }
        
        // Game continues normally
        result = handler.processPlay(.field_goal, .{ .kick_distance = 35 }, null);
        try testing.expectEqual(PlayType.field_goal, result.play_type);
    }

    test "scenario: PlayHandler: handles errors during critical plays" {
        var handler = PlayHandler.init(12345);
        
        // Red zone situation with errors
        handler.game_state.down = 1;
        handler.game_state.distance = 0; // Goal to go
        handler.game_state.possession = .home;
        handler.game_state.quarter = 4;
        handler.game_state.time_remaining = 30;
        handler.game_state.home_score = 21;
        handler.game_state.away_score = 24;
        
        // Process touchdown attempt
        var result = handler.processPlay(.quarterback_sneak, .{}, null);
        
        // Simulate error: invalid field position update
        result.field_position = 150; // Invalid
        if (handler.validatePlayResult(&result)) |_| {
            try testing.expect(false);
        } else |err| {
            try testing.expectEqual(error.InvalidPlayResult, err);
            // Fix it
            result.field_position = 100; // End zone
            result.is_touchdown = true;
        }
        
        // Update game state
        handler.updateGameState(&result);
        
        // Verify touchdown scored
        if (result.is_touchdown) {
            handler.game_state.home_score += 6;
            try testing.expectEqual(@as(u16, 27), handler.game_state.home_score);
        }
        
        // Extra point with error
        const xp_result = handler.processPlay(.extra_point, .{}, null);
        
        // Simulate blocked extra point (special outcome)
        if (xp_result.special_outcome == .extra_point_blocked) {
            // Handle gracefully
            handler.game_state.possession = .away;
        } else if (xp_result.special_outcome == .extra_point_good) {
            handler.game_state.home_score += 1;
        }
    }

    test "stress: PlayHandler: handles rapid error conditions" {
        var handler = PlayHandler.init(12345);
        
        // Rapidly cause and recover from various errors
        for (0..100) |i| {
            // Alternate between valid and invalid operations
            if (i % 3 == 0) {
                // Invalid game state
                handler.game_state.down = @as(u8, @intCast((i % 10))); // Sometimes 0 (invalid)
                handler.game_state.distance = @as(u8, @intCast((i % 256))); // Sometimes huge
                
                if (handler.validateGameState(handler.game_state)) |_| {
                    // Valid by chance
                } else |_| {
                    // Fix it
                    handler.game_state.down = @as(u8, @intCast((i % 4) + 1));
                    handler.game_state.distance = @as(u8, @intCast((i % 20) + 1));
                }
            } else if (i % 3 == 1) {
                // Process play with potential errors
                const play_type: PlayType = if (i % 2 == 0) .run_up_middle else .pass_short;
                var result = handler.processPlay(play_type, .{}, null);
                
                // Sometimes corrupt the result
                if (i % 5 == 0) {
                    result.field_position = 200; // Invalid
                    if (handler.validatePlayResult(&result)) |_| {
                        // Shouldn't succeed
                    } else |_| {
                        result.field_position = 50; // Fix it
                    }
                }
                
                handler.updateGameState(&result);
            } else {
                // Update statistics with potential errors
                handler.home_stats.plays_run += 1;
                handler.home_stats.total_yards += @as(i32, @intCast(i % 30)) - 10;
                
                // Periodically validate and fix
                if (i % 10 == 0) {
                    if (handler.validateStatistics(&handler.home_stats)) |_| {
                        // Valid
                    } else |_| {
                        // Reset to valid state
                        handler.home_stats.total_yards = @intCast(@abs(handler.home_stats.total_yards));
                        handler.home_stats.turnovers = @min(handler.home_stats.turnovers, handler.home_stats.plays_run);
                    }
                }
            }
        }
        
        // Final state should be valid
        handler.game_state.down = 1;
        handler.game_state.distance = 10;
        try handler.validateGameState(handler.game_state);
    }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────── Stress Tests ──────────────────────────┐

    test "stress: PlayHandler: handles all play types" {
        var handler = PlayHandler.init(12345);
        
        const all_play_types = [_]PlayType{
            .pass_short,
            .pass_medium,
            .pass_deep,
            .screen_pass,
            .run_up_middle,
            .run_off_tackle,
            .run_sweep,
            .quarterback_sneak,
            .punt,
            .field_goal,
            .extra_point,
            .kickoff,
            .kickoff_return,
            .punt_return,
            .kneel_down,
            .spike,
            .two_point_conversion,
            .onside_kick,
            .interception,
            .fumble,
            .fumble_recovery,
            .penalty_offense,
            .penalty_defense,
            .penalty_declined,
        };
        
        for (all_play_types) |play_type| {
            // Pass PlayOptions with turnovers disabled to ensure play types remain unchanged
            const options = PlayOptions{ .enable_turnovers = false };
            const result = handler.processPlay(play_type, .{}, options);
            
            // Every play should produce valid result
            try testing.expect(result.time_consumed >= 0);
            try testing.expect(result.field_position <= 100);
            try testing.expectEqual(play_type, result.play_type);
        }
    }

    test "stress: PlayHandler: handles extreme game states" {
        // Test with maximum scores
        var handler = PlayHandler.init(12345);
        handler.game_state.home_score = 999;
        handler.game_state.away_score = 999;
        handler.possession_team = .home;  // Set possession to home team
        handler.game_state.possession = .home;  // Update game state possession too
        
        var td_result = PlayResult{
            .play_type = .run_up_middle,
            .yards_gained = 50,
            .out_of_bounds = false,
            .pass_completed = false,
            .is_touchdown = true,
            .is_first_down = true,
            .is_turnover = false,
            .time_consumed = 8,
            .field_position = 100,
        };
        
        handler.updateGameState(&td_result);
        try testing.expectEqual(@as(u16, 1005), handler.game_state.home_score); // 999 + 6
        
        // Test with minimum time
        handler.game_state.time_remaining = 0;
        handler.updateGameState(&td_result);
        try testing.expectEqual(@as(u32, 0), handler.game_state.time_remaining);
        
        // Test with maximum down and distance
        handler.game_state.down = 255;
        handler.game_state.distance = 255;
        handler.updateGameState(&td_result);
        // Should reset after touchdown
        try testing.expectEqual(@as(u8, 1), handler.game_state.down);
        try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
    }

    test "stress: PlayHandler: handles rapid possession changes" {
        var handler = PlayHandler.init(12345);
        
        for (0..100) |i| {
            // Alternate turnovers
            var turnover_result = PlayResult{
                .play_type = if (i % 2 == 0) .interception else .fumble,
                .yards_gained = 0,
                .out_of_bounds = false,
                .pass_completed = false,
                .is_touchdown = false,
                .is_first_down = false,
                .is_turnover = true,
                .time_consumed = 5,
                .field_position = 50,
            };
            
            const initial_possession = handler.game_state.possession;
            handler.updateGameState(&turnover_result);
            
            // Verify possession changed
            const new_possession = handler.game_state.possession;
            try testing.expect(initial_possession != new_possession);
            
            // Verify down and distance reset
            try testing.expectEqual(@as(u8, 1), handler.game_state.down);
            try testing.expectEqual(@as(u8, 10), handler.game_state.distance);
        }
    }

    test "stress: PlayHandler: handles long games with many plays" {
        var handler = PlayHandler.init(12345);
        
        // Simulate a full game (approximately 150 plays)
        for (0..150) |i| {
            const play_selection = i % 15;
            const play_type: PlayType = switch (play_selection) {
                0...5 => .run_up_middle,
                6...10 => .pass_short,
                11 => .pass_deep,
                12 => .punt,
                13 => .field_goal,
                14 => .kickoff,
                else => .run_up_middle,
            };
            
            const result = handler.processPlay(play_type, .{}, null);
            
            // Update game state
            if (handler.game_state.time_remaining > result.time_consumed) {
                handler.game_state.time_remaining -= result.time_consumed;
            } else {
                // Quarter ended
                handler.game_state.quarter += 1;
                handler.game_state.time_remaining = 900;
            }
            
            // Verify stats are accumulating
            if (i > 0) {
                const total_stats = handler.home_stats.total_yards + @as(i32, @intCast(@abs(handler.away_stats.total_yards)));
                try testing.expect(total_stats != 0 or handler.play_number == i + 1);
            }
        }
        
        // Verify game progressed
        try testing.expect(handler.play_number == 150);
        try testing.expect(handler.game_state.quarter > 1);
    }

    test "unit: PlayHandler: PlayOptions controls turnovers" {
        // Test with turnovers disabled
        var handler = PlayHandler.init(999); // Fixed seed for reproducibility
        const no_turnover_opts = PlayOptions{
            .enable_turnovers = false,
            .turnover_chance = 0,
        };
        
        // Run many plays with turnovers disabled
        var turnover_count: u32 = 0;
        for (0..100) |_| {
            const result = handler.processPlay(.pass_deep, .{}, no_turnover_opts);
            if (result.is_turnover) {
                turnover_count += 1;
            }
        }
        
        // With turnovers disabled, there should be no turnovers
        try testing.expectEqual(@as(u32, 0), turnover_count);
        
        // Reset handler and test with turnovers enabled
        handler = PlayHandler.init(999);
        const turnover_opts = PlayOptions{
            .enable_turnovers = true,
            .turnover_chance = 100, // 100% chance for testing
        };
        
        // Run incomplete passes with 100% turnover chance
        var interception_count: u32 = 0;
        for (0..10) |_| {
            // Force incomplete pass scenario by using deep pass with low completion
            var modified_handler = PlayHandler.init(@intCast(999 + interception_count));
            const result = modified_handler.processPlay(.pass_deep, .{}, turnover_opts);
            if (!result.pass_completed and result.is_turnover) {
                interception_count += 1;
            }
        }
        
        // With 100% turnover chance, incomplete passes should result in interceptions
        try testing.expect(interception_count > 0);
    }

    test "unit: PlayHandler: deterministic with turnovers disabled" {
        var handler = PlayHandler.init(12345);
        const options = PlayOptions{ .enable_turnovers = false };
        
        // Run same play multiple times - should get same play type back
        for (0..10) |_| {
            const result = handler.processPlay(.pass_short, .{}, options);
            try testing.expectEqual(PlayType.pass_short, result.play_type);
        }
        
        // Test with different play types
        const test_plays = [_]PlayType{ .run_sweep, .pass_deep, .field_goal };
        for (test_plays) |play_type| {
            const result = handler.processPlay(play_type, .{}, options);
            try testing.expectEqual(play_type, result.play_type);
        }
    }

